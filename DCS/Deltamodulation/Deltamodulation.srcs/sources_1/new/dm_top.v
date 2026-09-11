module dm_top #(
    parameter WIDTH = 16
)(
    input clk, rst,
    input [15:0] phase_inc,
    output signed [WIDTH-1:0] x_in,
    output dm_bit,
    output signed [WIDTH-1:0] x_hat,
    output signed [WIDTH-1:0] y_raw,
    output signed [WIDTH-1:0] y_smooth
);
    sine_nco #(.WIDTH(WIDTH)) u_nco (
        .clk(clk), .rst(rst), .phase_inc(phase_inc), .sine_out(x_in)
    );

    delta_encoder #(.WIDTH(WIDTH)) u_enc (
        .clk(clk), .rst(rst), .x_in(x_in), .dm_bit(dm_bit), .x_hat(x_hat)
    );

    delta_decoder #(.WIDTH(WIDTH)) u_dec (
        .clk(clk), .rst(rst), .dm_bit(dm_bit), .y_raw(y_raw)
    );

    lpf_iir #(.WIDTH(WIDTH)) u_lpf (
        .clk(clk), .rst(rst), .x_in(y_raw), .y_out(y_smooth)
    );
endmodule