`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for ChipTop (VexRiscv new config)
// Simulate basic instruction fetch and data bus activity
//////////////////////////////////////////////////////////////////////////////////

module ChipTop_tb;

    // ----------------------------------------------
    // 1. Clock and Reset
    // ----------------------------------------------
    reg sys_clk;
    reg sys_resetn;

    initial begin
        sys_clk = 0;
        forever #5 sys_clk = ~sys_clk;  // 100 MHz clock -> 10 ns period
    end

    initial begin
        sys_resetn = 0;
        #100;
        sys_resetn = 1; // release reset after 100ns
    end

    // ----------------------------------------------
    // 2. Instantiate DUT
    // ----------------------------------------------
    wire [2:0] hdmi_tx_p, hdmi_tx_n;
    wire       hdmi_clk_p, hdmi_clk_n;

    ChipTop dut (
        .sys_clk(sys_clk),
        .sys_resetn(sys_resetn),
        .hdmi_tx_p(hdmi_tx_p),
        .hdmi_tx_n(hdmi_tx_n),
        .hdmi_clk_p(hdmi_clk_p),
        .hdmi_clk_n(hdmi_clk_n)
    );

    // ----------------------------------------------
    // 3. Dump waveform (for Vivado/GTKWave)
    // ----------------------------------------------
    

    // ----------------------------------------------
    // 4. Start simulation banner
    // ----------------------------------------------
    

    // ----------------------------------------------
    // 5. Monitor instruction bus (iBus)
    // ----------------------------------------------
    

    // ----------------------------------------------
    // 7. Simulation stop condition
    // ----------------------------------------------
    initial begin
        #200000;  // run 200 µs
        $display("==== Simulation finished ====");
        $stop;
    end

endmodule
