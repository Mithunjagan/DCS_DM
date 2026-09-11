module lpf_iir #(
    parameter WIDTH = 16,
    parameter SHIFT = 6              // was 4 - too fast to smooth the staircase
)(
    input clk, rst,
    input signed [WIDTH-1:0] x_in,
    output signed [WIDTH-1:0] y_out
);
    reg signed [WIDTH+SHIFT-1:0] acc;

    always @(posedge clk or posedge rst)
        if (rst) acc <= 0;
        else     acc <= acc + (x_in - (acc >>> SHIFT));

    assign y_out = acc >>> SHIFT;
endmodule