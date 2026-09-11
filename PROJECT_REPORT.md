# FPGA Implementation of a One-Bit Delta Modulation and Demodulation System on ZedBoard

**Project report / paper draft**  
**Author(s):** `[Name(s)]`  
**Register number(s):** `[Number(s)]`  
**Department / Institution:** `[Department, Institution]`  
**Guide:** `[Guide name]`  
**Academic year:** `[Year]`

> Before submitting: replace the title-page placeholders, insert your own Vivado waveform/ILA/scope screenshots where indicated, and format this manuscript according to your department’s template. Do not claim measured hardware results that you have not personally captured.

## Abstract

This work presents the design and FPGA implementation of a one-bit linear delta modulation and demodulation system using the Xilinx ZedBoard. The design generates a 1 kHz, 16-bit signed sine wave internally, samples it at 500 kHz, and encodes each sample as a single binary decision indicating whether the reconstructed staircase must move upward or downward. At the receiver, the binary stream is integrated to recover the staircase waveform and is passed through a first-order IIR low-pass filter to obtain a smoothed reconstruction. Two ZedBoard switches select delta steps of 16, 64, 128, and 512, making it possible to demonstrate slope overload and granular noise in real time. The design provides LED output, Pmod observation points, ILA probes, a behavioral CSV testbench, and a Cortex-A9 software reference model. The saved FPGA implementation meets timing for the XC7Z020-1CLG484 device and includes a generated bitstream. This project provides a compact, observable hardware platform for studying the trade-off between bit rate, tracking capability, and quantization noise in delta modulation.

**Keywords:** Delta modulation, FPGA, ZedBoard, one-bit encoder, demodulation, slope overload, granular noise, IIR filter, Vivado, Zynq-7020.

## 1. Introduction

Conventional pulse-code modulation transmits multiple quantized bits for every sample. Delta modulation takes a different approach: it sends only the direction in which the reconstructed signal must move. This reduces the encoded representation to one bit per sample and makes the core hardware extremely small: a comparator and an up/down accumulator form the encoder, while another accumulator and a low-pass filter form the decoder.

The simplicity has a cost. If the input waveform changes faster than the staircase can move, the encoder suffers **slope overload**. If the step is unnecessarily large while the input varies slowly, the staircase hunts around the desired value and produces **granular noise**. The present project turns both limitations into visible experimental modes, rather than hiding them in a purely theoretical simulation.

## 2. Aim

To implement and experimentally study a complete one-bit delta modulation and demodulation system on the ZedBoard FPGA, with selectable step size and hardware-visible output.

## 3. Objectives

1. Generate a deterministic 1 kHz sine-wave test signal in Verilog.
2. Derive a 500 kHz sample clock from the 100 MHz ZedBoard clock.
3. Implement a signed, saturating one-bit delta encoder.
4. Implement a signed delta decoder and a first-order IIR reconstruction filter.
5. Provide four selectable step sizes through `SW1:SW0`.
6. Simulate the design and export sample data to CSV/VCD files.
7. Implement the constrained design on the XC7Z020 ZedBoard FPGA and generate a bitstream.
8. Observe the system through LEDs, Pmod output, and Vivado ILA.
9. Provide a C model for equivalent PS-side numerical experiments.

## 4. Problem statement

The project must transmit/reconstruct a varying signal with one bit per sample while preserving its shape sufficiently for observation. It must also demonstrate the fundamental design trade-off: a small step reduces granular noise but may cause slope overload, while a large step avoids overload but reduces precision.

## 5. Theory

### 5.1 Delta modulation encoder

Let `x[n]` be the sampled input and `y[n-1]` be the previous encoder staircase approximation. The encoder sends:

```text
b[n] = 1 when x[n] >= y[n-1]
b[n] = 0 when x[n] <  y[n-1]
```

The staircase then advances by one fixed signed step:

```text
y[n] = y[n-1] + delta, when b[n] = 1
y[n] = y[n-1] - delta, when b[n] = 0
```

The implemented design saturates the result at the signed 16-bit limits rather than allowing a wraparound error.

### 5.2 Delta demodulation

The decoder receives `b[n]` and recreates the staircase using the same step size:

```text
y_dec[n] = y_dec[n-1] + delta, when b[n] = 1
y_dec[n] = y_dec[n-1] - delta, when b[n] = 0
```

Because the reconstructed output is a staircase, it contains high-frequency quantization components. A first-order IIR low-pass filter is used:

```text
y_f[n] = y_f[n-1] + (y_dec[n] - y_f[n-1]) / 32
```

The Verilog implementation uses an arithmetic right shift by five bits to realize division by 32 without a hardware divider.

### 5.3 Slope-overload condition

For a sinusoid of amplitude `A` and frequency `f`, sampled at `Fs`, the maximum signal slope is `2*pi*f*A`. To track it, the staircase needs:

```text
delta >= (2*pi*f*A) / Fs
```

For this project:

```text
A  = 8192
f  = 1000 Hz
Fs = 500000 Hz
delta_min = 102.94
```

Thus 128 is the expected correct step, while 16 and 64 should overload. A step of 512 has more than enough slew rate but generates larger steady-state staircase excursions.

## 6. Proposed architecture

```text
 +----------------+      +------------------+      +------------------+
 | 100 MHz clock  | ---> | /200 + BUFG      | ---> | 500 kHz sample   |
 | (ZedBoard Y9)  |      | clock generator  |      | clock             |
 +----------------+      +------------------+      +------------------+
                                                            |
                                                            v
          +---------------+       +----------------+   +------------------+
          | SW1:SW0       | ----> | delta selector |-->| delta modulator  |
          | 16/64/128/512 |       +----------------+   +------------------+
          +---------------+                                  ^      |
                                                             |      v
          +---------------+                                 |   1-bit DM stream ---> Pmod JB1
          | sine NCO/ROM  | --------------------------------+      |
          | 1 kHz, 16 bit |                                        v
          +---------------+                                  +------------------+
                                                             | delta demodulator |
                                                             +------------------+
                                                                      |
                                                                      v
                                                             +------------------+
                                                             | IIR low-pass     |
                                                             +------------------+
                                                                |          |
                                                                v          v
                                                             LEDs      PDM DAC -> JB2 -> RC filter

                         Internal source/staircase/error/bit signals -> Vivado ILA
```

## 7. Logic flow

1. The 100 MHz board clock is divided by 200 to form `clk_s = 500 kHz`.
2. A reset shift register holds the data path reset for several sample-clock cycles after reset is released.
3. The NCO updates a 32-bit phase accumulator; its eight most-significant bits index a 256-entry sine ROM.
4. The selected delta value is applied to both encoder and decoder.
5. The encoder compares the sine sample with its staircase estimate, emits `dm_bit`, and moves the staircase by `+delta` or `-delta`.
6. The decoder integrates the one-bit stream into a second staircase.
7. The IIR filter smooths the decoder staircase.
8. The filtered value drives LED visualization and a sigma-delta/PDM output for scope observation.
9. Marked internal signals are captured in the ILA for timing-domain inspection.

## 8. Hardware and software requirements

| Item | Requirement |
|---|---|
| FPGA board | ZedBoard with XC7Z020-1CLG484. |
| FPGA tool | Xilinx Vivado; saved results were generated using Vivado 2022.2. |
| Programming | JTAG cable/USB connection and board power supply. |
| Optional measurement | Oscilloscope, jumper wires, 1 kOhm resistor, 100 nF capacitor. |
| Software model | Xilinx Vitis plus Zynq standalone/BSP platform. |
| UART capture | USB-UART terminal at 115200-8-N-1. |

## 9. Implementation procedure

### 9.1 Vivado simulation

1. Open `DCS/delta/delta.xpr`.
2. Confirm `dm_top` is the design top and `tb_dm` is the simulation top.
3. Run behavioral simulation and select **Run All**.
4. Add the input, encoder staircase, DM bit, decoder staircase, filtered output, and error to the waveform view.
5. After automatic completion, obtain `dm_out.csv` and `tb_dm.vcd` from the simulator working directory.
6. Repeat the simulation for `DELTA = 16, 64, 128, 512` in `tb_dm.v`.
7. Plot input, staircase, filtered output, and error against sample number.

### 9.2 Vivado implementation and board execution

1. Check ZedBoard J18 voltage configuration. The supplied XDC assumes 1.8 V VADJ for buttons/switches.
2. Run synthesis, implementation, and bitstream generation.
3. Check timing summary, route status, and DRC reports.
4. Connect through JTAG and program `DCS/delta/delta.runs/impl_1/dm_top.bit`.
5. Press BTNC and select `SW1:SW0 = 10` as the recommended starting mode.
6. Observe LEDs, JB1, JB2 through the RC filter, and ILA traces.
7. Change the switch setting and document the visible change in tracking/noise behavior.

### 9.3 Cortex-A9 reference run

1. Create a Vitis Zynq standalone application.
2. Replace the application source with `DCS/delta_mod.c`.
3. Build and run the program.
4. Capture UART output and plot the generated CSV blocks.
5. Compare the numerical trend with the HDL simulation; exact sample alignment is not required because the models have different generation details.

## 10. Observation table

| Switch state | Delta | Theoretical expectation | Observation to record |
|---|---:|---|---|
| `00` | 16 | Severe slope overload; staircase cannot keep up. | `[Insert ILA/simulation screenshot and comment]` |
| `01` | 64 | Reduced but still present slope overload. | `[Insert ILA/simulation screenshot and comment]` |
| `10` | 128 | Sufficient staircase slew rate; best trade-off in this design. | `[Insert ILA/simulation screenshot and comment]` |
| `11` | 512 | Coarse staircase and granular/quantization noise. | `[Insert ILA/simulation screenshot and comment]` |

### Saved behavioral result for the nominal mode

The included saved CSV capture for `delta = 128` has the following calculated characteristics:

| Metric | Value |
|---|---:|
| Captured samples | 4096 |
| Input range | -8191 to +8191 |
| Mean absolute encoder error | 102.97 counts |
| Encoder RMSE | 126.90 counts |
| Maximum absolute encoder error | 322 counts |
| Encoder SNR | 33.16 dB |
| Zero bits / one bits | 2019 / 2077 |

### Saved implementation result

| Metric | Saved result |
|---|---:|
| Device | XC7Z020CLG484-1 |
| Routing errors | 0 |
| Timing failures | 0 |
| Worst setup slack | 26.957 ns |
| Core synthesis | 183 LUTs, 110 registers |
| Final placed design | 1500 LUTs, 2351 registers, 8 BRAM tiles |
| Estimated on-chip power | 0.108 W, medium confidence |

The placed resource count includes the inserted ILA/debug hub. It should not be presented as the resource cost of the delta-modulator arithmetic alone.

## 11. Results and discussion

The selected `delta = 128` configuration satisfies the derived slope condition and the saved simulation confirms close encoder tracking. At small delta values, the encoder has insufficient maximum slew rate; the bitstream remains at the same value for long periods while the input moves away from the staircase. This is the expected signature of slope overload. At `delta = 512`, the encoder has sufficient slew rate but crosses the desired input in large increments, producing increased granular error. The IIR filter smooths this error but also introduces delay and attenuates higher-frequency content.

The FPGA implementation is intentionally conservative in clock rate: the signal path runs at 500 kHz even though the board clock is 100 MHz. As a result, timing closure is easy and the design is suitable for teaching, debug capture, and physical observation. Its main practical contribution is the visibility of the entire codec chain on an actual board.

## 12. How this work differs from other projects

The difference is primarily in completeness and observability, not in claiming a novel modulation algorithm.

| Typical simple student demonstration | This project |
|---|---|
| Simulates only in MATLAB/Python. | Includes synthesizable HDL, XDC constraints, an implementation, and a board bitstream. |
| Shows only an input and output plot. | Exposes input, both staircases, error, and the DM bit to an ILA. |
| Treats delta as a fixed hidden constant. | Changes delta at run time through board switches to demonstrate both failure modes. |
| Uses an ideal plotted output. | Provides a raw physical Pmod bitstream and a PDM output that can be RC-filtered and viewed on a scope. |
| May omit fixed-point edge cases. | Uses saturation to prevent accumulator wraparound. |
| Has no reproducible data output. | Produces VCD and CSV captures, and has a separate UART/CSV software model. |

The repository’s alternate `Deltamodulation` project also serves as a useful contrast: it lacks hardware constraints, makes a testbench the design top, and its saved simulation reports a slope-overload failure. It must not be presented as the deployed ZedBoard implementation.

## 13. Limitations

1. The design uses an internally generated sine wave, not live sensor/audio data.
2. The Pmod reconstruction is one-bit pulse-density output and needs an external RC filter.
3. Mechanical reset and switches are not fully debounced/synchronized for robust field use.
4. The design uses a fabric-derived sample clock; clock-enable architecture is preferable for a larger system.
5. The IIR filter has a fixed response and introduces delay.
6. Only fixed-step delta modulation is implemented; adaptive delta modulation could improve tracking across varied signal slopes.
7. The saved DRC contains non-fatal Zynq/debug-related warnings that should be reviewed before a production deployment.

## 14. Future work

- Add a microphone/ADC or audio codec interface.
- Implement adaptive delta modulation or continuously variable slope delta modulation.
- Add digital filtering with configurable cutoff and quantitative spectral analysis.
- Add AXI/UART logging of real FPGA samples.
- Add switch synchronization/debouncing and a reset controller.
- Replace the fabric-generated clock with a clock-enable sample strobe.
- Compare resource use, SNR, and bandwidth with PCM, DPCM, and adaptive delta modulation.

## 15. Conclusion

A complete one-bit delta modulation system was implemented for the ZedBoard FPGA. The project demonstrates the encoder, decoder, reconstruction filter, physical outputs, simulation exports, and debug capture path needed to study delta modulation beyond theory. The selectable step sizes make the design’s core trade-off explicit: a step that is too small produces slope overload, while an excessive step produces granular noise. The nominal 128-count step satisfies the calculated slew-rate requirement for the 1 kHz, ±8192 test signal and the saved simulation/implementation evidence supports the expected behavior. The work is therefore a suitable FPGA laboratory project and a foundation for extensions toward real-time audio or adaptive delta modulation.

## 16. Figures to add before submission

1. **Figure 1:** System block diagram (redraw the architecture from Section 6 in your department’s preferred format).
2. **Figure 2:** Vivado waveform for `delta = 128` showing input, encoder staircase, DM bit, and filtered output.
3. **Figure 3:** Comparison waveform showing slope overload at `delta = 16` or `64`.
4. **Figure 4:** Comparison waveform showing granular noise at `delta = 512`.
5. **Figure 5:** Vivado implementation/timing summary screenshot.
6. **Figure 6:** ILA capture from the programmed ZedBoard.
7. **Figure 7:** Oscilloscope capture from Pmod JB2 after the RC filter.
8. **Figure 8:** Photograph of the ZedBoard, JTAG connection, switches, and Pmod measurement circuit.

## 17. References to include in the final departmental format

Use your institution’s required citation style. At a minimum, cite the board/tool documentation and the project source/reports below. Add the exact edition/URL/access date required by your template.

1. AMD/Xilinx, *Vivado Design Suite User Guide: Synthesis* and *Vivado Design Suite User Guide: Using Constraints*.
2. AMD/Xilinx, *Zynq-7000 SoC Technical Reference Manual*.
3. Avnet, *ZedBoard Hardware User Guide* and official master XDC file.
4. N. S. Jayant and P. Noll, *Digital Coding of Waveforms: Principles and Applications to Speech and Video*, Prentice-Hall, 1984.
5. Project HDL sources, simulation CSV, Vivado timing/utilization/DRC reports, `DCS/delta/`, accessed `[submission date]`.

## Appendix A: Repository guide

| Location | Content |
|---|---|
| `DCS/delta/delta.xpr` | Main Vivado project to open. |
| `DCS/dm_top.v` | Board top-level HDL. |
| `DCS/sine_gen.v` | Sine NCO/LUT. |
| `DCS/delta_modulator.v` | Encoder. |
| `DCS/delta_demodulator.v` | Decoder and LPF. |
| `DCS/tb_dm.v` | Main testbench and CSV writer. |
| `DCS/zedboard_dm.xdc` | Pin/timing constraints. |
| `DCS/delta/delta.runs/impl_1/dm_top.bit` | Generated bitstream. |
| `DCS/delta_mod.c` | Vitis/PS C reference implementation. |
| `DCS/Deltamodulation/` | Alternate experimental project; not the board target. |
