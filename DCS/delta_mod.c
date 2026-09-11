/*=====================================================================
 * delta_mod.c  -  Delta Modulation on the ZedBoard ARM (PS side)
 *
 * The easiest possible "0 to result" path: no PL, no constraints,
 * no bitstream logic. It runs on the Cortex-A9, prints CSV over the
 * USB-UART, and you plot it in Excel or Python.
 *
 * Vitis: File > New > Application Project > platform on ZYNQ_FSBL /
 *        or a hello_world template, then replace helloworld.c with this.
 * Open a serial terminal at 115200-8-N-1 and capture the output.
 *===================================================================*/
#include <stdio.h>
#include <math.h>
#include "xparameters.h"
#include "xil_printf.h"

#define FS      500000.0     /* delta-modulator sampling rate, Hz      */
#define FSIG      1000.0     /* test tone, Hz                          */
#define AMP       8192       /* amplitude in LSB (full scale = 32768)  */
#define NSAMP     2000       /* samples to print                       */
#define LPF_SHIFT 5          /* decoder low-pass strength              */

static int clamp16(int v)
{
    if (v >  32767) return  32767;
    if (v < -32768) return -32768;
    return v;
}

int main(void)
{
    int   delta_list[4] = {16, 64, 128, 512};
    int   k, n;

    /* Theoretical minimum step to avoid slope overload:
     *     delta >= 2*pi*FSIG*AMP / FS                                */
    double dmin = 2.0 * M_PI * FSIG * AMP / FS;
    printf("\r\n# slope-overload limit: delta >= %.1f\r\n", dmin);

    for (k = 0; k < 4; k++) {
        int delta = delta_list[k];
        int y_enc = 0;      /* encoder integrator  */
        int y_dec = 0;      /* decoder integrator  */
        int y_lpf = 0;      /* decoder LPF output  */
        double se = 0.0, sx = 0.0;

        printf("\r\n# ---- delta = %d ----\r\n", delta);
        printf("n,input,encoder_staircase,bit,decoder_filtered\r\n");

        for (n = 0; n < NSAMP; n++) {
            int x = (int)lround(AMP * sin(2.0 * M_PI * FSIG * n / FS));

            /* ---- MODULATOR: 1 comparison, 1 add. That is all it is. ---- */
            int b = (x >= y_enc) ? 1 : 0;
            y_enc = clamp16(b ? y_enc + delta : y_enc - delta);

            /* ---- DEMODULATOR: integrate the bits, then low-pass ---- */
            y_dec = clamp16(b ? y_dec + delta : y_dec - delta);
            y_lpf = y_lpf + ((y_dec - y_lpf) >> LPF_SHIFT);

            sx += (double)x * x;
            se += (double)(x - y_enc) * (x - y_enc);

            printf("%d,%d,%d,%d,%d\r\n", n, x, y_enc, b, y_lpf);
        }
        printf("# SNR = %.2f dB\r\n", 10.0 * log10(sx / se));
    }

    printf("\r\n# done\r\n");
    return 0;
}
