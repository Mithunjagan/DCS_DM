# FPGA Delta Modulation Demonstrator for ZedBoard

> **Project status:** board-targeted HDL, constraints, simulation testbench, a saved implementation, and a ready-made bitstream are included. The design is an educational demonstrator of *linear delta modulation*; it is not a production audio codec.

This repository demonstrates the complete delta-modulation signal chain on a Xilinx ZedBoard (XC7Z020): generation of a known sine-wave input, 1-bit delta encoding, transmission of the bit stream, delta decoding, low-pass reconstruction, live observation on LEDs/Pmod pins, and Integrated Logic Analyzer (ILA) debug capture.

The submission-ready technical report is in [PROJECT_REPORT.md](PROJECT_REPORT.md). It can be used as the basis for a project paper, synopsis, presentation, or viva.

## Abstract

Delta modulation represents a sampled waveform with only one bit per sample: `1` requests an upward step and `0` requests a downward step. This project implements that principle entirely in programmable logic. A 1 kHz, 16-bit sine wave is sampled at 500 kHz, encoded into a one-bit stream, decoded into a staircase, and smoothed through a first-order IIR low-pass filter. The user selects one of four encoder/decoder step sizes with the ZedBoard switches, making both major delta-modulation failure modes visible: slope overload for steps that are too small and granular noise for a step that is too large. The implementation is constrained for the ZedBoard, exposes the stream and reconstructed signal at Pmod pins, and includes ILA probes for internal inspection.

## Aim

To design, simulate, implement, and demonstrate a real-time 1-bit delta modulation and demodulation system on the ZedBoard FPGA, while experimentally showing the relationship between step size, slope overload, granular noise, and reconstruction quality.

## Objectives

- Generate a deterministic 1 kHz, signed 16-bit sine-wave test signal in FPGA logic.
- Sample the signal at 500 kHz from the ZedBoard 100 MHz oscillator.
- Encode each sample as a single delta-modulated bit using a saturating staircase estimate.
- Decode the bit stream, low-pass filter the reconstructed staircase, and expose the result in hardware.
- Select the step size at run time using two slide switches.
- Verify behavior in simulation using waveform (`.vcd`) and CSV outputs.
- Build a ZedBoard bitstream, meet timing, and provide ILA observability.
- Provide an equivalent Cortex-A9 software model for UART/CSV experimentation.

## What is in this repository?

There are **two Vivado projects**. Only one is the intended board target.

| Path | Purpose | Use it? |
|---|---|---|
| `DCS/delta/delta.xpr` | Main ZedBoard FPGA project; top level is `dm_top`; has XDC constraints and a generated bitstream. | **Yes** |
| `DCS/Deltamodulation/Deltamodulation.xpr` | Earlier experimental/simulation-oriented design; its top is a testbench and it has no board constraints. | No, except as a failure-case study |
| `DCS/delta_mod.c` | Standalone C model for the Zynq Cortex-A9 PS, designed for Vitis UART output. | Optional |

### Maintained source files

| File | Role |
|---|---|
| `DCS/dm_top.v` | Main board top level: clock division, reset, switch control, module wiring, LED/Pmod outputs, and ILA probe marks. |
| `DCS/sine_gen.v` | 32-bit phase accumulator and 256-sample signed sine ROM. |
| `DCS/delta_modulator.v` | One-bit delta encoder with signed saturation. |
| `DCS/delta_demodulator.v` | One-bit decoder/integrator and first-order IIR smoothing filter. |
| `DCS/tb_dm.v` | Main behavioral testbench; writes `tb_dm.vcd` and `dm_out.csv`. |
| `DCS/zedboard_dm.xdc` | ZedBoard package pins, I/O standards, and clock constraints. |
| `DCS/bufg_stub.v` | Simulation-only substitute for the Xilinx `BUFG` primitive; do **not** add it to the Vivado board project. |
| `DCS/delta_mod.c` | Software reference model that prints sample data and SNR for four step sizes. |
| `DCS/Deltamodulation/...` | Earlier alternate implementation and its testbench; retained for comparison, not deployment. |

### Generated and tool-owned files

The following are Vivado outputs, not hand-maintained source: `*.cache`, `*.runs`, `*.sim`, `*.hw`, `*.ip_user_files`, `*.dcp`, `*.wdb`, `*.pb`, `*.jou`, `*.log`, and the generated debug/IP data. The deployed bitstream is:

```text
DCS/delta/delta.runs/impl_1/dm_top.bit
```

Do not edit generated files manually. Recreate them by running synthesis and implementation in Vivado.

## Architecture

```text
              100 MHz ZedBoard clock
                         |
                  divide by 200
                         |
                  500 kHz clk_s
                         |
        +----------------+----------------+
        |                                 |
   sine_gen                         reset synchronizer
   1 kHz, +/-8191                         |
        |                                 |
        v                                 v
   delta_modulator <--- SW1:SW0 selects delta = 16/64/128/512
        |                     |
        |                     +--> encoder staircase and tracking error (ILA)
        v
   one-bit dm_bit ---------------------> Pmod JB1
        |
        v
   delta_demodulator
        |                     |
        |                     +--> raw decoder staircase (ILA)
        v
   IIR low-pass output
        |                     |
        |                     +--> filtered reconstruction and error (ILA)
        +--> LED[7:0]
        +--> 1-bit sigma-delta DAC --> Pmod JB2 --> external RC filter --> oscilloscope
```

## Logic flow and theory

For each sample `x[n]`, the encoder compares the input with its previous staircase value `y[n-1]`:

```text
b[n] = 1, if x[n] >= y[n-1]; otherwise b[n] = 0
y[n] = saturate(y[n-1] + delta), if b[n] = 1
       saturate(y[n-1] - delta), if b[n] = 0
```

`b[n]` is the one-bit transmitted delta-modulated output. The decoder performs the inverse staircase integration from the received bit:

```text
y_dec[n] = saturate(y_dec[n-1] +/- delta)
filtered[n] = filtered[n-1] + (y_dec[n] - filtered[n-1]) >>> 5
```

The last expression is a first-order IIR low-pass filter with a `1/32` update fraction. It removes high-frequency staircase/granular energy at the cost of delay. At the 500 kHz sample rate, its approximate small-signal corner frequency is 2.49 kHz, appropriate for the 1 kHz test tone.

### Why `delta = 128` is the design point

For `x(t) = A sin(2*pi*f*t)`, the greatest input slope is `2*pi*f*A`. A delta modulator can track it only when:

```text
delta >= 2*pi*f*A / Fs
```

Here `A = 8192`, `f = 1000 Hz`, and `Fs = 500000 Hz`, giving a required step of approximately `102.94`. Therefore `128` is large enough to track the sine, `16` and `64` cause slope overload, and `512` creates visibly larger granular/quantization noise.

## Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| Board clock | 100 MHz | ZedBoard oscillator on `Y9`. |
| Divider | 200 | Creates the 500 kHz codec sample clock. |
| Sample rate | 500 kHz | One encoded bit is produced per sample. |
| Tone frequency | 1 kHz | Actual NCO value is approximately 1000.0000475 Hz. |
| Signal width | 16 bits signed | Signed sample/staircase data range. |
| Tone amplitude | 8191 | Approximately one quarter of signed 16-bit full scale. |
| Sine LUT | 256 entries | The high eight phase bits select the ROM location. |
| DM stream | 1 bit/sample | Nominal raw serial rate: 500 kbit/s. |
| Filter shift | 5 | IIR update fraction `1/32`. |

## Hardware interface

| Signal | ZedBoard resource | Notes |
|---|---|---|
| `clk` | 100 MHz oscillator, pin Y9 | LVCMOS33, 10 ns primary clock. |
| `btn_rst` | BTNC, pin P16 | Active high. Bank 34 uses LVCMOS18 with factory-default J18 setting. |
| `sw[0]`, `sw[1]` | SW0 F22, SW1 G22 | Bank 35 uses LVCMOS18 with factory-default J18 setting. |
| `led[7:0]` | LD0–LD7 | Signed reconstructed waveform visualization. |
| `dm_bit_pin` | Pmod JB1, W12 | Raw 1-bit delta-modulated stream. |
| `sd_dac_pin` | Pmod JB2, W11 | One-bit pulse-density representation of filtered output. |

> **Important:** The XDC assumes the ZedBoard J18 VADJ jumper is at its factory 1.8 V setting. If it is moved to 3.3 V, change the button and switch I/O standards from `LVCMOS18` to `LVCMOS33` before implementation.

## Prerequisites

### FPGA path

- Windows or Linux workstation with Xilinx Vivado; the saved project artifacts were produced with **Vivado 2022.2**.
- ZedBoard with XC7Z020-1CLG484.
- JTAG programming connection and power supply.
- Optional: oscilloscope, jumper wires, 1 kOhm resistor, and 100 nF capacitor for the Pmod output.

### PS software path

- Xilinx Vitis with a Zynq standalone/BSP platform for the ZedBoard.
- A USB-UART terminal set to **115200-8-N-1**.

## Procedure: simulate the FPGA design

1. Open `DCS/delta/delta.xpr` in Vivado.
2. Confirm `dm_top` is the design top and `tb_dm` is the simulation top.
3. Select **Run Simulation → Run Behavioral Simulation**.
4. In XSIM, choose **Run All**. Do not stop at the default 1000 ns waveform-script duration: the testbench ends by itself after 4096 captured samples.
5. Inspect `x`, `y_enc`, `dm_bit`, `y_dec_stair`, and `y_dec` in the waveform viewer.
6. Open the generated `dm_out.csv` in Excel, MATLAB, Python, or another plotting tool. The saved example is under `DCS/delta/delta.sim/sim_1/behav/xsim/`.
7. Change `DELTA` in `tb_dm.v` to `16`, `64`, `128`, and `512`; rerun and compare tracking error and output smoothness.

The CSV columns are:

```text
n,input,encoder_staircase,dm_bit,decoder_staircase,decoder_filtered,error
```

## Procedure: build and run on the ZedBoard

1. Set the board’s J18 voltage jumper to match the I/O standards in `zedboard_dm.xdc` (factory default: 1.8 V for switches/buttons).
2. Connect the board through JTAG and power it on.
3. Open `DCS/delta/delta.xpr` with Vivado 2022.2 or later.
4. Check that the active source files are `dm_top.v`, `sine_gen.v`, `delta_modulator.v`, and `delta_demodulator.v`; the source paths intentionally sit one level above the `.xpr` directory.
5. Run **Synthesis**, then **Implementation**, then **Generate Bitstream**. Alternatively, use the included `DCS/delta/delta.runs/impl_1/dm_top.bit` after confirming it was built from the desired revision.
6. Open **Hardware Manager**, connect to the target, and program `dm_top.bit`.
7. Press BTNC once to restart the waveform chain.
8. Set `SW1:SW0 = 10` for normal operation (`delta = 128`). The LEDs should vary with the reconstructed sine.
9. Probe Pmod JB1 for the DM bit stream. Probe JB2 only through the recommended RC network (1 kOhm series resistor and 100 nF capacitor to ground); inspect across the capacitor.
10. Use Vivado Hardware Manager to arm the ILA and capture `dbg_x`, `dbg_yenc`, `dbg_ydec`, `dbg_err`, and `dbg_bit`.

## Procedure: run the Cortex-A9 software model

1. In Vitis, create a Zynq standalone application for the ZedBoard (for example from a `hello_world` template).
2. Replace the generated application source with `DCS/delta_mod.c`.
3. Build and run on the Cortex-A9 processor.
4. Open a serial terminal at 115200-8-N-1.
5. Capture the CSV output. The program evaluates delta values 16, 64, 128, and 512, prints the theoretical slope limit, and reports an SNR for each run.

This C file is a reference/learning model. It uses Xilinx BSP headers (`xparameters.h`, `xil_printf.h`) and is not a generic desktop C program without adapting those dependencies.

## Expected observations

| Mode | What should be observed in simulation / ILA / scope |
|---|---|
| `delta = 16` | Long runs of equal DM bits near sine peaks/slopes; encoder staircase cannot catch the input. |
| `delta = 64` | Better than 16, but still insufficient maximum staircase slope; visible tracking lag/error. |
| `delta = 128` | Fast alternating bit pattern around the sine; encoder follows input closely; filtered output is a smooth delayed sine. |
| `delta = 512` | Encoder crosses the input with coarse steps; bitstream and staircase are noisier; LPF reduces but cannot remove all granularity. |

The included saved `delta = 128` simulation contains 4096 samples with a ±8191 input, encoder RMSE of about 126.9 counts, encoder SNR of about 33.16 dB, and maximum absolute tracking error of 322 counts.

## Saved implementation evidence

The saved `delta` implementation was built for `xc7z020clg484-1` and records:

- Fully routed design with zero routing errors.
- Timing closure: zero failing endpoints and worst setup slack of 26.957 ns.
- Core synthesis footprint: 183 LUTs and 110 registers.
- Final placed footprint: 1500 LUTs, 2351 registers, and eight BRAM tiles. The increase is principally the automatically inserted ILA/debug hub, not the delta codec.
- Estimated on-chip power: 0.108 W, with medium confidence because real switching activity was not imported.

See `DCS/delta/delta.runs/impl_1/` for the timing, utilization, route-status, DRC, power reports, checkpoints, probes, and bitstream.

## How this differs from typical student projects

This is not a new delta-modulation algorithm; its value is that it is an **end-to-end, inspectable hardware experiment** rather than a graph-only demonstration.

- It uses a real FPGA clock, constrained board pins, and a deployable bitstream rather than only MATLAB/Python plots.
- It implements both the encoder and decoder in HDL and makes the actual one-bit stream available on a physical Pmod pin.
- It lets the examiner deliberately demonstrate both classic error mechanisms by changing switches at run time.
- It includes signed saturation, so the internal staircase does not silently wrap around at numeric limits.
- It includes ILA instrumentation and an analog-visible one-bit DAC output, allowing digital and physical observation of the same signal path.
- It has a software reference model on the Zynq PS for CSV/SNR experiments.
- Unlike the alternate `Deltamodulation` project in this repository, the main project has a real hardware top level, pin constraints, implementation reports, and a bitstream.

## Known limitations and honest scope

- The input is an internally generated sine, not a microphone/ADC input.
- The raw Pmod output is digital pulse density, not a line-level analog signal; it requires an external RC low-pass network.
- The button chain synchronizes reset but does **not** debounce a mechanical switch.
- The slide switches are used directly in the sample-clock domain. Synchronization/debouncing should be added for a robust product design.
- The design creates a fabric-derived 500 kHz clock. This is acceptable for the slow demonstrator but a clock-enable architecture or clock-management primitive is preferable in a larger design.
- The XDC currently declares the source and derived clocks asynchronous. That is tolerable here because no ordinary data crosses between their logic domains, but it should be reconsidered if the design evolves.
- The saved routed DRC has non-fatal warnings, including Zynq PS7 configuration guidance and debug-hub warnings. Review them before a release intended for deployment beyond JTAG demonstration.
- The alternative `Deltamodulation` project deliberately/incidentally exhibits slope overload and is not a valid hardware comparison baseline.

## Suggested evaluation checklist

- [ ] Main Vivado project opens with no missing source files.
- [ ] Behavioral simulation completes and creates a 4096-row CSV capture.
- [ ] `delta=128` has no sustained long bit runs and visibly tracks the input.
- [ ] `delta=16` and `delta=64` exhibit slope overload.
- [ ] `delta=512` exhibits increased granular noise.
- [ ] Implementation completes with no timing failures.
- [ ] Board is configured with J18 voltage matching the XDC.
- [ ] LEDs, JB1 stream, JB2 RC-filtered output, and ILA captures all behave as expected.

## Recommended future extensions

1. Add an external audio ADC/PDM microphone input and a proper output DAC or PWM filter stage.
2. Add switch/button synchronizers and debouncers.
3. Replace the fabric clock with a sample-rate clock enable.
4. Add an automated multi-step testbench that calculates SNR, error bounds, and bit-run statistics for every delta mode.
5. Add UART/AXI streaming so the PS can log FPGA samples in real time.
6. Compare fixed-step delta modulation with adaptive delta modulation (CVSD/ADM).

## Academic use

For the paper-ready narrative, figures, procedure, observation tables, result interpretation, comparison wording, limitations, and reference checklist, start with [PROJECT_REPORT.md](PROJECT_REPORT.md). Replace only the title-page placeholders and insert your own screenshots of the ILA, simulation waveform, and oscilloscope trace before submission.
