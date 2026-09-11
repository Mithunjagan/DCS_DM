#=====================================================================
# zedboard_dm.xdc  -  ZedBoard (XC7Z020-1CLG484) constraints for dm_top
#
# Pin numbers and I/O bank assignments verified against
# Zedboard-Master.xdc (Avnet, Digilent digilent-xdc repository).
#
# BANK / VOLTAGE NOTE - this is the part people get wrong:
#   Bank 13  (GCLK, Pmod JB)  -> fixed 3.3 V  -> LVCMOS33
#   Bank 33  (LEDs)           -> fixed 3.3 V  -> LVCMOS33
#   Bank 34  (push buttons)   -> Vadj, jumper J18
#   Bank 35  (DIP switches)   -> Vadj, jumper J18
#
#   J18 ships from the factory at 1.8 V, so banks 34 and 35 use
#   LVCMOS18 below. If YOUR board has J18 moved to 3.3 V, change the
#   two LVCMOS18 entries to LVCMOS33 or the inputs will misbehave.
#=====================================================================

#---------------------------------------------------------------------
# 100 MHz system clock - "GCLK", Bank 13 (3.3 V fixed)
#---------------------------------------------------------------------
set_property -dict {PACKAGE_PIN Y9 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 10.000 -name sys_clk [get_ports clk]

# Declare the /200 divided sample clock. Without this Vivado analyses
# clk_s as if it were 100 MHz and reports bogus timing failures.
create_generated_clock -name clk_s -source [get_pins bufg_s/I] -divide_by 200 [get_pins bufg_s/O]
set_clock_groups -asynchronous -group [get_clocks sys_clk] -group [get_clocks clk_s]

#---------------------------------------------------------------------
# DIP switches SW0, SW1 - Bank 35 (Vadj, 1.8 V default)
#   SW1 SW0 = 00 -> delta 16   (severe slope overload)
#             01 -> delta 64   (slope overload)
#             10 -> delta 128  (correct)
#             11 -> delta 512  (granular noise)
#---------------------------------------------------------------------
set_property -dict {PACKAGE_PIN F22 IOSTANDARD LVCMOS18} [get_ports {sw[0]}]
set_property -dict {PACKAGE_PIN G22 IOSTANDARD LVCMOS18} [get_ports {sw[1]}]

#---------------------------------------------------------------------
# Centre push button BTNC -> reset - Bank 34 (Vadj, 1.8 V default)
#---------------------------------------------------------------------
set_property -dict {PACKAGE_PIN P16 IOSTANDARD LVCMOS18} [get_ports btn_rst]

#---------------------------------------------------------------------
# User LEDs LD0..LD7 - Bank 33 (3.3 V fixed)
#---------------------------------------------------------------------
set_property -dict {PACKAGE_PIN T22 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN T21 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN U22 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN U21 IOSTANDARD LVCMOS33} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN V22 IOSTANDARD LVCMOS33} [get_ports {led[4]}]
set_property -dict {PACKAGE_PIN W22 IOSTANDARD LVCMOS33} [get_ports {led[5]}]
set_property -dict {PACKAGE_PIN U19 IOSTANDARD LVCMOS33} [get_ports {led[6]}]
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports {led[7]}]

#---------------------------------------------------------------------
# Pmod JB - scope probe points - Bank 13 (3.3 V fixed)
#   JB1 (W12) = raw 1-bit delta-modulated stream
#   JB2 (W11) = reconstructed signal, 1-bit sigma-delta output.
#               Add 1 kohm in series + 100 nF to GND, probe across the
#               capacitor to see the recovered sine on a scope.
#   JB5/JB11 = GND, JB6/JB12 = VCC on the Pmod connector.
#---------------------------------------------------------------------
set_property -dict {PACKAGE_PIN W12 IOSTANDARD LVCMOS33} [get_ports dm_bit_pin]
set_property -dict {PACKAGE_PIN W11 IOSTANDARD LVCMOS33} [get_ports sd_dac_pin]

#---------------------------------------------------------------------
# Housekeeping
#---------------------------------------------------------------------
set_property CFGBVS VCCO        [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
