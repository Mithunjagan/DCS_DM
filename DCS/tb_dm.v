`timescale 1ns/1ps
//======================================================================
// tb_dm.v  -  Simulation testbench for the delta modulation chain.
//   Runs the chain at the SAMPLE rate (fast to simulate) and writes
//   dm_out.csv  ->  open it in Excel / Python and plot the columns.
//   Change DELTA below to demonstrate slope overload / granular noise.
//======================================================================
module tb_dm;

    localparam integer W        = 16;
    localparam integer N        = 4096;          // samples to capture
    localparam signed [15:0] DELTA = 16'sd128;   // try 16, 64, 128, 512

    reg clk = 0, rst = 1;
    always #10 clk = ~clk;                       // 50 MHz "sample clock"

    wire signed [W-1:0] x, y_enc, y_dec, y_dec_stair;
    wire                dm_bit;
    integer             fd, n;

    sine_gen #(.W(W), .PHASE_INC(32'd8589935)) u_sine (
        .clk(clk), .rst(rst), .en(1'b1), .sine(x));

    delta_modulator #(.W(W)) u_mod (
        .clk(clk), .rst(rst), .en(1'b1),
        .x(x), .delta(DELTA), .dm_bit(dm_bit), .y_stair(y_enc));

    delta_demodulator #(.W(W), .LPF_SHIFT(5)) u_demod (
        .clk(clk), .rst(rst), .en(1'b1),
        .dm_bit(dm_bit), .delta(DELTA),
        .y_stair(y_dec_stair), .y_out(y_dec));

    initial begin
        $dumpfile("tb_dm.vcd");
        $dumpvars(0, tb_dm);

        fd = $fopen("dm_out.csv", "w");
        $fwrite(fd, "n,input,encoder_staircase,dm_bit,decoder_staircase,decoder_filtered,error\n");

        repeat (4) @(posedge clk);
        rst = 0;

        for (n = 0; n < N; n = n + 1) begin
            @(posedge clk);
            #1;
            $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
                    n, x, y_enc, dm_bit, y_dec_stair, y_dec, x - y_enc);
        end

        $fclose(fd);
        $display("TB done: %0d samples written to dm_out.csv (delta=%0d)", N, DELTA);
        $finish;
    end
endmodule
