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
set_property IOSTANDARD LVCMOS33 [get_ports iRstn]
set_property PULLTYPE PULLUP [get_ports iRstn]
# Reset assíncrono: não temporizar contra os clocks
set_false_path -from [get_ports iRstn]

## ==============================
## Sinais de teste / debug
## ==============================


# Saída de teste

## ==============================
## Saída Global Trip
## ==============================

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
# canal 1
# canal 2
# canal 3
# canal 4
# canal 5
# canal 6
# canal 7
# canal 8
# canal 9
# canal 10
set_property PACKAGE_PIN L14 [get_ports vauxp7]
set_property PACKAGE_PIN L15 [get_ports vauxn7]
set_property PACKAGE_PIN K14 [get_ports vauxp6]
set_property PACKAGE_PIN J14 [get_ports vauxn6]
set_property PACKAGE_PIN J20 [get_ports vauxp5]
set_property PACKAGE_PIN H20 [get_ports vauxn5]
set_property PACKAGE_PIN J18 [get_ports vauxp4]
set_property PACKAGE_PIN H18 [get_ports vauxn4]
set_property PACKAGE_PIN L19 [get_ports vauxp3]
set_property PACKAGE_PIN L20 [get_ports vauxn3]
set_property PACKAGE_PIN M17 [get_ports vauxp10]
set_property PACKAGE_PIN M18 [get_ports vauxn10]
set_property PACKAGE_PIN M19 [get_ports vauxp2]
set_property PACKAGE_PIN M20 [get_ports vauxn2]
set_property PACKAGE_PIN E18 [get_ports vauxp9]
set_property PACKAGE_PIN E19 [get_ports vauxn9]
set_property PACKAGE_PIN E17 [get_ports vauxp1]
set_property PACKAGE_PIN D18 [get_ports vauxn1]
set_property PACKAGE_PIN B19 [get_ports vauxp8]
set_property PACKAGE_PIN A20 [get_ports vauxn8]
set_property PACKAGE_PIN C20 [get_ports vauxp0]
set_property PACKAGE_PIN B20 [get_ports vauxn0]
# canal 11













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










# set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[0]}]
# set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[2]}]
# set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[3]}]
# set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[6]}]
# set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[8]}]
# set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[9]}]
# set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[11]}]
# set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[1]}]
# set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[4]}]
# set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[5]}]
# set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[7]}]
# set_property MARK_DEBUG false [get_nets {s_vaux0_decim_s12[10]}]









# set_property MARK_DEBUG false [get_nets s_clk1]

#set_property IOSTANDARD LVCMOS33 [get_ports I2C0_SCL_O_0]
#set_property IOSTANDARD LVCMOS33 [get_ports I2C0_SDA_O_0]
#set_property PACKAGE_PIN P16 [get_ports I2C0_SCL]
#set_property PACKAGE_PIN P15 [get_ports I2C0_SDA]




# Input Delays (Dados vindo da EEPROM para o SDA da FPGA)
# max delay = tAA (550 ns) + margem de atraso da trilha na placa (assumindo ~0.5ns)
# min delay = tDH (50 ns) - margem de trilha

# Output Delays (Dados saindo da FPGA para a EEPROM)
# max delay = tSU:DAT (100 ns) + margem de trilha
# min delay = - tHD:DAT (0 ns) - margem de trilha






set_property PACKAGE_PIN T14 [get_ports PS_EMIO_TLED0]
set_property IOSTANDARD LVCMOS33 [get_ports PS_EMIO_GPIO0]
set_property IOSTANDARD LVCMOS33 [get_ports PS_EMIO_GPIO1]
set_property IOSTANDARD LVCMOS33 [get_ports PS_EMIO_GPIO2]
set_property IOSTANDARD LVCMOS33 [get_ports PS_EMIO_TLED0]
set_property IOSTANDARD LVCMOS33 [get_ports PS_EMIO_TLED1]
set_property PACKAGE_PIN T15 [get_ports PS_EMIO_TLED1]
set_property PACKAGE_PIN M14 [get_ports PS_EMIO_GPIO0]
set_property PACKAGE_PIN M15 [get_ports PS_EMIO_GPIO1]
set_property PACKAGE_PIN N16 [get_ports PS_EMIO_GPIO2]
set_property IOSTANDARD LVCMOS33 [get_ports PS_UART0_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports PS_UART0_txd]
set_property PACKAGE_PIN T11 [get_ports o_relay_ch0]
set_property PACKAGE_PIN T10 [get_ports o_relay_ch1]
set_property PACKAGE_PIN U13 [get_ports o_relay_ch2]
set_property PACKAGE_PIN V13 [get_ports o_relay_ch3]
set_property PACKAGE_PIN T12 [get_ports o_relay_ch4]
set_property PACKAGE_PIN U12 [get_ports o_relay_ch5]
set_property PACKAGE_PIN V12 [get_ports o_relay_ch6]
set_property IOSTANDARD LVCMOS33 [get_ports o_relay_ch0]
set_property IOSTANDARD LVCMOS33 [get_ports o_relay_ch1]
set_property IOSTANDARD LVCMOS33 [get_ports o_relay_ch2]
set_property IOSTANDARD LVCMOS33 [get_ports o_relay_ch3]
set_property IOSTANDARD LVCMOS33 [get_ports o_relay_ch4]
set_property IOSTANDARD LVCMOS33 [get_ports o_relay_ch5]
set_property IOSTANDARD LVCMOS33 [get_ports o_relay_ch6]
set_property IOSTANDARD LVCMOS33 [get_ports vauxn0]
set_property IOSTANDARD LVCMOS33 [get_ports vauxn1]
set_property IOSTANDARD LVCMOS33 [get_ports vauxn2]
set_property IOSTANDARD LVCMOS33 [get_ports vauxn3]
set_property IOSTANDARD LVCMOS33 [get_ports vauxn4]
set_property IOSTANDARD LVCMOS33 [get_ports vauxn5]
set_property IOSTANDARD LVCMOS33 [get_ports vauxn6]
set_property IOSTANDARD LVCMOS33 [get_ports vauxn7]
set_property IOSTANDARD LVCMOS33 [get_ports vauxn8]
set_property IOSTANDARD LVCMOS33 [get_ports vauxn9]
set_property IOSTANDARD LVCMOS33 [get_ports vauxn10]
set_property IOSTANDARD LVCMOS33 [get_ports vauxp0]
set_property IOSTANDARD LVCMOS33 [get_ports vauxp1]
set_property IOSTANDARD LVCMOS33 [get_ports vauxp2]
set_property IOSTANDARD LVCMOS33 [get_ports vauxp3]
set_property IOSTANDARD LVCMOS33 [get_ports vauxp4]
set_property IOSTANDARD LVCMOS33 [get_ports vauxp5]
set_property IOSTANDARD LVCMOS33 [get_ports vauxp6]
set_property IOSTANDARD LVCMOS33 [get_ports vauxp7]
set_property IOSTANDARD LVCMOS33 [get_ports vauxp8]
set_property IOSTANDARD LVCMOS33 [get_ports vauxp9]
set_property IOSTANDARD LVCMOS33 [get_ports vauxp10]

set_property PACKAGE_PIN J15 [get_ports iRstn]




set_property PACKAGE_PIN L16 [get_ports PS_UART0_rxd]
set_property PACKAGE_PIN L17 [get_ports PS_UART0_txd]

#set_input_delay -clock [get_clocks -of_objects [get_pins inst_pll/inst/mmcm_adv_inst/CLKOUT0]] -min 0.000 [get_ports {i2c0_sda_io i2c0_scl_io}]
#set_input_delay -clock [get_clocks -of_objects [get_pins inst_pll/inst/mmcm_adv_inst/CLKOUT0]] 0.000 [get_ports {i2c0_sda_io i2c0_scl_io}]
#set_input_delay -clock [get_clocks -of_objects [get_pins inst_pll/inst/mmcm_adv_inst/CLKOUT0]] 0.000 [get_ports iRstn]
#set_output_delay -clock [get_clocks -of_objects [get_pins inst_pll/inst/mmcm_adv_inst/CLKOUT0]] -min 0.000 [get_ports {i2c0_sda_io i2c0_scl_io}]
#set_output_delay -clock [get_clocks -of_objects [get_pins inst_pll/inst/mmcm_adv_inst/CLKOUT0]] 0.000 [get_ports {i2c0_sda_io i2c0_scl_io}]






#set_property PACKAGE_PIN G14 [get_ports i_switch2]
#set_property IOSTANDARD LVCMOS33 [get_ports i_switch2]
#set_property PACKAGE_PIN T19 [get_ports i_switch3]
#set_property IOSTANDARD LVCMOS33 [get_ports i_switch3]
# set_property PACKAGE_PIN R19 [get_ports i_switch4]
# set_property IOSTANDARD LVCMOS33 [get_ports i_switch4]

set_property DRIVE 12 [get_ports o_relay_ch5]
set_property DRIVE 12 [get_ports o_relay_ch6]
set_property SLEW FAST [get_ports o_relay_ch0]

set_property PACKAGE_PIN R14 [get_ports {o_RGB_LED[2]}]
set_property PACKAGE_PIN Y16 [get_ports {o_RGB_LED[1]}]
set_property PACKAGE_PIN Y17 [get_ports {o_RGB_LED[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_RGB_LED[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_RGB_LED[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_RGB_LED[0]}]
set_property SLEW FAST [get_ports o_relay_ch1]
set_property SLEW FAST [get_ports o_relay_ch2]
set_property SLEW FAST [get_ports o_relay_ch3]
set_property SLEW FAST [get_ports o_relay_ch4]
set_property SLEW FAST [get_ports o_relay_ch5]
set_property SLEW FAST [get_ports o_relay_ch6]

# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux3_data[1]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux3_data[2]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux3_data[3]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux3_data[4]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux3_data[6]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux3_data[9]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux3_data[10]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux3_data[11]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux3_data[0]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux3_data[5]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux3_data[7]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux3_data[8]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux0_data[0]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux0_data[5]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux0_data[6]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux0_data[9]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux0_data[10]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux0_data[1]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux0_data[2]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux0_data[3]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux0_data[4]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux0_data[7]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux0_data[8]}]
# set_property MARK_DEBUG false [get_nets {inst_adc/s_vaux0_data[11]}]


# connect_debug_port u_ila_0/probe9 [get_nets [list {s_rms_aux_2[0]} {s_rms_aux_2[1]} {s_rms_aux_2[2]} {s_rms_aux_2[3]} {s_rms_aux_2[4]} {s_rms_aux_2[5]} {s_rms_aux_2[6]} {s_rms_aux_2[7]} {s_rms_aux_2[8]} {s_rms_aux_2[9]} {s_rms_aux_2[10]} {s_rms_aux_2[11]}]]
# connect_debug_port u_ila_0/probe11 [get_nets [list {s_rms_aux_0[0]} {s_rms_aux_0[1]} {s_rms_aux_0[2]} {s_rms_aux_0[3]} {s_rms_aux_0[4]} {s_rms_aux_0[5]} {s_rms_aux_0[6]} {s_rms_aux_0[7]} {s_rms_aux_0[8]} {s_rms_aux_0[9]} {s_rms_aux_0[10]} {s_rms_aux_0[11]}]]
# connect_debug_port u_ila_0/probe12 [get_nets [list {s_rms_aux_3[0]} {s_rms_aux_3[1]} {s_rms_aux_3[2]} {s_rms_aux_3[3]} {s_rms_aux_3[4]} {s_rms_aux_3[5]} {s_rms_aux_3[6]} {s_rms_aux_3[7]} {s_rms_aux_3[8]} {s_rms_aux_3[9]} {s_rms_aux_3[10]} {s_rms_aux_3[11]}]]
# connect_debug_port u_ila_0/probe13 [get_nets [list {s_rms_aux_1[0]} {s_rms_aux_1[1]} {s_rms_aux_1[2]} {s_rms_aux_1[3]} {s_rms_aux_1[4]} {s_rms_aux_1[5]} {s_rms_aux_1[6]} {s_rms_aux_1[7]} {s_rms_aux_1[8]} {s_rms_aux_1[9]} {s_rms_aux_1[10]} {s_rms_aux_1[11]}]]



# create_debug_core u_ila_0 ila
# set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
# set_property ALL_PROBE_SAME_MU_CNT 4 [get_debug_cores u_ila_0]
# set_property C_ADV_TRIGGER true [get_debug_cores u_ila_0]
# set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
# set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0]
# set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
# set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
# set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
# set_property port_width 1 [get_debug_ports u_ila_0/clk]
# connect_debug_port u_ila_0/clk [get_nets [list inst_pll/inst/clk_out1]]
# set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
# set_property port_width 32 [get_debug_ports u_ila_0/probe0]
# connect_debug_port u_ila_0/probe0 [get_nets [list {s_in_Port_069[0]} {s_in_Port_069[1]} {s_in_Port_069[2]} {s_in_Port_069[3]} {s_in_Port_069[4]} {s_in_Port_069[5]} {s_in_Port_069[6]} {s_in_Port_069[7]} {s_in_Port_069[8]} {s_in_Port_069[9]} {s_in_Port_069[10]} {s_in_Port_069[11]} {s_in_Port_069[12]} {s_in_Port_069[13]} {s_in_Port_069[14]} {s_in_Port_069[15]} {s_in_Port_069[16]} {s_in_Port_069[17]} {s_in_Port_069[18]} {s_in_Port_069[19]} {s_in_Port_069[20]} {s_in_Port_069[21]} {s_in_Port_069[22]} {s_in_Port_069[23]} {s_in_Port_069[24]} {s_in_Port_069[25]} {s_in_Port_069[26]} {s_in_Port_069[27]} {s_in_Port_069[28]} {s_in_Port_069[29]} {s_in_Port_069[30]} {s_in_Port_069[31]}]]
# create_debug_port u_ila_0 probe
# set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
# set_property port_width 32 [get_debug_ports u_ila_0/probe1]
# connect_debug_port u_ila_0/probe1 [get_nets [list {s_in_Port_070[0]} {s_in_Port_070[1]} {s_in_Port_070[2]} {s_in_Port_070[3]} {s_in_Port_070[4]} {s_in_Port_070[5]} {s_in_Port_070[6]} {s_in_Port_070[7]} {s_in_Port_070[8]} {s_in_Port_070[9]} {s_in_Port_070[10]} {s_in_Port_070[11]} {s_in_Port_070[12]} {s_in_Port_070[13]} {s_in_Port_070[14]} {s_in_Port_070[15]} {s_in_Port_070[16]} {s_in_Port_070[17]} {s_in_Port_070[18]} {s_in_Port_070[19]} {s_in_Port_070[20]} {s_in_Port_070[21]} {s_in_Port_070[22]} {s_in_Port_070[23]} {s_in_Port_070[24]} {s_in_Port_070[25]} {s_in_Port_070[26]} {s_in_Port_070[27]} {s_in_Port_070[28]} {s_in_Port_070[29]} {s_in_Port_070[30]} {s_in_Port_070[31]}]]
# create_debug_port u_ila_0 probe
# set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
# set_property port_width 32 [get_debug_ports u_ila_0/probe2]
# connect_debug_port u_ila_0/probe2 [get_nets [list {s_in_Port_136[0]} {s_in_Port_136[1]} {s_in_Port_136[2]} {s_in_Port_136[3]} {s_in_Port_136[4]} {s_in_Port_136[5]} {s_in_Port_136[6]} {s_in_Port_136[7]} {s_in_Port_136[8]} {s_in_Port_136[9]} {s_in_Port_136[10]} {s_in_Port_136[11]} {s_in_Port_136[12]} {s_in_Port_136[13]} {s_in_Port_136[14]} {s_in_Port_136[15]} {s_in_Port_136[16]} {s_in_Port_136[17]} {s_in_Port_136[18]} {s_in_Port_136[19]} {s_in_Port_136[20]} {s_in_Port_136[21]} {s_in_Port_136[22]} {s_in_Port_136[23]} {s_in_Port_136[24]} {s_in_Port_136[25]} {s_in_Port_136[26]} {s_in_Port_136[27]} {s_in_Port_136[28]} {s_in_Port_136[29]} {s_in_Port_136[30]} {s_in_Port_136[31]}]]
# create_debug_port u_ila_0 probe
# set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
# set_property port_width 32 [get_debug_ports u_ila_0/probe3]
# connect_debug_port u_ila_0/probe3 [get_nets [list {s_in_Port_135[0]} {s_in_Port_135[1]} {s_in_Port_135[2]} {s_in_Port_135[3]} {s_in_Port_135[4]} {s_in_Port_135[5]} {s_in_Port_135[6]} {s_in_Port_135[7]} {s_in_Port_135[8]} {s_in_Port_135[9]} {s_in_Port_135[10]} {s_in_Port_135[11]} {s_in_Port_135[12]} {s_in_Port_135[13]} {s_in_Port_135[14]} {s_in_Port_135[15]} {s_in_Port_135[16]} {s_in_Port_135[17]} {s_in_Port_135[18]} {s_in_Port_135[19]} {s_in_Port_135[20]} {s_in_Port_135[21]} {s_in_Port_135[22]} {s_in_Port_135[23]} {s_in_Port_135[24]} {s_in_Port_135[25]} {s_in_Port_135[26]} {s_in_Port_135[27]} {s_in_Port_135[28]} {s_in_Port_135[29]} {s_in_Port_135[30]} {s_in_Port_135[31]}]]
# create_debug_port u_ila_0 probe
# set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
# set_property port_width 32 [get_debug_ports u_ila_0/probe4]
# connect_debug_port u_ila_0/probe4 [get_nets [list {s_in_Port_134[0]} {s_in_Port_134[1]} {s_in_Port_134[2]} {s_in_Port_134[3]} {s_in_Port_134[4]} {s_in_Port_134[5]} {s_in_Port_134[6]} {s_in_Port_134[7]} {s_in_Port_134[8]} {s_in_Port_134[9]} {s_in_Port_134[10]} {s_in_Port_134[11]} {s_in_Port_134[12]} {s_in_Port_134[13]} {s_in_Port_134[14]} {s_in_Port_134[15]} {s_in_Port_134[16]} {s_in_Port_134[17]} {s_in_Port_134[18]} {s_in_Port_134[19]} {s_in_Port_134[20]} {s_in_Port_134[21]} {s_in_Port_134[22]} {s_in_Port_134[23]} {s_in_Port_134[24]} {s_in_Port_134[25]} {s_in_Port_134[26]} {s_in_Port_134[27]} {s_in_Port_134[28]} {s_in_Port_134[29]} {s_in_Port_134[30]} {s_in_Port_134[31]}]]
# create_debug_port u_ila_0 probe
# set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
# set_property port_width 32 [get_debug_ports u_ila_0/probe5]
# connect_debug_port u_ila_0/probe5 [get_nets [list {s_in_Port_033[0]} {s_in_Port_033[1]} {s_in_Port_033[2]} {s_in_Port_033[3]} {s_in_Port_033[4]} {s_in_Port_033[5]} {s_in_Port_033[6]} {s_in_Port_033[7]} {s_in_Port_033[8]} {s_in_Port_033[9]} {s_in_Port_033[10]} {s_in_Port_033[11]} {s_in_Port_033[12]} {s_in_Port_033[13]} {s_in_Port_033[14]} {s_in_Port_033[15]} {s_in_Port_033[16]} {s_in_Port_033[17]} {s_in_Port_033[18]} {s_in_Port_033[19]} {s_in_Port_033[20]} {s_in_Port_033[21]} {s_in_Port_033[22]} {s_in_Port_033[23]} {s_in_Port_033[24]} {s_in_Port_033[25]} {s_in_Port_033[26]} {s_in_Port_033[27]} {s_in_Port_033[28]} {s_in_Port_033[29]} {s_in_Port_033[30]} {s_in_Port_033[31]}]]
# create_debug_port u_ila_0 probe
# set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
# set_property port_width 32 [get_debug_ports u_ila_0/probe6]
# connect_debug_port u_ila_0/probe6 [get_nets [list {s_in_Port_034[0]} {s_in_Port_034[1]} {s_in_Port_034[2]} {s_in_Port_034[3]} {s_in_Port_034[4]} {s_in_Port_034[5]} {s_in_Port_034[6]} {s_in_Port_034[7]} {s_in_Port_034[8]} {s_in_Port_034[9]} {s_in_Port_034[10]} {s_in_Port_034[11]} {s_in_Port_034[12]} {s_in_Port_034[13]} {s_in_Port_034[14]} {s_in_Port_034[15]} {s_in_Port_034[16]} {s_in_Port_034[17]} {s_in_Port_034[18]} {s_in_Port_034[19]} {s_in_Port_034[20]} {s_in_Port_034[21]} {s_in_Port_034[22]} {s_in_Port_034[23]} {s_in_Port_034[24]} {s_in_Port_034[25]} {s_in_Port_034[26]} {s_in_Port_034[27]} {s_in_Port_034[28]} {s_in_Port_034[29]} {s_in_Port_034[30]} {s_in_Port_034[31]}]]
# create_debug_port u_ila_0 probe
# set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
# set_property port_width 12 [get_debug_ports u_ila_0/probe7]
# connect_debug_port u_ila_0/probe7 [get_nets [list {s_vaux1_data[0]} {s_vaux1_data[1]} {s_vaux1_data[2]} {s_vaux1_data[3]} {s_vaux1_data[4]} {s_vaux1_data[5]} {s_vaux1_data[6]} {s_vaux1_data[7]} {s_vaux1_data[8]} {s_vaux1_data[9]} {s_vaux1_data[10]} {s_vaux1_data[11]}]]
# create_debug_port u_ila_0 probe
# set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
# set_property port_width 12 [get_debug_ports u_ila_0/probe8]
# connect_debug_port u_ila_0/probe8 [get_nets [list {s_vaux0_decim_s12[0]} {s_vaux0_decim_s12[1]} {s_vaux0_decim_s12[2]} {s_vaux0_decim_s12[3]} {s_vaux0_decim_s12[4]} {s_vaux0_decim_s12[5]} {s_vaux0_decim_s12[6]} {s_vaux0_decim_s12[7]} {s_vaux0_decim_s12[8]} {s_vaux0_decim_s12[9]} {s_vaux0_decim_s12[10]} {s_vaux0_decim_s12[11]}]]
# create_debug_port u_ila_0 probe
# set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
# set_property port_width 12 [get_debug_ports u_ila_0/probe9]
# connect_debug_port u_ila_0/probe9 [get_nets [list {s_vaux1_decim_s12[0]} {s_vaux1_decim_s12[1]} {s_vaux1_decim_s12[2]} {s_vaux1_decim_s12[3]} {s_vaux1_decim_s12[4]} {s_vaux1_decim_s12[5]} {s_vaux1_decim_s12[6]} {s_vaux1_decim_s12[7]} {s_vaux1_decim_s12[8]} {s_vaux1_decim_s12[9]} {s_vaux1_decim_s12[10]} {s_vaux1_decim_s12[11]}]]
# create_debug_port u_ila_0 probe
# set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
# set_property port_width 12 [get_debug_ports u_ila_0/probe10]
# connect_debug_port u_ila_0/probe10 [get_nets [list {inst_adc/s_vaux0_data[0]} {inst_adc/s_vaux0_data[1]} {inst_adc/s_vaux0_data[2]} {inst_adc/s_vaux0_data[3]} {inst_adc/s_vaux0_data[4]} {inst_adc/s_vaux0_data[5]} {inst_adc/s_vaux0_data[6]} {inst_adc/s_vaux0_data[7]} {inst_adc/s_vaux0_data[8]} {inst_adc/s_vaux0_data[9]} {inst_adc/s_vaux0_data[10]} {inst_adc/s_vaux0_data[11]}]]
# create_debug_port u_ila_0 probe
# set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
# set_property port_width 12 [get_debug_ports u_ila_0/probe11]
# connect_debug_port u_ila_0/probe11 [get_nets [list {inst_rms_aux0/o_rms[0]} {inst_rms_aux0/o_rms[1]} {inst_rms_aux0/o_rms[2]} {inst_rms_aux0/o_rms[3]} {inst_rms_aux0/o_rms[4]} {inst_rms_aux0/o_rms[5]} {inst_rms_aux0/o_rms[6]} {inst_rms_aux0/o_rms[7]} {inst_rms_aux0/o_rms[8]} {inst_rms_aux0/o_rms[9]} {inst_rms_aux0/o_rms[10]} {inst_rms_aux0/o_rms[11]}]]
# create_debug_port u_ila_0 probe
# set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
# set_property port_width 12 [get_debug_ports u_ila_0/probe12]
# connect_debug_port u_ila_0/probe12 [get_nets [list {inst_rms_aux1/o_rms[0]} {inst_rms_aux1/o_rms[1]} {inst_rms_aux1/o_rms[2]} {inst_rms_aux1/o_rms[3]} {inst_rms_aux1/o_rms[4]} {inst_rms_aux1/o_rms[5]} {inst_rms_aux1/o_rms[6]} {inst_rms_aux1/o_rms[7]} {inst_rms_aux1/o_rms[8]} {inst_rms_aux1/o_rms[9]} {inst_rms_aux1/o_rms[10]} {inst_rms_aux1/o_rms[11]}]]
# create_debug_port u_ila_0 probe
# set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
# set_property port_width 1 [get_debug_ports u_ila_0/probe13]
# connect_debug_port u_ila_0/probe13 [get_nets [list s_rms_aux_0_valid]]
# create_debug_port u_ila_0 probe
# set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
# set_property port_width 1 [get_debug_ports u_ila_0/probe14]
# connect_debug_port u_ila_0/probe14 [get_nets [list s_rms_aux_1_valid]]
# create_debug_port u_ila_0 probe
# set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
# set_property port_width 1 [get_debug_ports u_ila_0/probe15]
# connect_debug_port u_ila_0/probe15 [get_nets [list s_vaux0_decim_s12_valid]]
# create_debug_port u_ila_0 probe
# set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
# set_property port_width 1 [get_debug_ports u_ila_0/probe16]
# connect_debug_port u_ila_0/probe16 [get_nets [list s_vaux1_decim_s12_valid]]
# set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
# set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
# set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
# connect_debug_port dbg_hub/clk [get_nets s_clk1]





# connect_debug_port u_ila_0/probe10 [get_nets [list inst_prot_46_51Q_s1/alarm_e2_reg]]





create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 4 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER true [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 1 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list inst_pll/inst/clk_out1]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 12 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {s_47_v1_abs_u12[0]} {s_47_v1_abs_u12[1]} {s_47_v1_abs_u12[2]} {s_47_v1_abs_u12[3]} {s_47_v1_abs_u12[4]} {s_47_v1_abs_u12[5]} {s_47_v1_abs_u12[6]} {s_47_v1_abs_u12[7]} {s_47_v1_abs_u12[8]} {s_47_v1_abs_u12[9]} {s_47_v1_abs_u12[10]} {s_47_v1_abs_u12[11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 12 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {s_47_v2_pickup_e1[0]} {s_47_v2_pickup_e1[1]} {s_47_v2_pickup_e1[2]} {s_47_v2_pickup_e1[3]} {s_47_v2_pickup_e1[4]} {s_47_v2_pickup_e1[5]} {s_47_v2_pickup_e1[6]} {s_47_v2_pickup_e1[7]} {s_47_v2_pickup_e1[8]} {s_47_v2_pickup_e1[9]} {s_47_v2_pickup_e1[10]} {s_47_v2_pickup_e1[11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 12 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {s_47_vuf_pickup_e2[0]} {s_47_vuf_pickup_e2[1]} {s_47_vuf_pickup_e2[2]} {s_47_vuf_pickup_e2[3]} {s_47_vuf_pickup_e2[4]} {s_47_vuf_pickup_e2[5]} {s_47_vuf_pickup_e2[6]} {s_47_vuf_pickup_e2[7]} {s_47_vuf_pickup_e2[8]} {s_47_vuf_pickup_e2[9]} {s_47_vuf_pickup_e2[10]} {s_47_vuf_pickup_e2[11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 20 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {s_47_target_ms_reg[0]} {s_47_target_ms_reg[1]} {s_47_target_ms_reg[2]} {s_47_target_ms_reg[3]} {s_47_target_ms_reg[4]} {s_47_target_ms_reg[5]} {s_47_target_ms_reg[6]} {s_47_target_ms_reg[7]} {s_47_target_ms_reg[8]} {s_47_target_ms_reg[9]} {s_47_target_ms_reg[10]} {s_47_target_ms_reg[11]} {s_47_target_ms_reg[12]} {s_47_target_ms_reg[13]} {s_47_target_ms_reg[14]} {s_47_target_ms_reg[15]} {s_47_target_ms_reg[16]} {s_47_target_ms_reg[17]} {s_47_target_ms_reg[18]} {s_47_target_ms_reg[19]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 12 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {s_47_ram_addr_stg1[0]} {s_47_ram_addr_stg1[1]} {s_47_ram_addr_stg1[2]} {s_47_ram_addr_stg1[3]} {s_47_ram_addr_stg1[4]} {s_47_ram_addr_stg1[5]} {s_47_ram_addr_stg1[6]} {s_47_ram_addr_stg1[7]} {s_47_ram_addr_stg1[8]} {s_47_ram_addr_stg1[9]} {s_47_ram_addr_stg1[10]} {s_47_ram_addr_stg1[11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 20 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {s_47_time_ms[0]} {s_47_time_ms[1]} {s_47_time_ms[2]} {s_47_time_ms[3]} {s_47_time_ms[4]} {s_47_time_ms[5]} {s_47_time_ms[6]} {s_47_time_ms[7]} {s_47_time_ms[8]} {s_47_time_ms[9]} {s_47_time_ms[10]} {s_47_time_ms[11]} {s_47_time_ms[12]} {s_47_time_ms[13]} {s_47_time_ms[14]} {s_47_time_ms[15]} {s_47_time_ms[16]} {s_47_time_ms[17]} {s_47_time_ms[18]} {s_47_time_ms[19]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 20 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {s_47_delay_e1_ms[0]} {s_47_delay_e1_ms[1]} {s_47_delay_e1_ms[2]} {s_47_delay_e1_ms[3]} {s_47_delay_e1_ms[4]} {s_47_delay_e1_ms[5]} {s_47_delay_e1_ms[6]} {s_47_delay_e1_ms[7]} {s_47_delay_e1_ms[8]} {s_47_delay_e1_ms[9]} {s_47_delay_e1_ms[10]} {s_47_delay_e1_ms[11]} {s_47_delay_e1_ms[12]} {s_47_delay_e1_ms[13]} {s_47_delay_e1_ms[14]} {s_47_delay_e1_ms[15]} {s_47_delay_e1_ms[16]} {s_47_delay_e1_ms[17]} {s_47_delay_e1_ms[18]} {s_47_delay_e1_ms[19]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 12 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {s_47_vuf[0]} {s_47_vuf[1]} {s_47_vuf[2]} {s_47_vuf[3]} {s_47_vuf[4]} {s_47_vuf[5]} {s_47_vuf[6]} {s_47_vuf[7]} {s_47_vuf[8]} {s_47_vuf[9]} {s_47_vuf[10]} {s_47_vuf[11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 20 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {s_47_stg1_bram_douta[0]} {s_47_stg1_bram_douta[1]} {s_47_stg1_bram_douta[2]} {s_47_stg1_bram_douta[3]} {s_47_stg1_bram_douta[4]} {s_47_stg1_bram_douta[5]} {s_47_stg1_bram_douta[6]} {s_47_stg1_bram_douta[7]} {s_47_stg1_bram_douta[8]} {s_47_stg1_bram_douta[9]} {s_47_stg1_bram_douta[10]} {s_47_stg1_bram_douta[11]} {s_47_stg1_bram_douta[12]} {s_47_stg1_bram_douta[13]} {s_47_stg1_bram_douta[14]} {s_47_stg1_bram_douta[15]} {s_47_stg1_bram_douta[16]} {s_47_stg1_bram_douta[17]} {s_47_stg1_bram_douta[18]} {s_47_stg1_bram_douta[19]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 32 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {s_seq2_abs[0]} {s_seq2_abs[1]} {s_seq2_abs[2]} {s_seq2_abs[3]} {s_seq2_abs[4]} {s_seq2_abs[5]} {s_seq2_abs[6]} {s_seq2_abs[7]} {s_seq2_abs[8]} {s_seq2_abs[9]} {s_seq2_abs[10]} {s_seq2_abs[11]} {s_seq2_abs[12]} {s_seq2_abs[13]} {s_seq2_abs[14]} {s_seq2_abs[15]} {s_seq2_abs[16]} {s_seq2_abs[17]} {s_seq2_abs[18]} {s_seq2_abs[19]} {s_seq2_abs[20]} {s_seq2_abs[21]} {s_seq2_abs[22]} {s_seq2_abs[23]} {s_seq2_abs[24]} {s_seq2_abs[25]} {s_seq2_abs[26]} {s_seq2_abs[27]} {s_seq2_abs[28]} {s_seq2_abs[29]} {s_seq2_abs[30]} {s_seq2_abs[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list s_trip_47_stg1]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list s_vseq_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list s_47_alarm_e1]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list s_47_alarm_e2]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list s_47_ram_rd_req_stg1]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list s_47_s1_en]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list s_47_trip_47_59Q_e2]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets s_clk1]
