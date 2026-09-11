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
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list clk_s]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 16 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {dbg_err[0]} {dbg_err[1]} {dbg_err[2]} {dbg_err[3]} {dbg_err[4]} {dbg_err[5]} {dbg_err[6]} {dbg_err[7]} {dbg_err[8]} {dbg_err[9]} {dbg_err[10]} {dbg_err[11]} {dbg_err[12]} {dbg_err[13]} {dbg_err[14]} {dbg_err[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 16 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {dbg_yenc[0]} {dbg_yenc[1]} {dbg_yenc[2]} {dbg_yenc[3]} {dbg_yenc[4]} {dbg_yenc[5]} {dbg_yenc[6]} {dbg_yenc[7]} {dbg_yenc[8]} {dbg_yenc[9]} {dbg_yenc[10]} {dbg_yenc[11]} {dbg_yenc[12]} {dbg_yenc[13]} {dbg_yenc[14]} {dbg_yenc[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 16 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {dbg_x[0]} {dbg_x[1]} {dbg_x[2]} {dbg_x[3]} {dbg_x[4]} {dbg_x[5]} {dbg_x[6]} {dbg_x[7]} {dbg_x[8]} {dbg_x[9]} {dbg_x[10]} {dbg_x[11]} {dbg_x[12]} {dbg_x[13]} {dbg_x[14]} {dbg_x[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 16 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {dbg_ydec[0]} {dbg_ydec[1]} {dbg_ydec[2]} {dbg_ydec[3]} {dbg_ydec[4]} {dbg_ydec[5]} {dbg_ydec[6]} {dbg_ydec[7]} {dbg_ydec[8]} {dbg_ydec[9]} {dbg_ydec[10]} {dbg_ydec[11]} {dbg_ydec[12]} {dbg_ydec[13]} {dbg_ydec[14]} {dbg_ydec[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list dbg_bit]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk_s]
