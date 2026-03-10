`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Mini RISC-V SoC Top
// - VexRiscv as control CPU
// - Instruction ROM
// - System RAM shared with framebuffer
// - Memory-mapped HDMI control registers
// - HDMI output via existing HDMI_Encode module
//////////////////////////////////////////////////////////////////////////////////

module ChipTop (
    input  wire       sys_clk,        // 125 MHz
    input  wire       sys_resetn,     // active-low reset
    input wire uart_rx,

    output wire [2:0] hdmi_tx_p,
    output wire [2:0] hdmi_tx_n,
    output wire       hdmi_clk_p,
    output wire       hdmi_clk_n,

    input  wire       hdmi_tx_hpdn,
    output wire [1:0] led
);

    // ============================================================
    // 1. Clock / Reset
    // ============================================================
    wire clk   = sys_clk;
    wire reset = ~sys_resetn;

    reg [25:0] heartbeat_cnt;
    always @(posedge clk or posedge reset) begin
        if (reset)
            heartbeat_cnt <= 26'd0;
        else
            heartbeat_cnt <= heartbeat_cnt + 1'b1;
    end

    // ============================================================
    // 2. Address map
    // ============================================================
    localparam ROM_BASE    = 32'h8000_0000;
    localparam ROM_WORDS   = 4096;       // 16 KB ROM

    localparam RAM_BASE    = 32'h4000_0000;
    localparam RAM_WORDS   = 131072;     // 512 KB RAM = 131072 words

    localparam PERIPH_BASE = 32'hF000_0000;

    // Peripheral offsets
    localparam REG_HDMI_ENABLE = 32'h0000_0000;
    localparam REG_FB_BASE     = 32'h0000_0004;
    localparam REG_STATUS      = 32'h0000_0008;
    localparam REG_LED_CTRL    = 32'h0000_000C;
    localparam REG_UART_DATA   = 32'h0000_0010;
    localparam REG_UART_STATUS = 32'h0000_0014;

    // ============================================================
    // 3. VexRiscv bus wires
    // ============================================================
    wire         iBus_cmd_valid;
    wire         iBus_cmd_ready;
    wire [31:0]  iBus_cmd_payload_pc;
    wire         iBus_rsp_valid;
    wire [31:0]  iBus_rsp_payload_inst;
    wire         iBus_rsp_payload_error;

    wire         dBus_cmd_valid;
    wire         dBus_cmd_ready;
    wire         dBus_cmd_payload_wr;
    wire [3:0]   dBus_cmd_payload_mask;
    wire [31:0]  dBus_cmd_payload_address;
    wire [31:0]  dBus_cmd_payload_data;
    wire [1:0]   dBus_cmd_payload_size;
    wire         dBus_rsp_ready;
    wire         dBus_rsp_error;
    wire [31:0]  dBus_rsp_data;

    // ============================================================
    // 4. CPU instance
    // ============================================================
    VexRiscv cpu_inst (
        .clk(clk),
        .reset(reset),

        .iBus_cmd_valid(iBus_cmd_valid),
        .iBus_cmd_ready(iBus_cmd_ready),
        .iBus_cmd_payload_pc(iBus_cmd_payload_pc),
        .iBus_rsp_valid(iBus_rsp_valid),
        .iBus_rsp_payload_error(iBus_rsp_payload_error),
        .iBus_rsp_payload_inst(iBus_rsp_payload_inst),

        .dBus_cmd_valid(dBus_cmd_valid),
        .dBus_cmd_ready(dBus_cmd_ready),
        .dBus_cmd_payload_wr(dBus_cmd_payload_wr),
        .dBus_cmd_payload_mask(dBus_cmd_payload_mask),
        .dBus_cmd_payload_address(dBus_cmd_payload_address),
        .dBus_cmd_payload_data(dBus_cmd_payload_data),
        .dBus_cmd_payload_size(dBus_cmd_payload_size),
        .dBus_rsp_ready(dBus_rsp_ready),
        .dBus_rsp_error(dBus_rsp_error),
        .dBus_rsp_data(dBus_rsp_data),

        .timerInterrupt(1'b0),
        .externalInterrupt(1'b0),
        .softwareInterrupt(1'b0),

        .debug_bus_cmd_valid(1'b0),
        .debug_bus_cmd_ready(),
        .debug_bus_cmd_payload_wr(1'b0),
        .debug_bus_cmd_payload_address(8'd0),
        .debug_bus_cmd_payload_data(32'd0),
        .debug_bus_rsp_data(),
        .debug_resetOut(),
        .debugReset(1'b0)
    );

    // ============================================================
    // 5. Instruction ROM
    // ============================================================
    reg [31:0] instr_mem [0:ROM_WORDS-1];
    reg [31:0] instr_data_reg;
    reg        instr_valid_reg;

    integer i;
    initial begin
        for (i = 0; i < ROM_WORDS; i = i + 1)
            instr_mem[i] = 32'h00000013; // NOP

        $readmemh("firmware_vex.hex", instr_mem);
    end

    wire [31:0] iBus_word_addr = (iBus_cmd_payload_pc - ROM_BASE) >> 2;
    wire        iBus_hit_rom   = (iBus_cmd_payload_pc >= ROM_BASE) &&
                                 (iBus_cmd_payload_pc < (ROM_BASE + ROM_WORDS*4));

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            instr_valid_reg <= 1'b0;
            instr_data_reg  <= 32'h00000013;
        end else begin
            instr_valid_reg <= 1'b0;

            if (iBus_cmd_valid && iBus_cmd_ready) begin
                if (iBus_hit_rom)
                    instr_data_reg <= instr_mem[iBus_word_addr];
                else
                    instr_data_reg <= 32'h00000013;

                instr_valid_reg <= 1'b1;
            end
        end
    end

    assign iBus_cmd_ready         = 1'b1;
    assign iBus_rsp_valid         = instr_valid_reg;
    assign iBus_rsp_payload_inst  = instr_data_reg;
    assign iBus_rsp_payload_error = 1'b0;

    // ============================================================
    // 6. Decode for dBus
    // ============================================================
    wire        dBus_hit_ram    = (dBus_cmd_payload_address >= RAM_BASE) &&
                                  (dBus_cmd_payload_address < (RAM_BASE + RAM_WORDS*4));
    wire        dBus_hit_periph = (dBus_cmd_payload_address >= PERIPH_BASE) &&
                                  (dBus_cmd_payload_address < (PERIPH_BASE + 32'h00000100));

    wire [31:0] dBus_ram_word_addr = (dBus_cmd_payload_address - RAM_BASE) >> 2;

    // ============================================================
    // 7. Peripheral registers
    // ============================================================
    reg        reg_hdmi_enable;
    reg [31:0] reg_fb_base_word;   // word address inside RAM space
    reg [1:0]  reg_led_ctrl;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            reg_hdmi_enable  <= 1'b1;
            reg_fb_base_word <= 32'd0;
            reg_led_ctrl     <= 2'b00;
        end else if (dBus_cmd_valid && dBus_cmd_ready && dBus_cmd_payload_wr && dBus_hit_periph) begin
            case (dBus_cmd_payload_address - PERIPH_BASE)
                REG_HDMI_ENABLE: begin
                    if (dBus_cmd_payload_mask[0])
                        reg_hdmi_enable <= dBus_cmd_payload_data[0];
                end

                REG_FB_BASE: begin
                    reg_fb_base_word <= dBus_cmd_payload_data;
                end

                REG_LED_CTRL: begin
                    if (dBus_cmd_payload_mask[0])
                        reg_led_ctrl <= dBus_cmd_payload_data[1:0];
                end

                default: begin
                end
            endcase
        end
    end

    // ============================================================
    // 8. System RAM
    //    Shared by CPU and HDMI framebuffer reader
    // ============================================================
    wire [31:0] cpu_ram_rdata;
    wire [31:0] hdmi_ram_rdata;

    reg        cpu_ram_we_r;
    reg [3:0]  cpu_ram_be_r;
    reg [16:0] cpu_ram_addr_r;
    reg [31:0] cpu_ram_wdata_r;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        cpu_ram_we_r    <= 1'b0;
        cpu_ram_be_r    <= 4'b0;
        cpu_ram_addr_r  <= 17'd0;
        cpu_ram_wdata_r <= 32'd0;
    end else begin
        cpu_ram_we_r <= dBus_cmd_valid && dBus_cmd_payload_wr && dBus_hit_ram;

        if (dBus_cmd_valid && dBus_hit_ram) begin
            cpu_ram_be_r    <= dBus_cmd_payload_mask;
            cpu_ram_addr_r  <= dBus_ram_word_addr[16:0];
            cpu_ram_wdata_r <= dBus_cmd_payload_data;
        end
    end
end


    wire pix_clk;
    wire [16:0] fb_rd_addr;
    wire [16:0] hdmi_pixel_word_offset;
    wire [31:0] hdmi_word_addr_full;
    wire [16:0] hdmi_word_addr;

    assign hdmi_pixel_word_offset = {1'b0, fb_rd_addr[16:1]};
    assign hdmi_word_addr_full    = reg_fb_base_word + {15'd0, hdmi_pixel_word_offset};
    assign hdmi_word_addr         = hdmi_word_addr_full[16:0];

DualPortRam #(
    .ADDR_WIDTH(17),
    .DATA_WIDTH(32)
) u_ram (
    .a_clk   (clk),
    .a_we    (cpu_ram_we_r),
    .a_be    (cpu_ram_be_r),
    .a_addr  (cpu_ram_addr_r),
    .a_wdata (cpu_ram_wdata_r),
    .a_rdata (cpu_ram_rdata),

    .b_clk   (pix_clk),
    .b_en    (1'b1),
    .b_addr  (hdmi_word_addr),
    .b_rdata (hdmi_ram_rdata)
);

    // ============================================================
    // 9. CPU data bus handling
    //    One-cycle response to match synchronous RAM
    // ============================================================
    reg        dBus_rsp_valid_reg;
    reg [31:0] dBus_rdata_reg;

    reg        dBus_pending_ram;
    reg        dBus_pending_periph;
    reg        dBus_pending_other;
    reg [31:0] dBus_pending_addr;
    reg        dBus_pending_wr;

    assign dBus_cmd_ready = 1'b1;
    assign dBus_rsp_ready = dBus_rsp_valid_reg;
    assign dBus_rsp_error = 1'b0;
    assign dBus_rsp_data  = dBus_rdata_reg;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            dBus_rsp_valid_reg <= 1'b0;
            dBus_rdata_reg     <= 32'd0;

            dBus_pending_ram   <= 1'b0;
            dBus_pending_periph<= 1'b0;
            dBus_pending_other <= 1'b0;
            dBus_pending_addr  <= 32'd0;
            dBus_pending_wr    <= 1'b0;
        end else begin
            dBus_rsp_valid_reg <= 1'b0;

            // phase 2: generate response for previous cycle request
            if (dBus_pending_ram) begin
                dBus_rdata_reg     <= cpu_ram_rdata;
                dBus_rsp_valid_reg <= 1'b1;
            end else if (dBus_pending_periph) begin
                case (dBus_pending_addr - PERIPH_BASE)
                    REG_HDMI_ENABLE: dBus_rdata_reg <= {31'd0, reg_hdmi_enable};
                    REG_FB_BASE:     dBus_rdata_reg <= reg_fb_base_word;
                    REG_STATUS:      dBus_rdata_reg <= {30'd0, sys_resetn, hdmi_tx_hpdn};
                    REG_LED_CTRL:    dBus_rdata_reg <= {30'd0, reg_led_ctrl};
                    REG_UART_DATA:   dBus_rdata_reg <= {24'd0, uart_data_reg};
                    REG_UART_STATUS: dBus_rdata_reg <= {31'd0, uart_data_ready};
                    default:         dBus_rdata_reg <= 32'd0;
                endcase
                dBus_rsp_valid_reg <= 1'b1;
            end else if (dBus_pending_other) begin
                dBus_rdata_reg     <= 32'd0;
                dBus_rsp_valid_reg <= 1'b1;
            end

            // clear pending flags
            dBus_pending_ram    <= 1'b0;
            dBus_pending_periph <= 1'b0;
            dBus_pending_other  <= 1'b0;
            dBus_pending_addr   <= 32'd0;
            dBus_pending_wr     <= 1'b0;

            // phase 1: accept new request
            if (dBus_cmd_valid && dBus_cmd_ready) begin
                dBus_pending_addr <= dBus_cmd_payload_address;
                dBus_pending_wr   <= dBus_cmd_payload_wr;

                // For both read and write, return one response beat.
                // RAM uses synchronous read, so response is generated next cycle.
                if (dBus_hit_ram) begin
                    dBus_pending_ram <= 1'b1;
                end else if (dBus_hit_periph) begin
                    dBus_pending_periph <= 1'b1;
                end else begin
                    dBus_pending_other <= 1'b1;
                end
            end
        end
    end

    // ============================================================
    // 10. HDMI framebuffer read path
    //     1 word RAM contains 2 pixels RGB565
    // ============================================================
    wire [15:0] fb_rd_data;

    assign fb_rd_data = reg_hdmi_enable
                        ? (fb_rd_addr[0] ? hdmi_ram_rdata[31:16] : hdmi_ram_rdata[15:0])
                        : 16'h0000;

    // ============================================================
    // 11. HDMI output engine
    // ============================================================
    HDMI_Encode hdmi_en (
    .pixel       (fb_rd_data),
    .clk         (clk),
    .TMDSp       (hdmi_tx_p),
    .TMDSn       (hdmi_tx_n),
    .TMDSp_clock (hdmi_clk_p),
    .TMDSn_clock (hdmi_clk_n),
    .fb_addr     (fb_rd_addr),
    .pix_clk_out (pix_clk)
);
    // ============================================================
    // 12. UART
    // ============================================================
wire [7:0] uart_rx_data;
wire uart_rx_valid;
reg  [7:0] uart_data_reg;
reg uart_data_ready;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        uart_data_reg   <= 8'd0;
        uart_data_ready <= 1'b0;
    end else begin
        if (uart_rx_valid) begin
            uart_data_reg   <= uart_rx_data;
            uart_data_ready <= 1'b1;
        end

        // CPU đọc DATA thì clear cờ ready
        if (dBus_cmd_valid && dBus_cmd_ready &&
            !dBus_cmd_payload_wr &&
            dBus_hit_periph &&
            ((dBus_cmd_payload_address - PERIPH_BASE) == REG_UART_DATA)) begin
            uart_data_ready <= 1'b0;
        end
    end
end

uart_rx #(
    .CLK_FREQ(125_000_000),
    .BAUD_RATE(921600)
) u_uart_rx (
    .clk(clk),
    .reset(reset),
    .rx(uart_rx),
    .data_out(uart_rx_data),
    .data_valid(uart_rx_valid)
);

    // ============================================================
    // 13. LEDs
    // ============================================================
    assign led[0] = reg_led_ctrl[0] ^ heartbeat_cnt[25];
    assign led[1] = reg_led_ctrl[1] ^ ~hdmi_tx_hpdn;

endmodule