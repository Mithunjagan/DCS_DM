module delta_decoder #(
    parameter WIDTH = 16,
    parameter STEP  = 64
)(
    input clk, rst,
    input dm_bit,
    output reg signed [WIDTH-1:0] y_raw
);
    always @(posedge clk or posedge rst)
        if (rst) y_raw <= 0;
        else y_raw <= dm_bit ? y_raw + STEP : y_raw - STEP;
endmodule