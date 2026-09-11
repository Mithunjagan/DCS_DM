`timescale 1ns/1ps
//======================================================================
// delta_modulator.v
//   Linear Delta Modulator (1-bit differential encoder)
//
//   Algorithm, executed once per sample:
//       b[n] = 1  if  x[n] >= y[n-1]     else 0
//       y[n] = y[n-1] + delta   when b=1
//              y[n-1] - delta   when b=0
//
//   'y' is the staircase approximation of the input. 'b' is the
//   1-bit output that you would actually transmit.
//======================================================================
module delta_modulator #(
    parameter integer W = 16          // sample width (bits, signed)
)(
    input  wire                 clk,
    input  wire                 rst,      // synchronous, active high
    input  wire                 en,       // 1 = process one sample this cycle
    input  wire signed [W-1:0]  x,        // input sample
    input  wire signed [W-1:0]  delta,    // step size (positive)
    output reg                  dm_bit,   // 1-bit encoded output
    output reg  signed [W-1:0]  y_stair   // staircase (for observation only)
);
    // one extra bit of headroom so the add/sub cannot silently wrap
    reg  signed [W:0] y_next;

    always @(*) begin
        if (x >= y_stair) y_next = {y_stair[W-1], y_stair} + delta;
        else              y_next = {y_stair[W-1], y_stair} - delta;
    end

    // saturate instead of wrapping around (wrap-around looks like a fault)
    wire signed [W-1:0] y_sat =
        (y_next >  $signed({1'b0, {(W-1){1'b1}}})) ?  {1'b0, {(W-1){1'b1}}} :  // +32767
        (y_next <  $signed({1'b1, {(W-1){1'b0}}})) ?  {1'b1, {(W-1){1'b0}}} :  // -32768
                                                      y_next[W-1:0];

    always @(posedge clk) begin
        if (rst) begin
            dm_bit  <= 1'b0;
            y_stair <= {W{1'b0}};
        end else if (en) begin
            dm_bit  <= (x >= y_stair);
            y_stair <= y_sat;
        end
    end
endmodule
