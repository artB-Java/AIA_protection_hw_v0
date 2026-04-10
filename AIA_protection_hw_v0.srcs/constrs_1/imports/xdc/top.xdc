## ==============================
## Clock de 12 MHz (single-ended)
## ==============================
set_property PACKAGE_PIN U14 [get_ports iClk]
set_property IOSTANDARD LVCMOS33 [get_ports iClk]
#create_clock -name clk12M -period 83.333 [get_ports iClk]   ; 12 MHz
# (Raro) Se houver reclamação de rota dedicada:
# set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets iClk]

## ==============================
## Reset assíncrono (ativo baixo)
## ==============================
set_property PACKAGE_PIN T11 [get_ports iRstn]
set_property IOSTANDARD LVCMOS33 [get_ports iRstn]
set_property PULLTYPE PULLUP [get_ports iRstn]
# Reset assíncrono: não temporizar contra os clocks
set_false_path -from [get_ports iRstn] -to [all_registers]

## ==============================
## Sinais de teste / debug
## ==============================


# Saída de teste
set_property PACKAGE_PIN W19 [get_ports o_teste]
set_property IOSTANDARD LVCMOS33 [get_ports o_teste]
set_property DRIVE 8 [get_ports o_teste]
set_property SLEW FAST [get_ports o_teste]

## ==============================
## Saída Global Trip
## ==============================
set_property PACKAGE_PIN M15 [get_ports o_GlobalTrip]
set_property IOSTANDARD LVCMOS18 [get_ports o_GlobalTrip]
set_property DRIVE 12 [get_ports o_GlobalTrip]
set_property SLEW FAST [get_ports o_GlobalTrip]

# (Opcional) Desconsiderar timing para saídas de debug:
# set_false_path -to [get_ports {o_GlobalTrip o_teste}]

## ==============================
## SPI Slave (3V3 - Bank 34)
## ==============================
# SCK (entrada no SLAVE)
#set_property PACKAGE_PIN N20 [get_ports spi_sck]
#set_property IOSTANDARD LVCMOS33 [get_ports spi_sck]

## MOSI (entrada no SLAVE)
#set_property PACKAGE_PIN P20 [get_ports spi_mosi]
#set_property IOSTANDARD LVCMOS33 [get_ports spi_mosi]

## MISO (saída do SLAVE)
#set_property PACKAGE_PIN W14 [get_ports spi_miso]
#set_property IOSTANDARD LVCMOS33 [get_ports spi_miso]
#set_property DRIVE 8 [get_ports spi_miso]
#set_property SLEW FAST [get_ports spi_miso]

## CS# vindo do master (SPISEL) - entrada
#set_property PACKAGE_PIN Y16 [get_ports spi_spisel]
#set_property IOSTANDARD LVCMOS33 [get_ports spi_spisel]
#set_property PULLTYPE PULLUP [get_ports spi_spisel]

## ==============================
## XADC - Canais Auxiliares (VAUX0..3)
## (Não usar IOSTANDARD em pinos analógicos)
## ==============================
# XADC external channels vauxp0..vauxp10 / vauxn0..vauxn10

# canal 0
set_property PACKAGE_PIN C20 [get_ports vauxp0]
set_property PACKAGE_PIN B20 [get_ports vauxn0]
# canal 1
set_property PACKAGE_PIN E17 [get_ports vauxp1]
set_property PACKAGE_PIN D18 [get_ports vauxn1]
# canal 2
set_property PACKAGE_PIN M19 [get_ports vauxp2]
set_property PACKAGE_PIN M20 [get_ports vauxn2]
# canal 3
set_property PACKAGE_PIN L19 [get_ports vauxp3]
set_property PACKAGE_PIN L20 [get_ports vauxn3]
# canal 4
set_property PACKAGE_PIN J18 [get_ports vauxp4]
set_property PACKAGE_PIN H18 [get_ports vauxn4]
# canal 5
set_property PACKAGE_PIN J20 [get_ports vauxp5]
set_property PACKAGE_PIN H20 [get_ports vauxn5]
# canal 6
set_property PACKAGE_PIN K14 [get_ports vauxp6]
set_property PACKAGE_PIN J14 [get_ports vauxn6]
# canal 7
set_property PACKAGE_PIN L14 [get_ports vauxp7]
set_property PACKAGE_PIN L15 [get_ports vauxn7]
# canal 8
set_property PACKAGE_PIN B19 [get_ports vauxp8]
set_property PACKAGE_PIN A20 [get_ports vauxn8]
# canal 9
set_property PACKAGE_PIN E18 [get_ports vauxp9]
set_property PACKAGE_PIN E19 [get_ports vauxn9]
# canal 10
set_property PACKAGE_PIN M17 [get_ports vauxp10]
set_property PACKAGE_PIN M18 [get_ports vauxn10]
# canal 11
set_property PACKAGE_PIN K19 [get_ports vauxp11]
set_property PACKAGE_PIN J19 [get_ports vauxn11]













#connect_debug_port u_ila_0/probe4 [get_nets [list {inst_prot_50_A/i_sample_s12[0]} {inst_prot_50_A/i_sample_s12[1]} {inst_prot_50_A/i_sample_s12[2]} {inst_prot_50_A/i_sample_s12[3]} {inst_prot_50_A/i_sample_s12[4]} {inst_prot_50_A/i_sample_s12[5]} {inst_prot_50_A/i_sample_s12[6]} {inst_prot_50_A/i_sample_s12[7]} {inst_prot_50_A/i_sample_s12[8]} {inst_prot_50_A/i_sample_s12[9]} {inst_prot_50_A/i_sample_s12[10]} {inst_prot_50_A/i_sample_s12[11]}]]
#connect_debug_port u_ila_0/probe5 [get_nets [list {inst_prot_50N/i_sample_s12[0]} {inst_prot_50N/i_sample_s12[1]} {inst_prot_50N/i_sample_s12[2]} {inst_prot_50N/i_sample_s12[3]} {inst_prot_50N/i_sample_s12[4]} {inst_prot_50N/i_sample_s12[5]} {inst_prot_50N/i_sample_s12[6]} {inst_prot_50N/i_sample_s12[7]} {inst_prot_50N/i_sample_s12[8]} {inst_prot_50N/i_sample_s12[9]} {inst_prot_50N/i_sample_s12[10]} {inst_prot_50N/i_sample_s12[11]}]]
#connect_debug_port u_ila_0/probe6 [get_nets [list {inst_prot_50_B/i_sample_s12[0]} {inst_prot_50_B/i_sample_s12[1]} {inst_prot_50_B/i_sample_s12[2]} {inst_prot_50_B/i_sample_s12[3]} {inst_prot_50_B/i_sample_s12[4]} {inst_prot_50_B/i_sample_s12[5]} {inst_prot_50_B/i_sample_s12[6]} {inst_prot_50_B/i_sample_s12[7]} {inst_prot_50_B/i_sample_s12[8]} {inst_prot_50_B/i_sample_s12[9]} {inst_prot_50_B/i_sample_s12[10]} {inst_prot_50_B/i_sample_s12[11]}]]
#connect_debug_port u_ila_0/probe8 [get_nets [list {inst_prot_50_C/i_sample_s12[0]} {inst_prot_50_C/i_sample_s12[1]} {inst_prot_50_C/i_sample_s12[2]} {inst_prot_50_C/i_sample_s12[3]} {inst_prot_50_C/i_sample_s12[4]} {inst_prot_50_C/i_sample_s12[5]} {inst_prot_50_C/i_sample_s12[6]} {inst_prot_50_C/i_sample_s12[7]} {inst_prot_50_C/i_sample_s12[8]} {inst_prot_50_C/i_sample_s12[9]} {inst_prot_50_C/i_sample_s12[10]} {inst_prot_50_C/i_sample_s12[11]}]]

#connect_debug_port u_ila_0/probe3 [get_nets [list {inst_prot_50N/i_sample_u12[0]} {inst_prot_50N/i_sample_u12[1]} {inst_prot_50N/i_sample_u12[2]} {inst_prot_50N/i_sample_u12[3]} {inst_prot_50N/i_sample_u12[4]} {inst_prot_50N/i_sample_u12[5]} {inst_prot_50N/i_sample_u12[6]} {inst_prot_50N/i_sample_u12[7]} {inst_prot_50N/i_sample_u12[8]} {inst_prot_50N/i_sample_u12[9]} {inst_prot_50N/i_sample_u12[10]} {inst_prot_50N/i_sample_u12[11]}]]
#connect_debug_port u_ila_0/probe9 [get_nets [list {inst_prot_50_B/i_sample_u12[0]} {inst_prot_50_B/i_sample_u12[1]} {inst_prot_50_B/i_sample_u12[2]} {inst_prot_50_B/i_sample_u12[3]} {inst_prot_50_B/i_sample_u12[4]} {inst_prot_50_B/i_sample_u12[5]} {inst_prot_50_B/i_sample_u12[6]} {inst_prot_50_B/i_sample_u12[7]} {inst_prot_50_B/i_sample_u12[8]} {inst_prot_50_B/i_sample_u12[9]} {inst_prot_50_B/i_sample_u12[10]} {inst_prot_50_B/i_sample_u12[11]}]]
#connect_debug_port u_ila_0/probe10 [get_nets [list {inst_prot_50_A/i_sample_u12[0]} {inst_prot_50_A/i_sample_u12[1]} {inst_prot_50_A/i_sample_u12[2]} {inst_prot_50_A/i_sample_u12[3]} {inst_prot_50_A/i_sample_u12[4]} {inst_prot_50_A/i_sample_u12[5]} {inst_prot_50_A/i_sample_u12[6]} {inst_prot_50_A/i_sample_u12[7]} {inst_prot_50_A/i_sample_u12[8]} {inst_prot_50_A/i_sample_u12[9]} {inst_prot_50_A/i_sample_u12[10]} {inst_prot_50_A/i_sample_u12[11]}]]
#connect_debug_port u_ila_0/probe11 [get_nets [list {inst_prot_50_C/i_sample_u12[0]} {inst_prot_50_C/i_sample_u12[1]} {inst_prot_50_C/i_sample_u12[2]} {inst_prot_50_C/i_sample_u12[3]} {inst_prot_50_C/i_sample_u12[4]} {inst_prot_50_C/i_sample_u12[5]} {inst_prot_50_C/i_sample_u12[6]} {inst_prot_50_C/i_sample_u12[7]} {inst_prot_50_C/i_sample_u12[8]} {inst_prot_50_C/i_sample_u12[9]} {inst_prot_50_C/i_sample_u12[10]} {inst_prot_50_C/i_sample_u12[11]}]]
#connect_debug_port u_ila_0/probe20 [get_nets [list inst_prot_50_A/i_valid]]
#connect_debug_port u_ila_0/probe21 [get_nets [list inst_prot_50_C/i_valid]]
#connect_debug_port u_ila_0/probe22 [get_nets [list inst_prot_50N/i_valid]]
#connect_debug_port u_ila_0/probe23 [get_nets [list inst_prot_50_B/i_valid]]
#connect_debug_port u_ila_0/probe26 [get_nets [list inst_prot_50N/o_trip]]
#connect_debug_port u_ila_0/probe27 [get_nets [list inst_prot_50_A/o_trip]]
#connect_debug_port u_ila_0/probe28 [get_nets [list inst_prot_50_B/o_trip]]
#connect_debug_port u_ila_0/probe29 [get_nets [list inst_prot_50_C/o_trip]]




connect_debug_port u_ila_0/probe8 [get_nets [list {inst_biasdec_vaux0/i_decimation_factor[0]} {inst_biasdec_vaux0/i_decimation_factor[1]} {inst_biasdec_vaux0/i_decimation_factor[2]} {inst_biasdec_vaux0/i_decimation_factor[3]} {inst_biasdec_vaux0/i_decimation_factor[4]} {inst_biasdec_vaux0/i_decimation_factor[5]} {inst_biasdec_vaux0/i_decimation_factor[6]} {inst_biasdec_vaux0/i_decimation_factor[7]}]]






set_property MARK_DEBUG true [get_nets {rmsA_opt[6]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[8]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[9]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[14]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[21]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[24]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[31]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[0]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[5]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[10]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[12]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[17]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[22]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[25]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[28]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[1]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[7]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[15]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[18]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[26]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[30]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[2]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[3]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[4]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[11]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[13]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[16]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[19]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[20]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[23]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[27]}]
set_property MARK_DEBUG true [get_nets {rmsA_opt[29]}]
set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[0]}]
set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[2]}]
set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[3]}]
set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[6]}]
set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[8]}]
set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[9]}]
set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[11]}]
set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[1]}]
set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[4]}]
set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[5]}]
set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[7]}]
set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[10]}]
connect_debug_port u_ila_0/probe0 [get_nets [list {angC_opt[0]} {angC_opt[1]} {angC_opt[2]} {angC_opt[3]} {angC_opt[4]} {angC_opt[5]} {angC_opt[6]} {angC_opt[7]} {angC_opt[8]} {angC_opt[9]} {angC_opt[10]} {angC_opt[11]} {angC_opt[12]} {angC_opt[13]} {angC_opt[14]} {angC_opt[15]}]]
connect_debug_port u_ila_0/probe1 [get_nets [list {absA_opt[0]} {absA_opt[1]} {absA_opt[2]} {absA_opt[3]} {absA_opt[4]} {absA_opt[5]} {absA_opt[6]} {absA_opt[7]} {absA_opt[8]} {absA_opt[9]} {absA_opt[10]} {absA_opt[11]} {absA_opt[12]} {absA_opt[13]} {absA_opt[14]} {absA_opt[15]} {absA_opt[16]} {absA_opt[17]} {absA_opt[18]} {absA_opt[19]} {absA_opt[20]} {absA_opt[21]} {absA_opt[22]} {absA_opt[23]} {absA_opt[24]} {absA_opt[25]} {absA_opt[26]} {absA_opt[27]} {absA_opt[28]} {absA_opt[29]} {absA_opt[30]} {absA_opt[31]}]]
connect_debug_port u_ila_0/probe2 [get_nets [list {angB_opt[0]} {angB_opt[1]} {angB_opt[2]} {angB_opt[3]} {angB_opt[4]} {angB_opt[5]} {angB_opt[6]} {angB_opt[7]} {angB_opt[8]} {angB_opt[9]} {angB_opt[10]} {angB_opt[11]} {angB_opt[12]} {angB_opt[13]} {angB_opt[14]} {angB_opt[15]}]]
connect_debug_port u_ila_0/probe3 [get_nets [list {absC_opt[0]} {absC_opt[1]} {absC_opt[2]} {absC_opt[3]} {absC_opt[4]} {absC_opt[5]} {absC_opt[6]} {absC_opt[7]} {absC_opt[8]} {absC_opt[9]} {absC_opt[10]} {absC_opt[11]} {absC_opt[12]} {absC_opt[13]} {absC_opt[14]} {absC_opt[15]} {absC_opt[16]} {absC_opt[17]} {absC_opt[18]} {absC_opt[19]} {absC_opt[20]} {absC_opt[21]} {absC_opt[22]} {absC_opt[23]} {absC_opt[24]} {absC_opt[25]} {absC_opt[26]} {absC_opt[27]} {absC_opt[28]} {absC_opt[29]} {absC_opt[30]} {absC_opt[31]}]]
connect_debug_port u_ila_0/probe4 [get_nets [list {absB_opt[0]} {absB_opt[1]} {absB_opt[2]} {absB_opt[3]} {absB_opt[4]} {absB_opt[5]} {absB_opt[6]} {absB_opt[7]} {absB_opt[8]} {absB_opt[9]} {absB_opt[10]} {absB_opt[11]} {absB_opt[12]} {absB_opt[13]} {absB_opt[14]} {absB_opt[15]} {absB_opt[16]} {absB_opt[17]} {absB_opt[18]} {absB_opt[19]} {absB_opt[20]} {absB_opt[21]} {absB_opt[22]} {absB_opt[23]} {absB_opt[24]} {absB_opt[25]} {absB_opt[26]} {absB_opt[27]} {absB_opt[28]} {absB_opt[29]} {absB_opt[30]} {absB_opt[31]}]]
connect_debug_port u_ila_0/probe5 [get_nets [list {angA_opt[0]} {angA_opt[1]} {angA_opt[2]} {angA_opt[3]} {angA_opt[4]} {angA_opt[5]} {angA_opt[6]} {angA_opt[7]} {angA_opt[8]} {angA_opt[9]} {angA_opt[10]} {angA_opt[11]} {angA_opt[12]} {angA_opt[13]} {angA_opt[14]} {angA_opt[15]}]]
connect_debug_port u_ila_0/probe6 [get_nets [list {rmsB_opt[0]} {rmsB_opt[1]} {rmsB_opt[2]} {rmsB_opt[3]} {rmsB_opt[4]} {rmsB_opt[5]} {rmsB_opt[6]} {rmsB_opt[7]} {rmsB_opt[8]} {rmsB_opt[9]} {rmsB_opt[10]} {rmsB_opt[11]} {rmsB_opt[12]} {rmsB_opt[13]} {rmsB_opt[14]} {rmsB_opt[15]} {rmsB_opt[16]} {rmsB_opt[17]} {rmsB_opt[18]} {rmsB_opt[19]} {rmsB_opt[20]} {rmsB_opt[21]} {rmsB_opt[22]} {rmsB_opt[23]} {rmsB_opt[24]} {rmsB_opt[25]} {rmsB_opt[26]} {rmsB_opt[27]} {rmsB_opt[28]} {rmsB_opt[29]} {rmsB_opt[30]} {rmsB_opt[31]}]]
connect_debug_port u_ila_0/probe7 [get_nets [list {rmsA_opt[0]} {rmsA_opt[1]} {rmsA_opt[2]} {rmsA_opt[3]} {rmsA_opt[4]} {rmsA_opt[5]} {rmsA_opt[6]} {rmsA_opt[7]} {rmsA_opt[8]} {rmsA_opt[9]} {rmsA_opt[10]} {rmsA_opt[11]} {rmsA_opt[12]} {rmsA_opt[13]} {rmsA_opt[14]} {rmsA_opt[15]} {rmsA_opt[16]} {rmsA_opt[17]} {rmsA_opt[18]} {rmsA_opt[19]} {rmsA_opt[20]} {rmsA_opt[21]} {rmsA_opt[22]} {rmsA_opt[23]} {rmsA_opt[24]} {rmsA_opt[25]} {rmsA_opt[26]} {rmsA_opt[27]} {rmsA_opt[28]} {rmsA_opt[29]} {rmsA_opt[30]} {rmsA_opt[31]}]]
connect_debug_port u_ila_0/probe8 [get_nets [list {rmsC_opt[0]} {rmsC_opt[1]} {rmsC_opt[2]} {rmsC_opt[3]} {rmsC_opt[4]} {rmsC_opt[5]} {rmsC_opt[6]} {rmsC_opt[7]} {rmsC_opt[8]} {rmsC_opt[9]} {rmsC_opt[10]} {rmsC_opt[11]} {rmsC_opt[12]} {rmsC_opt[13]} {rmsC_opt[14]} {rmsC_opt[15]} {rmsC_opt[16]} {rmsC_opt[17]} {rmsC_opt[18]} {rmsC_opt[19]} {rmsC_opt[20]} {rmsC_opt[21]} {rmsC_opt[22]} {rmsC_opt[23]} {rmsC_opt[24]} {rmsC_opt[25]} {rmsC_opt[26]} {rmsC_opt[27]} {rmsC_opt[28]} {rmsC_opt[29]} {rmsC_opt[30]} {rmsC_opt[31]}]]
connect_debug_port u_ila_0/probe11 [get_nets [list {s_vaux0_decim_s12[0]} {s_vaux0_decim_s12[1]} {s_vaux0_decim_s12[2]} {s_vaux0_decim_s12[3]} {s_vaux0_decim_s12[4]} {s_vaux0_decim_s12[5]} {s_vaux0_decim_s12[6]} {s_vaux0_decim_s12[7]} {s_vaux0_decim_s12[8]} {s_vaux0_decim_s12[9]} {s_vaux0_decim_s12[10]} {s_vaux0_decim_s12[11]}]]



connect_debug_port u_ila_0/probe5 [get_nets [list {s_sine_out[0]} {s_sine_out[1]} {s_sine_out[2]} {s_sine_out[3]} {s_sine_out[4]} {s_sine_out[5]} {s_sine_out[6]} {s_sine_out[7]} {s_sine_out[8]} {s_sine_out[9]} {s_sine_out[10]} {s_sine_out[11]}]]
connect_debug_port u_ila_0/probe18 [get_nets [list s_ovalid]]






set_property MARK_DEBUG false [get_nets s_clk1]
set_property MARK_DEBUG true [get_nets s_f46s1_trip]
set_property MARK_DEBUG true [get_nets s_f46s2_trip]

#set_property IOSTANDARD LVCMOS33 [get_ports I2C0_SCL_O_0]
#set_property IOSTANDARD LVCMOS33 [get_ports I2C0_SDA_O_0]
#set_property PACKAGE_PIN P16 [get_ports I2C0_SCL]
#set_property PACKAGE_PIN P15 [get_ports I2C0_SDA]


set_property IOSTANDARD LVCMOS33 [get_ports I2C0_SCL]
set_property IOSTANDARD LVCMOS33 [get_ports I2C0_SDA]

set_property PACKAGE_PIN P15 [get_ports IIC_0_0_scl_io]
set_property PACKAGE_PIN P16 [get_ports IIC_0_0_sda_io]
set_property IOSTANDARD LVCMOS33 [get_ports IIC_0_0_scl_io]
set_property IOSTANDARD LVCMOS33 [get_ports IIC_0_0_sda_io]

set_property PULLTYPE PULLUP [get_ports IIC_0_0_scl_io]
set_property PULLTYPE PULLUP [get_ports IIC_0_0_sda_io]
set_property SLEW FAST [get_ports IIC_0_0_scl_io]
set_property SLEW FAST [get_ports IIC_0_0_sda_io]

connect_debug_port u_ila_0/probe19 [get_nets [list s_OutTripBooleanBlock]]


set_property port_width 6 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list {s_sel_s0[0]} {s_sel_s0[1]} {s_sel_s0[2]} {s_sel_s0[3]} {s_sel_s0[4]} {s_sel_s0[5]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 6 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {s_sel_s7[0]} {s_sel_s7[1]} {s_sel_s7[2]} {s_sel_s7[3]} {s_sel_s7[4]} {s_sel_s7[5]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 6 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {s_sel_s4[0]} {s_sel_s4[1]} {s_sel_s4[2]} {s_sel_s4[3]} {s_sel_s4[4]} {s_sel_s4[5]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 6 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {s_sel_s5[0]} {s_sel_s5[1]} {s_sel_s5[2]} {s_sel_s5[3]} {s_sel_s5[4]} {s_sel_s5[5]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
set_property port_width 16 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list {s_ph_phase_phaseA[0]} {s_ph_phase_phaseA[1]} {s_ph_phase_phaseA[2]} {s_ph_phase_phaseA[3]} {s_ph_phase_phaseA[4]} {s_ph_phase_phaseA[5]} {s_ph_phase_phaseA[6]} {s_ph_phase_phaseA[7]} {s_ph_phase_phaseA[8]} {s_ph_phase_phaseA[9]} {s_ph_phase_phaseA[10]} {s_ph_phase_phaseA[11]} {s_ph_phase_phaseA[12]} {s_ph_phase_phaseA[13]} {s_ph_phase_phaseA[14]} {s_ph_phase_phaseA[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
set_property port_width 6 [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list {s_sel_s3[0]} {s_sel_s3[1]} {s_sel_s3[2]} {s_sel_s3[3]} {s_sel_s3[4]} {s_sel_s3[5]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list s_Boolean_o_trip]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list s_ph_valid_phaseA]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list s_vaux0_decim_s12_valid]]
