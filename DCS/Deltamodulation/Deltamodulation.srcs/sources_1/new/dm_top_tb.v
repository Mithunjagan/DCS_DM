`timescale 1ns/1ps
module dm_top_tb;
    reg clk = 0, rst = 1;
    reg [15:0] phase_inc = 16'd16;

    wire signed [15:0] x_in, x_hat, y_raw, y_smooth;
    wire dm_bit;

    dm_top uut (.clk(clk), .rst(rst), .phase_inc(phase_inc),
                .x_in(x_in), .dm_bit(dm_bit), .x_hat(x_hat),
                .y_raw(y_raw), .y_smooth(y_smooth));

    always #5 clk = ~clk;

    reg settled;
    integer err, max_err, n, ones, run, max_run, k;
    reg last_bit;

    initial begin
        settled = 0; max_err = 0; n = 0; ones = 0;
        run = 0; max_run = 0; k = 0; last_bit = 0;
        #50  rst = 0;
        #200000 settled = 1;          // skip startup slew
        #800000;
        $display("-----------------------------------------");
        $display("samples        = %0d", n);
        $display("max |x_in-x_hat| = %0d", max_err);
        $display("dm_bit ones    = %0d", ones);
        $display("longest bit run= %0d", max_run);
        if (max_run > 64) $display("RESULT: FAIL - slope overload");
        else              $display("RESULT: PASS - encoder tracking");
        $display("-----------------------------------------");
        $finish;
    end

    always @(posedge clk) if (settled) begin
        err = x_in - x_hat;
        if (err < 0) err = -err;
        if (err > max_err) max_err = err;
        n    = n + 1;
        ones = ones + dm_bit;

        if (dm_bit == last_bit) run = run + 1;
        else                    run = 1;
        last_bit = dm_bit;
        if (run > max_run) max_run = run;

        k = k + 1;
        if (k % 1024 == 0)
            $display("t=%0t x_in=%6d x_hat=%6d y_raw=%6d y_smooth=%6d bit=%b",
                     $time, x_in, x_hat, y_raw, y_smooth, dm_bit);
    end
endmodule