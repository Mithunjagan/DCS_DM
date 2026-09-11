module delta_encoder #(
    parameter WIDTH = 16,
    parameter STEP  = 64
)(
    input clk, rst,
    input signed [WIDTH-1:0] x_in,
    output reg dm_bit,
    output reg signed [WIDTH-1:0] x_hat
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x_hat  <= 0;
            dm_bit <= 0;
        end else if (x_in >= x_hat) begin
            dm_bit <= 1'b1;
            x_hat  <= x_hat + STEP;
        end else begin
            dm_bit <= 1'b0;
            x_hat  <= x_hat - STEP;
        end
    end
endmodule