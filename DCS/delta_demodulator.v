`timescale 1ns/1ps
//======================================================================
// delta_demodulator.v
//   Delta Demodulator = accumulator (integrator) + low-pass filter
//
//       y[n]  = y[n-1] +/- delta        <- rebuilds the staircase
//       yf[n] = yf[n-1] + (y[n]-yf[n-1]) >>> LPF_SHIFT
//
//   The LPF is a 1st-order IIR. It smooths the staircase edges,
//   which is what removes the "granular" quantisation noise.
//   Bigger LPF_SHIFT = smoother output but more delay.
//======================================================================
module delta_demodulator #(
    parameter integer W         = 16,
    parameter integer LPF_SHIFT = 5
)(
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 en,
    input  wire                 dm_bit,   // received 1-bit stream
    input  wire signed [W-1:0]  delta,
    output reg  signed [W-1:0]  y_stair,  // raw reconstructed staircase
    output reg  signed [W-1:0]  y_out     // filtered (final) output
);
    reg signed [W:0] y_next;

    always @(*) begin
        if (dm_bit) y_next = {y_stair[W-1], y_stair} + delta;
        else        y_next = {y_stair[W-1], y_stair} - delta;
    end

    wire signed [W-1:0] y_sat =
        (y_next >  $signed({1'b0, {(W-1){1'b1}}})) ?  {1'b0, {(W-1){1'b1}}} :
        (y_next <  $signed({1'b1, {(W-1){1'b0}}})) ?  {1'b1, {(W-1){1'b0}}} :
                                                      y_next[W-1:0];

    always @(posedge clk) begin
        if (rst) begin
            y_stair <= {W{1'b0}};
            y_out   <= {W{1'b0}};
        end else if (en) begin
            y_stair <= y_sat;
            y_out   <= y_out + ((y_sat - y_out) >>> LPF_SHIFT);
        end
    end
endmodule
