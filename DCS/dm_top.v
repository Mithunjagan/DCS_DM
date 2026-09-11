`timescale 1ns/1ps
//======================================================================
// dm_top.v  -  Delta Modulation demo for ZedBoard (XC7Z020)
//
//   100 MHz (Y9) --/200--> clk_s = 500 kHz  (= the DM sampling rate Fs)
//
//   sine_gen ---> delta_modulator ---> 1 bit ---> delta_demodulator
//                       |                                |
//                    y_stair                          y_out
//                       \______ both go to the ILA ______/
//
//   SW1:SW0 pick the step size so you can SEE slope overload and
//   granular noise on the board:
//        00 -> 16   (severe slope overload)
//        01 -> 64   (mild  slope overload)
//        10 -> 128  (correct - this is the design point)
//        11 -> 512  (granular / quantisation noise)
//
//   Theory check: to avoid slope overload for A*sin(2*pi*f*t),
//        delta >= 2*pi*f*A / Fs = 2*pi*1000*8192/500000 = 103
//   which is exactly why 128 is the good value and 64 is not.
//======================================================================
module dm_top #(
    parameter integer W         = 16,
    parameter integer DIV_HALF  = 100,        // 100 MHz /(2*100) = 500 kHz
    parameter [31:0]  PHASE_INC = 32'd8589935,   // 1 kHz tone
    parameter integer LPF_SHIFT = 5
)(
    input  wire       clk,          // 100 MHz oscillator, ZedBoard pin Y9
    input  wire       btn_rst,      // BTNC, active high
    input  wire [1:0] sw,           // SW1, SW0  -> step size
    output wire [7:0] led,
    output wire       dm_bit_pin,   // Pmod: the raw 1-bit DM stream
    output wire       sd_dac_pin    // Pmod: reconstructed signal, 1-bit DAC
);

    //------------------------------------------------------------------
    // 1. Sample clock: 100 MHz / 200 = 500 kHz, put onto a global buffer
    //    so it can legally clock the whole design (and the ILA).
    //------------------------------------------------------------------
    reg [7:0] divcnt = 8'd0;
    reg       clk_div = 1'b0;
    always @(posedge clk) begin
        if (divcnt == DIV_HALF-1) begin
            divcnt  <= 8'd0;
            clk_div <= ~clk_div;
        end else begin
            divcnt  <= divcnt + 8'd1;
        end
    end

    wire clk_s;
    BUFG bufg_s (.I(clk_div), .O(clk_s));    // instance name used in the XDC

    //------------------------------------------------------------------
    // 2. Reset synchroniser (button is asynchronous and bouncy)
    //------------------------------------------------------------------
    reg [3:0] rst_sr = 4'hF;
    always @(posedge clk_s) rst_sr <= {rst_sr[2:0], btn_rst};
    wire rst = rst_sr[3];

    //------------------------------------------------------------------
    // 3. Step size selected by the slide switches
    //------------------------------------------------------------------
    reg signed [W-1:0] delta;
    always @(*) begin
        case (sw)
            2'b00: delta = 16'sd16;
            2'b01: delta = 16'sd64;
            2'b10: delta = 16'sd128;
            default: delta = 16'sd512;
        endcase
    end

    //------------------------------------------------------------------
    // 4. Signal chain. en=1 -> one DM sample per clk_s edge.
    //------------------------------------------------------------------
    wire signed [W-1:0] x;
    sine_gen #(.W(W), .PHASE_INC(PHASE_INC)) u_sine (
        .clk(clk_s), .rst(rst), .en(1'b1), .sine(x));

    wire                dm_bit;
    wire signed [W-1:0] y_enc;
    delta_modulator #(.W(W)) u_mod (
        .clk(clk_s), .rst(rst), .en(1'b1),
        .x(x), .delta(delta), .dm_bit(dm_bit), .y_stair(y_enc));

    wire signed [W-1:0] y_dec_stair, y_dec;
    delta_demodulator #(.W(W), .LPF_SHIFT(LPF_SHIFT)) u_demod (
        .clk(clk_s), .rst(rst), .en(1'b1),
        .dm_bit(dm_bit), .delta(delta),
        .y_stair(y_dec_stair), .y_out(y_dec));

    //------------------------------------------------------------------
    // 5. Observation
    //------------------------------------------------------------------
    wire signed [W-1:0] err = x - y_enc;      // tracking error

    // 1-bit sigma-delta DAC: put an RC low-pass (1k + 100nF) on the pin
    // and you can watch the recovered sine on an oscilloscope.
    reg [W+1:0] sd_acc = 0;
    always @(posedge clk_s) sd_acc <= sd_acc[W:0] + {~y_dec[W-1], y_dec[W-2:0]};
    assign sd_dac_pin = sd_acc[W+1];

    assign dm_bit_pin = dm_bit;
    assign led        = y_dec[W-1] ? ~y_dec[W-2:W-9] : y_dec[W-2:W-9];

    //------------------------------------------------------------------
    // 6. Signals to capture with the ILA (Vivado adds the core for you)
    //------------------------------------------------------------------
    (* mark_debug = "true" *) wire signed [W-1:0] dbg_x     = x;
    (* mark_debug = "true" *) wire signed [W-1:0] dbg_yenc  = y_enc;
    (* mark_debug = "true" *) wire signed [W-1:0] dbg_ydec  = y_dec;
    (* mark_debug = "true" *) wire signed [W-1:0] dbg_err   = err;
    (* mark_debug = "true" *) wire                dbg_bit   = dm_bit;

endmodule
