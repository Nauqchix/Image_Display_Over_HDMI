module uart_rx #(
    parameter CLK_FREQ  = 125_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire clk,
    input  wire reset,
    input  wire rx,

    output reg  [7:0] data_out,
    output reg        data_valid
);

    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam integer HALF_CLKS    = CLKS_PER_BIT / 2;

    reg [15:0] clk_cnt;
    reg [3:0]  bit_idx;
    reg [7:0]  rx_shift;
    reg [2:0]  state;

    localparam IDLE  = 3'd0;
    localparam START = 3'd1;
    localparam DATA  = 3'd2;
    localparam STOP  = 3'd3;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            clk_cnt    <= 16'd0;
            bit_idx    <= 4'd0;
            rx_shift   <= 8'd0;
            data_out   <= 8'd0;
            data_valid <= 1'b0;
            state      <= IDLE;
        end else begin
            data_valid <= 1'b0;

            case (state)
                IDLE: begin
                    clk_cnt <= 16'd0;
                    bit_idx <= 4'd0;
                    if (rx == 1'b0)
                        state <= START;
                end

                START: begin
                    if (clk_cnt == HALF_CLKS - 1) begin
                        clk_cnt <= 16'd0;
                        if (rx == 1'b0)
                            state <= DATA;
                        else
                            state <= IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                DATA: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 16'd0;
                        rx_shift[bit_idx] <= rx;

                        if (bit_idx == 4'd7) begin
                            bit_idx <= 4'd0;
                            state   <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                STOP: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt    <= 16'd0;
                        data_out   <= rx_shift;
                        data_valid <= 1'b1;
                        state      <= IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule