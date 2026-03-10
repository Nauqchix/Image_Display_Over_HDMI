module DualPortRam #(
    parameter ADDR_WIDTH = 17,
    parameter DATA_WIDTH = 32
)(
    input  wire                    a_clk,
    input  wire                    a_we,
    input  wire [3:0]              a_be,
    input  wire [ADDR_WIDTH-1:0]   a_addr,
    input  wire [DATA_WIDTH-1:0]   a_wdata,
    output reg  [DATA_WIDTH-1:0]   a_rdata,

    input  wire                    b_clk,
    input  wire                    b_en,
    input  wire [ADDR_WIDTH-1:0]   b_addr,
    output reg  [DATA_WIDTH-1:0]   b_rdata
);

    reg [DATA_WIDTH-1:0] ram [0:(1<<ADDR_WIDTH)-1];
    integer k;

    always @(posedge a_clk) begin
        a_rdata <= ram[a_addr];
        if (a_we) begin
            for (k = 0; k < 4; k = k + 1) begin
                if (a_be[k])
                    ram[a_addr][8*k +: 8] <= a_wdata[8*k +: 8];
            end
        end
    end

    always @(posedge b_clk) begin
        if (b_en)
            b_rdata <= ram[b_addr];
    end

endmodule