module sine_nco #(
    parameter WIDTH   = 16,
    parameter PHASE_W = 16,
    parameter ADDR_W  = 10,          // 1024-entry LUT
    parameter AMPL    = 30000
)(
    input clk, rst,
    input [PHASE_W-1:0] phase_inc,
    output signed [WIDTH-1:0] sine_out
);
    localparam N = 1 << ADDR_W;
    reg [PHASE_W-1:0] phase;
    reg signed [WIDTH-1:0] lut [0:N-1];

    integer i;
    initial for (i = 0; i < N; i = i + 1)
        lut[i] = $rtoi(AMPL * $sin(2.0*3.14159265358979*i/N));

    always @(posedge clk or posedge rst)
        if (rst) phase <= 0;
        else     phase <= phase + phase_inc;

    assign sine_out = lut[phase[PHASE_W-1 -: ADDR_W]];
endmodule