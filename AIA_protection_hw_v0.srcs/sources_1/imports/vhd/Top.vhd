----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 15.08.2025 07:38:56
-- Design Name: 
-- Module Name: Top - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- Authors: Prof. André A. dos Anjos - UFU campus Patos de Minas; 
--          Arthur Javaroni - UFU Uberlândia.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.VComponents.all;

entity Top is
  port (
    ---------
    -- Reset 
    ---------
    iRstn : in std_logic; -- Rset externo não esta mais acessivel pela placa, mas pode ser gerado internamente ou via VIO
                             -- o botão de reset que tem agora corta a alimentação pois o o kit ja estava usando o sistema de reset
    ---------
    -- Clocks
    ---------
    iClk : in std_logic;
    ---------------------
    -- XADC Analog Inputs
    ---------------------
    vauxp0  : in std_logic; -- Auxiliary Channel 0 IA0
    vauxn0  : in std_logic;
    vauxp1  : in std_logic; -- Auxiliary Channel 1 IB0
    vauxn1  : in std_logic;
    vauxp2  : in std_logic; -- Auxiliary Channel 2 IC0
    vauxn2  : in std_logic;
    vauxp3  : in std_logic; -- Auxiliary Channel 3 IN0
    vauxn3  : in std_logic;
    vauxp4  : in std_logic; -- Auxiliary Channel 4 VA0
    vauxn4  : in std_logic;
    vauxp5  : in std_logic; -- Auxiliary Channel 5 VB0
    vauxn5  : in std_logic;
    vauxp6  : in std_logic; -- Auxiliary Channel 6 VC0
    vauxn6  : in std_logic;
    vauxp7  : in std_logic; -- Auxiliary Channel 7 IA1
    vauxn7  : in std_logic;
    vauxp8  : in std_logic; -- Auxiliary Channel 8 IB1
    vauxn8  : in std_logic;
    vauxp9  : in std_logic; -- Auxiliary Channel 9  IC1
    vauxn9  : in std_logic;
    vauxp10 : in std_logic; -- Auxiliary Channel 10 IN1
    vauxn10 : in std_logic;
    -------------------
    -- Output Trip Pin
    ------------------
    o_RGB_LED : out std_logic_vector (2 downto 0); -- RGB_LED
    --o_teste 					: out std_logic;
    ------------------
    -- Fixed PS pins
    ------------------
    DDR_addr          : inout std_logic_vector (14 downto 0);
    DDR_ba            : inout std_logic_vector (2 downto 0);
    DDR_cas_n         : inout std_logic;
    DDR_ck_n          : inout std_logic;
    DDR_ck_p          : inout std_logic;
    DDR_cke           : inout std_logic;
    DDR_cs_n          : inout std_logic;
    DDR_dm            : inout std_logic_vector (3 downto 0);
    DDR_dq            : inout std_logic_vector (31 downto 0);
    DDR_dqs_n         : inout std_logic_vector (3 downto 0);
    DDR_dqs_p         : inout std_logic_vector (3 downto 0);
    DDR_odt           : inout std_logic;
    DDR_ras_n         : inout std_logic;
    DDR_reset_n       : inout std_logic;
    DDR_we_n          : inout std_logic;
    FIXED_IO_ddr_vrn  : inout std_logic;
    FIXED_IO_ddr_vrp  : inout std_logic;
    FIXED_IO_mio      : inout std_logic_vector (53 downto 0);
    FIXED_IO_ps_clk   : inout std_logic;
    FIXED_IO_ps_porb  : inout std_logic;
    FIXED_IO_ps_srstb : inout std_logic;
    i2c0_scl_io       : inout std_logic; -- para controle da eeprom
    i2c0_sda_io       : inout std_logic; -- para controle da eeprom
    PS_EMIO_TLED0     : inout std_logic; -- LED de trip 0
    PS_EMIO_TLED1     : inout std_logic; -- LED de trip 1
    PS_EMIO_GPIO0     : inout std_logic; -- GPIO para backplane ou outros usos gerais
    PS_EMIO_GPIO1     : inout std_logic; -- GPIO para backplane ou outros usos gerais
    PS_EMIO_GPIO2     : inout std_logic; -- GPIO para backplane ou outros usos gerais
    PS_UART0_rxd      : in std_logic;    -- para debug via UART (pode ser conectado a um conversor USB-UART)
    PS_UART0_txd      : out std_logic;   -- para debug via UART (pode ser conectado a um conversor USB-UART)
    o_relay_ch0       : out std_logic;   
    o_relay_ch1       : out std_logic;
    o_relay_ch2       : out std_logic;
    o_relay_ch3       : out std_logic;
    o_relay_ch4       : out std_logic;
    o_relay_ch5       : out std_logic;
    o_relay_ch6       : out std_logic
  );
end Top;
architecture Behavioral of Top is

  -- =========================
  -- Component PLL
  -- =========================
  component clk_wiz_0
    port (
      -----------------
      -- Clock in ports
      -----------------
      resetn  : in std_logic;
      clk_in1 : in std_logic;
      ------------------
      -- Clock out ports
      ------------------
      clk_out1 : out std_logic;
      clk_out2 : out std_logic;
      clk_out3 : out std_logic;
      -----------------------------
      -- Status and control signals
      -----------------------------	
      locked : out std_logic

    );
  end component;
  -- Sinais para PLL
  signal s_clk1  : std_logic;
  signal s_clk2  : std_logic;
  signal sRst    : std_logic;
  signal sRstVio : std_logic_vector(0 downto 0);
  signal sRstn   : std_logic;
  signal s_Locked : std_logic;

  signal s_rgb : std_logic_vector(2 downto 0);
  -- ===================================
  -- VIO para debugs
  -- ===================================
  component vio_0
    port (
      clk         : in std_logic;
      probe_out0  : out std_logic_vector(0 downto 0);
      probe_out1  : out std_logic_vector(0 downto 0);
      probe_out2  : out std_logic_vector(11 downto 0);
      probe_out3  : out std_logic_vector(7 downto 0);
      probe_out4  : out std_logic_vector(11 downto 0);
      probe_out5  : out std_logic_vector(11 downto 0);
      probe_out6  : out std_logic_vector(0 downto 0);
      probe_out7  : out std_logic_vector(0 downto 0);
      probe_out8  : out std_logic_vector(11 downto 0);
      probe_out9  : out std_logic_vector(7 downto 0);
      probe_out10 : out std_logic_vector(11 downto 0);
      probe_out11 : out std_logic_vector(11 downto 0);
      probe_out12 : out std_logic_vector(0 downto 0);
      probe_out13 : out std_logic_vector(0 downto 0);
      probe_out14 : out std_logic_vector(11 downto 0);
      probe_out15 : out std_logic_vector(7 downto 0);
      probe_out16 : out std_logic_vector(11 downto 0);
      probe_out17 : out std_logic_vector(11 downto 0);
      probe_out18 : out std_logic_vector(0 downto 0);
      probe_out19 : out std_logic_vector(0 downto 0);
      probe_out20 : out std_logic_vector(11 downto 0);
      probe_out21 : out std_logic_vector(7 downto 0);
      probe_out22 : out std_logic_vector(11 downto 0);
      probe_out23 : out std_logic_vector(11 downto 0);
      probe_out24 : out std_logic_vector(0 downto 0);
      probe_out25 : out std_logic_vector(19 downto 0);
      probe_out26 : out std_logic_vector(19 downto 0);
      probe_out27 : out std_logic_vector(19 downto 0);
      probe_out28 : out std_logic_vector(19 downto 0);
      probe_out29 : out std_logic_vector(7 downto 0);
      probe_out30 : out std_logic_vector(255 downto 0);
      probe_out31 : out std_logic_vector(63 downto 0);
      probe_out32 : out std_logic_vector(5 downto 0);
      probe_out33 : out std_logic_vector(5 downto 0);
      probe_out34 : out std_logic_vector(5 downto 0);
      probe_out35 : out std_logic_vector(5 downto 0);
      probe_out36 : out std_logic_vector(5 downto 0);
      probe_out37 : out std_logic_vector(5 downto 0);
      probe_out38 : out std_logic_vector(5 downto 0);
      probe_out39 : out std_logic_vector(5 downto 0);
      probe_out40 : out std_logic_vector(19 downto 0);
      probe_out41 : out std_logic_vector(0 downto 0);
      probe_out42 : out std_logic_vector(11 downto 0);
      probe_out43 : out std_logic_vector(11 downto 0)

    );
  end component;
  signal s_AUX0_PhA_Enable_50  : std_logic_vector(0 downto 0); -- Enable protection 50
  signal s_AUX0_PhA_Enable_51  : std_logic_vector(0 downto 0); -- Enabel protection 51
  signal s_AUX0_PhA_Offset     : std_logic_vector(11 downto 0); -- offset0, default 2048d for phase A/B/C
  signal s_AUX0_PhA_Decimation : std_logic_vector(7 downto 0); -- decimation factor, default 25d
  signal s_AUX0_PhA_50_Peakup  : std_logic_vector(11 downto 0); -- peakup 50-PhaseA/B/C, default 1024d
  signal s_AUX0_PhA_51_Peakup  : std_logic_vector(11 downto 0); -- peakup 51-PhaseA/B/C, default 400d -- Matched with LUT 51
  signal s_AUX0_PhA_50_IntDly  : std_logic_vector(19 downto 0); -- intentional delay in ms for protection 50/50N default 0
  signal s_AUX1_PhB_Enable_50  : std_logic_vector(0 downto 0); -- Enable protection 50
  signal s_AUX1_PhB_Enable_51  : std_logic_vector(0 downto 0); -- Enabel protection 51
  signal s_AUX1_PhB_Offset     : std_logic_vector(11 downto 0); -- offset0, default 2048d for phase A/B/C
  signal s_AUX1_PhB_Decimation : std_logic_vector(7 downto 0); -- decimation factor, default 25d
  signal s_AUX1_PhB_50_Peakup  : std_logic_vector(11 downto 0); -- peakup 50-PhaseA/B/C, default 1024d
  signal s_AUX1_PhB_51_Peakup  : std_logic_vector(11 downto 0); -- peakup 51-PhaseA/B/C, default 400d -- Matched with LUT 51
  signal s_AUX1_PhB_50_IntDly  : std_logic_vector(19 downto 0); -- intentional delay in ms for protection 50/50N default 0
  signal s_AUX2_PhC_Enable_50  : std_logic_vector(0 downto 0); -- Enable protection 50
  signal s_AUX2_PhC_Enable_51  : std_logic_vector(0 downto 0); -- Enabel protection 51
  signal s_AUX2_PhC_Offset     : std_logic_vector(11 downto 0); -- offset0, default 2048d for phase A/B/C
  signal s_AUX2_PhC_Decimation : std_logic_vector(7 downto 0); -- decimation factor, default 25d
  signal s_AUX2_PhC_50_Peakup  : std_logic_vector(11 downto 0); -- peakup 50-PhaseA/B/C, default 1024d
  signal s_AUX2_PhC_51_Peakup  : std_logic_vector(11 downto 0); -- peakup 51-PhaseA/B/C, default 400d -- Matched with LUT 51
  signal s_AUX2_PhC_50_IntDly  : std_logic_vector(19 downto 0); -- intentional delay in ms for protection 50/50N default 0
  signal s_AUX3_PhN_Enable_50  : std_logic_vector(0 downto 0); -- Enable protection 50
  signal s_AUX3_PhN_Enable_51  : std_logic_vector(0 downto 0); -- Enabel protection 51
  signal s_AUX3_PhN_Offset     : std_logic_vector(11 downto 0); -- offset0, default 2048d for phase A/B/C
  signal s_AUX3_PhN_Decimation : std_logic_vector(7 downto 0); -- decimation factor, default 25d
  signal s_AUX3_PhN_50_Peakup  : std_logic_vector(11 downto 0); -- peakup 50-PhaseA/B/C, default 1024d
  signal s_AUX3_PhN_51_Peakup  : std_logic_vector(11 downto 0); -- peakup 51-PhaseA/B/C, default 400d -- Matched with LUT 51
  signal s_AUX3_PhN_50_IntDly  : std_logic_vector(19 downto 0); -- intentional delay in ms for protection 50/50N default 0

  signal s_InputBooleanBlock  : std_logic_vector(7 downto 0);
  signal s_ConfigBooleanBlock : std_logic_vector(255 downto 0);
  signal s_all_signals        : std_logic_vector(63 downto 0);
  signal s_sel_s0             : std_logic_vector(5 downto 0);
  signal s_sel_s1             : std_logic_vector(5 downto 0);
  signal s_sel_s2             : std_logic_vector(5 downto 0);
  signal s_sel_s3             : std_logic_vector(5 downto 0);
  signal s_sel_s4             : std_logic_vector(5 downto 0);
  signal s_sel_s5             : std_logic_vector(5 downto 0);
  signal s_sel_s6             : std_logic_vector(5 downto 0);
  signal s_sel_s7             : std_logic_vector(5 downto 0);

  signal s_46_s1_vio_e1_dly  : std_logic_vector(19 downto 0);
  signal s_46_s1_vio_e1_en   : std_logic_vector(0 downto 0) := (others => '0');
  signal s_46_s1_vio_e1_i2pu : std_logic_vector(11 downto 0);
  signal s_46_s1_vio_e2_i2pu : std_logic_vector(11 downto 0);

  -- =========================
  -- Component Processor
  -- =========================	
  component GOD_wrapper is
    port (
      Clk                : in std_logic;
      DDR_addr           : inout std_logic_vector (14 downto 0);
      DDR_ba             : inout std_logic_vector (2 downto 0);
      DDR_cas_n          : inout std_logic;
      DDR_ck_n           : inout std_logic;
      DDR_ck_p           : inout std_logic;
      DDR_cke            : inout std_logic;
      DDR_cs_n           : inout std_logic;
      DDR_dm             : inout std_logic_vector (3 downto 0);
      DDR_dq             : inout std_logic_vector (31 downto 0);
      DDR_dqs_n          : inout std_logic_vector (3 downto 0);
      DDR_dqs_p          : inout std_logic_vector (3 downto 0);
      DDR_odt            : inout std_logic;
      DDR_ras_n          : inout std_logic;
      DDR_reset_n        : inout std_logic;
      DDR_we_n           : inout std_logic;
      FIXED_IO_ddr_vrn   : inout std_logic;
      FIXED_IO_ddr_vrp   : inout std_logic;
      FIXED_IO_mio       : inout std_logic_vector (53 downto 0);
      FIXED_IO_ps_clk    : inout std_logic;
      FIXED_IO_ps_porb   : inout std_logic;
      FIXED_IO_ps_srstb  : inout std_logic;
      PS_EMIO_tri_io     : inout std_logic_vector (4 downto 0);
      PS_UART0_rxd       : in std_logic;
      PS_UART0_txd       : out std_logic;
      i2c0_scl_io        : inout std_logic;
      i2c0_sda_io        : inout std_logic;
      i_readdata_tri_i   : in std_logic_vector (31 downto 0);
      o_address_tri_o    : out std_logic_vector (7 downto 0);
      o_read_tri_o       : out std_logic_vector (0 to 0);
      o_write_data_tri_o : out std_logic_vector (31 downto 0);
      o_write_tri_o      : out std_logic_vector (0 to 0);
      reset_rtl_0        : in std_logic
    );
  end component;

  signal s_o_write_tri_o      : std_logic_vector (0 to 0);
  signal s_o_address_tri_o    : std_logic_vector (7 downto 0);
  signal s_o_write_data_tri_o : std_logic_vector (31 downto 0);
  signal s_o_read_tri_o       : std_logic_vector (0 to 0);
  signal s_i_readdata_tri_i   : std_logic_vector (31 downto 0);
  signal s_PS_EMIO_tri_io     : std_logic_vector (4 downto 0);
                    
  -- =========================
  -- Component xadc
  -- =========================
  component XadcFrontend is
    port (
      --------------------------
      -- Clock/reset do XADC/DRP
      --------------------------
      i_clk : in std_logic;
      i_rst : in std_logic;
      ---------------------------------
      -- Entradas analógicas auxiliares
      ---------------------------------
      i_vauxp0  : in std_logic;
      i_vauxn0  : in std_logic;
      i_vauxp1  : in std_logic;
      i_vauxn1  : in std_logic;
      i_vauxp2  : in std_logic;
      i_vauxn2  : in std_logic;
      i_vauxp3  : in std_logic;
      i_vauxn3  : in std_logic;
      i_vauxp4  : in std_logic;
      i_vauxn4  : in std_logic;
      i_vauxp5  : in std_logic;
      i_vauxn5  : in std_logic;
      i_vauxp6  : in std_logic;
      i_vauxn6  : in std_logic;
      i_vauxp7  : in std_logic;
      i_vauxn7  : in std_logic;
      i_vauxp8  : in std_logic;
      i_vauxn8  : in std_logic;
      i_vauxp9  : in std_logic;
      i_vauxn9  : in std_logic;
      i_vauxp10 : in std_logic;
      i_vauxn10 : in std_logic;
      -------------------------------------------------------------
      -- Saídas: dados (12b) e "valid" por canal (pulso de 1 ciclo)
      -------------------------------------------------------------
      o_temp_data    : out std_logic_vector(11 downto 0);
      o_temp_valid   : out std_logic;
      o_vaux0_data   : out std_logic_vector(11 downto 0);
      o_vaux0_valid  : out std_logic;
      o_vaux1_data   : out std_logic_vector(11 downto 0);
      o_vaux1_valid  : out std_logic;
      o_vaux2_data   : out std_logic_vector(11 downto 0);
      o_vaux2_valid  : out std_logic;
      o_vaux3_data   : out std_logic_vector(11 downto 0);
      o_vaux3_valid  : out std_logic;
      o_vaux4_data   : out std_logic_vector(11 downto 0);
      o_vaux4_valid  : out std_logic;
      o_vaux5_data   : out std_logic_vector(11 downto 0);
      o_vaux5_valid  : out std_logic;
      o_vaux6_data   : out std_logic_vector(11 downto 0);
      o_vaux6_valid  : out std_logic;
      o_vaux7_data   : out std_logic_vector(11 downto 0);
      o_vaux7_valid  : out std_logic;
      o_vaux8_data   : out std_logic_vector(11 downto 0);
      o_vaux8_valid  : out std_logic;
      o_vaux9_data   : out std_logic_vector(11 downto 0);
      o_vaux9_valid  : out std_logic;
      o_vaux10_data  : out std_logic_vector(11 downto 0);
      o_vaux10_valid : out std_logic;
      ------------------------------------------------
      -- Saídas de alarme (em PT, sufixo *_alarme_out)
      ------------------------------------------------
      o_user_temp_alarme_out : out std_logic;
      o_vccint_alarme_out    : out std_logic;
      o_vccaux_alarme_out    : out std_logic;
      o_alarme_out           : out std_logic
    );
  end component;
  -- Sinais para conectar o XADFront end aos blocos subsequentes
  signal s_temp_data    : std_logic_vector(11 downto 0);
  signal s_temp_valid   : std_logic;
  signal s_vaux0_data   : std_logic_vector(11 downto 0);
  signal s_vaux0_valid  : std_logic;
  signal s_vaux1_data   : std_logic_vector(11 downto 0);
  signal s_vaux1_valid  : std_logic;
  signal s_vaux2_data   : std_logic_vector(11 downto 0);
  signal s_vaux2_valid  : std_logic;
  signal s_vaux3_data   : std_logic_vector(11 downto 0);
  signal s_vaux3_valid  : std_logic;
  signal s_vaux4_data   : std_logic_vector(11 downto 0);
  signal s_vaux4_valid  : std_logic;
  signal s_vaux5_data   : std_logic_vector(11 downto 0);
  signal s_vaux5_valid  : std_logic;
  signal s_vaux6_data   : std_logic_vector(11 downto 0);
  signal s_vaux6_valid  : std_logic;
  signal s_vaux7_data   : std_logic_vector(11 downto 0);
  signal s_vaux7_valid  : std_logic;
  signal s_vaux8_data   : std_logic_vector(11 downto 0);
  signal s_vaux8_valid  : std_logic;
  signal s_vaux9_data   : std_logic_vector(11 downto 0);
  signal s_vaux9_valid  : std_logic;
  signal s_vaux10_data  : std_logic_vector(11 downto 0);
  signal s_vaux10_valid : std_logic;

  -- ===================================
  -- Offset Calibration Block
  -- ===================================
  component XadcDcOffsetCalibrator is
    generic (
        G_ACCUM_BITS : natural := 15 
    );
    port (
        i_clk          : in  std_logic;
        i_rst          : in  std_logic;
        
        -- Sinal BRUTO vindo direto do XADC (0 a 4095)
        i_data_raw     : in  std_logic_vector(11 downto 0); 
        i_valid        : in  std_logic;                     

        -- Saída com o Offset DC calculado (pronto para ser lido pelo Vitis)
        o_offset_avg   : out std_logic_vector(11 downto 0); 
        o_offset_valid : out std_logic                      
    );
end component;
signal s_aux0_calib_offset : STD_LOGIC_VECTOR(11 downto 0);
signal s_aux1_calib_offset : STD_LOGIC_VECTOR(11 downto 0);
signal s_aux2_calib_offset : STD_LOGIC_VECTOR(11 downto 0);
signal s_aux3_calib_offset : STD_LOGIC_VECTOR(11 downto 0);
signal s_aux4_calib_offset : STD_LOGIC_VECTOR(11 downto 0);
signal s_aux5_calib_offset : STD_LOGIC_VECTOR(11 downto 0);
signal s_aux6_calib_offset : STD_LOGIC_VECTOR(11 downto 0);



  -- ===================================
  -- Mean level removal and configurable decimation
  -- ===================================
  component XadcBiasAndDecimate_SingleProc is
    port (
      --------------------------
      -- Clock / Reset
      --------------------------
      i_clk : in std_logic;
      i_rst : in std_logic; -- ativo-alto

      --------------------------
      -- Entradas
      --------------------------
      i_data              : in std_logic_vector(11 downto 0); -- 12b unsigned (0..4095)
      i_valid             : in std_logic; -- pulso 1 ciclo
      i_offset            : in std_logic_vector(11 downto 0); -- 12b unsigned (bias a subtrair)
      i_decimation_factor : in std_logic_vector(7 downto 0); -- 0=>1, 1=>1, M=>1/M
      --------------------------
      -- Saídas (decimadas)
      --------------------------
      o_data_decim  : out std_logic_vector(11 downto 0); -- 12b signed (-2048..+2047)
      o_valid_decim : out std_logic; -- pulso 1 ciclo
      --------------------------
      -- Saídas (na taxa de entrada, sem DC)
      --------------------------
      o_data_nodc  : out std_logic_vector(11 downto 0); -- 12b signed (sem DC)
      o_valid_nodc : out std_logic -- pulso 1 ciclo (segue i_valid)
    );
  end component;
  -- Offset padrão (meia-escala)
  constant C_OFF_U12 : std_logic_vector(11 downto 0) := x"800"; -- 2048
  -- Fator de decimação (1 => sem decimar). Ex.: 8 => 1 a cada 8 amostras.
  signal s_dec_factor : std_logic_vector(7 downto 0) := x"01";
  -- Saídas bias-removidas (+decimadas) por canal
  signal s_vaux0_decim_s12        : std_logic_vector(11 downto 0);
  signal s_vaux0_decim_s12_valid  : std_logic;
  signal s_vaux1_decim_s12        : std_logic_vector(11 downto 0);
  signal s_vaux1_decim_s12_valid  : std_logic;
  signal s_vaux2_decim_s12        : std_logic_vector(11 downto 0);
  signal s_vaux2_decim_s12_valid  : std_logic;
  signal s_vaux3_decim_s12        : std_logic_vector(11 downto 0);
  signal s_vaux3_decim_s12_valid  : std_logic;
  signal s_vaux4_decim_s12        : std_logic_vector(11 downto 0);
  signal s_vaux4_decim_s12_valid  : std_logic;
  signal s_vaux5_decim_s12        : std_logic_vector(11 downto 0);
  signal s_vaux5_decim_s12_valid  : std_logic;
  signal s_vaux6_decim_s12        : std_logic_vector(11 downto 0);
  signal s_vaux6_decim_s12_valid  : std_logic;
  signal s_vaux7_decim_s12        : std_logic_vector(11 downto 0);
  signal s_vaux7_decim_s12_valid  : std_logic;
  signal s_vaux8_decim_s12        : std_logic_vector(11 downto 0);
  signal s_vaux8_decim_s12_valid  : std_logic;
  signal s_vaux9_decim_s12        : std_logic_vector(11 downto 0);
  signal s_vaux9_decim_s12_valid  : std_logic;
  signal s_vaux10_decim_s12       : std_logic_vector(11 downto 0);
  signal s_vaux10_decim_s12_valid : std_logic;

  signal s_vaux0_s12        : std_logic_vector(11 downto 0);
  signal s_vaux0_s12_valid  : std_logic;
  signal s_vaux1_s12        : std_logic_vector(11 downto 0);
  signal s_vaux1_s12_valid  : std_logic;
  signal s_vaux2_s12        : std_logic_vector(11 downto 0);
  signal s_vaux2_s12_valid  : std_logic;
  signal s_vaux3_s12        : std_logic_vector(11 downto 0);
  signal s_vaux3_s12_valid  : std_logic;
  signal s_vaux4_s12        : std_logic_vector(11 downto 0);
  signal s_vaux4_s12_valid  : std_logic;
  signal s_vaux5_s12        : std_logic_vector(11 downto 0);
  signal s_vaux5_s12_valid  : std_logic;
  signal s_vaux6_s12        : std_logic_vector(11 downto 0);
  signal s_vaux6_s12_valid  : std_logic;
  signal s_vaux7_s12        : std_logic_vector(11 downto 0);
  signal s_vaux7_s12_valid  : std_logic;
  signal s_vaux8_s12        : std_logic_vector(11 downto 0);
  signal s_vaux8_s12_valid  : std_logic;
  signal s_vaux9_s12        : std_logic_vector(11 downto 0);
  signal s_vaux9_s12_valid  : std_logic;
  signal s_vaux10_s12       : std_logic_vector(11 downto 0);
  signal s_vaux10_s12_valid : std_logic;
  -- =================================================
  -- Sine wave generator with ROM - for test purposes
  -- =================================================
  component GenSineWave is
    port (
      clk      : in std_logic;
      rst      : in std_logic;
      ivalid   : in std_logic;
      sine_out : out std_logic_vector(11 downto 0);
      ovalid   : out std_logic
    );
  end component;
  signal s_sine_out : std_logic_vector(11 downto 0);
  signal s_ovalid   : std_logic;
  -- ==========================================================
  -- Sine wave generator with ROM 3 phases - for test purposes
  -- ==========================================================	
  component stim_3ph_rom_64pts is
    generic (
      G_WIDTH : integer := 12;
      G_NPTS  : integer := 64
    );
    port (
      i_clk : in std_logic;
      i_rst : in std_logic;

      i_valid_fase_A : in std_logic;
      i_valid_fase_B : in std_logic;
      i_valid_fase_C : in std_logic;

      o_phase_A       : out signed(G_WIDTH - 1 downto 0);
      o_valid_phase_A : out std_logic;

      o_phase_B       : out signed(G_WIDTH - 1 downto 0);
      o_valid_phase_B : out std_logic;

      o_phase_C       : out signed(G_WIDTH - 1 downto 0);
      o_valid_phase_C : out std_logic
    );
  end component;
  signal s_phase_A       : signed(11 downto 0);
  signal s_valid_phase_A : std_logic;
  signal s_phase_B       : signed(11 downto 0);
  signal s_valid_phase_B : std_logic;
  signal s_phase_C       : signed(11 downto 0);
  signal s_valid_phase_C : std_logic;
  -- ===============================
  -- RMS calculation component
  -- ===============================
  component MovingAverageRMS is
    generic (
      N      : natural := 64; -- comprimento da média móvel
      Log2_N : natural := 6 -- log2(N)
    );
    port (
      --------------------------
      -- Clock / Reset
      --------------------------
      i_clk : in std_logic;
      i_rst : in std_logic;

      --------------------------
      -- Amostra de entrada
      --------------------------
      i_sample : in std_logic_vector(11 downto 0); -- signed 12b (-2048..+2047)
      i_valid  : in std_logic; -- pulso 1 ciclo por amostra

      -------------------------------------------------------------
      -- Saídas
      -------------------------------------------------------------
      o_sq_reg    : out std_logic_vector(23 downto 0); -- último x.^2 registrado
      o_rms       : out std_logic_vector(15 downto 0); -- RMS (16b)
      o_rms_valid : out std_logic -- pulso 1 ciclo quando o_rms válido
    );
  end component;
  signal s_sq_reg           : std_logic_vector(23 downto 0);
  signal s_rms              : std_logic_vector(15 downto 0);
  signal s_rms_valid        : std_logic;
  signal s_rms_aux_0        : std_logic_vector(15 downto 0);
  signal s_rms_aux_0_valid  : std_logic;
  signal s_rms_aux_1        : std_logic_vector(15 downto 0);
  signal s_rms_aux_1_valid  : std_logic;
  signal s_rms_aux_2        : std_logic_vector(15 downto 0);
  signal s_rms_aux_2_valid  : std_logic;
  signal s_rms_aux_3        : std_logic_vector(15 downto 0);
  signal s_rms_aux_3_valid  : std_logic;
  signal s_rms_aux_4        : std_logic_vector(15 downto 0);
  signal s_rms_aux_4_valid  : std_logic;
  signal s_rms_aux_5        : std_logic_vector(15 downto 0);
  signal s_rms_aux_5_valid  : std_logic;
  signal s_rms_aux_6        : std_logic_vector(15 downto 0);
  signal s_rms_aux_6_valid  : std_logic;
  signal s_rms_aux_7        : std_logic_vector(15 downto 0);
  signal s_rms_aux_7_valid  : std_logic;
  signal s_rms_aux_8        : std_logic_vector(15 downto 0);
  signal s_rms_aux_8_valid  : std_logic;
  signal s_rms_aux_9        : std_logic_vector(15 downto 0);
  signal s_rms_aux_9_valid  : std_logic;
  signal s_rms_aux_10       : std_logic_vector(15 downto 0);
  signal s_rms_aux_10_valid : std_logic;
  -- =============================================================
  -- Basic protection component 50/50N (instantaneous overcurrent)
  -- =============================================================
  component ProtectInstant_50_50N is
    generic (
      G_MS_TICKS : natural := 100_000; -- ciclos de i_clk por 1 ms (100MHz -> 100_000)
      G_HYST_U12 : natural := 0 -- histerese (0..4095) na mesma unidade de i_peakup_u12
    );
    port (
      --------------------------
      -- Clock / Reset
      --------------------------
      i_clk : in std_logic;
      i_rst : in std_logic;
      --------------------------
      -- Entradas
      --------------------------
      i_sample_u12        : in std_logic_vector(11 downto 0); -- unsigned (0..4095(2047))
      i_valid             : in std_logic; -- pulso de amostra válida
      i_peakup_u12        : in std_logic_vector(11 downto 0); -- unsigned (0..4095)
      i_intentional_delay : in std_logic_vector(19 downto 0); -- atraso intencional [ms]
      --------------------------
      -- Saída
      --------------------------
      o_trip : out std_logic
    );
  end component;
  -- signal outputs para o trip global
  signal s_trip_50_A : std_logic;
  signal s_trip_50_B : std_logic;
  signal s_trip_50_C : std_logic;
  signal s_trip_50N  : std_logic;
  -- reset signals
  signal s_rst_50_A : std_logic;
  signal s_rst_50_B : std_logic;
  signal s_rst_50_C : std_logic;
  signal s_rst_50_N : std_logic;

  
  -- ==========================================================================
  -- -- Component: Prot51_51N_ACC TESTE
  -- ==========================================================================
  component Prot51_51N_ACC is
    generic (
      -- Frequência de clock do sistema (Hz). Por padrão, 100 MHz.
      G_CLK_HZ    : natural := 100_000_000;
      -- Histerese em "contagens RMS" para evitar chatter (i_peakup - G_HYST).
      G_HYST      : natural := 0;
      -- Larguras da LUT (RAM) usadas para a curva temporizada.
      G_ADDR_BITS : natural := 11; -- 2^11 = 2048 endereços (RMS 0..2047)
      G_DATA_BITS : natural := 20  -- Taxa de incremento (velocidade), máximo 20 bits
    );
    port (
      --------------------------
      -- Clock / Reset / Start
      --------------------------
      i_clk_100MHz       : in  std_logic; 
      i_rst              : in  std_logic; 
      i_start_51_51N     : in  std_logic; 

      --------------------------
      -- Medida RMS e limiar
      --------------------------
      i_rms_51_51N       : in  std_logic_vector(11 downto 0); 
      i_rms_51_51N_valid : in  std_logic; 
      i_peakup           : in  std_logic_vector(11 downto 0); 

      --------------------------
      -- Interface RAM (LUT curva 51/51N)
      --------------------------
      o_ram_addr         : out std_logic_vector(G_ADDR_BITS-1 downto 0); 
      o_ram_rd_req       : out std_logic;                                
      i_ram_data         : in  std_logic_vector(G_DATA_BITS-1 downto 0);  

      --------------------------
      -- Saídas de proteção / debug
      --------------------------
      o_time_ms          : out std_logic_vector(G_DATA_BITS-1 downto 0);  
      o_start_trip_time  : out std_logic;                                 
      o_trip_51_51N      : out std_logic                                  
    );
  end component;


  -- ============================================================================
  -- -- Component: Prot51_51N_Time (time-delayed overcurrent protection 51/51N)
  -- ==========================================================================
  component Prot51_51N_Time is
    generic (
      G_CLK_HZ    : natural := 100_000_000; -- Hz
      G_HYST      : natural := 0; -- histerese em contagens RMS
      G_ADDR_BITS : natural := 12; -- 2048 endereços (0..2047)
      G_DATA_BITS : natural := 20 -- tempo em ms
    );
    port (
      -- Clock / Reset / Start
      i_clk_100MHz   : in std_logic;
      i_rst          : in std_logic;
      i_start_51_51N : in std_logic;
      -- RMS e limiar
      i_rms_51_51N       : in std_logic_vector(11 downto 0);
      i_rms_51_51N_valid : in std_logic;
      i_peakup           : in std_logic_vector(11 downto 0);
      -- Interface RAM (LUT)
      o_ram_addr   : out std_logic_vector(11 downto 0);
      o_ram_rd_req : out std_logic;
      i_ram_data   : in std_logic_vector(19 downto 0);
      -- Saídas
      o_time_ms         : out std_logic_vector(19 downto 0);
      o_start_trip_time : out std_logic;
      o_trip_51_51N     : out std_logic
    );
  end component;
  -- ========= 51 (A/B/C) =========
  signal s_start_51      : std_logic := '1';
  signal s_peakup_51_u12 : std_logic_vector(11 downto 0);
  signal s_time_ms_51    : std_logic_vector(19 downto 0);
  signal s_start_trip_51 : std_logic;
  signal s_trip_51_A     : std_logic;
  signal s_trip_51_B     : std_logic;
  signal s_trip_51_C     : std_logic;
  -- Handshake BRAM porta A -> proteção 51
  signal s_51_ram_addr_A   : std_logic_vector(11 downto 0);
  signal s_51_ram_rd_req_A : std_logic;
  signal s_51_ram_addr_B   : std_logic_vector(11 downto 0);
  signal s_51_ram_rd_req_B : std_logic;
  signal s_51_ram_addr_C   : std_logic_vector(11 downto 0);
  signal s_51_ram_rd_req_C : std_logic;
  -- ========= 51N (neutro, VAUX3) =========
  signal s_start_51N      : std_logic := '1';
  signal s_peakup_51N_u12 : std_logic_vector(11 downto 0);
  signal s_time_ms_51N    : std_logic_vector(19 downto 0);
  signal s_start_trip_51N : std_logic;
  signal s_trip_51N       : std_logic;
  -- Handshake BRAM porta B -> proteção 51N
  signal s_51N_ram_addr   : std_logic_vector(11 downto 0);
  signal s_51N_ram_rd_req : std_logic;
  -- reset signals
  signal s_rst_51_A : std_logic;
  signal s_rst_51_B : std_logic;
  signal s_rst_51_C : std_logic;
  signal s_rst_51_N : std_logic;
  -- ==========================================================================
  -- Component: Protection 47   
  -- ==========================================================================	
  component ProtVoltageUmbalanceNegSeq_47 is
    generic (
      G_CLK_HZ    : natural := 100_000_000; -- Frequencia do clock (Hz)
      G_HYST_VUF  : natural := 5; -- Histerese em unidades de 0.05% (5 = 0.25%)
      G_ADDR_BITS : natural := 12; -- Bits de endereco da LUT (2^11=2048, igual ao blk_mem_gen_0)
      G_DATA_BITS : natural := 20 -- Bits de dado da LUT (tempo em ms)
    );
    port (
      -- Clock / Reset
      i_clk : in std_logic;
      i_rst : in std_logic; -- Reset sincrono, ativo alto

      -- Entradas das componentes simetricas de tensao (saidas do inst_symcom_retpol)
      i_seq2_abs  : in std_logic_vector(31 downto 0); -- |V2|, unsigned 32b
      i_seq1_abs  : in std_logic_vector(31 downto 0); -- |V1|, unsigned 32b
      i_valid_seq : in std_logic; -- Pulso ~60 Hz

      -- Setpoint configuravel via Core_Regs
      -- Unidade: 1 = 0.05%  ->  Pickup 5.0% = 100 unidades
      i_pickup_vuf : in std_logic_vector(G_ADDR_BITS - 1 downto 0);

      -- Interface RAM - mesmo padrao do Prot51_51N_Time
      o_ram_addr   : out std_logic_vector(G_ADDR_BITS - 1 downto 0);
      o_ram_rd_req : out std_logic;
      i_ram_data   : in std_logic_vector(G_DATA_BITS - 1 downto 0);

      -- Saidas
      o_vuf     : out std_logic_vector(G_ADDR_BITS - 1 downto 0); -- VUF calculado (debug)
      o_time_ms : out std_logic_vector(G_DATA_BITS - 1 downto 0); -- Contador de ms (debug)
      o_trip    : out std_logic
    );
  end component;
  -- ========= 47 =========
  signal s_trip_47_stg1 : std_logic;
  signal s_rst_47_stg1  : std_logic;
  -- Handshake BRAM porta A -> proteção 47
  signal s_47_ram_addr_stg1   : std_logic_vector(11 downto 0);
  signal s_47_ram_rd_req_stg1 : std_logic;

  -- =========================================================================
  -- COMPONENT: Block Memory Generator (Dual-Port) Para proteções temporizadas
  -- =========================================================================
  component blk_mem_gen_0
    port (
      clka  : in std_logic;
      ena   : in std_logic;
      wea   : in std_logic_vector(0 downto 0);
      addra : in std_logic_vector(11 downto 0);
      dina  : in std_logic_vector(19 downto 0);
      douta : out std_logic_vector(19 downto 0);
      clkb  : in std_logic;
      enb   : in std_logic;
      web   : in std_logic_vector(0 downto 0);
      addrb : in std_logic_vector(11 downto 0);
      dinb  : in std_logic_vector(19 downto 0);
      doutb : out std_logic_vector(19 downto 0)
    );
  end component;
  signal s_51_bram_addrb      : std_logic_vector(11 downto 0) := (others => '0');
  signal s_51_bram_dina       : std_logic_vector(19 downto 0) := (others => '0');
  signal s_51_bram_dinb       : std_logic_vector(19 downto 0) := (others => '0');
  signal s_51_bram_douta      : std_logic_vector(19 downto 0);
  signal s_51_bram_doutb      : std_logic_vector(19 downto 0);
  signal s_51_bram_wea        : std_logic_vector(0 downto 0)  := "0"; -- "0" = somente leitura
  signal s_51_bram_web        : std_logic_vector(0 downto 0)  := "0";
  signal s_51_A_bram_addrb    : std_logic_vector(11 downto 0) := (others => '0');
  signal s_51_A_bram_dina     : std_logic_vector(19 downto 0) := (others => '0');
  signal s_51_A_bram_dinb     : std_logic_vector(19 downto 0) := (others => '0');
  signal s_51_A_bram_douta    : std_logic_vector(19 downto 0);
  signal s_51_A_bram_doutb    : std_logic_vector(19 downto 0);
  signal s_51_A_bram_wea      : std_logic_vector(0 downto 0)  := "0"; -- "0" = somente leitura
  signal s_51_A_bram_web      : std_logic_vector(0 downto 0)  := "0";
  signal s_51_B_bram_addrb    : std_logic_vector(11 downto 0) := (others => '0');
  signal s_51_B_bram_dina     : std_logic_vector(19 downto 0) := (others => '0');
  signal s_51_B_bram_dinb     : std_logic_vector(19 downto 0) := (others => '0');
  signal s_51_B_bram_douta    : std_logic_vector(19 downto 0);
  signal s_51_B_bram_doutb    : std_logic_vector(19 downto 0);
  signal s_51_B_bram_wea      : std_logic_vector(0 downto 0)  := "0"; -- "0" = somente leitura
  signal s_51_B_bram_web      : std_logic_vector(0 downto 0)  := "0";
  signal s_51_C_bram_addrb    : std_logic_vector(11 downto 0) := (others => '0');
  signal s_51_C_bram_dina     : std_logic_vector(19 downto 0) := (others => '0');
  signal s_51_C_bram_dinb     : std_logic_vector(19 downto 0) := (others => '0');
  signal s_51_C_bram_douta    : std_logic_vector(19 downto 0);
  signal s_51_C_bram_doutb    : std_logic_vector(19 downto 0);
  signal s_51_C_bram_wea      : std_logic_vector(0 downto 0)  := "0"; -- "0" = somente leitura
  signal s_51_C_bram_web      : std_logic_vector(0 downto 0)  := "0";
  signal s_51N_bram_addra     : std_logic_vector(11 downto 0) := (others => '0');
  signal s_51N_bram_addrb     : std_logic_vector(11 downto 0) := (others => '0');
  signal s_51N_bram_dina      : std_logic_vector(19 downto 0) := (others => '0');
  signal s_51N_bram_dinb      : std_logic_vector(19 downto 0) := (others => '0');
  signal s_51N_bram_douta     : std_logic_vector(19 downto 0);
  signal s_51N_bram_doutb     : std_logic_vector(19 downto 0);
  signal s_51N_bram_wea       : std_logic_vector(0 downto 0)  := "0"; -- "0" = somente leitura
  signal s_51N_bram_web       : std_logic_vector(0 downto 0)  := "0";
  -- signal s_47_bram_addrb      : std_logic_vector(10 downto 0) := (others => '0');
  -- signal s_47_bram_dina       : std_logic_vector(19 downto 0) := (others => '0');
  -- signal s_47_bram_dinb       : std_logic_vector(19 downto 0) := (others => '0');
  -- signal s_47_bram_douta      : std_logic_vector(19 downto 0);
  -- signal s_47_bram_doutb      : std_logic_vector(19 downto 0);
  -- signal s_47_bram_wea        : std_logic_vector(0 downto 0)  := "0"; -- "0" = somente leitura
  -- signal s_47_bram_web        : std_logic_vector(0 downto 0)  := "0";
  signal s_47_stg1_bram_addrb    : std_logic_vector(11 downto 0) := (others => '0');
  signal s_47_stg1_bram_dina  : std_logic_vector(19 downto 0) := (others => '0');
  signal s_47_stg1_bram_dinb     : std_logic_vector(19 downto 0) := (others => '0');
  signal s_47_stg1_bram_douta : std_logic_vector(19 downto 0);
  signal s_47_bram_doutb_stg1 : std_logic_vector(19 downto 0);
  signal s_47_stg1_bram_wea   : std_logic_vector(0 downto 0) := "0"; -- "0" = somente leitura
  signal s_47_stg1_bram_web      : std_logic_vector(0 downto 0) := "0";

  -- =============================================================
  -- Basic protection component 27 (undervoltage)
  -- =============================================================
  component ProtectUnderVoltage_27 is
    generic (
      G_MS_TICKS : natural := 100_000; -- ciclos de i_clk por 1 ms (100MHz -> 100_000)
      G_HYST_U12 : natural := 0 -- histerese (0..4095) na mesma unidade de i_peakup_u12
    );
    port (
      --------------------------
      -- Clock / Reset
      --------------------------
      i_clk : in std_logic;
      i_rst : in std_logic;
      --------------------------
      -- Entradas
      --------------------------
      i_vsample_u12       : in std_logic_vector(11 downto 0); -- tensão (0..4095)
      i_valid             : in std_logic; -- pulso de amostra válida
      i_peakup_u12        : in std_logic_vector(11 downto 0); -- unsigned (0..4095)
      i_intentional_delay : in std_logic_vector(19 downto 0); -- atraso intencional [ms]
      --------------------------
      -- Saída
      --------------------------
      o_trip : out std_logic
    );
  end component;
  -- signal outputs para função 27 (subtensão) - 2 estágios
  signal s_trip_27_A_stg1 : std_logic;
  signal s_trip_27_A_stg2 : std_logic;
  signal s_trip_27_B_stg1 : std_logic;
  signal s_trip_27_B_stg2 : std_logic;
  signal s_trip_27_C_stg1 : std_logic;
  signal s_trip_27_C_stg2 : std_logic;
  -- signal rst
  signal s_rst_27_A_stg1 : std_logic;
  signal s_rst_27_A_stg2 : std_logic;
  signal s_rst_27_B_stg1 : std_logic;
  signal s_rst_27_B_stg2 : std_logic;
  signal s_rst_27_C_stg1 : std_logic;
  signal s_rst_27_C_stg2 : std_logic;

  -- =============================================================
  -- Basic protection component 59 (overvoltage)
  -- =============================================================
  component ProtectOverVoltage_59 is
    generic (
      G_MS_TICKS : natural := 100_000; -- ciclos de i_clk por 1 ms (100MHz -> 100_000)
      G_HYST_U12 : natural := 0 -- histerese (0..4095) na mesma unidade de i_peakup_u12
    );
    port (
      --------------------------
      -- Clock / Reset
      --------------------------
      i_clk : in std_logic;
      i_rst : in std_logic;
      --------------------------
      -- Entradas
      --------------------------
      i_vsample_u12       : in std_logic_vector(11 downto 0); -- tensão (0..4095)
      i_valid             : in std_logic; -- pulso de amostra válida
      i_peakup_u12        : in std_logic_vector(11 downto 0); -- unsigned (0..4095)
      i_intentional_delay : in std_logic_vector(19 downto 0); -- atraso intencional [ms]
      --------------------------
      -- Saída
      --------------------------
      o_trip : out std_logic
    );
  end component;
  -- signal outputs para função 59 (sobretensão) - 2 estágios
  signal s_trip_59_A_stg1 : std_logic;
  signal s_trip_59_A_stg2 : std_logic;
  signal s_trip_59_B_stg1 : std_logic;
  signal s_trip_59_B_stg2 : std_logic;
  signal s_trip_59_C_stg1 : std_logic;
  signal s_trip_59_C_stg2 : std_logic;
  -- rst signal
  signal s_rst_59_A_stg1 : std_logic;
  signal s_rst_59_A_stg2 : std_logic;
  signal s_rst_59_B_stg1 : std_logic;
  signal s_rst_59_B_stg2 : std_logic;
  signal s_rst_59_C_stg1 : std_logic;
  signal s_rst_59_C_stg2 : std_logic;

  -------------------------------------------------------------
  -- Phasor métricas (real, imag, abs, phase) 
  ------------------------------------------------------------- 
  component phasor_64pts_3ph_unified_fsm is
    generic (
      SAMPLE_WIDTH : integer := 12;
      COEFF_WIDTH  : integer := 15;
      ACC_WIDTH    : integer := 36;
      OUT_WIDTH    : integer := 32;
      ANG_WIDTH    : integer := 16;
      ITER         : integer := 16
    );
    port (
      i_clk              : in std_logic;
      i_rst              : in std_logic;
      i_signal_phaseA_12 : in signed(SAMPLE_WIDTH - 1 downto 0);
      i_valid_phaseA     : in std_logic;
      i_signal_phasB_12  : in signed(SAMPLE_WIDTH - 1 downto 0);
      i_valid_phaseB     : in std_logic;
      i_signal_phaseC_12 : in signed(SAMPLE_WIDTH - 1 downto 0);
      i_valid_phaseC     : in std_logic;
      o_valid_phaseA     : out std_logic;
      o_Real_phaseA      : out signed(ACC_WIDTH - 1 downto 0);
      o_Imag_phaseA      : out signed(ACC_WIDTH - 1 downto 0);
      o_RMS_phaseA       : out unsigned(OUT_WIDTH - 1 downto 0);
      o_phase_phaseA     : out signed(ANG_WIDTH - 1 downto 0);
      o_valid_phaseB     : out std_logic;
      o_Real_phaseB      : out signed(ACC_WIDTH - 1 downto 0);
      o_Imag_phaseB      : out signed(ACC_WIDTH - 1 downto 0);
      o_RMS_phaseB       : out unsigned(OUT_WIDTH - 1 downto 0);
      o_phase_phaseB     : out signed(ANG_WIDTH - 1 downto 0);
      o_valid_phaseC     : out std_logic;
      o_Real_phaseC      : out signed(ACC_WIDTH - 1 downto 0);
      o_Imag_phaseC      : out signed(ACC_WIDTH - 1 downto 0);
      o_RMS_phaseC       : out unsigned(OUT_WIDTH - 1 downto 0);
      o_phase_phaseC     : out signed(ANG_WIDTH - 1 downto 0)
    );
  end component;
  signal s_ph_valid_phaseA : std_logic;
  signal s_ph_Real_phaseA  : signed(35 downto 0);
  signal s_ph_Imag_phaseA  : signed(35 downto 0);
  signal s_ph_RMS_phaseA   : unsigned(31 downto 0);
  signal s_ph_phase_phaseA : signed(15 downto 0);
  signal s_ph_valid_phaseB : std_logic;
  signal s_ph_Real_phaseB  : signed(35 downto 0);
  signal s_ph_Imag_phaseB  : signed(35 downto 0);
  signal s_ph_RMS_phaseB   : unsigned(31 downto 0);
  signal s_ph_phase_phaseB : signed(15 downto 0);
  signal s_ph_valid_phaseC : std_logic;
  signal s_ph_Real_phaseC  : signed(35 downto 0);
  signal s_ph_Imag_phaseC  : signed(35 downto 0);
  signal s_ph_RMS_phaseC   : unsigned(31 downto 0);
  signal s_ph_phase_phaseC : signed(15 downto 0);
  --  -------------------------------------------------------------
  --  -- Componentes simetricas seq 0, 1, 2
  --  ------------------------------------------------------------- 	
  --	Component symcomp_3ph_from_phasors_fsm is
  --	generic (
  --		ACC_WIDTH : integer := 36  -- deve casar com ACC_WIDTH do seu bloco de fasor
  --	);
  --	port (
  --		i_clk : in  std_logic;
  --		i_rst : in  std_logic;

  --		-- Entradas do bloco de fasor (somente Re/Im + valids)
  --		i_valid_phaseA : in std_logic;
  --		i_Re_phaseA    : in signed(ACC_WIDTH-1 downto 0);
  --		i_Im_phaseA    : in signed(ACC_WIDTH-1 downto 0);

  --		i_valid_phaseB : in std_logic;
  --		i_Re_phaseB    : in signed(ACC_WIDTH-1 downto 0);
  --		i_Im_phaseB    : in signed(ACC_WIDTH-1 downto 0);

  --		i_valid_phaseC : in std_logic;
  --		i_Re_phaseC    : in signed(ACC_WIDTH-1 downto 0);
  --		i_Im_phaseC    : in signed(ACC_WIDTH-1 downto 0);

  --		-- Saídas: componentes simétricas (sequências 0/1/2)
  --		o_valid_seq : out std_logic;

  --		o_seq0_re : out signed(ACC_WIDTH-1 downto 0);
  --		o_seq0_im : out signed(ACC_WIDTH-1 downto 0);

  --		o_seq1_re : out signed(ACC_WIDTH-1 downto 0);
  --		o_seq1_im : out signed(ACC_WIDTH-1 downto 0);

  --		o_seq2_re : out signed(ACC_WIDTH-1 downto 0);
  --		o_seq2_im : out signed(ACC_WIDTH-1 downto 0)
  --	);
  --	end Component;

  signal s_valid_seq : std_logic;
  signal s_Re_seq0   : signed(35 downto 0);
  signal s_Im_seq0   : signed(35 downto 0);
  signal s_Re_seq1   : signed(35 downto 0);
  signal s_Im_seq1   : signed(35 downto 0);
  signal s_Re_seq2   : signed(35 downto 0);
  signal s_Im_seq2   : signed(35 downto 0);

  -------------------------------------------------------------
  -- Componentes simetricas seq 0, 1, 2 com phase e RMS
  ------------------------------------------------------------- 	
  component symcomp_3ph_from_phasors_fsm_retpol is
    generic (
      ACC_WIDTH : integer := 36;
      OUT_WIDTH : integer := 32;
      ANG_WIDTH : integer := 16;
      ITER      : integer := 16
    );
    port (
      i_clk : in std_logic;
      i_rst : in std_logic;

      -- Entradas do bloco de fasor (Re/Im por fase)
      i_valid_phaseA : in std_logic;
      i_Re_phaseA    : in signed(ACC_WIDTH - 1 downto 0);
      i_Im_phaseA    : in signed(ACC_WIDTH - 1 downto 0);

      i_valid_phaseB : in std_logic;
      i_Re_phaseB    : in signed(ACC_WIDTH - 1 downto 0);
      i_Im_phaseB    : in signed(ACC_WIDTH - 1 downto 0);

      i_valid_phaseC : in std_logic;
      i_Re_phaseC    : in signed(ACC_WIDTH - 1 downto 0);
      i_Im_phaseC    : in signed(ACC_WIDTH - 1 downto 0);

      -- Saídas (sequências 0,1,2)
      o_valid_seq  : out std_logic;
      o_seq0_re    : out signed(ACC_WIDTH - 1 downto 0);
      o_seq0_im    : out signed(ACC_WIDTH - 1 downto 0);
      o_seq0_abs   : out unsigned(OUT_WIDTH - 1 downto 0);
      o_seq0_phase : out signed(ANG_WIDTH - 1 downto 0);
      o_seq0_rms   : out unsigned(OUT_WIDTH - 1 downto 0);
      o_seq1_abs   : out unsigned(OUT_WIDTH - 1 downto 0);
      o_seq1_phase : out signed(ANG_WIDTH - 1 downto 0);
      o_seq1_rms   : out unsigned(OUT_WIDTH - 1 downto 0);
      o_seq1_re    : out signed(ACC_WIDTH - 1 downto 0);
      o_seq1_im    : out signed(ACC_WIDTH - 1 downto 0);
      o_seq2_re    : out signed(ACC_WIDTH - 1 downto 0);
      o_seq2_im    : out signed(ACC_WIDTH - 1 downto 0);
      o_seq2_abs   : out unsigned(OUT_WIDTH - 1 downto 0);
      o_seq2_phase : out signed(ANG_WIDTH - 1 downto 0);
      o_seq2_rms   : out unsigned(OUT_WIDTH - 1 downto 0)
    );
  end component;

  signal s_seq0_re    : signed(35 downto 0);
  signal s_seq0_im    : signed(35 downto 0);
  signal s_seq0_abs   : unsigned(31 downto 0);
  signal s_seq0_phase : signed(15 downto 0);
  signal s_seq0_rms   : unsigned(31 downto 0);
  signal s_seq1_abs   : unsigned(31 downto 0);
  signal s_seq1_phase : signed(15 downto 0);
  signal s_seq1_rms   : unsigned(31 downto 0);
  signal s_seq1_re    : signed(35 downto 0);
  signal s_seq1_im    : signed(35 downto 0);
  signal s_seq2_re    : signed(35 downto 0);
  signal s_seq2_im    : signed(35 downto 0);
  signal s_seq2_abs   : unsigned(31 downto 0);
  signal s_seq2_phase : signed(15 downto 0);
  signal s_seq2_rms   : unsigned(31 downto 0);
  signal s_seq_valid  : std_logic;

  -------------------------------------------------------------
  ----- Gerador de sinal com DC 3harmonica ----- Only for test
  -------------------------------------------------------------
  component siggen_dc_h3_lut is
    generic (
      G_W : integer := 12; -- largura de saída (bits)
      G_N : integer := 64 -- tamanho da LUT (fixo em 64 nesta versão)
    );
    port (
      i_clk    : in std_logic;
      i_rst    : in std_logic;
      i_valid  : in std_logic;
      o_valid  : out std_logic;
      o_sample : out std_logic_vector(G_W - 1 downto 0)
    );
  end component;

  signal s_siggen_dch3_valid  : std_logic;
  signal s_siggen_dch3_sample : std_logic_vector(11 downto 0);

  -------------------------------------------------------------
  -- filtor passa faixa 40 a 60 Hz
  -------------------------------------------------------------     
  component filtro_Remove_DC_H3 is
    port (
      i_clk          : in std_logic;
      i_rst          : in std_logic; -- reset assíncrono, ativo em '1'
      i_sample_valid : in std_logic;
      i_sample       : in std_logic_vector(11 downto 0);
      o_sample_valid : out std_logic;
      o_sample       : out std_logic_vector(11 downto 0)
    );
  end component;
  signal s_filter_DCH3_sample_in       : std_logic_vector(11 downto 0);
  signal s_filter_DCH3_sample_in_valid : std_logic := '0';
  signal s_filter_DCH3_sample_valid    : std_logic;
  signal s_filter_DCH3_sample          : std_logic_vector(11 downto 0);
  signal s_filter2_DCH3_sample_valid   : std_logic;
  signal s_filter2_DCH3_sample         : std_logic_vector(11 downto 0);

  -------------------------------------------------------------
  -- Estimador de desvio de frequencia em mHz
  -------------------------------------------------------------         
  component freq_diff_from_phasor_sliding64 is
    generic (
      ANG_WIDTH : integer := 16; -- largura do angulo em Q13
      ANG_FRAC  : integer := 13;
      M         : integer := 64; -- tamanho da janela deslizante
      FS_HZ     : integer := 3844 -- taxa de atualizacao do fasor
    );
    port (
      i_clk : in std_logic;
      i_rst : in std_logic;

      i_valid_phasor : in std_logic;
      i_phase_q13    : in signed(ANG_WIDTH - 1 downto 0);

      o_valid : out std_logic;

      -- Diferenca de fase instantanea
      o_dphi_q13 : out signed(ANG_WIDTH - 1 downto 0);

      -- Deriva acumulada em 64 amostras
      o_dtheta64_q13 : out signed(31 downto 0);

      -- Diferenca de frequencia em mHz
      o_dfreq_mHz : out signed(31 downto 0)
    );
  end component;
  signal s_freq_diff_valid_A        : std_logic;
  signal s_freq_diff_dphi_q13_A     : signed(15 downto 0);
  signal s_freq_diff_dtheta64_q13_A : signed(31 downto 0);
  signal s_freq_diff_dfreq_mHz_A    : signed(31 downto 0);

  signal s_freq_diff_valid_B        : std_logic;
	signal s_freq_diff_dphi_q13_B     : signed(15 downto 0);
	signal s_freq_diff_dtheta64_q13_B : signed(31 downto 0);
	signal s_freq_diff_dfreq_mHz_B    : signed(31 downto 0);

	signal s_freq_diff_valid_C        : std_logic;
	signal s_freq_diff_dphi_q13_C     : signed(15 downto 0);
	signal s_freq_diff_dtheta64_q13_C : signed(31 downto 0);
	signal s_freq_diff_dfreq_mHz_C    : signed(31 downto 0);

  -------------------------------------------------------------
   -- Estimador de ROCOF em mHz/s para função ANSI 81R
   -------------------------------------------------------------
   Component rocof_from_phasor_shortwin is
     generic (
       ANG_WIDTH : integer := 16;
       ANG_FRAC  : integer := 13;
       FS_HZ     : integer := 3844;
       K_FREQ    : integer := 8;
       R_ROCOF   : integer := 8; 
       FREQ_MUL  : integer := 9562;
       FREQ_SH   : integer := 10;  
       ROCOF_MUL : integer := 492032;
       ROCOF_SH  : integer := 10; 
       IIR_SH    : integer := 3
     );
     port (
       i_clk          : in  std_logic;
       i_rst          : in  std_logic;
   
       i_valid_phasor : in  std_logic;
       i_phase_q13    : in  signed(ANG_WIDTH-1 downto 0);
   
       o_valid        : out std_logic;
       o_dphi_q13     : out signed(ANG_WIDTH-1 downto 0);
       o_dfreq_mHz    : out signed(31 downto 0);
       o_rocof_mHzps  : out signed(31 downto 0)
     );
   end Component;
	
  -- Estimadores de ROCOF em mHz/s - fases A, B e C
  signal s_rocof_valid_A       : std_logic;
  signal s_rocof_dphi_q13_A    : signed(15 downto 0);
  signal s_rocof_dfreq_mHz_A   : signed(31 downto 0);
  signal s_rocof_mHzps_A       : signed(31 downto 0);

  signal s_rocof_valid_B       : std_logic;
  signal s_rocof_dphi_q13_B    : signed(15 downto 0);
  signal s_rocof_dfreq_mHz_B   : signed(31 downto 0);
  signal s_rocof_mHzps_B       : signed(31 downto 0);

  signal s_rocof_valid_C       : std_logic;
  signal s_rocof_dphi_q13_C    : signed(15 downto 0);
  signal s_rocof_dfreq_mHz_C   : signed(31 downto 0);
  signal s_rocof_mHzps_C       : signed(31 downto 0);
  
   ------------------------------------------------------------
   -- Estimador de ROCOF em mHz/s para função ANSI 81R
   ------------------------------------------------------------- 
	Component rocof_d2theta_from_phasor is
	  generic (
		ANG_WIDTH     : integer := 16;
		ANG_FRAC      : integer := 13;
		K_FREQ        : integer := 16;
		R_ROCOF       : integer := 16;
		G_D2_SCALE_SH : integer := 16
	  );
	  port (
		i_clk           : in  std_logic;
		i_rst           : in  std_logic;

		i_valid_phasor  : in  std_logic;
		i_phase_q13     : in  signed(15 downto 0);

		o_valid         : out std_logic;
		o_dphi_q13      : out signed(15 downto 0);
		o_d2theta_q13   : out signed(31 downto 0);
		o_d2theta_scaled: out signed(47 downto 0);
		o_d2theta_scaled_filt : out signed(47 downto 0)
	  );
	end component; 
	-- =========================
	-- ROCOF NEW - Fase A
	-- =========================
	signal s_rocofnew_valid_A         : std_logic;
	signal s_rocofnew_dphi_A_q13      : signed(15 downto 0);
	signal s_rocofnew_d2theta_A_q13   : signed(31 downto 0);
	signal s_rocofnew_d2theta_A_scaled: signed(47 downto 0);
    signal s_rocofnew_d2theta_A_scaled_filt : signed(47 downto 0);

	signal s_rocofnew_pickup_A        : signed(47 downto 0);
	signal s_rocofnew_trip_A          : std_logic;
	
	
	-------------------------------------------------------------
    -- Estimador de ROCOF a partir do desvio de frequencia em mHz
    -------------------------------------------------------------
	Component rocof_from_dfreq is
		generic (
			DATA_WIDTH : integer := 32;
			WIN_SIZE   : integer := 128;
			IIR_SH     : integer := 3
		);
		port (
		--------------------------------------------------------------------------
		-- Clock / Reset
		--------------------------------------------------------------------------
		i_clk        : in  std_logic;
		i_rst        : in  std_logic;
		--------------------------------------------------------------------------
		-- Entrada do estimador de frequencia
		--------------------------------------------------------------------------
		i_valid      : in  std_logic;
		i_dfreq_mHz  : in  signed(DATA_WIDTH-1 downto 0);
		--------------------------------------------------------------------------
		-- Saidas
		--------------------------------------------------------------------------
		o_valid              : out std_logic;
		-- Desvio de frequencia filtrado, para debug/monitoramento
		o_dfreq_filt_mHz     : out signed(DATA_WIDTH-1 downto 0);
		-- Diferenca de 1 amostra:
		--   dfreq_filt[n] - dfreq_filt[n-1]
		-- Unidade: mHz/amostra
		o_rocof_diff_1samp_mHz : out signed(DATA_WIDTH-1 downto 0);
		-- Diferenca em janela configuravel:
		o_rocof_diff_win_mHz   : out signed(DATA_WIDTH-1 downto 0)
		);
	  end Component;
	  -------------------------------------------------------------
	  -- ROCOF a partir de dfreq em mHz - Fase A
	  -------------------------------------------------------------
	  signal s_rocofdf_valid_A              : std_logic := '0';
	  signal s_rocofdf_diff_1samp_mHz_A     : signed(31 downto 0) := (others => '0');
	  signal s_rocofdf_diff_win_mHz_A       : signed(31 downto 0) := (others => '0');
	  signal s_rocofdf_dfreq_filt_mHz_A     : signed(31 downto 0) := (others => '0');
	  -------------------------------------------------------------
	  -- ROCOF a partir de dfreq em mHz - Fase B
	  -------------------------------------------------------------
	  signal s_rocofdf_valid_B              : std_logic := '0';
	  signal s_rocofdf_diff_1samp_mHz_B     : signed(31 downto 0) := (others => '0');
	  signal s_rocofdf_diff_win_mHz_B       : signed(31 downto 0) := (others => '0');
	  signal s_rocofdf_dfreq_filt_mHz_B     : signed(31 downto 0) := (others => '0');
	  -------------------------------------------------------------
	  -- ROCOF a partir de dfreq em mHz - Fase C
	  -------------------------------------------------------------
	  signal s_rocofdf_valid_C              : std_logic := '0';
	  signal s_rocofdf_diff_1samp_mHz_C     : signed(31 downto 0) := (others => '0');
	  signal s_rocofdf_diff_win_mHz_C       : signed(31 downto 0) := (others => '0');
	  signal s_rocofdf_dfreq_filt_mHz_C     : signed(31 downto 0) := (others => '0');

  ---------------------------------------------------
  -- Bollena Logic with 64 inputs Mux to 8 LUT inputs
  ---------------------------------------------------
  component boolean_logic_64in_lut8 is
    port (
      i_clk : in std_logic;
      i_rst : in std_logic;
      -- 64 sinais disponíveis no sistema
      i_all_signals : in std_logic_vector(63 downto 0);
      -- Seleção de quais sinais entram como S0..S7
      i_sel_s0 : in std_logic_vector(5 downto 0);
      i_sel_s1 : in std_logic_vector(5 downto 0);
      i_sel_s2 : in std_logic_vector(5 downto 0);
      i_sel_s3 : in std_logic_vector(5 downto 0);
      i_sel_s4 : in std_logic_vector(5 downto 0);
      i_sel_s5 : in std_logic_vector(5 downto 0);
      i_sel_s6 : in std_logic_vector(5 downto 0);
      i_sel_s7 : in std_logic_vector(5 downto 0);
      -- LUT programável
      i_lut_cfg : in std_logic_vector(255 downto 0);
      -- Sinais selecionados para debug
      o_selected_s : out std_logic_vector(7 downto 0);
      -- Saída lógica final
      o_trip : out std_logic
    );
  end component;
  signal s_Boolean_selected_s : std_logic_vector(7 downto 0);
  signal s_Boolean_o_trip     : std_logic;

  -----------------------------------------------------------------------
	-- Proteção 81 para uma das fases (Terei 3 instancias desse componente)
	-----------------------------------------------------------------------
	Component Protect81_Channel is
	  generic (
		G_CLK_TICKS_PER_MS : natural := 100_000;
		G_DATA_WIDTH       : natural := 32;
		G_TIME_WIDTH       : natural := 20
	  );
	  port (
		----------------------------------------------------------------
		-- Clock / Reset
		----------------------------------------------------------------
		i_clk                  : in  std_logic;
		i_rst                  : in  std_logic;
		----------------------------------------------------------------
		-- Entrada do estimador de frequência
		--
		-- i_valid:
		--   indica que o valor presente em i_dfreq_mHz é válido
		--
		-- i_dfreq_mHz:
		--   desvio de frequência em mHz
		--   negativo -> subfrequência
		--   positivo -> sobrefrequência
		----------------------------------------------------------------
		i_valid                : in  std_logic;
		i_dfreq_mHz            : in  signed(G_DATA_WIDTH-1 downto 0);
		----------------------------------------------------------------
		-- Configurações
		--
		-- Todos os pickups e margens devem ser fornecidos como valores
		-- positivos, na mesma unidade da entrada (mHz).
		----------------------------------------------------------------
		i_pickup_under_e1_mHz  : in  signed(G_DATA_WIDTH-1 downto 0);
		i_pickup_over_e1_mHz   : in  signed(G_DATA_WIDTH-1 downto 0);
		i_margin_e2_mHz        : in  signed(G_DATA_WIDTH-1 downto 0);
		i_hyst_mHz             : in  signed(G_DATA_WIDTH-1 downto 0);
		i_delay_e1_ms          : in  unsigned(G_TIME_WIDTH-1 downto 0);
		i_delay_e2_ms          : in  unsigned(G_TIME_WIDTH-1 downto 0);
		i_init_time_ms         : in  unsigned(G_TIME_WIDTH-1 downto 0);
		----------------------------------------------------------------
		-- Saídas
		----------------------------------------------------------------
		o_alarm_e1             : out std_logic;
		o_alarm_e2             : out std_logic;
		o_trip_e1              : out std_logic;
		o_trip_e2              : out std_logic;
		o_trip_81			   : out std_logic
	  );
	end Component;
	signal s_prot_81_faseA_alarm_e1 : std_logic;
	signal s_prot_81_faseA_alarm_e2 : std_logic;
	signal s_prot_81_faseA_trip_e1  : std_logic;
	signal s_prot_81_faseA_trip_e2  : std_logic;
	signal s_trip_81_A              : std_logic;
  signal s_rst_81               : std_logic;

	signal s_prot_81_faseB_alarm_e1 : std_logic;
	signal s_prot_81_faseB_alarm_e2 : std_logic;
	signal s_prot_81_faseB_trip_e1  : std_logic;
	signal s_prot_81_faseB_trip_e2  : std_logic;
	signal s_trip_81_B              : std_logic;


	signal s_prot_81_faseC_alarm_e1 : std_logic;
	signal s_prot_81_faseC_alarm_e2 : std_logic;
	signal s_prot_81_faseC_trip_e1  : std_logic;
	signal s_prot_81_faseC_trip_e2  : std_logic;
	signal s_trip_81_C              : std_logic;

	
  -------------------------------------------------------------
  -- Protecao ANSI 81R por canal/fase
  -------------------------------------------------------------
  Component Protect81R_Channel is
    generic (
      G_CLK_TICKS_PER_MS : natural := 100000;
      G_DATA_WIDTH       : natural := 32;
      G_TIME_WIDTH       : natural := 20
    );
    port (
      i_clk  : in std_logic;
      i_rst  : in std_logic;

      i_valid              : in std_logic;
      i_rocof_diff_win_mHz : in signed(G_DATA_WIDTH-1 downto 0);

      i_pickup_e1_mHz_win  : in signed(G_DATA_WIDTH-1 downto 0);
      i_pickup_e2_mHz_win  : in signed(G_DATA_WIDTH-1 downto 0);
      i_hyst_mHz_win       : in signed(G_DATA_WIDTH-1 downto 0);

      i_delay_e1_ms        : in unsigned(G_TIME_WIDTH-1 downto 0);
      i_delay_e2_ms        : in unsigned(G_TIME_WIDTH-1 downto 0);
      i_init_time_ms       : in unsigned(G_TIME_WIDTH-1 downto 0);

      o_alarm_e1           : out std_logic;
      o_alarm_e2           : out std_logic;

      o_trip_e1            : out std_logic;
      o_trip_e2            : out std_logic;
      o_trip_81R           : out std_logic;

      o_rocof_abs_mHz_win  : out signed(G_DATA_WIDTH-1 downto 0)
    );
  end Component;
  -------------------------------------------------------------
  -- Protecao ANSI 81R - Fase A
  -------------------------------------------------------------
  signal s_prot_81R_faseA_alarm_e1 : std_logic := '0';
  signal s_prot_81R_faseA_alarm_e2 : std_logic := '0';
  signal s_prot_81R_faseA_trip_e1  : std_logic := '0';
  signal s_prot_81R_faseA_trip_e2  : std_logic := '0';
  signal s_trip_81R_A              : std_logic := '0';
  signal s_rocofdf_abs_mHz_win_A   : signed(31 downto 0) := (others => '0');
  signal s_rst_81R               : std_logic;  

  -------------------------------------------------------------
  -- Protecao ANSI 81R - Fase B
  -------------------------------------------------------------
  signal s_prot_81R_faseB_alarm_e1 : std_logic := '0';
  signal s_prot_81R_faseB_alarm_e2 : std_logic := '0';
  signal s_prot_81R_faseB_trip_e1  : std_logic := '0';
  signal s_prot_81R_faseB_trip_e2  : std_logic := '0';
  signal s_trip_81R_B              : std_logic := '0';
  signal s_rocofdf_abs_mHz_win_B   : signed(31 downto 0) := (others => '0');


  -------------------------------------------------------------
  -- Protecao ANSI 81R - Fase C
  -------------------------------------------------------------
  signal s_prot_81R_faseC_alarm_e1 : std_logic := '0';
  signal s_prot_81R_faseC_alarm_e2 : std_logic := '0';
  signal s_prot_81R_faseC_trip_e1  : std_logic := '0';
  signal s_prot_81R_faseC_trip_e2  : std_logic := '0';
  signal s_trip_81R_C              : std_logic := '0';
  signal s_rocofdf_abs_mHz_win_C   : signed(31 downto 0) := (others => '0');


  -- =======================
  -- Compente da funcao 46
  --========================
  component ProtPhaseUmbalanceNegSeq_46_51Q is
  generic (
    G_CLK_HZ    : natural := 100_000_000;
    G_HYST      : natural := 0;
    G_TIME_WIDTH       : natural := 20;
    G_ADDR_BITS : natural := 12; 
    G_DATA_BITS : natural := 20 
  );
  port (
    --------------------------
    -- Clock / Reset / Start
    --------------------------
    i_clk_100MHz       : in  std_logic; -- usar 100 MHz (ou outro; ajuste G_CLK_HZ)
    i_rst              : in  std_logic; -- reset síncrono (nível alto)
    i_start            : in  std_logic; -- pulso/nível para armar e iniciar monitoramento

    --------------------------
    -- Medida seqNeg e limiar
    --------------------------
    i_seq2_abs          : in  unsigned(31 downto 0); -- RMS 12b (0..*), usado addr[10:0]
    i_seq2_valid        : in  std_logic; -- '1' quando RMS atual é válido (amostras espaçadas)
    i_seq2_pickup_e1    : in  std_logic_vector(11 downto 0); -- limiar de atuação (contagens RMS)
    i_seq2_pickup_e2    : in  std_logic_vector(11 downto 0); -- limiar de atuação (contagens RMS)
    i_delay_e1_ms       : in unsigned(G_TIME_WIDTH-1 downto 0);

    --------------------------
    -- Interface RAM (LUT)
    --------------------------
    o_ram_addr         : out std_logic_vector(G_ADDR_BITS-1 downto 0);  -- endereço (RMS mapeado)
    o_ram_rd_req       : out std_logic;                                 -- pulso de leitura (1 ciclo)
    i_ram_data         : in  std_logic_vector(G_DATA_BITS-1 downto 0);  -- tempo-alvo em ms

    --------------------------
    -- Saídas de proteção / debug
    --------------------------
    o_seq_abs_u12      : out UNSIGNED(11 downto 0);
    o_time_ms          : out std_logic_vector(G_DATA_BITS-1 downto 0);  -- contador de ms (satura)
    o_target_ms_reg    : out unsigned(G_DATA_BITS-1 downto 0);
    o_e1_time_cnt      : out STD_LOGIC_VECTOR(G_TIME_WIDTH-1 downto 0);
    o_alarm_e1         : out std_logic;
    o_alarm_e2         : out std_logic;                        
    o_trip_46_e1       : out std_logic;
    o_trip_46_e2       : out std_logic;
    o_trip_46          : out std_logic                                   
  );
end component;
signal s_46_s1_ram_addr      : std_logic_vector(11 downto 0);
signal s_46_s1_ram_rd_req    : std_logic;
signal s_46_s1_time_ms       : std_logic_vector(19 downto 0);  -- contador de ms (satura)
signal s_46_s1_e1_time_cnt   : STD_LOGIC_VECTOR(19 downto 0);
signal s_46_s1_rst           : std_logic;
signal s_46_s1_bram_wea      : std_logic_vector(0 downto 0)  := (others => '0');
signal s_46_s1_bram_dina     : std_logic_vector(19 downto 0) := (others => '0');
signal s_46_s1_bram_douta    : std_logic_vector(19 downto 0);
signal s_46_s1_bram_doutb    : std_logic_vector(19 downto 0);
signal s_46_s1_i2_abs_u12     : unsigned(11 downto 0) := (others => '0');
signal s_46_s1_ram_target_ms  : UNSIGNED(19 downto 0) := (others => '0');
signal s_46_s1_e1_trip        : std_logic;
signal s_46_s1_e2_trip        : std_logic;
signal s_46_s1_trip        : std_logic;
signal s_46_s1_e1_alarm        : std_logic;
signal s_46_s1_e2_alarm        : std_logic;



  -- =========================
  -- Core Regs
  -- =========================
  component core_regs is -- {{{
    port (-- Avalon slave interface
      clk   : in std_logic;
      reset : in std_logic;
      -- Avalon slave interface
      chipselect : in std_logic;
      write      : in std_logic;
      address    : in std_logic_vector(7 downto 0);
      writedata  : in std_logic_vector(31 downto 0);
      read       : in std_logic;
      readdata   : out std_logic_vector(31 downto 0);
      irq        : out std_logic;
      -- Core interface
      -- InPort																{{{
      in_Port_000 : in std_logic_vector(31 downto 0);
      in_Port_001 : in std_logic_vector(31 downto 0);
      in_Port_002 : in std_logic_vector(31 downto 0);
      in_Port_003 : in std_logic_vector(31 downto 0);
      in_Port_004 : in std_logic_vector(31 downto 0);
      in_Port_005 : in std_logic_vector(31 downto 0);
      in_Port_006 : in std_logic_vector(31 downto 0);
      in_Port_007 : in std_logic_vector(31 downto 0);
      in_Port_008 : in std_logic_vector(31 downto 0);
      in_Port_009 : in std_logic_vector(31 downto 0);
      in_Port_010 : in std_logic_vector(31 downto 0);
      in_Port_011 : in std_logic_vector(31 downto 0);
      in_Port_012 : in std_logic_vector(31 downto 0);
      in_Port_013 : in std_logic_vector(31 downto 0);
      in_Port_014 : in std_logic_vector(31 downto 0);
      in_Port_015 : in std_logic_vector(31 downto 0);
      in_Port_016 : in std_logic_vector(31 downto 0);
      in_Port_017 : in std_logic_vector(31 downto 0);
      in_Port_018 : in std_logic_vector(31 downto 0);
      in_Port_019 : in std_logic_vector(31 downto 0);
      in_Port_020 : in std_logic_vector(31 downto 0);
      in_Port_021 : in std_logic_vector(31 downto 0);
      in_Port_022 : in std_logic_vector(31 downto 0);
      in_Port_023 : in std_logic_vector(31 downto 0);
      in_Port_024 : in std_logic_vector(31 downto 0);
      in_Port_025 : in std_logic_vector(31 downto 0);
      in_Port_026 : in std_logic_vector(31 downto 0);
      in_Port_027 : in std_logic_vector(31 downto 0);
      in_Port_028 : in std_logic_vector(31 downto 0);
      in_Port_029 : in std_logic_vector(31 downto 0);
      in_Port_030 : in std_logic_vector(31 downto 0);
      in_Port_031 : in std_logic_vector(31 downto 0);
      in_Port_032 : in std_logic_vector(31 downto 0);
      in_Port_033 : in std_logic_vector(31 downto 0);
      in_Port_034 : in std_logic_vector(31 downto 0);
      in_Port_035 : in std_logic_vector(31 downto 0);
      in_Port_036 : in std_logic_vector(31 downto 0);
      in_Port_037 : in std_logic_vector(31 downto 0);
      in_Port_038 : in std_logic_vector(31 downto 0);
      in_Port_039 : in std_logic_vector(31 downto 0);
      in_Port_040 : in std_logic_vector(31 downto 0);
      in_Port_041 : in std_logic_vector(31 downto 0);
      in_Port_042 : in std_logic_vector(31 downto 0);
      in_Port_043 : in std_logic_vector(31 downto 0);
      in_Port_044 : in std_logic_vector(31 downto 0);
      in_Port_045 : in std_logic_vector(31 downto 0);
      in_Port_046 : in std_logic_vector(31 downto 0);
      in_Port_047 : in std_logic_vector(31 downto 0);
      in_Port_048 : in std_logic_vector(31 downto 0);
      in_Port_049 : in std_logic_vector(31 downto 0);
      in_Port_050 : in std_logic_vector(31 downto 0);
      in_Port_051 : in std_logic_vector(31 downto 0);
      in_Port_052 : in std_logic_vector(31 downto 0);
      in_Port_053 : in std_logic_vector(31 downto 0);
      in_Port_054 : in std_logic_vector(31 downto 0);
      in_Port_055 : in std_logic_vector(31 downto 0);
      in_Port_056 : in std_logic_vector(31 downto 0);
      in_Port_057 : in std_logic_vector(31 downto 0);
      in_Port_058 : in std_logic_vector(31 downto 0);
      in_Port_059 : in std_logic_vector(31 downto 0);
      in_Port_060 : in std_logic_vector(31 downto 0);
      in_Port_061 : in std_logic_vector(31 downto 0);
      in_Port_062 : in std_logic_vector(31 downto 0);
      in_Port_063 : in std_logic_vector(31 downto 0);
      in_Port_064 : in std_logic_vector(31 downto 0);
      in_Port_065 : in std_logic_vector(31 downto 0);
      in_Port_066 : in std_logic_vector(31 downto 0);
      in_Port_067 : in std_logic_vector(31 downto 0);
      in_Port_068 : in std_logic_vector(31 downto 0);
      in_Port_069 : in std_logic_vector(31 downto 0);
      in_Port_070 : in std_logic_vector(31 downto 0);
      in_Port_071 : in std_logic_vector(31 downto 0);
      in_Port_072 : in std_logic_vector(31 downto 0);
      in_Port_073 : in std_logic_vector(31 downto 0);
      in_Port_074 : in std_logic_vector(31 downto 0);
      in_Port_075 : in std_logic_vector(31 downto 0);
      in_Port_076 : in std_logic_vector(31 downto 0);
      in_Port_077 : in std_logic_vector(31 downto 0);
      in_Port_078 : in std_logic_vector(31 downto 0);
      in_Port_079 : in std_logic_vector(31 downto 0);
      in_Port_080 : in std_logic_vector(31 downto 0);
      in_Port_081 : in std_logic_vector(31 downto 0);
      in_Port_082 : in std_logic_vector(31 downto 0);
      in_Port_083 : in std_logic_vector(31 downto 0);
      in_Port_084 : in std_logic_vector(31 downto 0);
      in_Port_085 : in std_logic_vector(31 downto 0);
      in_Port_086 : in std_logic_vector(31 downto 0);
      in_Port_087 : in std_logic_vector(31 downto 0);
      in_Port_088 : in std_logic_vector(31 downto 0);
      in_Port_089 : in std_logic_vector(31 downto 0);
      in_Port_090 : in std_logic_vector(31 downto 0);
      in_Port_091 : in std_logic_vector(31 downto 0);
      in_Port_092 : in std_logic_vector(31 downto 0);
      in_Port_093 : in std_logic_vector(31 downto 0);
      in_Port_094 : in std_logic_vector(31 downto 0);
      in_Port_095 : in std_logic_vector(31 downto 0);
      in_Port_096 : in std_logic_vector(31 downto 0);
      in_Port_097 : in std_logic_vector(31 downto 0);
      in_Port_098 : in std_logic_vector(31 downto 0);
      in_Port_099 : in std_logic_vector(31 downto 0);
      in_Port_100 : in std_logic_vector(31 downto 0);
      in_Port_101 : in std_logic_vector(31 downto 0);
      in_Port_102 : in std_logic_vector(31 downto 0);
      in_Port_103 : in std_logic_vector(31 downto 0);
      in_Port_104 : in std_logic_vector(31 downto 0);
      in_Port_105 : in std_logic_vector(31 downto 0);
      in_Port_106 : in std_logic_vector(31 downto 0);
      in_Port_107 : in std_logic_vector(31 downto 0);
      in_Port_108 : in std_logic_vector(31 downto 0);
      in_Port_109 : in std_logic_vector(31 downto 0);
      in_Port_110 : in std_logic_vector(31 downto 0);
      in_Port_111 : in std_logic_vector(31 downto 0);
      in_Port_112 : in std_logic_vector(31 downto 0);
      in_Port_113 : in std_logic_vector(31 downto 0);
      in_Port_114 : in std_logic_vector(31 downto 0);
      in_Port_115 : in std_logic_vector(31 downto 0);
      in_Port_116 : in std_logic_vector(31 downto 0);
      in_Port_117 : in std_logic_vector(31 downto 0);
      in_Port_118 : in std_logic_vector(31 downto 0);
      in_Port_119 : in std_logic_vector(31 downto 0);
      in_Port_120 : in std_logic_vector(31 downto 0);
      in_Port_121 : in std_logic_vector(31 downto 0);
      in_Port_122 : in std_logic_vector(31 downto 0);
      in_Port_123 : in std_logic_vector(31 downto 0);
      in_Port_124 : in std_logic_vector(31 downto 0);
      in_Port_125 : in std_logic_vector(31 downto 0);
      in_Port_126 : in std_logic_vector(31 downto 0);
      in_Port_127 : in std_logic_vector(31 downto 0);
      in_Port_128 : in std_logic_vector(31 downto 0);
      in_Port_129 : in std_logic_vector(31 downto 0);
      in_Port_130 : in std_logic_vector(31 downto 0);
      in_Port_131 : in std_logic_vector(31 downto 0);
      in_Port_132 : in std_logic_vector(31 downto 0);
      in_Port_133 : in std_logic_vector(31 downto 0);
      in_Port_134 : in std_logic_vector(31 downto 0);
      in_Port_135 : in std_logic_vector(31 downto 0);
      in_Port_136 : in std_logic_vector(31 downto 0);
      in_Port_137 : in std_logic_vector(31 downto 0);
      in_Port_138 : in std_logic_vector(31 downto 0);
      in_Port_139 : in std_logic_vector(31 downto 0);
      in_Port_140 : in std_logic_vector(31 downto 0);
      in_Port_141 : in std_logic_vector(31 downto 0);
      in_Port_142 : in std_logic_vector(31 downto 0);
      in_Port_143 : in std_logic_vector(31 downto 0);
      in_Port_144 : in std_logic_vector(31 downto 0);
      in_Port_145 : in std_logic_vector(31 downto 0);
      in_Port_146 : in std_logic_vector(31 downto 0);
      in_Port_147 : in std_logic_vector(31 downto 0);
      in_Port_148 : in std_logic_vector(31 downto 0);
      in_Port_149 : in std_logic_vector(31 downto 0);
      in_Port_150 : in std_logic_vector(31 downto 0);
      in_Port_151 : in std_logic_vector(31 downto 0);
      in_Port_152 : in std_logic_vector(31 downto 0);
      in_Port_153 : in std_logic_vector(31 downto 0);
      in_Port_154 : in std_logic_vector(31 downto 0);
      in_Port_155 : in std_logic_vector(31 downto 0);
      in_Port_156 : in std_logic_vector(31 downto 0);
      in_Port_157 : in std_logic_vector(31 downto 0);
      in_Port_158 : in std_logic_vector(31 downto 0);
      in_Port_159 : in std_logic_vector(31 downto 0);
      in_Port_160 : in std_logic_vector(31 downto 0);
      in_Port_161 : in std_logic_vector(31 downto 0);
      in_Port_162 : in std_logic_vector(31 downto 0);
      in_Port_163 : in std_logic_vector(31 downto 0);
      in_Port_164 : in std_logic_vector(31 downto 0);
      in_Port_165 : in std_logic_vector(31 downto 0);
      in_Port_166 : in std_logic_vector(31 downto 0);
      in_Port_167 : in std_logic_vector(31 downto 0);
      in_Port_168 : in std_logic_vector(31 downto 0);
      in_Port_169 : in std_logic_vector(31 downto 0);
      in_Port_170 : in std_logic_vector(31 downto 0);
      in_Port_171 : in std_logic_vector(31 downto 0);
      in_Port_172 : in std_logic_vector(31 downto 0);
      in_Port_173 : in std_logic_vector(31 downto 0);
      in_Port_174 : in std_logic_vector(31 downto 0);
      in_Port_175 : in std_logic_vector(31 downto 0);
      in_Port_176 : in std_logic_vector(31 downto 0);
      in_Port_177 : in std_logic_vector(31 downto 0);
      in_Port_178 : in std_logic_vector(31 downto 0);
      in_Port_179 : in std_logic_vector(31 downto 0);
      in_Port_180 : in std_logic_vector(31 downto 0);
      in_Port_181 : in std_logic_vector(31 downto 0);
      in_Port_182 : in std_logic_vector(31 downto 0);
      in_Port_183 : in std_logic_vector(31 downto 0);
      in_Port_184 : in std_logic_vector(31 downto 0);
      in_Port_185 : in std_logic_vector(31 downto 0);
      in_Port_186 : in std_logic_vector(31 downto 0);
      in_Port_187 : in std_logic_vector(31 downto 0);
      in_Port_188 : in std_logic_vector(31 downto 0);
      in_Port_189 : in std_logic_vector(31 downto 0);
      in_Port_190 : in std_logic_vector(31 downto 0);
      in_Port_191 : in std_logic_vector(31 downto 0);
      in_Port_192 : in std_logic_vector(31 downto 0);
      in_Port_193 : in std_logic_vector(31 downto 0);
      in_Port_194 : in std_logic_vector(31 downto 0);
      in_Port_195 : in std_logic_vector(31 downto 0);
      in_Port_196 : in std_logic_vector(31 downto 0);
      in_Port_197 : in std_logic_vector(31 downto 0);
      in_Port_198 : in std_logic_vector(31 downto 0);
      in_Port_199 : in std_logic_vector(31 downto 0);
      in_Port_200 : in std_logic_vector(31 downto 0);
      in_Port_201 : in std_logic_vector(31 downto 0);
      in_Port_202 : in std_logic_vector(31 downto 0);
      in_Port_203 : in std_logic_vector(31 downto 0);
      in_Port_204 : in std_logic_vector(31 downto 0);
      in_Port_205 : in std_logic_vector(31 downto 0);
      in_Port_206 : in std_logic_vector(31 downto 0);
      in_Port_207 : in std_logic_vector(31 downto 0);
      in_Port_208 : in std_logic_vector(31 downto 0);
      in_Port_209 : in std_logic_vector(31 downto 0);
      in_Port_210 : in std_logic_vector(31 downto 0);
      in_Port_211 : in std_logic_vector(31 downto 0);
      in_Port_212 : in std_logic_vector(31 downto 0);
      in_Port_213 : in std_logic_vector(31 downto 0);
      in_Port_214 : in std_logic_vector(31 downto 0);
      in_Port_215 : in std_logic_vector(31 downto 0);
      in_Port_216 : in std_logic_vector(31 downto 0);
      in_Port_217 : in std_logic_vector(31 downto 0);
      in_Port_218 : in std_logic_vector(31 downto 0);
      in_Port_219 : in std_logic_vector(31 downto 0);
      in_Port_220 : in std_logic_vector(31 downto 0);
      in_Port_221 : in std_logic_vector(31 downto 0);
      in_Port_222 : in std_logic_vector(31 downto 0);
      in_Port_223 : in std_logic_vector(31 downto 0);
      in_Port_224 : in std_logic_vector(31 downto 0);
      in_Port_225 : in std_logic_vector(31 downto 0);
      in_Port_226 : in std_logic_vector(31 downto 0);
      in_Port_227 : in std_logic_vector(31 downto 0);
      in_Port_228 : in std_logic_vector(31 downto 0);
      in_Port_229 : in std_logic_vector(31 downto 0);
      in_Port_230 : in std_logic_vector(31 downto 0);
      in_Port_231 : in std_logic_vector(31 downto 0);
      in_Port_232 : in std_logic_vector(31 downto 0);
      in_Port_233 : in std_logic_vector(31 downto 0);
      in_Port_234 : in std_logic_vector(31 downto 0);
      in_Port_235 : in std_logic_vector(31 downto 0);
      in_Port_236 : in std_logic_vector(31 downto 0);
      in_Port_237 : in std_logic_vector(31 downto 0);
      in_Port_238 : in std_logic_vector(31 downto 0);
      in_Port_239 : in std_logic_vector(31 downto 0);
      in_Port_240 : in std_logic_vector(31 downto 0);
      in_Port_241 : in std_logic_vector(31 downto 0);
      in_Port_242 : in std_logic_vector(31 downto 0);
      in_Port_243 : in std_logic_vector(31 downto 0);
      in_Port_244 : in std_logic_vector(31 downto 0);
      in_Port_245 : in std_logic_vector(31 downto 0);
      in_Port_246 : in std_logic_vector(31 downto 0);
      in_Port_247 : in std_logic_vector(31 downto 0);
      in_Port_248 : in std_logic_vector(31 downto 0);
      in_Port_249 : in std_logic_vector(31 downto 0);
      in_Port_250 : in std_logic_vector(31 downto 0);
      in_Port_251 : in std_logic_vector(31 downto 0);
      in_Port_252 : in std_logic_vector(31 downto 0);
      in_Port_253 : in std_logic_vector(31 downto 0);
      in_Port_254 : in std_logic_vector(31 downto 0);
      in_Port_255 : in std_logic_vector(31 downto 0);
      -- }}}
      -- OutPort																{{{
      out_Port_000 : out std_logic_vector(31 downto 0);
      out_Port_001 : out std_logic_vector(31 downto 0);
      out_Port_002 : out std_logic_vector(31 downto 0);
      out_Port_003 : out std_logic_vector(31 downto 0);
      out_Port_004 : out std_logic_vector(31 downto 0);
      out_Port_005 : out std_logic_vector(31 downto 0);
      out_Port_006 : out std_logic_vector(31 downto 0);
      out_Port_007 : out std_logic_vector(31 downto 0);
      out_Port_008 : out std_logic_vector(31 downto 0);
      out_Port_009 : out std_logic_vector(31 downto 0);
      out_Port_010 : out std_logic_vector(31 downto 0);
      out_Port_011 : out std_logic_vector(31 downto 0);
      out_Port_012 : out std_logic_vector(31 downto 0);
      out_Port_013 : out std_logic_vector(31 downto 0);
      out_Port_014 : out std_logic_vector(31 downto 0);
      out_Port_015 : out std_logic_vector(31 downto 0);
      out_Port_016 : out std_logic_vector(31 downto 0);
      out_Port_017 : out std_logic_vector(31 downto 0);
      out_Port_018 : out std_logic_vector(31 downto 0);
      out_Port_019 : out std_logic_vector(31 downto 0);
      out_Port_020 : out std_logic_vector(31 downto 0);
      out_Port_021 : out std_logic_vector(31 downto 0);
      out_Port_022 : out std_logic_vector(31 downto 0);
      out_Port_023 : out std_logic_vector(31 downto 0);
      out_Port_024 : out std_logic_vector(31 downto 0);
      out_Port_025 : out std_logic_vector(31 downto 0);
      out_Port_026 : out std_logic_vector(31 downto 0);
      out_Port_027 : out std_logic_vector(31 downto 0);
      out_Port_028 : out std_logic_vector(31 downto 0);
      out_Port_029 : out std_logic_vector(31 downto 0);
      out_Port_030 : out std_logic_vector(31 downto 0);
      out_Port_031 : out std_logic_vector(31 downto 0);
      out_Port_032 : out std_logic_vector(31 downto 0);
      out_Port_033 : out std_logic_vector(31 downto 0);
      out_Port_034 : out std_logic_vector(31 downto 0);
      out_Port_035 : out std_logic_vector(31 downto 0);
      out_Port_036 : out std_logic_vector(31 downto 0);
      out_Port_037 : out std_logic_vector(31 downto 0);
      out_Port_038 : out std_logic_vector(31 downto 0);
      out_Port_039 : out std_logic_vector(31 downto 0);
      out_Port_040 : out std_logic_vector(31 downto 0);
      out_Port_041 : out std_logic_vector(31 downto 0);
      out_Port_042 : out std_logic_vector(31 downto 0);
      out_Port_043 : out std_logic_vector(31 downto 0);
      out_Port_044 : out std_logic_vector(31 downto 0);
      out_Port_045 : out std_logic_vector(31 downto 0);
      out_Port_046 : out std_logic_vector(31 downto 0);
      out_Port_047 : out std_logic_vector(31 downto 0);
      out_Port_048 : out std_logic_vector(31 downto 0);
      out_Port_049 : out std_logic_vector(31 downto 0);
      out_Port_050 : out std_logic_vector(31 downto 0);
      out_Port_051 : out std_logic_vector(31 downto 0);
      out_Port_052 : out std_logic_vector(31 downto 0);
      out_Port_053 : out std_logic_vector(31 downto 0);
      out_Port_054 : out std_logic_vector(31 downto 0);
      out_Port_055 : out std_logic_vector(31 downto 0);
      out_Port_056 : out std_logic_vector(31 downto 0);
      out_Port_057 : out std_logic_vector(31 downto 0);
      out_Port_058 : out std_logic_vector(31 downto 0);
      out_Port_059 : out std_logic_vector(31 downto 0);
      out_Port_060 : out std_logic_vector(31 downto 0);
      out_Port_061 : out std_logic_vector(31 downto 0);
      out_Port_062 : out std_logic_vector(31 downto 0);
      out_Port_063 : out std_logic_vector(31 downto 0);
      out_Port_064 : out std_logic_vector(31 downto 0);
      out_Port_065 : out std_logic_vector(31 downto 0);
      out_Port_066 : out std_logic_vector(31 downto 0);
      out_Port_067 : out std_logic_vector(31 downto 0);
      out_Port_068 : out std_logic_vector(31 downto 0);
      out_Port_069 : out std_logic_vector(31 downto 0);
      out_Port_070 : out std_logic_vector(31 downto 0);
      out_Port_071 : out std_logic_vector(31 downto 0);
      out_Port_072 : out std_logic_vector(31 downto 0);
      out_Port_073 : out std_logic_vector(31 downto 0);
      out_Port_074 : out std_logic_vector(31 downto 0);
      out_Port_075 : out std_logic_vector(31 downto 0);
      out_Port_076 : out std_logic_vector(31 downto 0);
      out_Port_077 : out std_logic_vector(31 downto 0);
      out_Port_078 : out std_logic_vector(31 downto 0);
      out_Port_079 : out std_logic_vector(31 downto 0);
      out_Port_080 : out std_logic_vector(31 downto 0);
      out_Port_081 : out std_logic_vector(31 downto 0);
      out_Port_082 : out std_logic_vector(31 downto 0);
      out_Port_083 : out std_logic_vector(31 downto 0);
      out_Port_084 : out std_logic_vector(31 downto 0);
      out_Port_085 : out std_logic_vector(31 downto 0);
      out_Port_086 : out std_logic_vector(31 downto 0);
      out_Port_087 : out std_logic_vector(31 downto 0);
      out_Port_088 : out std_logic_vector(31 downto 0);
      out_Port_089 : out std_logic_vector(31 downto 0);
      out_Port_090 : out std_logic_vector(31 downto 0);
      out_Port_091 : out std_logic_vector(31 downto 0);
      out_Port_092 : out std_logic_vector(31 downto 0);
      out_Port_093 : out std_logic_vector(31 downto 0);
      out_Port_094 : out std_logic_vector(31 downto 0);
      out_Port_095 : out std_logic_vector(31 downto 0);
      out_Port_096 : out std_logic_vector(31 downto 0);
      out_Port_097 : out std_logic_vector(31 downto 0);
      out_Port_098 : out std_logic_vector(31 downto 0);
      out_Port_099 : out std_logic_vector(31 downto 0);
      out_Port_100 : out std_logic_vector(31 downto 0);
      out_Port_101 : out std_logic_vector(31 downto 0);
      out_Port_102 : out std_logic_vector(31 downto 0);
      out_Port_103 : out std_logic_vector(31 downto 0);
      out_Port_104 : out std_logic_vector(31 downto 0);
      out_Port_105 : out std_logic_vector(31 downto 0);
      out_Port_106 : out std_logic_vector(31 downto 0);
      out_Port_107 : out std_logic_vector(31 downto 0);
      out_Port_108 : out std_logic_vector(31 downto 0);
      out_Port_109 : out std_logic_vector(31 downto 0);
      out_Port_110 : out std_logic_vector(31 downto 0);
      out_Port_111 : out std_logic_vector(31 downto 0);
      out_Port_112 : out std_logic_vector(31 downto 0);
      out_Port_113 : out std_logic_vector(31 downto 0);
      out_Port_114 : out std_logic_vector(31 downto 0);
      out_Port_115 : out std_logic_vector(31 downto 0);
      out_Port_116 : out std_logic_vector(31 downto 0);
      out_Port_117 : out std_logic_vector(31 downto 0);
      out_Port_118 : out std_logic_vector(31 downto 0);
      out_Port_119 : out std_logic_vector(31 downto 0);
      out_Port_120 : out std_logic_vector(31 downto 0);
      out_Port_121 : out std_logic_vector(31 downto 0);
      out_Port_122 : out std_logic_vector(31 downto 0);
      out_Port_123 : out std_logic_vector(31 downto 0);
      out_Port_124 : out std_logic_vector(31 downto 0);
      out_Port_125 : out std_logic_vector(31 downto 0);
      out_Port_126 : out std_logic_vector(31 downto 0);
      out_Port_127 : out std_logic_vector(31 downto 0);
      out_Port_128 : out std_logic_vector(31 downto 0);
      out_Port_129 : out std_logic_vector(31 downto 0);
      out_Port_130 : out std_logic_vector(31 downto 0);
      out_Port_131 : out std_logic_vector(31 downto 0);
      out_Port_132 : out std_logic_vector(31 downto 0);
      out_Port_133 : out std_logic_vector(31 downto 0);
      out_Port_134 : out std_logic_vector(31 downto 0);
      out_Port_135 : out std_logic_vector(31 downto 0);
      out_Port_136 : out std_logic_vector(31 downto 0);
      out_Port_137 : out std_logic_vector(31 downto 0);
      out_Port_138 : out std_logic_vector(31 downto 0);
      out_Port_139 : out std_logic_vector(31 downto 0);
      out_Port_140 : out std_logic_vector(31 downto 0);
      out_Port_141 : out std_logic_vector(31 downto 0);
      out_Port_142 : out std_logic_vector(31 downto 0);
      out_Port_143 : out std_logic_vector(31 downto 0);
      out_Port_144 : out std_logic_vector(31 downto 0);
      out_Port_145 : out std_logic_vector(31 downto 0);
      out_Port_146 : out std_logic_vector(31 downto 0);
      out_Port_147 : out std_logic_vector(31 downto 0);
      out_Port_148 : out std_logic_vector(31 downto 0);
      out_Port_149 : out std_logic_vector(31 downto 0);
      out_Port_150 : out std_logic_vector(31 downto 0);
      out_Port_151 : out std_logic_vector(31 downto 0);
      out_Port_152 : out std_logic_vector(31 downto 0);
      out_Port_153 : out std_logic_vector(31 downto 0);
      out_Port_154 : out std_logic_vector(31 downto 0);
      out_Port_155 : out std_logic_vector(31 downto 0);
      out_Port_156 : out std_logic_vector(31 downto 0);
      out_Port_157 : out std_logic_vector(31 downto 0);
      out_Port_158 : out std_logic_vector(31 downto 0);
      out_Port_159 : out std_logic_vector(31 downto 0);
      out_Port_160 : out std_logic_vector(31 downto 0);
      out_Port_161 : out std_logic_vector(31 downto 0);
      out_Port_162 : out std_logic_vector(31 downto 0);
      out_Port_163 : out std_logic_vector(31 downto 0);
      out_Port_164 : out std_logic_vector(31 downto 0);
      out_Port_165 : out std_logic_vector(31 downto 0);
      out_Port_166 : out std_logic_vector(31 downto 0);
      out_Port_167 : out std_logic_vector(31 downto 0);
      out_Port_168 : out std_logic_vector(31 downto 0);
      out_Port_169 : out std_logic_vector(31 downto 0);
      out_Port_170 : out std_logic_vector(31 downto 0);
      out_Port_171 : out std_logic_vector(31 downto 0);
      out_Port_172 : out std_logic_vector(31 downto 0);
      out_Port_173 : out std_logic_vector(31 downto 0);
      out_Port_174 : out std_logic_vector(31 downto 0);
      out_Port_175 : out std_logic_vector(31 downto 0);
      out_Port_176 : out std_logic_vector(31 downto 0);
      out_Port_177 : out std_logic_vector(31 downto 0);
      out_Port_178 : out std_logic_vector(31 downto 0);
      out_Port_179 : out std_logic_vector(31 downto 0);
      out_Port_180 : out std_logic_vector(31 downto 0);
      out_Port_181 : out std_logic_vector(31 downto 0);
      out_Port_182 : out std_logic_vector(31 downto 0);
      out_Port_183 : out std_logic_vector(31 downto 0);
      out_Port_184 : out std_logic_vector(31 downto 0);
      out_Port_185 : out std_logic_vector(31 downto 0);
      out_Port_186 : out std_logic_vector(31 downto 0);
      out_Port_187 : out std_logic_vector(31 downto 0);
      out_Port_188 : out std_logic_vector(31 downto 0);
      out_Port_189 : out std_logic_vector(31 downto 0);
      out_Port_190 : out std_logic_vector(31 downto 0);
      out_Port_191 : out std_logic_vector(31 downto 0);
      out_Port_192 : out std_logic_vector(31 downto 0);
      out_Port_193 : out std_logic_vector(31 downto 0);
      out_Port_194 : out std_logic_vector(31 downto 0);
      out_Port_195 : out std_logic_vector(31 downto 0);
      out_Port_196 : out std_logic_vector(31 downto 0);
      out_Port_197 : out std_logic_vector(31 downto 0);
      out_Port_198 : out std_logic_vector(31 downto 0);
      out_Port_199 : out std_logic_vector(31 downto 0);
      out_Port_200 : out std_logic_vector(31 downto 0);
      out_Port_201 : out std_logic_vector(31 downto 0);
      out_Port_202 : out std_logic_vector(31 downto 0);
      out_Port_203 : out std_logic_vector(31 downto 0);
      out_Port_204 : out std_logic_vector(31 downto 0);
      out_Port_205 : out std_logic_vector(31 downto 0);
      out_Port_206 : out std_logic_vector(31 downto 0);
      out_Port_207 : out std_logic_vector(31 downto 0);
      out_Port_208 : out std_logic_vector(31 downto 0);
      out_Port_209 : out std_logic_vector(31 downto 0);
      out_Port_210 : out std_logic_vector(31 downto 0);
      out_Port_211 : out std_logic_vector(31 downto 0);
      out_Port_212 : out std_logic_vector(31 downto 0);
      out_Port_213 : out std_logic_vector(31 downto 0);
      out_Port_214 : out std_logic_vector(31 downto 0);
      out_Port_215 : out std_logic_vector(31 downto 0);
      out_Port_216 : out std_logic_vector(31 downto 0);
      out_Port_217 : out std_logic_vector(31 downto 0);
      out_Port_218 : out std_logic_vector(31 downto 0);
      out_Port_219 : out std_logic_vector(31 downto 0);
      out_Port_220 : out std_logic_vector(31 downto 0);
      out_Port_221 : out std_logic_vector(31 downto 0);
      out_Port_222 : out std_logic_vector(31 downto 0);
      out_Port_223 : out std_logic_vector(31 downto 0);
      out_Port_224 : out std_logic_vector(31 downto 0);
      out_Port_225 : out std_logic_vector(31 downto 0);
      out_Port_226 : out std_logic_vector(31 downto 0);
      out_Port_227 : out std_logic_vector(31 downto 0);
      out_Port_228 : out std_logic_vector(31 downto 0);
      out_Port_229 : out std_logic_vector(31 downto 0);
      out_Port_230 : out std_logic_vector(31 downto 0);
      out_Port_231 : out std_logic_vector(31 downto 0);
      out_Port_232 : out std_logic_vector(31 downto 0);
      out_Port_233 : out std_logic_vector(31 downto 0);
      out_Port_234 : out std_logic_vector(31 downto 0);
      out_Port_235 : out std_logic_vector(31 downto 0);
      out_Port_236 : out std_logic_vector(31 downto 0);
      out_Port_237 : out std_logic_vector(31 downto 0);
      out_Port_238 : out std_logic_vector(31 downto 0);
      out_Port_239 : out std_logic_vector(31 downto 0);
      out_Port_240 : out std_logic_vector(31 downto 0);
      out_Port_241 : out std_logic_vector(31 downto 0);
      out_Port_242 : out std_logic_vector(31 downto 0);
      out_Port_243 : out std_logic_vector(31 downto 0);
      out_Port_244 : out std_logic_vector(31 downto 0);
      out_Port_245 : out std_logic_vector(31 downto 0);
      out_Port_246 : out std_logic_vector(31 downto 0);
      out_Port_247 : out std_logic_vector(31 downto 0);
      out_Port_248 : out std_logic_vector(31 downto 0);
      out_Port_249 : out std_logic_vector(31 downto 0);
      out_Port_250 : out std_logic_vector(31 downto 0);
      out_Port_251 : out std_logic_vector(31 downto 0);
      out_Port_252 : out std_logic_vector(31 downto 0);
      out_Port_253 : out std_logic_vector(31 downto 0);
      out_Port_254 : out std_logic_vector(31 downto 0);
      out_Port_255 : out std_logic_vector(31 downto 0));
    -- }}}
  end component;
  signal s_rst_core_regs : std_logic;
  -- Vamos criando conforme a necessidade
  signal s_out_Port_000 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_001 : std_logic_vector(31 downto 0) := x"00000800"; --Valor default offset
  signal s_out_Port_002 : std_logic_vector(31 downto 0) := x"00000019"; --Valor default decimacao
  signal s_out_Port_003 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_004 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_005 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_006 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_007 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_008 : std_logic_vector(31 downto 0) := x"00000800"; --Valor default offset;
  signal s_out_Port_009 : std_logic_vector(31 downto 0) := x"00000019"; --Valor default decimacao
  signal s_out_Port_010 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_011 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_012 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_013 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_014 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_015 : std_logic_vector(31 downto 0) := x"00000800"; --Valor default offset;
  signal s_out_Port_016 : std_logic_vector(31 downto 0) := x"00000019"; --Valor default decimacao
  signal s_out_Port_017 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_018 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_019 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_020 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_021 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_022 : std_logic_vector(31 downto 0) := x"00000800"; --Valor default offset;
  signal s_out_Port_023 : std_logic_vector(31 downto 0) := x"00000019"; --Valor default decimacao
  signal s_out_Port_024 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_025 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_026 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_027 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_028 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_029 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_030 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_031 : std_logic_vector(31 downto 0) := (others => '0');


  -- Registros Only Read
  signal s_in_Port_032 : std_logic_vector(31 downto 0) := (others => '0'); -- Trip A,B,C,N Global
  signal s_in_Port_033 : std_logic_vector(31 downto 0) := (others => '0'); -- RMS AB
  signal s_in_Port_034 : std_logic_vector(31 downto 0) := (others => '0'); -- RMS CN

  -- Novos registradores de configuração para proteções 27/59 (fases A/B/C)
  signal s_out_Port_035 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_036 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_037 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_038 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_039 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_040 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_041 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_042 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_043 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_044 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_045 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_046 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_047 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_048 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_049 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_050 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_051 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_052 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_053 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_054 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_055 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_056 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_057 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_058 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_059 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_060 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_061 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_062 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_063 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_064 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_065 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_066 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_067 : std_logic_vector(31 downto 0) := (others => '0');

  -- Registros Only Read
  signal s_in_Port_068 : std_logic_vector(31 downto 0) := (others => '0'); -- Trip A,B,C,N Global
  signal s_in_Port_069 : std_logic_vector(31 downto 0) := (others => '0'); -- RMS AB aux 4 e 5
  signal s_in_Port_070 : std_logic_vector(31 downto 0) := (others => '0'); -- RMS C  aux 6

  -- 46 registers
  signal s_out_Port_071 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_072 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_073 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_074 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_in_Port_075  : std_logic_vector(31 downto 0) := (others => '0'); -- RDO



  -- 46 Temp registers
  signal s_out_Port_076 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_077 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_078 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_in_Port_079 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_in_Port_080  : std_logic_vector(31 downto 0) := (others => '0'); -- RDO

  

  -- 47 registers - ProtVoltageUmbalanceNegSeq_47
  signal s_out_Port_081 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_082 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_083 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_084 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_in_Port_085  : std_logic_vector(31 downto 0) := (others => '0'); -- RDO
  signal s_out_Port_086 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_in_Port_087  : std_logic_vector(31 downto 0) := (others => '0'); -- RDO
  signal s_in_Port_088  : std_logic_vector(31 downto 0) := (others => '0'); -- RDO

  
  -- sequencias
  signal s_in_Port_089 : std_logic_vector(31 downto 0) := (others => '0'); -- RDO
  signal s_in_Port_090 : std_logic_vector(31 downto 0) := (others => '0'); -- RDO
  signal s_in_Port_091 : std_logic_vector(31 downto 0) := (others => '0'); -- RDO
  signal s_in_Port_092 : std_logic_vector(31 downto 0) := (others => '0'); -- RDO
  signal s_in_Port_093 : std_logic_vector(31 downto 0) := (others => '0'); -- RDO
  signal s_in_Port_094 : std_logic_vector(31 downto 0) := (others => '0'); -- RDO
  signal s_in_Port_095 : std_logic_vector(31 downto 0) := (others => '0'); -- RDO
  signal s_in_Port_096 : std_logic_vector(31 downto 0) := (others => '0'); -- RDO
  signal s_in_Port_097 : std_logic_vector(31 downto 0) := (others => '0'); -- RDO

  -- logica boleana
  signal s_out_Port_098 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_099 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_100 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_101 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_102 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_103 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_104 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_105 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_106 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_107 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_108 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_109 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_110 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_111 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_112 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_113 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_114 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_115 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_116 : std_logic_vector(31 downto 0) := (others => '0');

  -- relay
  signal s_out_Port_117  : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_118  : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_119  : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_120  : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_121  : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_122  : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_123  : std_logic_vector(31 downto 0) := (others => '0');

  -- sem nada
  signal s_in_Port_124 : std_logic_vector(31 downto 0) := (others => '0');

  -- globlar trip e boolean trip
  signal s_in_Port_125  : std_logic_vector(31 downto 0) := (others => '0'); -- RDO
  signal s_in_Port_126  : std_logic_vector(31 downto 0) := (others => '0'); -- RDO

  -- Force trip
  signal s_out_Port_127 : std_logic_vector(31 downto 0) := (others => '0');

  -- Not used
  
  signal s_out_Port_129 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_130 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_131 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_132 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_out_Port_133 : std_logic_vector(31 downto 0) := (others => '0');
  --

  -- RAM output
  signal s_in_Port_128 : std_logic_vector(31 downto 0) := (others => '0');

  -- RMS
  signal s_in_Port_134 : std_logic_vector(31 downto 0) := (others => '0'); 
  signal s_in_Port_135 : std_logic_vector(31 downto 0) := (others => '0'); 
  signal s_in_Port_136 : std_logic_vector(31 downto 0) := (others => '0'); 

  -- Registros de configuração da proteção 81 (comuns a A/B/C)
  signal s_out_Port_137 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
  signal s_out_Port_138 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
  signal s_out_Port_139 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
  signal s_out_Port_140 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
  signal s_out_Port_141 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
  signal s_out_Port_142 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
  signal s_out_Port_143 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');

  -- Registros de monitoramento da proteção 81
  signal s_in_Port_144 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0'); -- status 81 A/B/C
  signal s_in_Port_145 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0'); -- dfreq fase A
  signal s_in_Port_146 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0'); -- dfreq fase B
  signal s_in_Port_147 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0'); -- dfreq fase C
  
  -- Registros de configuração da proteção 81R (comuns a A/B/C)
  signal s_out_Port_148 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
  signal s_out_Port_149 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
  signal s_out_Port_150 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
  signal s_out_Port_151 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
  signal s_out_Port_152 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
  signal s_out_Port_153 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
  
  -- Registros de monitoramento da proteção 81R
  signal s_in_Port_154 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0'); -- status 81R A/B/C
  signal s_in_Port_155 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0'); -- ROCOF win fase A
  signal s_in_Port_156 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0'); -- ROCOF win fase B
  signal s_in_Port_157 : STD_LOGIC_VECTOR(31 downto 0) := (others => '0'); -- ROCOF win fase C

  -- RGB_LED
  signal s_out_Port_158 : std_logic_vector(31 downto 0) := (others => '0');

  --offset_calibration
  signal s_in_Port_159 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_in_Port_160 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_in_Port_161 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_in_Port_162 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_in_Port_163 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_in_Port_164 : std_logic_vector(31 downto 0) := (others => '0');
  signal s_in_Port_165 : std_logic_vector(31 downto 0) := (others => '0');


	-- ============================================================
	-- Aliases legíveis para os registradores do CoreRegs (0x00..1F)
	-- Casam com regmap_simple.h
	-- ============================================================

  -- 0x00 SOFTRESET
  alias REG_SOFTRESET : std_logic_vector(0 downto 0) is s_out_Port_000(0 downto 0);

  -- A (0x01..0x07)
  alias REG_A_RMS_U12      : std_logic_vector(11 downto 0) is s_in_Port_033(11 downto 0);
  alias REG_A_OFFSET_U12   : std_logic_vector(11 downto 0) is s_out_Port_001(11 downto 0);
  alias REG_A_DECIM_U8     : std_logic_vector(7 downto 0) is s_out_Port_002(7 downto 0);
  alias REG_A_EN50         : std_logic_vector(0 downto 0) is s_out_Port_003(0 downto 0);
  alias REG_A_50_PEAK_U12  : std_logic_vector(11 downto 0) is s_out_Port_004(11 downto 0);
  alias REG_A_50_INTDLY_MS : std_logic_vector(19 downto 0) is s_out_Port_005(19 downto 0);
  alias REG_A_EN51         : std_logic_vector(0 downto 0) is s_out_Port_006(0 downto 0);
  alias REG_A_51_PEAK_U12  : std_logic_vector(11 downto 0) is s_out_Port_007(11 downto 0);

  -- B (0x08..0x0E)
  alias REG_B_RMS_U12      : std_logic_vector(11 downto 0) is s_in_Port_034(11 downto 0);
  alias REG_B_OFFSET_U12   : std_logic_vector(11 downto 0) is s_out_Port_008(11 downto 0);
  alias REG_B_DECIM_U8     : std_logic_vector(7 downto 0) is s_out_Port_009(7 downto 0);
  alias REG_B_EN50         : std_logic_vector(0 downto 0) is s_out_Port_010(0 downto 0);
  alias REG_B_50_PEAK_U12  : std_logic_vector(11 downto 0) is s_out_Port_011(11 downto 0);
  alias REG_B_50_INTDLY_MS : std_logic_vector(19 downto 0) is s_out_Port_012(19 downto 0);
  alias REG_B_EN51         : std_logic_vector(0 downto 0) is s_out_Port_013(0 downto 0);
  alias REG_B_51_PEAK_U12  : std_logic_vector(11 downto 0) is s_out_Port_014(11 downto 0);

  -- C (0x0F..0x15)
  alias REG_C_RMS_U12      : std_logic_vector(11 downto 0) is s_in_Port_069(11 downto 0);
  alias REG_C_OFFSET_U12   : std_logic_vector(11 downto 0) is s_out_Port_015(11 downto 0);
  alias REG_C_DECIM_U8     : std_logic_vector(7 downto 0) is s_out_Port_016(7 downto 0);
  alias REG_C_EN50         : std_logic_vector(0 downto 0) is s_out_Port_017(0 downto 0);
  alias REG_C_50_PEAK_U12  : std_logic_vector(11 downto 0) is s_out_Port_018(11 downto 0);
  alias REG_C_50_INTDLY_MS : std_logic_vector(19 downto 0) is s_out_Port_019(19 downto 0);
  alias REG_C_EN51         : std_logic_vector(0 downto 0) is s_out_Port_020(0 downto 0);
  alias REG_C_51_PEAK_U12  : std_logic_vector(11 downto 0) is s_out_Port_021(11 downto 0);

  -- N (0x16..0x1C)
  alias REG_N_RMS_U12      : std_logic_vector(11 downto 0) is s_in_Port_070(11 downto 0);
  alias REG_N_OFFSET_U12   : std_logic_vector(11 downto 0) is s_out_Port_022(11 downto 0);
  alias REG_N_DECIM_U8     : std_logic_vector(7 downto 0) is s_out_Port_023(7 downto 0);
  alias REG_N_EN50         : std_logic_vector(0 downto 0) is s_out_Port_024(0 downto 0);
  alias REG_N_50_PEAK_U12  : std_logic_vector(11 downto 0) is s_out_Port_025(11 downto 0);
  alias REG_N_50_INTDLY_MS : std_logic_vector(19 downto 0) is s_out_Port_026(19 downto 0);
  alias REG_N_EN51         : std_logic_vector(0 downto 0) is s_out_Port_027(0 downto 0);
  alias REG_N_51_PEAK_U12  : std_logic_vector(11 downto 0) is s_out_Port_028(11 downto 0);

  -- LUT (0x1D..0x1F)
  alias REG_LUT_ADDR    : std_logic_vector(11 downto 0) is s_out_Port_029(11 downto 0); -- 0..2047
  alias REG_LUT_DATA    : std_logic_vector(19 downto 0) is s_out_Port_030(19 downto 0); -- 20b
  alias REG_LUT_WR_EN_A : std_logic_vector(0 downto 0) is s_out_Port_031(0 downto 0); -- [0]=A,[1]=B,[2]=C,[3]=N
  alias REG_LUT_WR_EN_B : std_logic_vector(0 downto 0) is s_out_Port_031(1 downto 1); -- [0]=A,[1]=B,[2]=C,[3]=N
  alias REG_LUT_WR_EN_C : std_logic_vector(0 downto 0) is s_out_Port_031(2 downto 2); -- [0]=A,[1]=B,[2]=C,[3]=N
  alias REG_LUT_WR_EN_N : std_logic_vector(0 downto 0) is s_out_Port_031(3 downto 3); -- [0]=A,[1]=B,[2]=C,[3]=N

  -- Tensão Fase C (VC = aux4) – OFFSET/DECIMAÇÃO + 27/59 (stg1/stg2)
  alias REG_VC_OFFSET_U12 : std_logic_vector(11 downto 0) is s_out_Port_035(11 downto 0);
  alias REG_VC_DECIM_U8   : std_logic_vector(7 downto 0) is s_out_Port_036(7 downto 0);
  alias REG_VC_RMS_U12      : std_logic_vector(11 downto 0) is s_in_Port_134(11 downto 0);
  -- Enables das proteções 27/59 da fase C (VC)
  alias REG_VC_EN27_STG1 : std_logic_vector(0 downto 0) is s_out_Port_037(0 downto 0);
  alias REG_VC_EN27_STG2 : std_logic_vector(0 downto 0) is s_out_Port_037(1 downto 1);
  alias REG_VC_EN59_STG1 : std_logic_vector(0 downto 0) is s_out_Port_037(2 downto 2);
  alias REG_VC_EN59_STG2 : std_logic_vector(0 downto 0) is s_out_Port_037(3 downto 3);
  -- 27 – Stage 1 (fase VC)
  alias REG_VC_27_STG1_PEAK_U12  : std_logic_vector(11 downto 0) is s_out_Port_038(11 downto 0);
  alias REG_VC_27_STG1_INTDLY_MS : std_logic_vector(19 downto 0) is s_out_Port_039(19 downto 0);
  -- 27 – Stage 2 (fase VC)
  alias REG_VC_27_STG2_PEAK_U12  : std_logic_vector(11 downto 0) is s_out_Port_040(11 downto 0);
  alias REG_VC_27_STG2_INTDLY_MS : std_logic_vector(19 downto 0) is s_out_Port_041(19 downto 0);
  -- 59 – Stage 1 (fase VC)
  alias REG_VC_59_STG1_PEAK_U12  : std_logic_vector(11 downto 0) is s_out_Port_042(11 downto 0);
  alias REG_VC_59_STG1_INTDLY_MS : std_logic_vector(19 downto 0) is s_out_Port_043(19 downto 0);
  -- 59 – Stage 2 (fase VC)
  alias REG_VC_59_STG2_PEAK_U12  : std_logic_vector(11 downto 0) is s_out_Port_044(11 downto 0);
  alias REG_VC_59_STG2_INTDLY_MS : std_logic_vector(19 downto 0) is s_out_Port_045(19 downto 0);

  -- Tensão Fase B (VB = aux5) – OFFSET/DECIMAÇÃO + 27/59 (stg1/stg2)
  alias REG_VB_OFFSET_U12 : std_logic_vector(11 downto 0) is s_out_Port_046(11 downto 0);
  alias REG_VB_DECIM_U8   : std_logic_vector(7 downto 0) is s_out_Port_047(7 downto 0);
  alias REG_VB_RMS_U12      : std_logic_vector(11 downto 0) is s_in_Port_135(11 downto 0);

  -- Enables das proteções 27/59 da fase B (VB)
  alias REG_VB_EN27_STG1 : std_logic_vector(0 downto 0) is s_out_Port_048(0 downto 0);
  alias REG_VB_EN27_STG2 : std_logic_vector(0 downto 0) is s_out_Port_048(1 downto 1);
  alias REG_VB_EN59_STG1 : std_logic_vector(0 downto 0) is s_out_Port_048(2 downto 2);
  alias REG_VB_EN59_STG2 : std_logic_vector(0 downto 0) is s_out_Port_048(3 downto 3);
  -- 27 – Stage 1 (fase B)
  alias REG_VB_27_STG1_PEAK_U12  : std_logic_vector(11 downto 0) is s_out_Port_049(11 downto 0);
  alias REG_VB_27_STG1_INTDLY_MS : std_logic_vector(19 downto 0) is s_out_Port_050(19 downto 0);
  -- 27 – Stage 2 (fase B)
  alias REG_VB_27_STG2_PEAK_U12  : std_logic_vector(11 downto 0) is s_out_Port_051(11 downto 0);
  alias REG_VB_27_STG2_INTDLY_MS : std_logic_vector(19 downto 0) is s_out_Port_052(19 downto 0);
  -- 59 – Stage 1 (fase B)
  alias REG_VB_59_STG1_PEAK_U12  : std_logic_vector(11 downto 0) is s_out_Port_053(11 downto 0);
  alias REG_VB_59_STG1_INTDLY_MS : std_logic_vector(19 downto 0) is s_out_Port_054(19 downto 0);
  -- 59 – Stage 2 (fase B)
  alias REG_VB_59_STG2_PEAK_U12  : std_logic_vector(11 downto 0) is s_out_Port_055(11 downto 0);
  alias REG_VB_59_STG2_INTDLY_MS : std_logic_vector(19 downto 0) is s_out_Port_056(19 downto 0);
  -- Tensão Fase A (VA = aux6) – OFFSET/DECIMAÇÃO + 27/59 (stg1/stg2)
  alias REG_VA_OFFSET_U12 : std_logic_vector(11 downto 0) is s_out_Port_057(11 downto 0);
  alias REG_VA_DECIM_U8   : std_logic_vector(7 downto 0) is s_out_Port_058(7 downto 0);
  alias REG_VA_RMS_U12      : std_logic_vector(11 downto 0) is s_in_Port_136(11 downto 0);
  -- Enables das proteções 27/59 da fase A (VA)
  alias REG_VA_EN27_STG1 : std_logic_vector(0 downto 0) is s_out_Port_059(0 downto 0);
  alias REG_VA_EN27_STG2 : std_logic_vector(0 downto 0) is s_out_Port_059(1 downto 1);
  alias REG_VA_EN59_STG1 : std_logic_vector(0 downto 0) is s_out_Port_059(2 downto 2);
  alias REG_VA_EN59_STG2 : std_logic_vector(0 downto 0) is s_out_Port_059(3 downto 3);
  -- 27 – Stage 1 (fase C)
  alias REG_VA_27_STG1_PEAK_U12  : std_logic_vector(11 downto 0) is s_out_Port_060(11 downto 0);
  alias REG_VA_27_STG1_INTDLY_MS : std_logic_vector(19 downto 0) is s_out_Port_061(19 downto 0);
  -- 27 – Stage 2 (fase C)
  alias REG_VA_27_STG2_PEAK_U12  : std_logic_vector(11 downto 0) is s_out_Port_062(11 downto 0);
  alias REG_VA_27_STG2_INTDLY_MS : std_logic_vector(19 downto 0) is s_out_Port_063(19 downto 0);
  -- 59 – Stage 1 (fase C)
  alias REG_VA_59_STG1_PEAK_U12  : std_logic_vector(11 downto 0) is s_out_Port_064(11 downto 0);
  alias REG_VA_59_STG1_INTDLY_MS : std_logic_vector(19 downto 0) is s_out_Port_065(19 downto 0);
  -- 59 – Stage 2 (fase C)
  alias REG_VA_59_STG2_PEAK_U12  : std_logic_vector(11 downto 0) is s_out_Port_066(11 downto 0);
  alias REG_VA_59_STG2_INTDLY_MS : std_logic_vector(19 downto 0) is s_out_Port_067(19 downto 0);

  

  alias REG_BOOLEAN_SEL_0         : std_logic_vector(5 downto 0) is s_out_Port_098(5 downto 0);
  alias REG_BOOLEAN_SEL_1         : std_logic_vector(5 downto 0) is s_out_Port_099(5 downto 0);
  alias REG_BOOLEAN_SEL_2         : std_logic_vector(5 downto 0) is s_out_Port_100(5 downto 0);
  alias REG_BOOLEAN_SEL_3         : std_logic_vector(5 downto 0) is s_out_Port_101(5 downto 0);
  alias REG_BOOLEAN_SEL_4         : std_logic_vector(5 downto 0) is s_out_Port_102(5 downto 0);
  alias REG_BOOLEAN_SEL_5         : std_logic_vector(5 downto 0) is s_out_Port_103(5 downto 0);
  alias REG_BOOLEAN_SEL_6         : std_logic_vector(5 downto 0) is s_out_Port_104(5 downto 0);
  alias REG_BOOLEAN_SEL_7         : std_logic_vector(5 downto 0) is s_out_Port_105(5 downto 0);
  alias REG_BOOLEAN_SEL_SIGNALS   : std_logic_vector(7 downto 0) is s_out_Port_106(7 downto 0);
  alias REG_BOOLEAN_BLOCK_0       : std_logic_vector(31 downto 0) is s_out_Port_107(31 downto 0);
  alias REG_BOOLEAN_BLOCK_1       : std_logic_vector(31 downto 0) is s_out_Port_108(31 downto 0);
  alias REG_BOOLEAN_BLOCK_2       : std_logic_vector(31 downto 0) is s_out_Port_109(31 downto 0);
  alias REG_BOOLEAN_BLOCK_3       : std_logic_vector(31 downto 0) is s_out_Port_110(31 downto 0);
  alias REG_BOOLEAN_BLOCK_4       : std_logic_vector(31 downto 0) is s_out_Port_111(31 downto 0);
  alias REG_BOOLEAN_BLOCK_5       : std_logic_vector(31 downto 0) is s_out_Port_112(31 downto 0);
  alias REG_BOOLEAN_BLOCK_6       : std_logic_vector(31 downto 0) is s_out_Port_113(31 downto 0);
  alias REG_BOOLEAN_BLOCK_7       : std_logic_vector(31 downto 0) is s_out_Port_114(31 downto 0);
  alias REG_BOOLEAN_ALL_SIGNALS_0 : std_logic_vector(31 downto 0) is s_out_Port_115(31 downto 0);
  alias REG_BOOLEAN_ALL_SIGNALS_1 : std_logic_vector(31 downto 0) is s_out_Port_116(31 downto 0);

  alias REG_46_S1_E1_I2PU_U12 : std_logic_vector(11 downto 0) is s_out_Port_071(11 downto 0);
  alias REG_46_S1_E2_I2PU_U12 : std_logic_vector(11 downto 0) is s_out_Port_072(11 downto 0);
  alias REG_46_S1_E1_DLY_U20  : std_logic_vector(19 downto 0) is s_out_Port_073(19 downto 0);
  alias REG_46_S1_EN          : std_logic is s_out_Port_074(0);
  alias REG_46_S1_E1_TRIP     : std_logic is s_in_Port_075(0);
  alias REG_46_S1_E2_TRIP     : std_logic is s_in_Port_075(1);
  alias REG_46_S1_TRIP        : std_logic is s_in_Port_075(2);
  alias REG_46_S1_E1_ALARM    : std_logic is s_in_Port_075(3);
  alias REG_46_S1_E2_ALARM    : std_logic is s_in_Port_075(4);

  alias REG_46_S1_LUT_WR_EN  : std_logic_vector(0 downto 0) is s_out_Port_076(0 downto 0);
  alias REG_46_S1_LUT_ADDR   : std_logic_vector(11 downto 0) is s_out_Port_077(11 downto 0);
  alias REG_46_S1_LUT_DATA   : std_logic_vector(19 downto 0) is s_out_Port_078(19 downto 0);
  alias REG_46_S1_LUT_DOUTB  : std_logic_vector(19 downto 0) is s_in_Port_079(19 downto 0);
  -- alias REG_46Temp_STG1_TRIP     : std_logic_vector(0 downto 0) is s_in_Port_080(0 downto 0);

  alias REG_47_STG1_VPU_U11   : std_logic_vector(11 downto 0) is s_out_Port_081(11 downto 0);
  alias REG_47_STG1_VUF_U11   : std_logic_vector(11 downto 0) is s_in_Port_085(11 downto 0);
  alias REG_47_STG1_TIME_MS   : std_logic_vector(19 downto 0) is s_in_Port_087(19 downto 0);
  alias REG_47_STG1_TRIP      : std_logic_vector(0 downto 0) is s_in_Port_088(0 downto 0);
  alias REG_47_STG1_EN        : std_logic_vector(0 downto 0) is s_out_Port_082(0 downto 0);
  alias REG_47_STG1_LUT_WR_EN : std_logic_vector(0 downto 0) is s_out_Port_083(0 downto 0);
  alias REG_47_STG1_LUT_ADDR  : std_logic_vector(11 downto 0) is s_out_Port_084(11 downto 0);
  alias REG_47_STG1_LUT_DATA  : std_logic_vector(19 downto 0) is s_out_Port_086(19 downto 0);

  alias REG_SEQ0_ABS   : std_logic_vector(31 downto 0) is s_in_Port_089(31 downto 0);
  alias REG_SEQ0_PHASE : std_logic_vector(15 downto 0) is s_in_Port_090(15 downto 0);
  alias REG_SEQ0_RMS   : std_logic_vector(31 downto 0) is s_in_Port_091(31 downto 0);

  alias REG_SEQ1_ABS   : std_logic_vector(31 downto 0) is s_in_Port_092(31 downto 0);
  alias REG_SEQ1_PHASE : std_logic_vector(15 downto 0) is s_in_Port_093(15 downto 0);
  alias REG_SEQ1_RMS   : std_logic_vector(31 downto 0) is s_in_Port_094(31 downto 0);

  alias REG_SEQ2_ABS   : std_logic_vector(31 downto 0) is s_in_Port_095(31 downto 0);
  alias REG_SEQ2_PHASE : std_logic_vector(15 downto 0) is s_in_Port_096(15 downto 0);
  alias REG_SEQ2_RMS   : std_logic_vector(31 downto 0) is s_in_Port_097(31 downto 0);

  alias REG_GLOBAL_TRIP : std_logic is s_in_Port_125(0);
  alias REG_BOOL_TRIP   : std_logic is s_in_Port_126(0);
  alias REG_FORCE_GLOBAL_TRIP: std_logic is s_out_Port_127(0);

  alias REG_RELAY_CH0_EN : std_logic is s_out_Port_117(0);
  alias REG_RELAY_CH1_EN : std_logic is s_out_Port_118(0);
  alias REG_RELAY_CH2_EN : std_logic is s_out_Port_119(0);
  alias REG_RELAY_CH3_EN : std_logic is s_out_Port_120(0);
  alias REG_RELAY_CH4_EN : std_logic is s_out_Port_121(0);
  alias REG_RELAY_CH5_EN : std_logic is s_out_Port_122(0);
  alias REG_RELAY_CH6_EN : std_logic is s_out_Port_123(0);

  -- Aliases da proteção 81 (configuração comum para A/B/C)
	alias REG_81_PICKUP_UNDER_E1_MHZ : std_logic_vector(31 downto 0) is s_out_Port_137;
	alias REG_81_PICKUP_OVER_E1_MHZ  : std_logic_vector(31 downto 0) is s_out_Port_138;
	alias REG_81_MARGIN_E2_MHZ       : std_logic_vector(31 downto 0) is s_out_Port_139;
	alias REG_81_HYST_MHZ            : std_logic_vector(31 downto 0) is s_out_Port_140;
	alias REG_81_DELAY_E1_MS         : std_logic_vector(19 downto 0) is s_out_Port_141(19 downto 0);
	alias REG_81_DELAY_E2_MS         : std_logic_vector(19 downto 0) is s_out_Port_142(19 downto 0);
	alias REG_81_INIT_TIME_MS 		 : std_logic_vector(19 downto 0) is s_out_Port_143(19 downto 0);
  alias REG_81_EN                  : std_logic_vector(0 downto 0)  is s_out_Port_143(20 downto 20);

  -- Aliases de Monitoramento 81
  -- Fase A
  alias REG_81_A_ALARM_E1 : std_logic is s_in_Port_144(0);
  alias REG_81_A_ALARM_E2 : std_logic is s_in_Port_144(1);
  alias REG_81_A_TRIP_E1  : std_logic is s_in_Port_144(2);
  alias REG_81_A_TRIP_E2  : std_logic is s_in_Port_144(3);
  alias REG_81_A_TRIP     : std_logic is s_in_Port_144(4);
  alias REG_81_A_FREQ_DIFF_MHZ : std_logic_vector is s_in_Port_145;

  -- Fase B
  alias REG_81_B_ALARM_E1 : std_logic is s_in_Port_144(5);
  alias REG_81_B_ALARM_E2 : std_logic is s_in_Port_144(6);
  alias REG_81_B_TRIP_E1  : std_logic is s_in_Port_144(7);
  alias REG_81_B_TRIP_E2  : std_logic is s_in_Port_144(8);
  alias REG_81_B_TRIP     : std_logic is s_in_Port_144(9);
  alias REG_81_B_FREQ_DIFF_MHZ : std_logic_vector is s_in_Port_146;

  -- Fase C
  alias REG_81_C_ALARM_E1 : std_logic is s_in_Port_144(10);
  alias REG_81_C_ALARM_E2 : std_logic is s_in_Port_144(11);
  alias REG_81_C_TRIP_E1  : std_logic is s_in_Port_144(12);
  alias REG_81_C_TRIP_E2  : std_logic is s_in_Port_144(13);
  alias REG_81_C_TRIP     : std_logic is s_in_Port_144(14);
  alias REG_81_C_FREQ_DIFF_MHZ : std_logic_vector is s_in_Port_147;

   
	-- Aliases da proteção 81R (configuração comum para A/B/C)
	alias REG_81R_PICKUP_E1_MHZ_WIN : std_logic_vector(31 downto 0) is s_out_Port_148;
	alias REG_81R_PICKUP_E2_MHZ_WIN : std_logic_vector(31 downto 0) is s_out_Port_149;
	alias REG_81R_HYST_MHZ_WIN      : std_logic_vector(31 downto 0) is s_out_Port_150;
	alias REG_81R_DELAY_E1_MS       : std_logic_vector(19 downto 0) is s_out_Port_151(19 downto 0);
	alias REG_81R_DELAY_E2_MS       : std_logic_vector(19 downto 0) is s_out_Port_152(19 downto 0);
	alias REG_81R_INIT_TIME_MS      : std_logic_vector(19 downto 0) is s_out_Port_153(19 downto 0);
	alias REG_81R_EN                : std_logic_vector(0 downto 0)  is s_out_Port_153(20 downto 20);

  -- Monitoramento 81R
  -- Fase A
  alias REG_81R_A_ALARM_E1 : std_logic is s_in_Port_154(0);
  alias REG_81R_A_ALARM_E2 : std_logic is s_in_Port_154(1);
  alias REG_81R_A_TRIP_E1  : std_logic is s_in_Port_154(2);
  alias REG_81R_A_TRIP_E2  : std_logic is s_in_Port_154(3);
  alias REG_81R_A_TRIP     : std_logic is s_in_Port_154(4);

  -- Fase B
  alias REG_81R_B_ALARM_E1 : std_logic is s_in_Port_154(5);
  alias REG_81R_B_ALARM_E2 : std_logic is s_in_Port_154(6);
  alias REG_81R_B_TRIP_E1  : std_logic is s_in_Port_154(7);
  alias REG_81R_B_TRIP_E2  : std_logic is s_in_Port_154(8);
  alias REG_81R_B_TRIP     : std_logic is s_in_Port_154(9);

  -- Fase C
  alias REG_81R_C_ALARM_E1 : std_logic is s_in_Port_154(10);
  alias REG_81R_C_ALARM_E2 : std_logic is s_in_Port_154(11);
  alias REG_81R_C_TRIP_E1  : std_logic is s_in_Port_154(12);
  alias REG_81R_C_TRIP_E2  : std_logic is s_in_Port_154(13);
  alias REG_81R_C_TRIP     : std_logic is s_in_Port_154(14); 
    
  -- Monitoramento Analógico 81R (Derivada de Frequência / ROCOF)
  -- Fase A
  alias REG_81R_A_ROCOF : std_logic_vector is s_in_Port_155;

  -- Fase B
  alias REG_81R_B_ROCOF : std_logic_vector is s_in_Port_156;

  -- Fase C
  alias REG_81R_C_ROCOF : std_logic_vector is s_in_Port_157;

  alias REG_RGB_LED     : std_logic_vector(2 downto 0) is s_out_Port_158(2 downto 0);

  alias REG_A_CALIB_OFFSET  : STD_LOGIC_VECTOR(11 downto 0) is s_in_Port_159(11 downto 0);
  alias REG_B_CALIB_OFFSET  : STD_LOGIC_VECTOR(11 downto 0) is s_in_Port_160(11 downto 0);
  alias REG_C_CALIB_OFFSET  : STD_LOGIC_VECTOR(11 downto 0) is s_in_Port_161(11 downto 0);
  alias REG_N_CALIB_OFFSET  : STD_LOGIC_VECTOR(11 downto 0) is s_in_Port_162(11 downto 0);
  alias REG_VA_CALIB_OFFSET : STD_LOGIC_VECTOR(11 downto 0) is s_in_Port_163(11 downto 0);
  alias REG_VB_CALIB_OFFSET : STD_LOGIC_VECTOR(11 downto 0) is s_in_Port_164(11 downto 0);
  alias REG_VC_CALIB_OFFSET : STD_LOGIC_VECTOR(11 downto 0) is s_in_Port_165(11 downto 0);

  -- 
  alias REG_A_LUT_DATA_OUT : STD_LOGIC_VECTOR(19 downto 0) is s_in_Port_128(19 downto 0);


  -- =========================
  -- Blink (1 Hz) signals
  -- =========================
  -- signal counter         : unsigned(25 downto 0)        := (others => '0');
  -- signal blink           : std_logic                    := '0';
  -- constant ONE_SEC_COUNT : unsigned(25 downto 0)        := to_unsigned(50_000_000 - 1, 26);
  -- signal led_reg         : std_logic_vector(3 downto 0) := (others => '0');
  signal s_GlobalTrip   : std_logic := '0';
  signal s_relay_ch0_out : std_logic                     := '0';
  signal s_relay_ch1_out : std_logic                     := '0';
  signal s_relay_ch2_out : std_logic                     := '0';
  signal s_relay_ch3_out : std_logic                     := '0';
  signal s_relay_ch4_out : std_logic                     := '0';
  signal s_relay_ch5_out : std_logic                     := '0';
  signal s_relay_ch6_out : std_logic                     := '0';
  
  ------------------------------------------------------------------------------
-- Atributos para não remover registros e componentes na parte de otimizacaao
------------------------------------------------------------------------------
  
  attribute  DONT_TOUCH : string;
  attribute  KEEP       : string;
  --
  --
  --attribute keep       of s_sq_reg            : signal is "true";
  --attribute keep       of s_rms               : signal is "true";
  --attribute keep       of s_rms_valid         : signal is "true";
  --attribute keep       of s_rms_aux_2         : signal is "true";
  --attribute keep       of s_rms_aux_2_valid   : signal is "true";
  --attribute keep       of s_rms_aux_3         : signal is "true";
  --attribute keep       of s_rms_aux_3_valid   : signal is "true";
  --attribute keep       of s_rms_aux_4         : signal is "true";
  --attribute keep       of s_rms_aux_4_valid   : signal is "true";
  --attribute keep       of s_rms_aux_5         : signal is "true";
  --attribute keep       of s_rms_aux_5_valid   : signal is "true";
  --attribute keep       of s_rms_aux_6         : signal is "true";
  --attribute keep       of s_rms_aux_6_valid   : signal is "true";
  --attribute keep       of s_rms_aux_7         : signal is "true";
  --attribute keep       of s_rms_aux_7_valid   : signal is "true";
  --attribute keep       of s_rms_aux_8         : signal is "true";
  --attribute keep       of s_rms_aux_8_valid   : signal is "true";
  --attribute keep       of s_rms_aux_9         : signal is "true";
  --attribute keep       of s_rms_aux_9_valid   : signal is "true";
  --attribute keep       of s_rms_aux_10        : signal is "true";
  --attribute keep       of s_rms_aux_10_valid  : signal is "true";


attribute KEEP of s_46_s1_rst : signal is "true";
attribute KEEP of s_seq2_abs : signal is "true";
attribute KEEP of s_seq_valid : signal is "true";
attribute KEEP of s_46_s1_vio_e1_i2pu : signal is "true";
attribute KEEP of s_46_s1_vio_e2_i2pu : signal is "true";
attribute KEEP of s_46_s1_vio_e1_dly : signal is "true";
attribute KEEP of s_46_s1_ram_addr : signal is "true";
attribute KEEP of s_46_s1_ram_rd_req : signal is "true";
attribute KEEP of s_46_s1_bram_douta : signal is "true";
attribute KEEP of s_46_s1_time_ms : signal is "true";
attribute KEEP of s_46_s1_e1_time_cnt : signal is "true";
attribute KEEP of s_46_s1_e1_alarm : signal is "true";
attribute KEEP of s_46_s1_e2_alarm : signal is "true";
attribute KEEP of s_46_s1_e1_trip : signal is "true";
attribute KEEP of s_46_s1_e2_trip : signal is "true";
attribute KEEP of s_46_s1_trip : signal is "true";
attribute KEEP of s_46_s1_vio_e1_en : signal is "true";
attribute KEEP of REG_46_S1_LUT_WR_EN : signal is "true";
attribute KEEP of REG_46_S1_LUT_ADDR : signal is "true";
attribute KEEP of REG_46_S1_LUT_DATA : signal is "true";
attribute KEEP of REG_46_S1_LUT_DOUTB : signal is "true";
attribute KEEP of s_46_s1_i2_abs_u12 : signal is "true";
attribute KEEP of s_46_s1_ram_target_ms : signal is "true";


attribute DONT_TOUCH of s_46_s1_rst : signal is "true";
attribute DONT_TOUCH of s_seq2_abs : signal is "true";
attribute DONT_TOUCH of s_seq_valid : signal is "true";
attribute DONT_TOUCH of s_46_s1_vio_e1_i2pu : signal is "true";
attribute DONT_TOUCH of s_46_s1_vio_e2_i2pu : signal is "true";
attribute DONT_TOUCH of s_46_s1_vio_e1_dly : signal is "true";
attribute DONT_TOUCH of s_46_s1_ram_addr : signal is "true";
attribute DONT_TOUCH of s_46_s1_ram_rd_req : signal is "true";
attribute DONT_TOUCH of s_46_s1_bram_douta : signal is "true";
attribute DONT_TOUCH of s_46_s1_time_ms : signal is "true";
attribute DONT_TOUCH of s_46_s1_e1_time_cnt : signal is "true";
attribute DONT_TOUCH of s_46_s1_e1_alarm : signal is "true";
attribute DONT_TOUCH of s_46_s1_e2_alarm : signal is "true";
attribute DONT_TOUCH of s_46_s1_e1_trip : signal is "true";
attribute DONT_TOUCH of s_46_s1_e2_trip : signal is "true";
attribute DONT_TOUCH of s_46_s1_trip : signal is "true";
attribute DONT_TOUCH of s_46_s1_vio_e1_en : signal is "true";
attribute DONT_TOUCH of REG_46_S1_LUT_WR_EN : signal is "true";
attribute DONT_TOUCH of REG_46_S1_LUT_ADDR : signal is "true";
attribute DONT_TOUCH of REG_46_S1_LUT_DATA : signal is "true";
attribute DONT_TOUCH of REG_46_S1_LUT_DOUTB : signal is "true";
attribute DONT_TOUCH of s_46_s1_i2_abs_u12 : signal is "true";
attribute DONT_TOUCH of s_46_s1_ram_target_ms : signal is "true";

  
  attribute KEEP of s_vaux0_decim_s12_valid : signal is "true";
  attribute KEEP of s_vaux1_decim_s12_valid : signal is "true";
  attribute KEEP of s_vaux2_decim_s12_valid : signal is "true";
  attribute KEEP of s_vaux0_decim_s12 : signal is "true";
  attribute KEEP of s_vaux1_decim_s12 : signal is "true";
  attribute KEEP of s_vaux2_decim_s12 : signal is "true";
  
  attribute DONT_TOUCH of s_vaux0_decim_s12_valid : signal is "true";
  attribute DONT_TOUCH of s_vaux1_decim_s12_valid : signal is "true";
  attribute DONT_TOUCH of s_vaux2_decim_s12_valid : signal is "true";
  attribute DONT_TOUCH of s_vaux0_decim_s12 : signal is "true";
  attribute DONT_TOUCH of s_vaux1_decim_s12 : signal is "true";
  attribute DONT_TOUCH of s_vaux2_decim_s12 : signal is "true";

  attribute KEEP of s_rms_aux_0_valid : signal is "true";
  attribute KEEP of s_rms_aux_1_valid : signal is "true";
  attribute KEEP of s_rms_aux_0 : signal is "true";
  attribute KEEP of s_rms_aux_1 : signal is "true";
  attribute DONT_TOUCH of s_rms_aux_0_valid : signal is "true";
  attribute DONT_TOUCH of s_rms_aux_1_valid : signal is "true";
  attribute DONT_TOUCH of s_rms_aux_0 : signal is "true";
  attribute DONT_TOUCH of s_rms_aux_1 : signal is "true";
  
  --attribute KEEP of s_ovalid : signal is "true";
  --attribute KEEP of s_sine_out : signal is "true";
  
  attribute KEEP of s_phase_A        : signal is "true";
  attribute KEEP of s_valid_phase_A  : signal is "true";
  attribute KEEP of s_phase_B        : signal is "true";
  attribute KEEP of s_valid_phase_B  : signal is "true";
  attribute KEEP of s_phase_C        : signal is "true";
  attribute KEEP of s_valid_phase_C  : signal is "true";
  attribute KEEP of sRstVio  	     : signal is "true";
  
  
  
  --Unified fasor
  attribute KEEP of s_ph_valid_phaseA   : signal is "true";
  attribute KEEP of s_ph_Real_phaseA    : signal is "true";
  attribute KEEP of s_ph_Imag_phaseA    : signal is "true";
  attribute KEEP of s_ph_RMS_phaseA     : signal is "true";
  attribute KEEP of s_ph_phase_phaseA   : signal is "true";
  attribute KEEP of s_ph_valid_phaseB   : signal is "true";
  attribute KEEP of s_ph_Real_phaseB    : signal is "true";
  attribute KEEP of s_ph_Imag_phaseB    : signal is "true";
  attribute KEEP of s_ph_RMS_phaseB     : signal is "true";
  attribute KEEP of s_ph_phase_phaseB   : signal is "true";
  attribute KEEP of s_ph_valid_phaseC   : signal is "true";
  attribute KEEP of s_ph_Real_phaseC    : signal is "true";
  attribute KEEP of s_ph_Imag_phaseC    : signal is "true";
  attribute KEEP of s_ph_RMS_phaseC     : signal is "true";
  attribute KEEP of s_ph_phase_phaseC   : signal is "true";
  ---
  attribute KEEP of s_valid_seq         : signal is "true";	
  attribute KEEP of s_Re_seq0           : signal is "true";
  attribute KEEP of s_Im_seq0 	        : signal is "true";
  attribute KEEP of s_Re_seq1           : signal is "true";
  attribute KEEP of s_Im_seq1 	        : signal is "true";
  attribute KEEP of s_Re_seq2           : signal is "true";
  attribute KEEP of s_Im_seq2           : signal is "true";
  
  
  
  
  
  
  attribute DONT_TOUCH of s_ph_valid_phaseA   : signal is "true";
  attribute DONT_TOUCH of s_ph_Real_phaseA    : signal is "true";
  attribute DONT_TOUCH of s_ph_Imag_phaseA    : signal is "true";
  attribute DONT_TOUCH of s_ph_RMS_phaseA     : signal is "true";
  attribute DONT_TOUCH of s_ph_phase_phaseA   : signal is "true";
  attribute DONT_TOUCH of s_ph_valid_phaseB   : signal is "true";
  attribute DONT_TOUCH of s_ph_Real_phaseB    : signal is "true";
  attribute DONT_TOUCH of s_ph_Imag_phaseB    : signal is "true";
  attribute DONT_TOUCH of s_ph_RMS_phaseB     : signal is "true";
  attribute DONT_TOUCH of s_ph_phase_phaseB   : signal is "true";
  attribute DONT_TOUCH of s_ph_valid_phaseC   : signal is "true";
  attribute DONT_TOUCH of s_ph_Real_phaseC    : signal is "true";
  attribute DONT_TOUCH of s_ph_Imag_phaseC    : signal is "true";
  attribute DONT_TOUCH of s_ph_RMS_phaseC     : signal is "true";
  attribute DONT_TOUCH of s_ph_phase_phaseC   : signal is "true";
  ---
  attribute DONT_TOUCH of s_valid_seq         : signal is "true";	
  attribute DONT_TOUCH of s_Re_seq0           : signal is "true";
  attribute DONT_TOUCH of s_Im_seq0 	      : signal is "true";
  attribute DONT_TOUCH of s_Re_seq1           : signal is "true";
  attribute DONT_TOUCH of s_Im_seq1 	      : signal is "true";
  attribute DONT_TOUCH of s_Re_seq2           : signal is "true";
  attribute DONT_TOUCH of s_Im_seq2           : signal is "true";
  
  
  
 --attribute KEEP of  s_seq_valid 		  	  : signal is "true";
 attribute KEEP of  s_seq0_re 		  		  : signal is "true";
 attribute KEEP of  s_seq0_im 		  		  : signal is "true";
 attribute KEEP of  s_seq0_abs    	  		  : signal is "true";
 attribute KEEP of  s_seq0_phase  	  		  : signal is "true";
 attribute KEEP of  s_seq0_rms    	  		  : signal is "true";
 attribute KEEP of  s_seq1_abs    	  		  : signal is "true";
 attribute KEEP of  s_seq1_phase  	  		  : signal is "true";
 attribute KEEP of  s_seq1_rms    	  		  : signal is "true";
 attribute KEEP of  s_seq1_re 		  		  : signal is "true";
 attribute KEEP of  s_seq1_im     	  		  : signal is "true";
 attribute KEEP of  s_seq2_re     	  		  : signal is "true";
 attribute KEEP of  s_seq2_im     	  		  : signal is "true";
 --attribute KEEP of  s_seq2_abs    	  		  : signal is "true";
 attribute KEEP of  s_seq2_phase  	  		  : signal is "true";
 attribute KEEP of  s_seq2_rms    	  		  : signal is "true"; 
  
  
  
 --attribute DONT_TOUCH of  s_seq_valid 		  	  : signal is "true"; 	
 attribute DONT_TOUCH of  s_seq0_re 		  : signal is "true";
 attribute DONT_TOUCH of  s_seq0_im 		  : signal is "true";
 attribute DONT_TOUCH of  s_seq0_abs    	  : signal is "true";
 attribute DONT_TOUCH of  s_seq0_phase  	  : signal is "true";
 attribute DONT_TOUCH of  s_seq0_rms    	  : signal is "true";
 attribute DONT_TOUCH of  s_seq1_abs    	  : signal is "true";
 attribute DONT_TOUCH of  s_seq1_phase  	  : signal is "true";
 attribute DONT_TOUCH of  s_seq1_rms    	  : signal is "true";
 attribute DONT_TOUCH of  s_seq1_re 		  : signal is "true";
 attribute DONT_TOUCH of  s_seq1_im     	  : signal is "true";
 attribute DONT_TOUCH of  s_seq2_re     	  : signal is "true";
 attribute DONT_TOUCH of  s_seq2_im     	  : signal is "true";
-- attribute DONT_TOUCH of  s_seq2_abs    	  : signal is "true";
 attribute DONT_TOUCH of  s_seq2_phase  	  : signal is "true";
 attribute DONT_TOUCH of  s_seq2_rms    	  : signal is "true";
 
 
 
 
 attribute KEEP of s_filter_DCH3_sample_in    		: signal is "true";
 attribute KEEP of s_filter_DCH3_sample_in_valid    : signal is "true";
 attribute KEEP of s_filter_DCH3_sample_valid 		: signal is "true";
 attribute KEEP of s_filter_DCH3_sample       		: signal is "true";
 attribute DONT_TOUCH of s_filter_DCH3_sample_in    	  : signal is "true";
 attribute DONT_TOUCH of s_filter_DCH3_sample_in_valid    : signal is "true";
 attribute DONT_TOUCH of s_filter_DCH3_sample_valid 	  : signal is "true";
 attribute DONT_TOUCH of s_filter_DCH3_sample       	  : signal is "true";
 
 
  
  attribute KEEP of s_filter2_DCH3_sample_valid 		: signal is "true";
  attribute KEEP of s_filter2_DCH3_sample       		: signal is "true";
  attribute DONT_TOUCH of s_filter2_DCH3_sample_valid 	: signal is "true";
  attribute DONT_TOUCH of s_filter2_DCH3_sample       	: signal is "true";
  attribute KEEP of s_siggen_dch3_valid 			: signal is "true";
  attribute KEEP of s_siggen_dch3_sample       		: signal is "true";
  attribute DONT_TOUCH of s_siggen_dch3_valid    	: signal is "true";
  attribute DONT_TOUCH of s_siggen_dch3_sample    	: signal is "true";
  attribute KEEP of s_rocofdf_dfreq_filt_mHz_A : signal is "true";
  attribute DONT_TOUCH of s_rocofdf_dfreq_filt_mHz_A : signal is "true";
  
  

  --attribute KEEP of s_freq_diff_valid                   : signal is "true";
  --attribute KEEP of s_freq_diff_dphi_q13                : signal is "true";
  --attribute KEEP of s_freq_diff_dtheta64_q13            : signal is "true";
  --attribute KEEP of s_freq_diff_dfreq_mHz               : signal is "true";
  --attribute DONT_TOUCH of s_freq_diff_valid             : signal is "true";
  --attribute DONT_TOUCH of s_freq_diff_dphi_q13          : signal is "true";
  --attribute DONT_TOUCH of s_freq_diff_dtheta64_q13      : signal is "true";
  --attribute DONT_TOUCH of s_freq_diff_dfreq_mHz         : signal is "true";
  

    attribute KEEP of s_trip_81_A                   : signal is "true";
    attribute DONT_TOUCH of s_trip_81_A             : signal is "true";
  
  
  -- Form Boolean logic
  attribute KEEP of s_InputBooleanBlock            		: signal is "true";
  attribute KEEP of s_ConfigBooleanBlock                : signal is "true";
  attribute DONT_TOUCH of s_InputBooleanBlock           : signal is "true";
  attribute DONT_TOUCH of s_ConfigBooleanBlock          : signal is "true";
  attribute keep       of s_all_signals : signal is "true";
  attribute dont_touch of s_all_signals : signal is "true";     
  attribute keep       of s_sel_s0 : signal is "true";
  attribute dont_touch of s_sel_s0 : signal is "true";     
  attribute keep       of s_sel_s1 : signal is "true";
  attribute dont_touch of s_sel_s1 : signal is "true";     
  attribute keep       of s_sel_s2 : signal is "true";
  attribute dont_touch of s_sel_s2 : signal is "true";   
  attribute keep       of s_sel_s3 : signal is "true";
  attribute dont_touch of s_sel_s3 : signal is "true";     
  attribute keep       of s_sel_s4 : signal is "true";
  attribute dont_touch of s_sel_s4 : signal is "true";     
  attribute keep       of s_sel_s5 : signal is "true";
  attribute dont_touch of s_sel_s5 : signal is "true";     
  attribute keep       of s_sel_s6 : signal is "true";
  attribute dont_touch of s_sel_s6 : signal is "true";  
  attribute keep       of s_sel_s7 : signal is "true";
  attribute dont_touch of s_sel_s7 : signal is "true";
  attribute keep       of s_Boolean_selected_s : signal is "true";
  attribute dont_touch of s_Boolean_selected_s : signal is "true";
  attribute keep       of s_Boolean_o_trip : signal is "true";
  attribute dont_touch of s_Boolean_o_trip : signal is "true";
  
  
  -- Alarmes
  attribute keep       of s_prot_81_faseA_alarm_e1 : signal is "true";
  attribute dont_touch of s_prot_81_faseA_alarm_e1 : signal is "true";
  
  attribute keep       of s_prot_81_faseA_alarm_e2 : signal is "true";
  attribute dont_touch of s_prot_81_faseA_alarm_e2 : signal is "true";
  
  -- Trips
  attribute keep       of s_prot_81_faseA_trip_e1 : signal is "true";
  attribute dont_touch of s_prot_81_faseA_trip_e1 : signal is "true";
  
  attribute keep       of s_prot_81_faseA_trip_e2 : signal is "true";
  attribute dont_touch of s_prot_81_faseA_trip_e2 : signal is "true";
  
  
  
  
  attribute KEEP of s_rocof_valid_A      : signal is "true";
  attribute KEEP of s_rocof_dphi_q13_A   : signal is "true";
  attribute KEEP of s_rocof_dfreq_mHz_A  : signal is "true";
  attribute KEEP of s_rocof_mHzps_A      : signal is "true";
  attribute KEEP of s_rocof_valid_B      : signal is "true";
  attribute KEEP of s_rocof_mHzps_B      : signal is "true";
  attribute KEEP of s_rocof_valid_C      : signal is "true";
  attribute KEEP of s_rocof_mHzps_C      : signal is "true";

  
  
  
  
  attribute DONT_TOUCH of s_rocof_valid_A      : signal is "true";
  attribute DONT_TOUCH of s_rocof_dphi_q13_A   : signal is "true";
  attribute DONT_TOUCH of s_rocof_dfreq_mHz_A  : signal is "true";
  attribute DONT_TOUCH of s_rocof_mHzps_A : signal is "true";
  attribute DONT_TOUCH of s_rocof_valid_B : signal is "true";
  attribute DONT_TOUCH of s_rocof_mHzps_B : signal is "true";
  attribute DONT_TOUCH of s_rocof_valid_C : signal is "true";
  attribute DONT_TOUCH of s_rocof_mHzps_C : signal is "true";
  
  
  -------------------------------------------------------------
  -- Debug - ROCOF a partir de dfreq em mHz - Fase A
  -------------------------------------------------------------
  attribute KEEP of s_rocofdf_valid_A          : signal is "true";
  attribute KEEP of s_rocofdf_diff_1samp_mHz_A : signal is "true";
  attribute KEEP of s_rocofdf_diff_win_mHz_A   : signal is "true";


  attribute DONT_TOUCH of s_rocofdf_valid_A          : signal is "true";
  attribute DONT_TOUCH of s_rocofdf_diff_1samp_mHz_A : signal is "true";
  attribute DONT_TOUCH of s_rocofdf_diff_win_mHz_A   : signal is "true";

  
  
  
  
  
  
    -- =========================
	-- ROCOF NEW - DEBUG Fase A
	-- =========================
	attribute KEEP of s_rocofnew_valid_A : signal is "TRUE";
	attribute DONT_TOUCH of s_rocofnew_valid_A : signal is "TRUE";
	attribute KEEP of s_rocofnew_dphi_A_q13 : signal is "TRUE";
	attribute DONT_TOUCH of s_rocofnew_dphi_A_q13 : signal is "TRUE";
	attribute KEEP of s_rocofnew_d2theta_A_q13 : signal is "TRUE";
	attribute DONT_TOUCH of s_rocofnew_d2theta_A_q13 : signal is "TRUE";
	attribute KEEP of s_rocofnew_d2theta_A_scaled : signal is "TRUE";
	attribute DONT_TOUCH of s_rocofnew_d2theta_A_scaled : signal is "TRUE";
	attribute KEEP of s_rocofnew_trip_A : signal is "TRUE";
	attribute DONT_TOUCH of s_rocofnew_trip_A : signal is "TRUE";
	attribute KEEP of s_rocofnew_d2theta_A_scaled_filt : signal is "TRUE";
    attribute DONT_TOUCH of s_rocofnew_d2theta_A_scaled_filt : signal is "TRUE";
	
	
	
	
	
  -------------------------------------------------------------
  -- Debug - Protecao ANSI 81R - Fase A
  -------------------------------------------------------------
  attribute KEEP of s_prot_81R_faseA_alarm_e1 : signal is "true";
  attribute KEEP of s_prot_81R_faseA_alarm_e2 : signal is "true";
  attribute KEEP of s_prot_81R_faseA_trip_e1  : signal is "true";
  attribute KEEP of s_prot_81R_faseA_trip_e2  : signal is "true";
  attribute KEEP of s_trip_81R_A              : signal is "true";
  attribute KEEP of s_rocofdf_abs_mHz_win_A   : signal is "true";

  attribute DONT_TOUCH of s_prot_81R_faseA_alarm_e1 : signal is "true";
  attribute DONT_TOUCH of s_prot_81R_faseA_alarm_e2 : signal is "true";
  attribute DONT_TOUCH of s_prot_81R_faseA_trip_e1  : signal is "true";
  attribute DONT_TOUCH of s_prot_81R_faseA_trip_e2  : signal is "true";
  attribute DONT_TOUCH of s_trip_81R_A              : signal is "true";
  attribute DONT_TOUCH of s_rocofdf_abs_mHz_win_A   : signal is "true";

  -------------------------------------------------------------
  -- Debug - Protecao ANSI 81R - Fases B e C
  -- Mantidos para facilitar expansao futura
  -------------------------------------------------------------
  attribute KEEP of s_trip_81R_B            : signal is "true";
  attribute KEEP of s_trip_81R_C            : signal is "true";
  attribute KEEP of s_rocofdf_abs_mHz_win_B : signal is "true";
  attribute KEEP of s_rocofdf_abs_mHz_win_C : signal is "true";
  attribute DONT_TOUCH of s_trip_81R_B            : signal is "true";
  attribute DONT_TOUCH of s_trip_81R_C            : signal is "true";
  attribute DONT_TOUCH of s_rocofdf_abs_mHz_win_B : signal is "true";
  attribute DONT_TOUCH of s_rocofdf_abs_mHz_win_C : signal is "true";
  
  
  

	
  
  ---- Para a RAM
  ----attribute dont_touch of inst_lut : label  is "true";
  --
  --
  ----BRAM
  --attribute mark_debug : string;
  --  
  ---- Processor
  --attribute keep 		of s_o_write_tri_o 		: signal is "true";
  --attribute keep 		of s_o_address_tri_o 	: signal is "true";
  --attribute keep 		of s_o_write_data_tri_o : signal is "true";	
  --attribute keep 		of s_o_read_tri_o 		: signal is "true";
  --attribute keep 		of s_i_readdata_tri_i 	: signal is "true";
  --
  --
  --
  ---- Para protecao 51/51N
  --attribute dont_touch of inst_prot_51_time_A        : label  is "true";
  --attribute dont_touch of inst_prot_51_time_B        : label  is "true";
  --attribute dont_touch of inst_prot_51_time_C        : label  is "true";
  --attribute keep of s_time_ms_51    	: signal is "true"; 
  --attribute keep of s_start_trip_51 	: signal is "true"; 
 ---- attribute keep of s_trip_51       	: signal is "true"; 
  --attribute dont_touch of inst_prot_51N_time        : label  is "true"; 
  --attribute keep of s_time_ms_51N    	: signal is "true"; 
  --attribute keep of s_start_trip_51N 	: signal is "true"; 
  --attribute keep of s_trip_51N       	: signal is "true"; 
  --
  ---- Core regs
  --attribute keep of  s_out_Port_000  	: signal is "true";
  --attribute keep of  s_out_Port_001  	: signal is "true";
  --attribute keep of  s_out_Port_002  	: signal is "true";
  --attribute keep of  s_out_Port_003  	: signal is "true";
  --attribute keep of  s_out_Port_004  	: signal is "true";
  --
  --
  --
  --  
  ---- Para xadc frontend
  --attribute dont_touch of inst_adc        : label  is "true";
  --attribute keep       of s_temp_data  : signal is "true";
  --attribute keep       of s_temp_valid : signal is "true";
  --attribute keep       of s_vaux0_data : signal is "true";
  --attribute keep       of s_vaux0_valid: signal is "true";
  --attribute keep       of s_vaux1_data : signal is "true";
  --attribute keep       of s_vaux1_valid: signal is "true";
  --attribute keep       of s_vaux2_data : signal is "true";
  --attribute keep       of s_vaux2_valid: signal is "true";
  --attribute keep       of s_vaux3_data : signal is "true";
  --attribute keep       of s_vaux3_valid: signal is "true";

begin
  ---------------------------------------------------
  -- sRst active 1 or by VIO software reset (probe 24)
  ----------------------------------------------------

  sRst <= not(sRstn) or sRstVio(0) or REG_SOFTRESET(0) or not(s_Locked) ;
  

  -------------------
  -- Instancia do PLL
  -------------------
  inst_pll : clk_wiz_0
  port map
  (
    -- Clock in ports
    clk_in1 => iClk,
    resetn  => '1',
    -- Clock out ports  
    clk_out1 => s_clk1,
    clk_out2 => s_clk2,
    clk_out3 => open,
    locked   => s_Locked
  );

  ---------------------
  -- Instancia processor
  ----------------------
  inst_processor : GOD_wrapper
  port map
  (
    Clk         => s_clk1,
    reset_rtl_0 => sRstn,
    --PIO for WR/RD CoreRegs
    o_write_tri_o      => s_o_write_tri_o,
    o_address_tri_o    => s_o_address_tri_o,
    o_write_data_tri_o => s_o_write_data_tri_o,
    o_read_tri_o       => s_o_read_tri_o,
    i_readdata_tri_i   => s_i_readdata_tri_i,
    DDR_addr           => DDR_addr,
    DDR_ba             => DDR_ba,
    DDR_cas_n          => DDR_cas_n,
    DDR_ck_n           => DDR_ck_n,
    DDR_ck_p           => DDR_ck_p,
    DDR_cke            => DDR_cke,
    DDR_cs_n           => DDR_cs_n,
    DDR_dm             => DDR_dm,
    DDR_dq             => DDR_dq,
    DDR_dqs_n          => DDR_dqs_n,
    DDR_dqs_p          => DDR_dqs_p,
    DDR_odt            => DDR_odt,
    DDR_ras_n          => DDR_ras_n,
    DDR_reset_n        => DDR_reset_n,
    DDR_we_n           => DDR_we_n,
    FIXED_IO_ddr_vrn   => FIXED_IO_ddr_vrn,
    FIXED_IO_ddr_vrp   => FIXED_IO_ddr_vrp,
    FIXED_IO_mio       => FIXED_IO_mio,
    FIXED_IO_ps_clk    => FIXED_IO_ps_clk,
    FIXED_IO_ps_porb   => FIXED_IO_ps_porb,
    FIXED_IO_ps_srstb  => FIXED_IO_ps_srstb,
    i2c0_scl_io        => i2c0_scl_io,
    i2c0_sda_io        => i2c0_sda_io,
    PS_EMIO_tri_io     => s_PS_EMIO_tri_io,
    PS_UART0_rxd       => PS_UART0_rxd,
    PS_UART0_txd       => PS_UART0_txd
  );
  PS_EMIO_TLED0 <= s_PS_EMIO_tri_io(0);
  PS_EMIO_TLED1 <= s_PS_EMIO_tri_io(1);
  PS_EMIO_GPIO0 <= s_PS_EMIO_tri_io(2);
  PS_EMIO_GPIO1 <= s_PS_EMIO_tri_io(3);
  PS_EMIO_GPIO2 <= s_PS_EMIO_tri_io(4);

  -------------------
  -- Instancia do Xadc
  -------------------	 
  inst_adc : XadcFrontend
  port map
  (
    i_clk                  => s_clk1,
    i_rst                  => sRst,
    i_vauxp0               => vauxp0,
    i_vauxn0               => vauxn0,
    i_vauxp1               => vauxp1,
    i_vauxn1               => vauxn1,
    i_vauxp2               => vauxp2,
    i_vauxn2               => vauxn2,
    i_vauxp3               => vauxp3,
    i_vauxn3               => vauxn3,
    i_vauxp4               => vauxp4,
    i_vauxn4               => vauxn4,
    i_vauxp5               => vauxp5,
    i_vauxn5               => vauxn5,
    i_vauxp6               => vauxp6,
    i_vauxn6               => vauxn6,
    i_vauxp7               => vauxp7,
    i_vauxn7               => vauxn7,
    i_vauxp8               => vauxp8,
    i_vauxn8               => vauxn8,
    i_vauxp9               => vauxp9,
    i_vauxn9               => vauxn9,
    i_vauxp10              => vauxp10,
    i_vauxn10              => vauxn10,
    o_temp_data            => s_temp_data,
    o_temp_valid           => s_temp_valid,
    o_vaux0_data           => s_vaux0_data,
    o_vaux0_valid          => s_vaux0_valid,
    o_vaux1_data           => s_vaux1_data,
    o_vaux1_valid          => s_vaux1_valid,
    o_vaux2_data           => s_vaux2_data,
    o_vaux2_valid          => s_vaux2_valid,
    o_vaux3_data           => s_vaux3_data,
    o_vaux3_valid          => s_vaux3_valid,
    o_vaux4_data           => s_vaux4_data,
    o_vaux4_valid          => s_vaux4_valid,
    o_vaux5_data           => s_vaux5_data,
    o_vaux5_valid          => s_vaux5_valid,
    o_vaux6_data           => s_vaux6_data,
    o_vaux6_valid          => s_vaux6_valid,
    o_vaux7_data           => s_vaux7_data,
    o_vaux7_valid          => s_vaux7_valid,
    o_vaux8_data           => s_vaux8_data,
    o_vaux8_valid          => s_vaux8_valid,
    o_vaux9_data           => s_vaux9_data,
    o_vaux9_valid          => s_vaux9_valid,
    o_vaux10_data          => s_vaux10_data,
    o_vaux10_valid         => s_vaux10_valid,
    o_user_temp_alarme_out => open,
    o_vccint_alarme_out    => open,
    o_vccaux_alarme_out    => open,
    o_alarme_out           => open
  );

  inst_aux0_XadcDcOffsetCalibrator: XadcDcOffsetCalibrator
   generic map(
      G_ACCUM_BITS => 14
  )
   port map(
      i_clk => s_clk1,
      i_rst => sRst,
      i_data_raw => s_vaux0_data,
      i_valid => s_vaux0_valid,
      o_offset_avg => s_aux0_calib_offset,
      o_offset_valid => open
  );
  REG_A_CALIB_OFFSET <= s_aux0_calib_offset;


  inst_aux1_XadcDcOffsetCalibrator: XadcDcOffsetCalibrator
  generic map(
      G_ACCUM_BITS => 14
  )
   port map(
      i_clk => s_clk1,
      i_rst => sRst,
      i_data_raw => s_vaux1_data,
      i_valid => s_vaux1_valid,
      o_offset_avg => s_aux1_calib_offset,
      o_offset_valid => open
  );
  REG_B_CALIB_OFFSET <= s_aux1_calib_offset;

    inst_aux2_XadcDcOffsetCalibrator: XadcDcOffsetCalibrator
   generic map(
      G_ACCUM_BITS => 14
  )
   port map(
      i_clk => s_clk1,
      i_rst => sRst,
      i_data_raw => s_vaux2_data,
      i_valid => s_vaux2_valid,
      o_offset_avg => s_aux2_calib_offset,
      o_offset_valid => open
  );
  REG_C_CALIB_OFFSET <= s_aux2_calib_offset;


    inst_aux3_XadcDcOffsetCalibrator: XadcDcOffsetCalibrator
   generic map(
      G_ACCUM_BITS => 14
  )
   port map(
      i_clk => s_clk1,
      i_rst => sRst,
      i_data_raw => s_vaux3_data,
      i_valid => s_vaux3_valid,
      o_offset_avg => s_aux3_calib_offset,
      o_offset_valid => open
  );
  REG_N_CALIB_OFFSET <= s_aux3_calib_offset;


    inst_aux4_XadcDcOffsetCalibrator: XadcDcOffsetCalibrator
   generic map(
      G_ACCUM_BITS => 14
  )
   port map(
      i_clk => s_clk1,
      i_rst => sRst,
      i_data_raw => s_vaux4_data,
      i_valid => s_vaux4_valid,
      o_offset_avg => s_aux4_calib_offset,
      o_offset_valid => open
  );
  REG_VC_CALIB_OFFSET <= s_aux4_calib_offset;

    inst_aux5_XadcDcOffsetCalibrator: XadcDcOffsetCalibrator
   generic map(
      G_ACCUM_BITS => 14
  )
   port map(
      i_clk => s_clk1,
      i_rst => sRst,
      i_data_raw => s_vaux5_data,
      i_valid => s_vaux5_valid,
      o_offset_avg => s_aux5_calib_offset,
      o_offset_valid => open
  );
  REG_VB_CALIB_OFFSET <= s_aux5_calib_offset;

    inst_aux6_XadcDcOffsetCalibrator: XadcDcOffsetCalibrator
   generic map(
      G_ACCUM_BITS => 14
  )
   port map(
      i_clk => s_clk1,
      i_rst => sRst,
      i_data_raw => s_vaux6_data,
      i_valid => s_vaux6_valid,
      o_offset_avg => s_aux6_calib_offset,
      o_offset_valid => open
  );
  REG_VA_CALIB_OFFSET <= s_aux6_calib_offset;

  -------------------
  -- Instancia do VIO
  -------------------	 	
  inst_vio : vio_0
  port map
  (
    clk         => s_clk1,
    probe_out0  => s_AUX0_PhA_Enable_50,
    probe_out1  => s_AUX0_PhA_Enable_51,
    probe_out2  => s_AUX0_PhA_Offset,
    probe_out3  => s_AUX0_PhA_Decimation,
    probe_out4  => s_AUX0_PhA_50_Peakup,
    probe_out5  => s_AUX0_PhA_51_Peakup,
    probe_out6  => s_AUX1_PhB_Enable_50,
    probe_out7  => s_AUX1_PhB_Enable_51,
    probe_out8  => s_AUX1_PhB_Offset,
    probe_out9  => s_AUX1_PhB_Decimation,
    probe_out10 => s_AUX1_PhB_50_Peakup,
    probe_out11 => s_AUX1_PhB_51_Peakup,
    probe_out12 => s_AUX2_PhC_Enable_50,
    probe_out13 => s_AUX2_PhC_Enable_51,
    probe_out14 => s_AUX2_PhC_Offset,
    probe_out15 => s_AUX2_PhC_Decimation,
    probe_out16 => s_AUX2_PhC_50_Peakup,
    probe_out17 => s_AUX2_PhC_51_Peakup,
    probe_out18 => s_AUX3_PhN_Enable_50,
    probe_out19 => s_AUX3_PhN_Enable_51,
    probe_out20 => s_AUX3_PhN_Offset,
    probe_out21 => s_AUX3_PhN_Decimation,
    probe_out22 => s_AUX3_PhN_50_Peakup,
    probe_out23 => s_AUX3_PhN_51_Peakup,
    probe_out24 => sRstVio,
    probe_out25 => s_AUX0_PhA_50_IntDly,
    probe_out26 => s_AUX1_PhB_50_IntDly,
    probe_out27 => s_AUX2_PhC_50_IntDly,
    probe_out28 => s_AUX3_PhN_50_IntDly,
    probe_out29 => s_InputBooleanBlock,
    probe_out30 => s_ConfigBooleanBlock,
    probe_out31 => s_all_signals,
    probe_out32 => s_sel_s0,
    probe_out33 => s_sel_s1,
    probe_out34 => s_sel_s2,
    probe_out35 => s_sel_s3,
    probe_out36 => s_sel_s4,
    probe_out37 => s_sel_s5,
    probe_out38 => s_sel_s6,
    probe_out39 => s_sel_s7,
    probe_out40 => s_46_s1_vio_e1_dly,
    probe_out41 => s_46_s1_vio_e1_en,
    probe_out42 => s_46_s1_vio_e1_i2pu,
    probe_out43 => s_46_s1_vio_e2_i2pu
  );
  ------------------------------------------------
  -- Bias removal and Decimation VAUX0 - Phase A
  ------------------------------------------------
  inst_biasdec_vaux0 : XadcBiasAndDecimate_SingleProc
  port map
  (
    i_clk               => s_clk1,
    i_rst               => sRst,
    i_data              => s_vaux0_data,
    i_valid             => s_vaux0_valid,
    i_offset            => s_aux0_calib_offset,--REG_A_OFFSET_U12, --x"800",--REG_A_OFFSET_U12,LEMBRAR DE VOLTAR NO PROJETO FINAL, FOI COLOCADO PARA NÃO PRECISAR DE USAR O PROCESSADO DURANTE DESENVOLVIMENTO DE BLOCOS NO FPGA PARA USAR OS CANAIS 0 1 e 2
    i_decimation_factor => REG_A_DECIM_U8, -- x"0B",--REG_A_DECIM_U8,
    o_data_decim        => s_vaux0_decim_s12,
    o_valid_decim       => s_vaux0_decim_s12_valid,
    o_data_nodc         => s_vaux0_s12,
    o_valid_nodc        => s_vaux0_s12_valid
  );

  -----------------------------------------------
  -- Bias removal and Decimation VAUX1 - Phase B
  ----------------------------------------------
  inst_biasdec_vaux1 : XadcBiasAndDecimate_SingleProc
  port map
  (
    i_clk               => s_clk1,
    i_rst               => sRst,
    i_data              => s_vaux1_data,
    i_valid             => s_vaux1_valid,
    i_offset            => s_aux1_calib_offset,--REG_B_OFFSET_U12, --REG_B_OFFSET_U12 x"800",
    i_decimation_factor => REG_B_DECIM_U8, --x"0B",--REG_B_DECIM_U8,
    o_data_decim        => s_vaux1_decim_s12,
    o_valid_decim       => s_vaux1_decim_s12_valid,
    o_data_nodc         => s_vaux1_s12,
    o_valid_nodc        => s_vaux1_s12_valid
  );

  -------------------------------------------------
  ---- Bias removal and Decimation VAUX2 - Phase C
  -------------------------------------------------
  inst_biasdec_vaux2 : XadcBiasAndDecimate_SingleProc
  port map
  (
    i_clk               => s_clk1,
    i_rst               => sRst,
    i_data              => s_vaux2_data,
    i_valid             => s_vaux2_valid,
    i_offset            => s_aux0_calib_offset,--REG_C_OFFSET_U12, --x"800",--REG_C_OFFSET_U12,
    i_decimation_factor => REG_C_DECIM_U8, --x"0B",--REG_C_DECIM_U8,
    o_data_decim        => s_vaux2_decim_s12,
    o_valid_decim       => s_vaux2_decim_s12_valid,
    o_data_nodc         => s_vaux2_s12,
    o_valid_nodc        => s_vaux2_s12_valid
  );

  ----------------------------------------------
  -- Bias removal and Decimation VAUX3 - Neutral
  ----------------------------------------------
  inst_biasdec_vaux3 : XadcBiasAndDecimate_SingleProc
  port map
  (
    i_clk               => s_clk1,
    i_rst               => sRst,
    i_data              => s_vaux3_data,
    i_valid             => s_vaux3_valid,
    i_offset            => s_aux3_calib_offset,--REG_N_OFFSET_U12,
    i_decimation_factor => REG_N_DECIM_U8,
    o_data_decim        => s_vaux3_decim_s12,
    o_valid_decim       => s_vaux3_decim_s12_valid,
    o_data_nodc         => s_vaux3_s12,
    o_valid_nodc        => s_vaux3_s12_valid
  );

  ------------------------------------------------
  -- Bias removal and Decimation VAUX4
  ------------------------------------------------
  inst_biasdec_vaux4 : XadcBiasAndDecimate_SingleProc
  port map
  (
    i_clk               => s_clk1,
    i_rst               => sRst,
    i_data              => s_vaux4_data,
    i_valid             => s_vaux4_valid,
    i_offset            => s_aux4_calib_offset,--REG_VA_OFFSET_U12,
    i_decimation_factor => REG_VA_DECIM_U8,
    o_data_decim        => s_vaux4_decim_s12,
    o_valid_decim       => s_vaux4_decim_s12_valid,
    o_data_nodc         => s_vaux4_s12,
    o_valid_nodc        => s_vaux4_s12_valid
  );

  ------------------------------------------------
  -- Bias removal and Decimation VAUX5
  ------------------------------------------------
  inst_biasdec_vaux5 : XadcBiasAndDecimate_SingleProc
  port map
  (
    i_clk               => s_clk1,
    i_rst               => sRst,
    i_data              => s_vaux5_data,
    i_valid             => s_vaux5_valid,
    i_offset            => s_aux5_calib_offset,--REG_VB_OFFSET_U12,
    i_decimation_factor => REG_VB_DECIM_U8,
    o_data_decim        => s_vaux5_decim_s12,
    o_valid_decim       => s_vaux5_decim_s12_valid,
    o_data_nodc         => s_vaux5_s12,
    o_valid_nodc        => s_vaux5_s12_valid
  );

  ------------------------------------------------
  -- Bias removal and Decimation VAUX6
  ------------------------------------------------
  inst_biasdec_vaux6 : XadcBiasAndDecimate_SingleProc
  port map
  (
    i_clk               => s_clk1,
    i_rst               => sRst,
    i_data              => s_vaux6_data,
    i_valid             => s_vaux6_valid,
    i_offset            => s_aux6_calib_offset,--REG_VC_OFFSET_U12,
    i_decimation_factor => REG_VC_DECIM_U8,
    o_data_decim        => s_vaux6_decim_s12,
    o_valid_decim       => s_vaux6_decim_s12_valid,
    o_data_nodc         => s_vaux6_s12,
    o_valid_nodc        => s_vaux6_s12_valid
  );

  ------------------------------------------------
  -- Bias removal and Decimation VAUX7
  ------------------------------------------------
  inst_biasdec_vaux7 : XadcBiasAndDecimate_SingleProc
  port map
  (
    i_clk               => s_clk1,
    i_rst               => sRst,
    i_data              => s_vaux7_data,
    i_valid             => s_vaux7_valid,
    i_offset            => X"800",--REG_A_OFFSET_U12,
    i_decimation_factor => x"0B", -- REG_A_DECIM_U8,
    o_data_decim        => s_vaux7_decim_s12,
    o_valid_decim       => s_vaux7_decim_s12_valid,
    o_data_nodc         => s_vaux7_s12,
    o_valid_nodc        => s_vaux7_s12_valid
  );

  ------------------------------------------------
  -- Bias removal and Decimation VAUX8
  ------------------------------------------------
  inst_biasdec_vaux8 : XadcBiasAndDecimate_SingleProc
  port map
  (
    i_clk               => s_clk1,
    i_rst               => sRst,
    i_data              => s_vaux8_data,
    i_valid             => s_vaux8_valid,
    i_offset            => X"800", --REG_A_OFFSET_U12,
    i_decimation_factor => x"0B", --REG_A_DECIM_U8,
    o_data_decim        => s_vaux8_decim_s12,
    o_valid_decim       => s_vaux8_decim_s12_valid,
    o_data_nodc         => s_vaux8_s12,
    o_valid_nodc        => s_vaux8_s12_valid
  );

  ------------------------------------------------
  -- Bias removal and Decimation VAUX9
  ------------------------------------------------
  inst_biasdec_vaux9 : XadcBiasAndDecimate_SingleProc
  port map
  (
    i_clk               => s_clk1,
    i_rst               => sRst,
    i_data              => s_vaux9_data,
    i_valid             => s_vaux9_valid,
    i_offset            => X"800", --REG_A_OFFSET_U12,
    i_decimation_factor => x"0B", --REG_A_DECIM_U8,
    o_data_decim        => s_vaux9_decim_s12,
    o_valid_decim       => s_vaux9_decim_s12_valid,
    o_data_nodc         => s_vaux9_s12,
    o_valid_nodc        => s_vaux9_s12_valid
  );

  ------------------------------------------------
  -- Bias removal and Decimation VAUX10
  ------------------------------------------------
  inst_biasdec_vaux10 : XadcBiasAndDecimate_SingleProc
  port map
  (
    i_clk               => s_clk1,
    i_rst               => sRst,
    i_data              => s_vaux10_data,
    i_valid             => s_vaux10_valid,
    i_offset            => X"800",--REG_A_OFFSET_U12,
    i_decimation_factor => x"0B", --REG_A_DECIM_U8,
    o_data_decim        => s_vaux10_decim_s12,
    o_valid_decim       => s_vaux10_decim_s12_valid,
    o_data_nodc         => s_vaux10_s12,
    o_valid_nodc        => s_vaux10_s12_valid
  );

  ---------------------------------------------------------------
  --instancia o gerador senoidal simlando ADC -- Apenas para teste
  ---------------------------------------------------------------
  --inst_sin : GenSineWave 
  --port map(
  --    clk      => s_clk1,
  --    rst      => sRst,
  --    ivalid   => s_vaux0_valid,
  --    sine_out => s_sine_out,
  --	ovalid   => s_ovalid
  --);
  inst_sin3phase : stim_3ph_rom_64pts
  port map
  (
    i_clk           => s_clk1,
    i_rst           => sRst,
    i_valid_fase_A  => s_vaux0_valid, --s_vaux0_decim_s12_valid esse será mais o menos o valid correto.
    i_valid_fase_B  => s_vaux1_valid,
    i_valid_fase_C  => s_vaux2_valid,
    o_phase_A       => s_phase_A, -- s_vaux0_decim_s12  
    o_valid_phase_A => s_valid_phase_A,
    o_phase_B       => s_phase_B,
    o_valid_phase_B => s_valid_phase_B,
    o_phase_C       => s_phase_C,
    o_valid_phase_C => s_valid_phase_C
  );
  -------------------------------------------
  -- Gerador DC e H3 -- Only for test
  -------------------------------------------  
  inst_stim_dch3 : siggen_dc_h3_lut
  generic map(
    G_W => 12, -- largura de saída (bits)
    G_N => 64 -- tamanho da LUT (fixo em 64 nesta versão)
  )
  port map
  (
    i_clk    => s_clk1,
    i_rst    => sRst,
    i_valid  => s_vaux0_decim_s12_valid,
    o_valid  => s_siggen_dch3_valid,
    o_sample => s_siggen_dch3_sample
  );
  -------------------------------------------------------------------------------------------------------------------------------------------------------------
  -- Filtro passa faixa para eliminar DC e H3 -- Filtro testado com o sinal do ch0 - Depois teremos que verificar quais canais precisam ser filtrados realmente
  -------------------------------------------------------------------------------------------------------------------------------------------------------------
  inst_filtrpb : filtro_Remove_DC_H3
  port map
  (
    i_clk          => s_clk1,
    i_rst          => sRst,
    i_sample_valid => s_filter_DCH3_sample_in_valid, --s_vaux0_decim_s12_valid
    i_sample       => s_filter_DCH3_sample_in, ----s_vaux0_decim_s12,
    o_sample_valid => s_filter_DCH3_sample_valid,
    o_sample       => s_filter_DCH3_sample
  );
  -- Processo só para passar de stdlogicvector signed para unsigned
  process (s_clk1)
  begin
    if rising_edge(s_clk1) then
      s_filter_DCH3_sample_in       <= std_logic_vector(resize(unsigned(resize(signed(s_vaux0_decim_s12), 13) + to_signed(2048, 13)), 12));
      s_filter_DCH3_sample_in_valid <= s_vaux0_decim_s12_valid;
    end if;
  end process;

  -------------------------------------------------------------------------------------------------
  -- Filtro 2 gerador interno passa faixa para eliminar DC e H3 -- Apenas para validacao do filtro
  -------------------------------------------------------------------------------------------------
  inst_filtrpb2 : filtro_Remove_DC_H3
  port map
  (
    i_clk          => s_clk1,
    i_rst          => sRst,
    i_sample_valid => s_siggen_dch3_valid, --s_vaux0_decim_s12_valid
    i_sample       => s_siggen_dch3_sample, ----s_vaux0_decim_s12,
    o_sample_valid => s_filter2_DCH3_sample_valid,
    o_sample       => s_filter2_DCH3_sample
  );
  -------------------------------------
  -- Fasor unified Re/Im, RMS, phase
  -------------------------------------
  inst_fasor_unified : phasor_64pts_3ph_unified_fsm
  generic map(
    SAMPLE_WIDTH => 12,
    COEFF_WIDTH  => 15,
    ACC_WIDTH    => 36,
    OUT_WIDTH    => 32,
    ANG_WIDTH    => 16,
    ITER         => 16
  )
  port map
  (
    i_clk              => s_clk1,
    i_rst              => sRst,
    i_signal_phaseA_12 => signed(s_vaux0_decim_s12), --s_phase_A,  -- Temos que verificar quais canais realmente entraram nesse componente dos fasores (Testei com o ch 0 e canais B e C do gerador artifical) Aqui tem que ser os 3 canais de corrente IA IB e IC.
    i_valid_phaseA     => s_vaux0_decim_s12_valid, --s_valid_phase_A,--s_vaux0_decim_s12_valid,
    i_signal_phasB_12  => signed(s_vaux1_decim_s12), -- s_vaux0_decim_s12
    i_valid_phaseB     => s_vaux1_decim_s12_valid, --s_vaux1_decim_s12_valid,
    i_signal_phaseC_12 => signed(s_vaux2_decim_s12),
    i_valid_phaseC     => s_vaux2_decim_s12_valid, --s_vaux2_decim_s12_valid,
    o_valid_phaseA     => s_ph_valid_phaseA,
    o_Real_phaseA      => s_ph_Real_phaseA,
    o_Imag_phaseA      => s_ph_Imag_phaseA,
    o_RMS_phaseA       => s_ph_RMS_phaseA,
    o_phase_phaseA     => s_ph_phase_phaseA,
    o_valid_phaseB     => s_ph_valid_phaseB,
    o_Real_phaseB      => s_ph_Real_phaseB,
    o_Imag_phaseB      => s_ph_Imag_phaseB,
    o_RMS_phaseB       => s_ph_RMS_phaseB,
    o_phase_phaseB     => s_ph_phase_phaseB,
    o_valid_phaseC     => s_ph_valid_phaseC,
    o_Real_phaseC      => s_ph_Real_phaseC,
    o_Imag_phaseC      => s_ph_Imag_phaseC,
    o_RMS_phaseC       => s_ph_RMS_phaseC,
    o_phase_phaseC     => s_ph_phase_phaseC
  );
  --	-------------------------------------
  --	-- Instancia componente de seq simetricas
  --	-------------------------------------
  --	inst_symcom : symcomp_3ph_from_phasors_fsm
  --	generic map (
  --		ACC_WIDTH => 36
  --	)
  --	port map (
  --		i_clk => s_clk1,
  --		i_rst => sRst,
  --		-- ========================
  --		-- Entradas – Fase A
  --		-- ========================
  --		i_valid_phaseA => s_ph_valid_phaseA,
  --		i_Re_phaseA    => s_ph_Real_phaseA,
  --		i_Im_phaseA    => s_ph_Imag_phaseA,
  --		-- ========================
  --		-- Entradas – Fase B
  --		-- ========================
  --		i_valid_phaseB => s_ph_valid_phaseB,
  --		i_Re_phaseB    => s_ph_Real_phaseB,
  --		i_Im_phaseB    => s_ph_Imag_phaseB,
  --		-- ========================
  --		-- Entradas – Fase C
  --		-- ========================
  --		i_valid_phaseC => s_ph_valid_phaseC,
  --		i_Re_phaseC    => s_ph_Real_phaseC,
  --		i_Im_phaseC    => s_ph_Imag_phaseC,
  --		-- ========================
  --		-- Saídas – Componentes Simétricas
  --		-- ========================
  --		o_valid_seq => s_valid_seq,
  --		o_seq0_re   => s_Re_seq0,
  --		o_seq0_im   => s_Im_seq0,	
  --		o_seq1_re   => s_Re_seq1,
  --		o_seq1_im   => s_Im_seq1,	
  --		o_seq2_re   => s_Re_seq2,
  --		o_seq2_im   => s_Im_seq2
  --	);

  -------------------------------------
  -- Instancia componente de seq simetricas
  -------------------------------------
  inst_symcom_retpol : symcomp_3ph_from_phasors_fsm_retpol
  generic map(
    ACC_WIDTH => 36
  )
  port map
  (
    i_clk => s_clk1,
    i_rst => sRst,
    -- ========================
    -- Entradas – Fase A
    -- ========================
    i_valid_phaseA => s_ph_valid_phaseA,
    i_Re_phaseA    => s_ph_Real_phaseA,
    i_Im_phaseA    => s_ph_Imag_phaseA,
    -- ========================
    -- Entradas – Fase B
    -- ========================
    i_valid_phaseB => s_ph_valid_phaseB,
    i_Re_phaseB    => s_ph_Real_phaseB,
    i_Im_phaseB    => s_ph_Imag_phaseB,
    -- ========================
    -- Entradas – Fase C
    -- ========================
    i_valid_phaseC => s_ph_valid_phaseC,
    i_Re_phaseC    => s_ph_Real_phaseC,
    i_Im_phaseC    => s_ph_Imag_phaseC,
    -- ========================
    -- Saídas – Componentes Simétricas
    -- ========================
    o_valid_seq  => s_seq_valid,
    o_seq0_re    => s_seq0_re,
    o_seq0_im    => s_seq0_im,
    o_seq0_abs   => s_seq0_abs,
    o_seq0_phase => s_seq0_phase,
    o_seq0_rms   => s_seq0_rms,
    o_seq1_abs   => s_seq1_abs,
    o_seq1_phase => s_seq1_phase,
    o_seq1_rms   => s_seq1_rms,
    o_seq1_re    => s_seq1_re,
    o_seq1_im    => s_seq1_im,
    o_seq2_re    => s_seq2_re,
    o_seq2_im    => s_seq2_im,
    o_seq2_abs   => s_seq2_abs,
    o_seq2_phase => s_seq2_phase,
    o_seq2_rms   => s_seq2_rms

  );
  REG_SEQ0_ABS   <= std_logic_vector(s_seq0_abs);
  REG_SEQ0_PHASE <= std_logic_vector(s_seq0_phase);
  REG_SEQ0_RMS   <= std_logic_vector(s_seq0_rms);

  REG_SEQ1_ABS   <= std_logic_vector(s_seq1_abs);
  REG_SEQ1_PHASE <= std_logic_vector(s_seq1_phase);
  REG_SEQ1_RMS   <= std_logic_vector(s_seq1_rms); 

  REG_SEQ2_ABS   <= std_logic_vector(s_seq2_abs);
  REG_SEQ2_PHASE <= std_logic_vector(s_seq2_phase);
  REG_SEQ2_RMS   <= std_logic_vector(s_seq2_rms);

  

  --------------------------------------------------
  ---- Instancia da Logica Bolean 64 input with MUX  -- Alan mencinou que depois que validar esse componente
  --------------------------------------------------
  inst_bolean_logic_64 : boolean_logic_64in_lut8
  port map
  (
    i_clk => s_clk1,
    i_rst => sRst,
    -- S0..S63
    i_all_signals => s_all_signals, -- Aqui entrará os sinais que poderão entrar na lógica booleana (s_trip_50_A, s_trip_50_B ..., s_trip_51_A ..., s_trip_27_A_stg1 ... )
    -- Seleção de quais sinais entram como S0..S7
    i_sel_s0 => s_sel_s0, -- ISSO ESTÁ VINDO DO VIO, mas o arthur passará para CoreRegs e a interface enviará. Quando for replicar a gente verifica se vale a pena passar para AXI
    i_sel_s1 => s_sel_s1,
    i_sel_s2 => s_sel_s2,
    i_sel_s3 => s_sel_s3,
    i_sel_s4 => s_sel_s4,
    i_sel_s5 => s_sel_s5,
    i_sel_s6 => s_sel_s6,
    i_sel_s7 => s_sel_s7,
    -- Sinais selecionados para debug
    o_selected_s => s_Boolean_selected_s, -- VEM do VIO hoje, mas virá do core Regs ou do AXI.
    -- LUT: endereço = i_signals
    i_lut_cfg => s_ConfigBooleanBlock,
    o_trip    => s_Boolean_o_trip

  );

  --------------------------------------------------
  ---- Instancia da funcao 46
  --------------------------------------------------
  inst_prot_46_51Q_s1 : ProtPhaseUmbalanceNegSeq_46_51Q
   generic map(
      G_CLK_HZ => 100_000_000,
      G_HYST => 0,
      G_TIME_WIDTH => 20,
      G_ADDR_BITS => 12,
      G_DATA_BITS => 20
  )
   port map(
      i_clk_100MHz      => s_clk1,
      i_rst             => s_46_s1_rst,
      i_start           => '1',
      i_seq2_abs        => s_seq2_abs,
      i_seq2_valid      => s_seq_valid,
      i_seq2_pickup_e1  => s_46_s1_vio_e1_i2pu,--REG_46_S1_E1_I2PU_U12,
      i_seq2_pickup_e2  => s_46_s1_vio_e2_i2pu,--REG_46_S1_E2_I2PU_U12,
      i_delay_e1_ms     => UNSIGNED(s_46_s1_vio_e1_dly),--UNSIGNED(REG_46_S1_E1_DLY_U20),
      o_ram_addr        => s_46_s1_ram_addr,
      o_ram_rd_req      => s_46_s1_ram_rd_req,
      i_ram_data        => s_46_s1_bram_douta,
      o_seq_abs_u12     => s_46_s1_i2_abs_u12,
      o_time_ms         => s_46_s1_time_ms,
      o_target_ms_reg   => s_46_s1_ram_target_ms,
      o_e1_time_cnt     => s_46_s1_e1_time_cnt,
      o_alarm_e1        => s_46_s1_e1_alarm,
      o_alarm_e2        => s_46_s1_e2_alarm,
      o_trip_46_e1      => s_46_s1_e1_trip,
      o_trip_46_e2      => s_46_s1_e2_trip,
      o_trip_46         => s_46_s1_trip
  );
  s_46_s1_rst <= (sRst or s_46_s1_vio_e1_en(0)); -- or not REG_46_S1_EN);
  REG_46_S1_E1_ALARM <=  s_46_s1_e1_alarm;
  REG_46_S1_E2_ALARM <=  s_46_s1_e2_alarm;
  REG_46_S1_E1_TRIP  <=  s_46_s1_e1_trip;
  REG_46_S1_E2_TRIP  <=  s_46_s1_e2_trip;
  REG_46_S1_TRIP     <=  s_46_s1_trip;

  inst_bram0_46_s1 : blk_mem_gen_0
  port map
  (
    -- Porta A
    clka  => s_clk1,
    ena   => '1',
    wea   => s_46_s1_bram_wea, -- "0" = somente leitura (ROM via COE)
    addra => s_46_s1_ram_addr, -- 11 bits
    dina  => s_46_s1_bram_dina, -- 20 bits (não usado se wea="0")
    douta => s_46_s1_bram_douta, -- 20 bits

    -- Porta B
    clkb  => s_clk1,
    enb   => '1',
    web   => REG_46_S1_LUT_WR_EN, -- "0" = somente leitura
    addrb => REG_46_S1_LUT_ADDR,  -- 11 bits
    dinb  => REG_46_S1_LUT_DATA,  -- 20 bits
    doutb => REG_46_S1_LUT_DOUTB  --s_51_A_bram_doutb -- 20 bits
  );

  inst_rms_aux0 : MovingAverageRMS
  generic map(
    N      => 64,
    Log2_N => 6
  )
  port map
  (

    --------------------------
    -- Clock / Reset
    --------------------------
    i_clk => s_clk1,
    i_rst => sRst,

    --------------------------
    -- Amostra de entrada
    --------------------------
    i_sample => s_vaux0_decim_s12,
    i_valid  => s_vaux0_decim_s12_valid,

    ----------------
    -- Saídas
    ----------------
    o_sq_reg    => open,
    o_rms       => s_rms_aux_0,
    o_rms_valid => s_rms_aux_0_valid

  );
  inst_rms_aux1 : MovingAverageRMS
  generic map(
    N      => 64,
    Log2_N => 6
  )
  port map
  (

    --------------------------
    -- Clock / Reset
    --------------------------
    i_clk => s_clk1,
    i_rst => sRst,

    --------------------------
    -- Amostra de entrada
    --------------------------
    i_sample => s_vaux1_decim_s12,
    i_valid  => s_vaux1_decim_s12_valid,

    ----------------
    -- Saídas
    ----------------
    o_sq_reg    => open,
    o_rms       => s_rms_aux_1,
    o_rms_valid => s_rms_aux_1_valid

  );

  inst_rms_aux2 : MovingAverageRMS
  generic map(
    N      => 64,
    Log2_N => 6
  )
  port map
  (

    --------------------------
    -- Clock / Reset
    --------------------------
    i_clk => s_clk1,
    i_rst => sRst,

    --------------------------
    -- Amostra de entrada
    --------------------------
    i_sample => s_vaux2_decim_s12,
    i_valid  => s_vaux2_decim_s12_valid,

    ----------------
    -- Saídas
    ----------------
    o_sq_reg    => open,
    o_rms       => s_rms_aux_2,
    o_rms_valid => s_rms_aux_2_valid

  );

  inst_rms_aux3 : MovingAverageRMS
  generic map(
    N      => 64,
    Log2_N => 6
  )
  port map
  (

    --------------------------
    -- Clock / Reset
    --------------------------
    i_clk => s_clk1,
    i_rst => sRst,
    --------------------------
    -- Amostra de entrada
    --------------------------
    i_sample => s_vaux3_decim_s12,
    i_valid  => s_vaux3_decim_s12_valid,
    ----------------
    -- Saídas
    ----------------
    o_sq_reg    => open,
    o_rms       => s_rms_aux_3,
    o_rms_valid => s_rms_aux_3_valid

  );

  inst_rms_aux4 : MovingAverageRMS
  generic map(
    N      => 64,
    Log2_N => 6
  )
  port map
  (

    --------------------------
    -- Clock / Reset
    --------------------------
    i_clk => s_clk1,
    i_rst => sRst,
    --------------------------
    -- Amostra de entrada
    --------------------------
    i_sample => s_vaux4_decim_s12,
    i_valid  => s_vaux4_decim_s12_valid,
    ----------------
    -- Saídas
    ----------------
    o_sq_reg    => open,
    o_rms       => s_rms_aux_4,
    o_rms_valid => s_rms_aux_4_valid

  );

  inst_rms_aux5 : MovingAverageRMS
  generic map(
    N      => 64,
    Log2_N => 6
  )
  port map
  (

    --------------------------
    -- Clock / Reset
    --------------------------
    i_clk => s_clk1,
    i_rst => sRst,
    --------------------------
    -- Amostra de entrada
    --------------------------
    i_sample => s_vaux5_decim_s12,
    i_valid  => s_vaux5_decim_s12_valid,
    ----------------
    -- Saídas
    ----------------
    o_sq_reg    => open,
    o_rms       => s_rms_aux_5,
    o_rms_valid => s_rms_aux_5_valid

  );

  inst_rms_aux6 : MovingAverageRMS
  generic map(
    N      => 64,
    Log2_N => 6
  )
  port map
  (

    --------------------------
    -- Clock / Reset
    --------------------------
    i_clk => s_clk1,
    i_rst => sRst,
    --------------------------
    -- Amostra de entrada
    --------------------------
    i_sample => s_vaux6_decim_s12,
    i_valid  => s_vaux6_decim_s12_valid,
    ----------------
    -- Saídas
    ----------------
    o_sq_reg    => open,
    o_rms       => s_rms_aux_6,
    o_rms_valid => s_rms_aux_6_valid

  );

  inst_rms_aux7 : MovingAverageRMS
  generic map(
    N      => 64,
    Log2_N => 6
  )
  port map
  (

    --------------------------
    -- Clock / Reset
    --------------------------
    i_clk => s_clk1,
    i_rst => sRst,
    --------------------------
    -- Amostra de entrada
    --------------------------
    i_sample => s_vaux7_decim_s12,
    i_valid  => s_vaux7_decim_s12_valid,
    ----------------
    -- Saídas
    ----------------
    o_sq_reg    => open,
    o_rms       => s_rms_aux_7,
    o_rms_valid => s_rms_aux_7_valid

  );

  inst_rms_aux8 : MovingAverageRMS
  generic map(
    N      => 64,
    Log2_N => 6
  )
  port map
  (

    --------------------------
    -- Clock / Reset
    --------------------------
    i_clk => s_clk1,
    i_rst => sRst,
    --------------------------
    -- Amostra de entrada
    --------------------------
    i_sample => s_vaux8_decim_s12,
    i_valid  => s_vaux8_decim_s12_valid,
    ----------------
    -- Saídas
    ----------------
    o_sq_reg    => open,
    o_rms       => s_rms_aux_8,
    o_rms_valid => s_rms_aux_8_valid

  );

  inst_rms_aux9 : MovingAverageRMS
  generic map(
    N      => 64,
    Log2_N => 6
  )
  port map
  (

    --------------------------
    -- Clock / Reset
    --------------------------
    i_clk => s_clk1,
    i_rst => sRst,
    --------------------------
    -- Amostra de entrada
    --------------------------
    i_sample => s_vaux9_decim_s12,
    i_valid  => s_vaux9_decim_s12_valid,
    ----------------
    -- Saídas
    ----------------
    o_sq_reg    => open,
    o_rms       => s_rms_aux_9,
    o_rms_valid => s_rms_aux_9_valid

  );

  inst_rms_aux10 : MovingAverageRMS
  generic map(
    N      => 64,
    Log2_N => 6
  )
  port map
  (

    --------------------------
    -- Clock / Reset
    --------------------------
    i_clk => s_clk1,
    i_rst => sRst,
    --------------------------
    -- Amostra de entrada
    --------------------------
    i_sample => s_vaux10_decim_s12,
    i_valid  => s_vaux10_decim_s12_valid,
    ----------------
    -- Saídas
    ----------------
    o_sq_reg    => open,
    o_rms       => s_rms_aux_10,
    o_rms_valid => s_rms_aux_10_valid

  );
  -- ==================================================================================================
  -- Instância das protecoes instantaneas 50/50N - Vou usar amostras de RMS que vieram da decimacao
  -- ==================================================================================================

  inst_prot_50_A : ProtectInstant_50_50N
  generic map(
    G_MS_TICKS => 100_000,
    G_HYST_U12 => 10
  )
  port map
  (
    i_clk               => s_clk1,
    i_rst               => s_rst_50_A,
    i_sample_u12        => s_rms_aux_0(11 downto 0),
    i_valid             => s_rms_aux_0_valid,
    i_peakup_u12        => REG_A_50_PEAK_U12,
    i_intentional_delay => REG_A_50_INTDLY_MS,
    o_trip              => s_trip_50_A
  );
  s_rst_50_A <= (sRst or not(REG_A_EN50(0)));

  inst_prot_50_B : ProtectInstant_50_50N
  generic map(
    G_MS_TICKS => 100_000,
    G_HYST_U12 => 10
  )
  port map
  (
    i_clk               => s_clk1,
    i_rst               => s_rst_50_B,
    i_sample_u12        => s_rms_aux_1(11 downto 0),
    i_valid             => s_rms_aux_1_valid,
    i_peakup_u12        => REG_B_50_PEAK_U12,
    i_intentional_delay => REG_B_50_INTDLY_MS,
    o_trip              => s_trip_50_B
  );
  s_rst_50_B <= (sRst or not(REG_B_EN50(0)));

  inst_prot_50_C : ProtectInstant_50_50N
  generic map(
    G_MS_TICKS => 100_000,
    G_HYST_U12 => 10
  )
  port map
  (
    i_clk               => s_clk1,
    i_rst               => s_rst_50_C,
    i_sample_u12        => s_rms_aux_2(11 downto 0),
    i_valid             => s_rms_aux_2_valid,
    i_peakup_u12        => REG_C_50_PEAK_U12,
    i_intentional_delay => REG_C_50_INTDLY_MS,
    o_trip              => s_trip_50_C
  );
  s_rst_50_C <= (sRst or not(REG_C_EN50(0)));

  -- 50N (neutro) – usa VAUX3 decimado
  inst_prot_50N : ProtectInstant_50_50N
  generic map(
    G_MS_TICKS => 100_000,
    G_HYST_U12 => 10
  )
  port map
  (
    i_clk               => s_clk1,
    i_rst               => s_rst_50_N,
    i_sample_u12        => s_rms_aux_3(11 downto 0),
    i_valid             => s_rms_aux_3_valid,
    i_peakup_u12        => REG_N_50_PEAK_U12,
    i_intentional_delay => REG_N_50_INTDLY_MS,
    o_trip              => s_trip_50N
  );
  s_rst_50_N <= (sRst or not(REG_N_EN50(0)));
  -- ==================================================================================================
  -- Instância das protecoes temporizadas 51/51N - Vou usar amostras de RMS que vieram da decimacao
  -- ==================================================================================================
  -- =========================
  -- 51 (fase, usa VAUX0-AUX2 for A/B/C)
  -- =========================

  inst_prot_51_time_A : Prot51_51N_ACC
  generic map(
    G_CLK_HZ    => 100_000_000, -- ajuste se s_clk1 ≠ 100 MHz
    G_HYST      => 10, -- histerese (ex.: 10 contagens RMS)
    G_ADDR_BITS => 12,
    G_DATA_BITS => 20
  )
  port map
  (
    -- relógio / reset / start
    i_clk_100MHz   => s_clk1,
    i_rst          => s_rst_51_A,
    i_start_51_51N => s_start_51, -- '1' mantém monitorando
    -- RMS/limiar
    i_rms_51_51N       => s_rms_aux_0(11 downto 0),
    i_rms_51_51N_valid => s_rms_aux_0_valid,
    i_peakup           => REG_A_51_PEAK_U12, -- virá do core regs
    -- RAM (porta A da BRAM)
    o_ram_addr   => s_51_ram_addr_A,
    o_ram_rd_req => s_51_ram_rd_req_A,
    i_ram_data   => s_51_A_bram_douta,
    -- saídas
    o_time_ms         => s_time_ms_51,
    o_start_trip_time => s_start_trip_51,
    o_trip_51_51N     => s_trip_51_A
  );
  s_rst_51_A <= (sRst or not(REG_A_EN51(0)));

  -- Instância da BRAM da protecao 51
  inst_bram0_51_A : blk_mem_gen_0
  port map
  (
    -- Porta A
    clka  => s_clk1,
    ena   => '1',
    wea   => s_51_A_bram_wea, -- "0" = somente leitura (ROM via COE)
    addra => s_51_ram_addr_A, -- 11 bits
    dina  => s_51_A_bram_dina, -- 20 bits (não usado se wea="0")
    douta => s_51_A_bram_douta, -- 20 bits

    -- Porta B
    clkb  => s_clk1,
    enb   => '1',
    web   => REG_LUT_WR_EN_A, -- "0" = somente leitura
    addrb => REG_LUT_ADDR, -- 11 bits
    dinb  => REG_LUT_DATA, -- 20 bits
    doutb => REG_A_LUT_DATA_OUT--s_51_A_bram_doutb -- 20 bits
  );

  inst_prot_51_time_B : Prot51_51N_Time
  generic map(
    G_CLK_HZ    => 100_000_000, -- ajuste se s_clk1 ≠ 100 MHz
    G_HYST      => 10, -- histerese (ex.: 10 contagens RMS)
    G_ADDR_BITS => 12,
    G_DATA_BITS => 20
  )
  port map
  (
    -- relógio / reset / start
    i_clk_100MHz   => s_clk1,
    i_rst          => s_rst_51_B,
    i_start_51_51N => s_start_51, -- '1' mantém monitorando
    -- RMS/limiar
    i_rms_51_51N       => s_rms_aux_1(11 downto 0),
    i_rms_51_51N_valid => s_rms_aux_1_valid,
    i_peakup           => REG_B_51_PEAK_U12, -- virá do core regs
    -- RAM (porta A da BRAM)
    o_ram_addr   => s_51_ram_addr_B,
    o_ram_rd_req => s_51_ram_rd_req_B,
    i_ram_data   => s_51_B_bram_douta,
    -- saídas
    o_time_ms         => open,
    o_start_trip_time => open,
    o_trip_51_51N     => s_trip_51_B
  );
  s_rst_51_B <= (sRst or not(REG_B_EN51(0)));

  -- Instância da BRAM da protecao 51
  inst_bram0_51_B : blk_mem_gen_0
  port map
  (
    -- Porta A
    clka  => s_clk1,
    ena   => '1',
    wea   => s_51_B_bram_wea, -- "0" = somente leitura (ROM via COE)
    addra => s_51_ram_addr_B, -- 11 bits
    dina  => s_51_B_bram_dina, -- 20 bits (não usado se wea="0")
    douta => s_51_B_bram_douta, -- 20 bits

    -- Porta B
    clkb  => s_clk1,
    enb   => '1',
    web   => REG_LUT_WR_EN_B, -- "0" = somente leitura
    addrb => REG_LUT_ADDR, -- 11 bits
    dinb  => REG_LUT_DATA, -- 20 bits
    doutb => s_51_B_bram_doutb -- 20 bits
  );
  inst_prot_51_time_C : Prot51_51N_ACC
  generic map(
    G_CLK_HZ    => 100_000_000, -- ajuste se s_clk1 ≠ 100 MHz
    G_HYST      => 10, -- histerese (ex.: 10 contagens RMS)
    G_ADDR_BITS => 12,
    G_DATA_BITS => 20
  )
  port map
  (
    -- relógio / reset / start
    i_clk_100MHz   => s_clk1,
    i_rst          => s_rst_51_C,
    i_start_51_51N => s_start_51, -- '1' mantém monitorando
    -- RMS/limiar
    i_rms_51_51N       => s_rms_aux_2(11 downto 0),
    i_rms_51_51N_valid => s_rms_aux_2_valid,
    i_peakup           => REG_C_51_PEAK_U12, -- virá do core regs
    -- RAM (porta A da BRAM)
    o_ram_addr   => s_51_ram_addr_C,
    o_ram_rd_req => s_51_ram_rd_req_C,
    i_ram_data   => s_51_C_bram_douta,
    -- saídas
    o_time_ms         => open,
    o_start_trip_time => open,
    o_trip_51_51N     => s_trip_51_C
  );
  s_rst_51_C <= (sRst or not(REG_C_EN51(0)));

  -- Instância da BRAM da protecao 51
  inst_bram0_51_C : blk_mem_gen_0
  port map
  (
    -- Porta A
    clka  => s_clk1,
    ena   => '1',
    wea   => s_51_C_bram_wea, -- "0" = somente leitura (ROM via COE)
    addra => s_51_ram_addr_C, -- 11 bits
    dina  => s_51_C_bram_dina, -- 20 bits (não usado se wea="0")
    douta => s_51_C_bram_douta, -- 20 bits

    -- Porta B
    clkb  => s_clk1,
    enb   => '1',
    web   => REG_LUT_WR_EN_C, -- "0" = somente leitura
    addrb => REG_LUT_ADDR, -- 11 bits
    dinb  => REG_LUT_DATA, -- 20 bits
    doutb => s_51_C_bram_doutb -- 20 bits
  );

  -- =========================
  -- 51N (fase, usa VAUX3)
  -- =========================	
  inst_prot_51N_time : Prot51_51N_ACC
  generic map(
    G_CLK_HZ    => 100_000_000, -- ajuste se s_clk1 ≠ 100 MHz
    G_HYST      => 10, -- histerese (ex.: 10 contagens RMS)
    G_ADDR_BITS => 12,
    G_DATA_BITS => 20
  )
  port map
  (
    -- relógio / reset / start
    i_clk_100MHz   => s_clk1,
    i_rst          => s_rst_51_N,
    i_start_51_51N => s_start_51, -- '1' mantém monitorando

    -- RMS/limiar
    i_rms_51_51N       => s_rms_aux_3(11 downto 0),
    i_rms_51_51N_valid => s_rms_aux_3_valid,
    i_peakup           => REG_N_51_PEAK_U12,

    -- RAM (porta A da BRAM)
    o_ram_addr   => s_51N_ram_addr,
    o_ram_rd_req => s_51N_ram_rd_req,
    i_ram_data   => s_51N_bram_douta,

    -- saídas
    o_time_ms         => s_time_ms_51N,
    o_start_trip_time => s_start_trip_51N,
    o_trip_51_51N     => s_trip_51N
  );
  s_rst_51_N <= (sRst or not(REG_N_EN51(0)));

  -- Instância da BRAM da protecao 51
  inst_bram0_51N : blk_mem_gen_0
  port map
  (
    -- Porta A
    clka  => s_clk1,
    ena   => '1',
    wea   => s_51N_bram_wea, -- "0" = somente leitura (ROM via COE)
    addra => s_51N_ram_addr, -- 11 bits
    dina  => s_51N_bram_dina, -- 20 bits (não usado se wea="0")
    douta => s_51N_bram_douta, -- 20 bits

    -- Porta B
    clkb  => s_clk1,
    enb   => '1',
    web   => REG_LUT_WR_EN_N, -- "0" = somente leitura
    addrb => REG_LUT_ADDR, -- 11 bits
    dinb  => REG_LUT_DATA, -- 20 bits
    doutb => s_51N_bram_doutb -- 20 bits
  );

  -- ==================================================================================================
  -- Instância das protecoes temporizadas 47 
  -- ==================================================================================================
  -- =========================
  -- 47 - STAGE 1
  -- =========================
  inst_prot_47_stg1 : ProtVoltageUmbalanceNegSeq_47
  generic map(
    G_CLK_HZ    => 100_000_000,
    G_HYST_VUF  => 5,
    G_ADDR_BITS => 12,
    G_DATA_BITS => 20
  )
  port map
  (
    i_clk        => s_clk1,
    i_rst        => s_rst_47_stg1,
    i_seq2_abs   => std_logic_vector(s_seq2_abs),
    i_seq1_abs   => std_logic_vector(s_seq1_abs),
    i_valid_seq  => s_seq_valid,
    i_pickup_vuf => REG_47_STG1_VPU_U11, -- core_regis
    o_ram_addr   => s_47_ram_addr_stg1,
    o_ram_rd_req => s_47_ram_rd_req_stg1,
    i_ram_data   => s_47_stg1_bram_douta,
    o_vuf        => REG_47_STG1_VUF_U11,
    o_time_ms    => REG_47_STG1_TIME_MS,
    o_trip       => s_trip_47_stg1
  );
  s_rst_47_stg1       <= (sRst or not(REG_47_STG1_EN(0)));
  REG_47_STG1_TRIP(0) <= s_trip_47_stg1;

  inst_bram0_47 : blk_mem_gen_0
  port map
  (
    -- Porta A
    clka  => s_clk1,
    ena   => '1',
    wea   => s_47_stg1_bram_wea, -- "0" = somente leitura (ROM via COE)
    addra => s_47_ram_addr_stg1, -- 11 bits
    dina  => s_47_stg1_bram_dina, -- 20 bits (não usado se wea="0")
    douta => s_47_stg1_bram_douta, -- 20 bits

    -- Porta B
    clkb  => s_clk1,
    enb   => '1',
    web   => REG_47_STG1_LUT_WR_EN, -- "0" = somente leitura
    addrb => REG_47_STG1_LUT_ADDR, -- 11 bits
    dinb  => REG_47_STG1_LUT_DATA, -- 20 bits
    doutb => s_47_bram_doutb_stg1 -- 20 bits
  );

  --==================================================================================================
  --Instância das proteções de tensão 27 (Subtensão) - usando RMS (aux4,5,6)
  --==================================================================================================
  --=========================
  --27 (fase tensao, usa VAUX3-AUX6 for A/B/C)
  --=========================

  -- FASE A – STAGE 1
  inst_prot_27_A_stg1 : ProtectUnderVoltage_27
  generic map(
    G_MS_TICKS => 100_000,
    G_HYST_U12 => 10
  )
  port map
  (
    i_clk               => s_clk1,
    i_rst               => s_rst_27_A_stg1,
    i_vsample_u12       => s_rms_aux_6(11 downto 0),
    i_valid             => s_rms_aux_6_valid,
    i_peakup_u12        => REG_VA_27_STG1_PEAK_U12,
    i_intentional_delay => REG_VA_27_STG1_INTDLY_MS,
    o_trip              => s_trip_27_A_stg1
  );
  s_rst_27_A_stg1 <= (sRst or not(REG_VA_EN27_STG1(0)));

  -- FASE A – STAGE 2
  inst_prot_27_A_stg2 : ProtectUnderVoltage_27
  generic map(
    G_MS_TICKS => 100_000,
    G_HYST_U12 => 10
  )
  port map
  (
    i_clk               => s_clk1,
    i_rst               => s_rst_27_A_stg2,
    i_vsample_u12       => s_rms_aux_6(11 downto 0),
    i_valid             => s_rms_aux_6_valid,
    i_peakup_u12        => REG_VA_27_STG2_PEAK_U12,
    i_intentional_delay => REG_VA_27_STG2_INTDLY_MS,
    o_trip              => s_trip_27_A_stg2
  );
  s_rst_27_A_stg2 <= (sRst or not(REG_VA_EN27_STG2(0)));

  -- FASE B – STAGE 1
  inst_prot_27_B_stg1 : ProtectUnderVoltage_27
  generic map(
    G_MS_TICKS => 100_000,
    G_HYST_U12 => 10
  )
  port map
  (
    i_clk               => s_clk1,
    i_rst               => s_rst_27_B_stg1,
    i_vsample_u12       => s_rms_aux_5(11 downto 0),
    i_valid             => s_rms_aux_5_valid,
    i_peakup_u12        => REG_VB_27_STG1_PEAK_U12,
    i_intentional_delay => REG_VB_27_STG1_INTDLY_MS,
    o_trip              => s_trip_27_B_stg1
  );
  s_rst_27_B_stg1 <= (sRst or not(REG_VB_EN27_STG1(0)));

  -- FASE B – STAGE 2
  inst_prot_27_B_stg2 : ProtectUnderVoltage_27
  generic map(
    G_MS_TICKS => 100_000,
    G_HYST_U12 => 10
  )
  port map
  (
    i_clk               => s_clk1,
    i_rst               => s_rst_27_B_stg2,
    i_vsample_u12       => s_rms_aux_5(11 downto 0),
    i_valid             => s_rms_aux_5_valid,
    i_peakup_u12        => REG_VB_27_STG2_PEAK_U12,
    i_intentional_delay => REG_VB_27_STG2_INTDLY_MS,
    o_trip              => s_trip_27_B_stg2
  );
  s_rst_27_B_stg2 <= (sRst or not(REG_VB_EN27_STG2(0)));

  -- FASE C – STAGE 1
  inst_prot_27_C_stg1 : ProtectUnderVoltage_27
  generic map(
    G_MS_TICKS => 100_000,
    G_HYST_U12 => 10
  )
  port map
  (
    i_clk               => s_clk1,
    i_rst               => s_rst_27_C_stg1,
    i_vsample_u12       => s_rms_aux_4(11 downto 0),
    i_valid             => s_rms_aux_4_valid,
    i_peakup_u12        => REG_VC_27_STG1_PEAK_U12,
    i_intentional_delay => REG_VC_27_STG1_INTDLY_MS,
    o_trip              => s_trip_27_C_stg1
  );
  s_rst_27_C_stg1 <= (sRst or not(REG_VC_EN27_STG1(0)));

  -- FASE C – STAGE 2
  inst_prot_27_C_stg2 : ProtectUnderVoltage_27
  generic map(
    G_MS_TICKS => 100_000,
    G_HYST_U12 => 10
  )
  port map
  (
    i_clk               => s_clk1,
    i_rst               => s_rst_27_C_stg2,
    i_vsample_u12       => s_rms_aux_4(11 downto 0),
    i_valid             => s_rms_aux_4_valid,
    i_peakup_u12        => REG_VC_27_STG2_PEAK_U12,
    i_intentional_delay => REG_VC_27_STG2_INTDLY_MS,
    o_trip              => s_trip_27_C_stg2
  );
  s_rst_27_C_stg2 <= (sRst or not(REG_VC_EN27_STG2(0)));

  -- ==================================================================================================
  -- Instância das proteções de tensão 59 (Sobretensão) - usando RMS (aux4,5,6)
  -- ==================================================================================================
  -- =========================
  -- 59 (fase tensão, usa VAUX4-AUX6 for A/B/C)
  -- =========================

  -- FASE A – STAGE 1
  inst_prot_59_A_stg1 : ProtectOverVoltage_59
  generic map(
    G_MS_TICKS => 100_000,
    G_HYST_U12 => 10
  )
  port map
  (
    i_clk               => s_clk1,
    i_rst               => s_rst_59_A_stg1,
    i_vsample_u12       => s_rms_aux_6(11 downto 0),
    i_valid             => s_rms_aux_6_valid,
    i_peakup_u12        => REG_VA_59_STG1_PEAK_U12,
    i_intentional_delay => REG_VA_59_STG1_INTDLY_MS,
    o_trip              => s_trip_59_A_stg1
  );
  s_rst_59_A_stg1 <= (sRst or not(REG_VA_EN59_STG1(0)));

  -- FASE A – STAGE 2
  inst_prot_59_A_stg2 : ProtectOverVoltage_59
  generic map(
    G_MS_TICKS => 100_000,
    G_HYST_U12 => 10
  )
  port map
  (
    i_clk               => s_clk1,
    i_rst               => s_rst_59_A_stg2,
    i_vsample_u12       => s_rms_aux_6(11 downto 0),
    i_valid             => s_rms_aux_6_valid,
    i_peakup_u12        => REG_VA_59_STG2_PEAK_U12,
    i_intentional_delay => REG_VA_59_STG2_INTDLY_MS,
    o_trip              => s_trip_59_A_stg2
  );
  s_rst_59_A_stg2 <= (sRst or not(REG_VA_EN59_STG2(0)));

  -- FASE B – STAGE 1
  inst_prot_59_B_stg1 : ProtectOverVoltage_59
  generic map(
    G_MS_TICKS => 100_000,
    G_HYST_U12 => 10
  )
  port map
  (
    i_clk               => s_clk1,
    i_rst               => s_rst_59_B_stg1,
    i_vsample_u12       => s_rms_aux_5(11 downto 0),
    i_valid             => s_rms_aux_5_valid,
    i_peakup_u12        => REG_VB_59_STG1_PEAK_U12,
    i_intentional_delay => REG_VB_59_STG1_INTDLY_MS,
    o_trip              => s_trip_59_B_stg1
  );
  s_rst_59_B_stg1 <= (sRst or not(REG_VB_EN59_STG1(0)));

  -- FASE B – STAGE 2
  inst_prot_59_B_stg2 : ProtectOverVoltage_59
  generic map(
    G_MS_TICKS => 100_000,
    G_HYST_U12 => 10
  )
  port map
  (
    i_clk               => s_clk1,
    i_rst               => s_rst_59_B_stg2,
    i_vsample_u12       => s_rms_aux_5(11 downto 0),
    i_valid             => s_rms_aux_5_valid,
    i_peakup_u12        => REG_VB_59_STG2_PEAK_U12,
    i_intentional_delay => REG_VB_59_STG2_INTDLY_MS,
    o_trip              => s_trip_59_B_stg2
  );
  s_rst_59_B_stg2 <= (sRst or not(REG_VB_EN59_STG2(0)));

  -- FASE C – STAGE 1
  inst_prot_59_C_stg1 : ProtectOverVoltage_59
  generic map(
    G_MS_TICKS => 100_000,
    G_HYST_U12 => 10
  )
  port map
  (
    i_clk               => s_clk1,
    i_rst               => s_rst_59_C_stg1,
    i_vsample_u12       => s_rms_aux_4(11 downto 0),
    i_valid             => s_rms_aux_4_valid,
    i_peakup_u12        => REG_VC_59_STG1_PEAK_U12,
    i_intentional_delay => REG_VC_59_STG1_INTDLY_MS,
    o_trip              => s_trip_59_C_stg1
  );
  s_rst_59_C_stg1 <= (sRst or not(REG_VC_EN59_STG1(0)));

  -- FASE C – STAGE 2
  inst_prot_59_C_stg2 : ProtectOverVoltage_59
  generic map(
    G_MS_TICKS => 100_000,
    G_HYST_U12 => 10
  )
  port map
  (
    i_clk               => s_clk1,
    i_rst               => s_rst_59_C_stg2,
    i_vsample_u12       => s_rms_aux_4(11 downto 0),
    i_valid             => s_rms_aux_4_valid,
    i_peakup_u12        => REG_VC_59_STG2_PEAK_U12,
    i_intentional_delay => REG_VC_59_STG2_INTDLY_MS,
    o_trip              => s_trip_59_C_stg2
  );
  s_rst_59_C_stg2 <= (sRst or not(REG_VC_EN59_STG2(0)));

  -- ==================================================================================================
	-- Instância das proteções de tensão 81U/O -  terá que ser feito para (aux4,5,6) -- Pegarei saída do bloco de fasor de Tensão
	-- ==================================================================================================
	-- =============================================================
	-- Estimador de frequência - Fase A
	-- =============================================================
  inst_freqdiff_A: freq_diff_from_phasor_sliding64
	  generic map (
		ANG_WIDTH => 16,
		ANG_FRAC  => 13,
		M         => 64,
		FS_HZ     => 3844
	  )
	  port map (
		i_clk          => s_clk1,
		i_rst          => sRst,
		i_valid_phasor => s_ph_valid_phaseA,   -- fasor fase A
		i_phase_q13    => s_ph_phase_phaseA,
		o_valid        => s_freq_diff_valid_A,
		o_dphi_q13     => s_freq_diff_dphi_q13_A,
		o_dtheta64_q13 => s_freq_diff_dtheta64_q13_A,
		o_dfreq_mHz    => s_freq_diff_dfreq_mHz_A
	  );

	-- =============================================================
	-- Estimador de frequência - Fase B
	-- =============================================================
	inst_freqdiff_B: freq_diff_from_phasor_sliding64
	  generic map (
		ANG_WIDTH => 16,
		ANG_FRAC  => 13,
		M         => 64,
		FS_HZ     => 3844
	  )
	  port map (
		i_clk          => s_clk1,
		i_rst          => sRst,
		i_valid_phasor => s_ph_valid_phaseB,   -- fasor fase B
		i_phase_q13    => s_ph_phase_phaseB,
		o_valid        => s_freq_diff_valid_B,
		o_dphi_q13     => s_freq_diff_dphi_q13_B,
		o_dtheta64_q13 => s_freq_diff_dtheta64_q13_B,
		o_dfreq_mHz    => s_freq_diff_dfreq_mHz_B
	  );

	-- =============================================================
	-- Estimador de frequência - Fase C
	-- =============================================================
	inst_freqdiff_C: freq_diff_from_phasor_sliding64
	  generic map (
		ANG_WIDTH => 16,
		ANG_FRAC  => 13,
		M         => 64,
		FS_HZ     => 3844
	  )
	  port map (
		i_clk          => s_clk1,
		i_rst          => sRst,
		i_valid_phasor => s_ph_valid_phaseC,   -- fasor fase C
		i_phase_q13    => s_ph_phase_phaseC,
		o_valid        => s_freq_diff_valid_C,
		o_dphi_q13     => s_freq_diff_dphi_q13_C,
		o_dtheta64_q13 => s_freq_diff_dtheta64_q13_C,
		o_dfreq_mHz    => s_freq_diff_dfreq_mHz_C
	  );

	-- =============================================================
	-- Proteção 81 - Fase A
	-- =============================================================
	inst_prot81_A : Protect81_Channel
	generic map (
	  G_CLK_TICKS_PER_MS => 100_000,
	  G_DATA_WIDTH       => 32,
	  G_TIME_WIDTH       => 20
	)
	port map(
	  i_clk                  => s_clk1,
	  i_rst                  => s_rst_81, ----LEMBRAR DE VOLTAR QUANDO TIVER COM O PROCESSADOR
	  i_valid                => s_freq_diff_valid_A,   -- freq fase A
	  i_dfreq_mHz            => s_freq_diff_dfreq_mHz_A,
      -- i_pickup_under_e1_mHz  => to_signed(1500, 32), -- 58.5 Hz
      -- i_pickup_over_e1_mHz   => to_signed(1500, 32), -- 61.5 Hz
      -- i_margin_e2_mHz        => to_signed(1000, 32), -- +1 Hz para E2
      -- i_hyst_mHz             => to_signed(200, 32),  -- histerese (200 mHz)
      -- i_delay_e1_ms          => to_unsigned(1000, 20), -- 1 segundo
      -- i_delay_e2_ms          => to_unsigned(50, 20),   -- 50 ms
      -- i_init_time_ms         => to_unsigned(20, 20),   -- 20 ms
	  i_pickup_under_e1_mHz  => signed(REG_81_PICKUP_UNDER_E1_MHZ), -- Com o processador tem que trabalhar dessa forma
	  i_pickup_over_e1_mHz   => signed(REG_81_PICKUP_OVER_E1_MHZ),
	  i_margin_e2_mHz        => signed(REG_81_MARGIN_E2_MHZ),
	  i_hyst_mHz             => signed(REG_81_HYST_MHZ),
	  i_delay_e1_ms          => unsigned(REG_81_DELAY_E1_MS),
	  i_delay_e2_ms          => unsigned(REG_81_DELAY_E2_MS),
	  i_init_time_ms         => unsigned(REG_81_INIT_TIME_MS),
	  o_alarm_e1             => s_prot_81_faseA_alarm_e1,
	  o_alarm_e2             => s_prot_81_faseA_alarm_e2,
	  o_trip_e1              => s_prot_81_faseA_trip_e1,
	  o_trip_e2              => s_prot_81_faseA_trip_e2,
	  o_trip_81              => s_trip_81_A
	);


	-- =============================================================
	-- Proteção 81 - Fase B
	-- =============================================================
	inst_prot81_B : Protect81_Channel
	generic map (
	  G_CLK_TICKS_PER_MS => 100_000,
	  G_DATA_WIDTH       => 32,
	  G_TIME_WIDTH       => 20
	)
	port map(
	  i_clk                  => s_clk1,
	  i_rst                  => s_rst_81,
	  i_valid                => s_freq_diff_valid_B,   -- freq fase B
	  i_dfreq_mHz            => s_freq_diff_dfreq_mHz_B,
	  i_pickup_under_e1_mHz  => signed(REG_81_PICKUP_UNDER_E1_MHZ),
	  i_pickup_over_e1_mHz   => signed(REG_81_PICKUP_OVER_E1_MHZ),
	  i_margin_e2_mHz        => signed(REG_81_MARGIN_E2_MHZ),
	  i_hyst_mHz             => signed(REG_81_HYST_MHZ),
	  i_delay_e1_ms          => unsigned(REG_81_DELAY_E1_MS),
	  i_delay_e2_ms          => unsigned(REG_81_DELAY_E2_MS),
	  i_init_time_ms         => unsigned(REG_81_INIT_TIME_MS),
	  o_alarm_e1             => s_prot_81_faseB_alarm_e1,
	  o_alarm_e2             => s_prot_81_faseB_alarm_e2,
	  o_trip_e1              => s_prot_81_faseB_trip_e1,
	  o_trip_e2              => s_prot_81_faseB_trip_e2,
	  o_trip_81              => s_trip_81_B
	);


	-- =============================================================
	-- Proteção 81 - Fase C
	-- =============================================================
	inst_prot81_C : Protect81_Channel
	generic map (
	  G_CLK_TICKS_PER_MS => 100_000,
	  G_DATA_WIDTH       => 32,
	  G_TIME_WIDTH       => 20
	)
	port map(
	  i_clk                  => s_clk1,
	  i_rst                  => s_rst_81,
	  i_valid                => s_freq_diff_valid_C,   -- freq fase C
	  i_dfreq_mHz            => s_freq_diff_dfreq_mHz_C,
	  i_pickup_under_e1_mHz  => signed(REG_81_PICKUP_UNDER_E1_MHZ),
	  i_pickup_over_e1_mHz   => signed(REG_81_PICKUP_OVER_E1_MHZ),
	  i_margin_e2_mHz        => signed(REG_81_MARGIN_E2_MHZ),
	  i_hyst_mHz             => signed(REG_81_HYST_MHZ),
	  i_delay_e1_ms          => unsigned(REG_81_DELAY_E1_MS),
	  i_delay_e2_ms          => unsigned(REG_81_DELAY_E2_MS),
	  i_init_time_ms         => unsigned(REG_81_INIT_TIME_MS),
	  o_alarm_e1             => s_prot_81_faseC_alarm_e1,
	  o_alarm_e2             => s_prot_81_faseC_alarm_e2,
	  o_trip_e1              => s_prot_81_faseC_trip_e1,
	  o_trip_e2              => s_prot_81_faseC_trip_e2,
	  o_trip_81              => s_trip_81_C
	);
  s_rst_81 <= (sRst or not(REG_81_EN(0)));	  

  -- ==================================================================================================
	-- Instância das proteções de tensão 81R -  terá que ser feito para (aux4,5,6) -- Pegarei saída do bloco de fasor de Tensão
	-- ==================================================================================================				  
	--  -- =============================================================
	--  -- ROCOF a partir de dfreq em mHz - Fase A
	--  -- =============================================================
	--  inst_rocofdf_A : rocof_from_dfreq
	--	generic map (
	--	  DATA_WIDTH => 32,
	--	  WIN_SIZE   => 128,
	--	  IIR_SH     => 6
	--	)
	--	port map (
	--	  i_clk       				=> s_clk1,
	--	  i_rst       				=> sRst,
	--	  i_valid     				=> s_freq_diff_valid_A,
	--	  i_dfreq_mHz 				=> s_freq_diff_dfreq_mHz_A,
	--	  o_valid                   => s_rocofdf_valid_A,
	--	  o_dfreq_filt_mHz 			=> s_rocofdf_dfreq_filt_mHz_A,
	--	  o_rocof_diff_1samp_mHz 	=> s_rocofdf_diff_1samp_mHz_A,
	--	  o_rocof_diff_win_mHz   	=> s_rocofdf_diff_win_mHz_A
	--	);
	---- =============================================================
	---- Protecao ANSI 81R - Fase A
	---- =============================================================
	--inst_Protect81R_A : Protect81R_Channel
	--	generic map (
	--	  G_CLK_TICKS_PER_MS => 100000, -- s_clk1 = 100 MHz
	--	  G_DATA_WIDTH       => 32,
	--	  G_TIME_WIDTH       => 20
	--	)
	--	port map (
	--	  i_clk  => s_clk1,
	--
	--	  -- Por enquanto, reset geral.
	--	  -- Depois pode usar: sRst or not(REG_81R_EN(0))
	--	  i_rst  => sRst,
	--
	--	  i_valid              => s_rocofdf_valid_A,
	--	  i_rocof_diff_win_mHz => s_rocofdf_diff_win_mHz_A,
	--
	--	  -- Valores fixos iniciais para teste:
	--	  -- E1 = 1 Hz/s  -> 33 mHz/janela
	--	  -- E2 = 10 Hz/s -> 333 mHz/janela
	--	  -- Histerese = 1 Hz/s -> 33 mHz/janela
	--	  i_pickup_e1_mHz_win  => to_signed(33, 32),
	--	  i_pickup_e2_mHz_win  => to_signed(333, 32),
	--	  i_hyst_mHz_win       => to_signed(10, 32),
	--
	--	  -- Temporizacoes iniciais
	--	  i_delay_e1_ms        => to_unsigned(200, 20),
	--	  i_delay_e2_ms        => to_unsigned(50, 20),
	--	  i_init_time_ms       => to_unsigned(100, 20),
	--
	--	  o_alarm_e1           => s_prot_81R_faseA_alarm_e1,
	--	  o_alarm_e2           => s_prot_81R_faseA_alarm_e2,
	--
	--	  o_trip_e1            => s_prot_81R_faseA_trip_e1,
	--	  o_trip_e2            => s_prot_81R_faseA_trip_e2,
	--	  o_trip_81R           => s_trip_81R_A,
	--
	--	  o_rocof_abs_mHz_win  => s_rocofdf_abs_mHz_win_A
	--	);
		
		
	-- =============================================================
	-- Estimador de ROCOF a partir do desvio de frequencia - Fase A
	-- =============================================================
	inst_rocofdf_A : rocof_from_dfreq
		generic map (
		DATA_WIDTH => 32,
		WIN_SIZE   => 128,
		IIR_SH     => 6
		)
		port map (
		i_clk                     => s_clk1,
		i_rst                     => sRst,
		i_valid                   => s_freq_diff_valid_A,
		i_dfreq_mHz               => s_freq_diff_dfreq_mHz_A,
		o_valid                   => s_rocofdf_valid_A,
		o_dfreq_filt_mHz          => s_rocofdf_dfreq_filt_mHz_A,
		o_rocof_diff_1samp_mHz    => s_rocofdf_diff_1samp_mHz_A,
		o_rocof_diff_win_mHz      => s_rocofdf_diff_win_mHz_A
		);
	
	-- =============================================================
	-- Estimador de ROCOF a partir do desvio de frequencia - Fase B
	-- =============================================================
	inst_rocofdf_B : rocof_from_dfreq
		generic map (
		DATA_WIDTH => 32,
		WIN_SIZE   => 128,
		IIR_SH     => 6
		)
		port map (
		i_clk                     => s_clk1,
		i_rst                     => sRst,
		i_valid                   => s_freq_diff_valid_B,
		i_dfreq_mHz               => s_freq_diff_dfreq_mHz_B,
		o_valid                   => s_rocofdf_valid_B,
		o_dfreq_filt_mHz          => s_rocofdf_dfreq_filt_mHz_B,
		o_rocof_diff_1samp_mHz    => s_rocofdf_diff_1samp_mHz_B,
		o_rocof_diff_win_mHz      => s_rocofdf_diff_win_mHz_B
		);
	
	-- =============================================================
	-- Estimador de ROCOF a partir do desvio de frequencia - Fase C
	-- =============================================================
	inst_rocofdf_C : rocof_from_dfreq
		generic map (
		DATA_WIDTH => 32,
		WIN_SIZE   => 128,
		IIR_SH     => 6
		)
		port map (
		i_clk                     => s_clk1,
		i_rst                     => sRst,
		i_valid                   => s_freq_diff_valid_C,
		i_dfreq_mHz               => s_freq_diff_dfreq_mHz_C,
		o_valid                   => s_rocofdf_valid_C,
		o_dfreq_filt_mHz          => s_rocofdf_dfreq_filt_mHz_C,
		o_rocof_diff_1samp_mHz    => s_rocofdf_diff_1samp_mHz_C,
		o_rocof_diff_win_mHz      => s_rocofdf_diff_win_mHz_C
		);
	
	
	-- =============================================================
	-- Protecao ANSI 81R - Fase A
	-- =============================================================
  s_rst_81R <= sRst or (not REG_81R_EN(0));
	inst_Protect81R_A : Protect81R_Channel
		generic map (
		G_CLK_TICKS_PER_MS => 100000, -- s_clk1 = 100 MHz
		G_DATA_WIDTH       => 32,
		G_TIME_WIDTH       => 20
		)
		port map (
		i_clk  => s_clk1,
	
		-- Reset geral da funcao 81R.
		-- Se ainda nao declarou s_rst_81R, pode usar sRst temporariamente.
		-- Recomendado:
		--   s_rst_81R <= sRst or (not REG_81R_EN(0));
		i_rst  => s_rst_81R,  ----------------------------------------------------------sRst or (not REG_81R_EN(0))
	
		i_valid              => s_rocofdf_valid_A,
		i_rocof_diff_win_mHz => s_rocofdf_diff_win_mHz_A,
	
		-- Valores fixos iniciais para teste:
		-- E1 = 1 Hz/s   ->  33 mHz/janela
		-- E2 = 10 Hz/s  -> 333 mHz/janela
		-- Histerese ~0,3 Hz/s -> 10 mHz/janela
		-- i_pickup_e1_mHz_win  => to_signed(33, 32),
		-- i_pickup_e2_mHz_win  => to_signed(333, 32),
		-- i_hyst_mHz_win       => to_signed(10, 32),
		-- i_delay_e1_ms        => to_unsigned(200, 20),
		-- i_delay_e2_ms        => to_unsigned(50, 20),
		-- i_init_time_ms       => to_unsigned(100, 20),
		i_pickup_e1_mHz_win  => signed(REG_81R_PICKUP_E1_MHZ_WIN), ---- QUANDO TIVER OS REGISTROS SUBSTITUIR PELAS LINHAS ACIMA e o RST
		i_pickup_e2_mHz_win  => signed(REG_81R_PICKUP_E2_MHZ_WIN),
		i_hyst_mHz_win       => signed(REG_81R_HYST_MHZ_WIN),
		i_delay_e1_ms        => unsigned(REG_81R_DELAY_E1_MS),
		i_delay_e2_ms        => unsigned(REG_81R_DELAY_E2_MS),
		i_init_time_ms       => unsigned(REG_81R_INIT_TIME_MS),
		o_alarm_e1           => s_prot_81R_faseA_alarm_e1,
		o_alarm_e2           => s_prot_81R_faseA_alarm_e2,
		o_trip_e1            => s_prot_81R_faseA_trip_e1,
		o_trip_e2            => s_prot_81R_faseA_trip_e2,
		o_trip_81R           => s_trip_81R_A,
		o_rocof_abs_mHz_win  => s_rocofdf_abs_mHz_win_A
		);
	-- =============================================================
	-- Protecao ANSI 81R - Fase B
	-- =============================================================
	inst_Protect81R_B : Protect81R_Channel
		generic map (
		G_CLK_TICKS_PER_MS => 100000, -- s_clk1 = 100 MHz
		G_DATA_WIDTH       => 32,
		G_TIME_WIDTH       => 20
		)
		port map (
		i_clk  => s_clk1,
		i_rst  => s_rst_81R,
		i_valid              => s_rocofdf_valid_B,
		i_rocof_diff_win_mHz => s_rocofdf_diff_win_mHz_B,
		i_pickup_e1_mHz_win  => signed(REG_81R_PICKUP_E1_MHZ_WIN),
		i_pickup_e2_mHz_win  => signed(REG_81R_PICKUP_E2_MHZ_WIN),
		i_hyst_mHz_win       => signed(REG_81R_HYST_MHZ_WIN),
		i_delay_e1_ms        => unsigned(REG_81R_DELAY_E1_MS),
		i_delay_e2_ms        => unsigned(REG_81R_DELAY_E2_MS),
		i_init_time_ms       => unsigned(REG_81R_INIT_TIME_MS),
		o_alarm_e1           => s_prot_81R_faseB_alarm_e1,
		o_alarm_e2           => s_prot_81R_faseB_alarm_e2,
		o_trip_e1            => s_prot_81R_faseB_trip_e1,
		o_trip_e2            => s_prot_81R_faseB_trip_e2,
		o_trip_81R           => s_trip_81R_B,
		o_rocof_abs_mHz_win  => s_rocofdf_abs_mHz_win_B
		);
    
	
	-- =============================================================
	-- Protecao ANSI 81R - Fase C
	-- =============================================================
	inst_Protect81R_C : Protect81R_Channel
		generic map (
		G_CLK_TICKS_PER_MS => 100000, -- s_clk1 = 100 MHz
		G_DATA_WIDTH       => 32,
		G_TIME_WIDTH       => 20
		)
		port map (
		i_clk  => s_clk1,
		i_rst  => s_rst_81R,
		i_valid              => s_rocofdf_valid_C,
		i_rocof_diff_win_mHz => s_rocofdf_diff_win_mHz_C,
		i_pickup_e1_mHz_win  => signed(REG_81R_PICKUP_E1_MHZ_WIN),
		i_pickup_e2_mHz_win  => signed(REG_81R_PICKUP_E2_MHZ_WIN),
		i_hyst_mHz_win       => signed(REG_81R_HYST_MHZ_WIN),
		i_delay_e1_ms        => unsigned(REG_81R_DELAY_E1_MS),
		i_delay_e2_ms        => unsigned(REG_81R_DELAY_E2_MS),
		i_init_time_ms       => unsigned(REG_81R_INIT_TIME_MS),
		o_alarm_e1           => s_prot_81R_faseC_alarm_e1,
		o_alarm_e2           => s_prot_81R_faseC_alarm_e2,
		o_trip_e1            => s_prot_81R_faseC_trip_e1,
		o_trip_e2            => s_prot_81R_faseC_trip_e2,
		o_trip_81R           => s_trip_81R_C,
	
		o_rocof_abs_mHz_win  => s_rocofdf_abs_mHz_win_C
		);
 
  ---------------------------------------
  ----- Atuação do Trip Global
  ---------------------------------------
  s_GlobalTrip <= (s_trip_50_A or s_trip_50_B or s_trip_50_C or s_trip_50N or s_trip_51_A or s_trip_51_B or s_trip_51_C or s_trip_51N or
    s_trip_27_A_stg1 or s_trip_27_A_stg2 or s_trip_27_B_stg1 or s_trip_27_B_stg2 or s_trip_27_C_stg1 or s_trip_27_C_stg2 or
    s_trip_59_A_stg1 or s_trip_59_A_stg2 or s_trip_59_B_stg1 or s_trip_59_B_stg2 or s_trip_59_C_stg1 or s_trip_59_C_stg2 );

    -- s_GlobalTrip <= (s_trip_50_A or s_trip_50_B or s_trip_50_C or s_trip_50N or s_trip_51_A or s_trip_51_B or s_trip_51_C or s_trip_51N or
    -- s_trip_27_A_stg1 or s_trip_27_A_stg2 or s_trip_27_B_stg1 or s_trip_27_B_stg2 or s_trip_27_C_stg1 or s_trip_27_C_stg2 or
    -- s_trip_59_A_stg1 or s_trip_59_A_stg2 or s_trip_59_B_stg1 or s_trip_59_B_stg2 or s_trip_59_C_stg1 or s_trip_59_C_stg2 or 
    -- s_trip_46_stg1 or s_trip_46Temp_stg1 or s_trip_47_stg1 or s_trip_81_A or s_trip_81_B or s_trip_81_C or s_trip_81R_A or s_trip_81R_B or s_trip_81R_C or REG_FORCE_GLOBAL_TRIP);

  ------------------------------------
  ---- Leitura para monitoramento
  ------------------------------------
  -- Trip 50 51
  s_in_Port_032(7 downto 0) <= (0 => s_trip_50_A, 1 => s_trip_50_B, 2 => s_trip_50_C, 3 => s_trip_50N, 4 => s_trip_51_A, 5 => s_trip_51_B, 6 => s_trip_51_C, 7 => s_trip_51N);
  -- RMS correntes fases A,B,C,N
  REG_A_RMS_U12  <= s_rms_aux_0(11 downto 0); --IA
  REG_B_RMS_U12  <= s_rms_aux_1(11 downto 0); --IB
  REG_C_RMS_U12  <= s_rms_aux_2(11 downto 0); --IC
  REG_N_RMS_U12  <= s_rms_aux_3(11 downto 0); --IN

  -- Trip tensões 27/59 – fases A/B/C com respectivos estágios
  s_in_Port_068(11 downto 0) <= (0 => s_trip_27_A_stg1, 1 => s_trip_27_A_stg2, 2 => s_trip_27_B_stg1, 3 => s_trip_27_B_stg2, 4 => s_trip_27_C_stg1, 5 => s_trip_27_C_stg2,
  6 => s_trip_59_A_stg1, 7 => s_trip_59_A_stg2, 8 => s_trip_59_B_stg1, 9 => s_trip_59_B_stg2, 10 => s_trip_59_C_stg1, 11 => s_trip_59_C_stg2);
  -- RMS tensões – VA (aux4) e VB (aux5)
  REG_VA_RMS_U12  <= s_rms_aux_6(11 downto 0); -- VA
  REG_VB_RMS_U12  <= s_rms_aux_5(11 downto 0); -- VB
  REG_VC_RMS_U12  <= s_rms_aux_4(11 downto 0); -- VC

  -- Trips e alarmes da 81 mais sinais de monitoramento
  -- Fase A
    REG_81_A_ALARM_E1 <= s_prot_81_faseA_alarm_e1;
    REG_81_A_ALARM_E2 <= s_prot_81_faseA_alarm_e2;
    REG_81_A_TRIP_E1  <= s_prot_81_faseA_trip_e1;
    REG_81_A_TRIP_E2  <= s_prot_81_faseA_trip_e2;
    REG_81_A_TRIP     <= s_trip_81_A;
    -- Fase B
    REG_81_B_ALARM_E1 <= s_prot_81_faseB_alarm_e1;
    REG_81_B_ALARM_E2 <= s_prot_81_faseB_alarm_e2;
    REG_81_B_TRIP_E1  <= s_prot_81_faseB_trip_e1;
    REG_81_B_TRIP_E2  <= s_prot_81_faseB_trip_e2;
    REG_81_B_TRIP     <= s_trip_81_B;
    -- Fase C
    REG_81_C_ALARM_E1 <= s_prot_81_faseC_alarm_e1;
    REG_81_C_ALARM_E2 <= s_prot_81_faseC_alarm_e2;
    REG_81_C_TRIP_E1  <= s_prot_81_faseC_trip_e1;
    REG_81_C_TRIP_E2  <= s_prot_81_faseC_trip_e2;
    REG_81_C_TRIP     <= s_trip_81_C;

  REG_81_A_FREQ_DIFF_MHZ <= std_logic_vector(s_freq_diff_dfreq_mHz_A);
  REG_81_B_FREQ_DIFF_MHZ <= std_logic_vector(s_freq_diff_dfreq_mHz_B);
  REG_81_C_FREQ_DIFF_MHZ <= std_logic_vector(s_freq_diff_dfreq_mHz_C);
  
  -- Monitoramento 81R
  -- Fase A 
  REG_81R_A_ALARM_E1 <= s_prot_81R_faseA_alarm_e1;
  REG_81R_A_ALARM_E2 <= s_prot_81R_faseA_alarm_e2;
  REG_81R_A_TRIP_E1  <= s_prot_81R_faseA_trip_e1;
  REG_81R_A_TRIP_E2  <= s_prot_81R_faseA_trip_e2;
  REG_81R_A_TRIP     <= s_trip_81R_A;
  -- Fase B
  REG_81R_B_ALARM_E1 <= s_prot_81R_faseB_alarm_e1;
  REG_81R_B_ALARM_E2 <= s_prot_81R_faseB_alarm_e2;
  REG_81R_B_TRIP_E1  <= s_prot_81R_faseB_trip_e1;
  REG_81R_B_TRIP_E2  <= s_prot_81R_faseB_trip_e2;
  REG_81R_B_TRIP     <= s_trip_81R_B;
  -- Fase C
  REG_81R_C_ALARM_E1 <= s_prot_81R_faseC_alarm_e1;
  REG_81R_C_ALARM_E2 <= s_prot_81R_faseC_alarm_e2;
  REG_81R_C_TRIP_E1  <= s_prot_81R_faseC_trip_e1;
  REG_81R_C_TRIP_E2  <= s_prot_81R_faseC_trip_e2;
  REG_81R_C_TRIP     <= s_trip_81R_C;
  
   -- Valor absoluto do ROCOF usado pela 81R - fase A
  REG_81R_A_ROCOF <= std_logic_vector(s_rocofdf_abs_mHz_win_A);
  REG_81R_B_ROCOF <= std_logic_vector(s_rocofdf_abs_mHz_win_B);
  REG_81R_C_ROCOF <= std_logic_vector(s_rocofdf_abs_mHz_win_C);
  -------------------------------
  -- instancia do Core regs 
  ------------------------------
  s_rst_core_regs <= (not sRstn);
  inst_CoreRegs : Core_regs
  port map
  (-- {{{
    -- Avalon slave interface
    clk   => s_clk1,
    reset => s_rst_core_regs,
    -- Avalon slave interface
    chipselect => '1',
    write      => s_o_write_tri_o(0),
    address    => s_o_address_tri_o,
    writedata  => s_o_write_data_tri_o,
    read       => s_o_read_tri_o(0),
    readdata   => s_i_readdata_tri_i,
    irq        => open,
    -- Core interface
    -- InPort																{{{
    in_Port_000 => s_out_Port_000, --RW
    in_Port_001 => s_out_Port_001,
    in_Port_002 => s_out_Port_002,
    in_Port_003 => s_out_Port_003,
    in_Port_004 => s_out_Port_004,
    in_Port_005 => s_out_Port_005,
    in_Port_006 => s_out_Port_006,
    in_Port_007 => s_out_Port_007,
    in_Port_008 => s_out_Port_008,
    in_Port_009 => s_out_Port_009,
    in_Port_010 => s_out_Port_010,
    in_Port_011 => s_out_Port_011,
    in_Port_012 => s_out_Port_012,
    in_Port_013 => s_out_Port_013,
    in_Port_014 => s_out_Port_014,
    in_Port_015 => s_out_Port_015,
    in_Port_016 => s_out_Port_016,
    in_Port_017 => s_out_Port_017,
    in_Port_018 => s_out_Port_018,
    in_Port_019 => s_out_Port_019,
    in_Port_020 => s_out_Port_020,
    in_Port_021 => s_out_Port_021,
    in_Port_022 => s_out_Port_022,
    in_Port_023 => s_out_Port_023,
    in_Port_024 => s_out_Port_024,
    in_Port_025 => s_out_Port_025,
    in_Port_026 => s_out_Port_026,
    in_Port_027 => s_out_Port_027,
    in_Port_028 => s_out_Port_028,
    in_Port_029 => s_out_Port_029,
    in_Port_030 => s_out_Port_030,
    in_Port_031 => s_out_Port_031,
    -- Read only
    in_Port_032 => s_in_Port_032, --RDO
    in_Port_033 => s_in_Port_033, --RDO
    in_Port_034 => s_in_Port_034, --RDO
    in_Port_035 => s_out_Port_035,
    in_Port_036 => s_out_Port_036,
    in_Port_037 => s_out_Port_037,
    in_Port_038 => s_out_Port_038,
    in_Port_039 => s_out_Port_039,
    in_Port_040 => s_out_Port_040,
    in_Port_041 => s_out_Port_041,
    in_Port_042 => s_out_Port_042,
    in_Port_043 => s_out_Port_043,
    in_Port_044 => s_out_Port_044,
    in_Port_045 => s_out_Port_045,
    in_Port_046 => s_out_Port_046,
    in_Port_047 => s_out_Port_047,
    in_Port_048 => s_out_Port_048,
    in_Port_049 => s_out_Port_049,
    in_Port_050 => s_out_Port_050,
    in_Port_051 => s_out_Port_051,
    in_Port_052 => s_out_Port_052,
    in_Port_053 => s_out_Port_053,
    in_Port_054 => s_out_Port_054,
    in_Port_055 => s_out_Port_055,
    in_Port_056 => s_out_Port_056,
    in_Port_057 => s_out_Port_057,
    in_Port_058 => s_out_Port_058,
    in_Port_059 => s_out_Port_059,
    in_Port_060 => s_out_Port_060,
    in_Port_061 => s_out_Port_061,
    in_Port_062 => s_out_Port_062,
    in_Port_063 => s_out_Port_063,
    in_Port_064 => s_out_Port_064,
    in_Port_065 => s_out_Port_065,
    in_Port_066 => s_out_Port_066,
    in_Port_067 => s_out_Port_067,
    in_Port_068 => s_in_Port_068, --RDO
    in_Port_069 => s_in_Port_069, --RDO
    in_Port_070 => s_in_Port_070, --RDO
    in_Port_071 => s_out_Port_071,
    in_Port_072 => s_out_Port_072,
    in_Port_073 => s_out_Port_073,
    in_Port_074 => s_out_Port_074,
    in_Port_075 => s_in_Port_075, --rdo
    in_Port_076 => s_out_Port_076,
    in_Port_077 => s_out_Port_077,
    in_Port_078 => s_out_Port_078,
    in_Port_079 => s_in_Port_079, --rdo
    in_Port_080 => s_in_Port_080, --rdo
    in_Port_081 => s_out_Port_081,
    in_Port_082 => s_out_Port_082,
    in_Port_083 => s_out_Port_083,
    in_Port_084 => s_out_Port_084,
    in_Port_085 => s_in_Port_085, --rdo
    in_Port_086 => s_out_Port_086,
    in_Port_087 => s_in_Port_087, --rdo
    in_Port_088 => s_in_Port_088, --rdo
    in_Port_089 => s_in_Port_089, --rdo
    in_Port_090 => s_in_Port_090, --rdo
    in_Port_091 => s_in_Port_091, --rdo
    in_Port_092 => s_in_Port_092, --rdo
    in_Port_093 => s_in_Port_093, --rdo
    in_Port_094 => s_in_Port_094, --rdo
    in_Port_095 => s_in_Port_095, --rdo
    in_Port_096 => s_in_Port_096, --rdo
    in_Port_097 => s_in_Port_097, --rdo
    in_Port_098 => s_out_Port_098,
    in_Port_099 => s_out_Port_099,
    in_Port_100 => s_out_Port_100,
    in_Port_101 => s_out_Port_101,
    in_Port_102 => s_out_Port_102,
    in_Port_103 => s_out_Port_103,
    in_Port_104 => s_out_Port_104,
    in_Port_105 => s_out_Port_105,
    in_Port_106 => s_out_Port_106,
    in_Port_107 => s_out_Port_107,
    in_Port_108 => s_out_Port_108,
    in_Port_109 => s_out_Port_109,
    in_Port_110 => s_out_Port_110,
    in_Port_111 => s_out_Port_111,
    in_Port_112 => s_out_Port_112,
    in_Port_113 => s_out_Port_113,
    in_Port_114 => s_out_Port_114,
    in_Port_115 => s_out_Port_115,
    in_Port_116 => s_out_Port_116,
    in_Port_117 => s_out_Port_117,
    in_Port_118 => s_out_Port_118,
    in_Port_119 => s_out_Port_119,
    in_Port_120 => s_out_Port_120,
    in_Port_121 => s_out_Port_121,
    in_Port_122 => s_out_Port_122,
    in_Port_123 => s_out_Port_123,
    in_Port_124 => s_in_Port_124, -- RDO
    in_Port_125 => s_in_Port_125, --RDO
    in_Port_126 => s_in_Port_126, --RDO
    in_Port_127 => s_out_Port_127,
    in_Port_128 => s_in_Port_128,
    in_Port_129 => s_out_Port_129,
    in_Port_130 => s_out_Port_130,
    in_Port_131 => s_out_Port_131,
    in_Port_132 => s_out_Port_132,
    in_Port_133 => s_out_Port_133,
    in_Port_134 => s_in_Port_134, --RDO
    in_Port_135 => s_in_Port_135, --RDO
    in_Port_136 => s_in_Port_136, --RDO
    in_Port_137 => s_out_Port_137,
    in_Port_138 => s_out_Port_138,
    in_Port_139 => s_out_Port_139,
    in_Port_140 => s_out_Port_140,
    in_Port_141 => s_out_Port_141,
    in_Port_142 => s_out_Port_142,
    in_Port_143 => s_out_Port_143,
    in_Port_144 => s_in_Port_144, -- RDO
    in_Port_145 => s_in_Port_145, -- RDO
    in_Port_146 => s_in_Port_146, -- RDO
    in_Port_147 => s_in_Port_147, -- RDO
    in_Port_148 => s_out_Port_148,
    in_Port_149 => s_out_Port_149,
    in_Port_150 => s_out_Port_150,
    in_Port_151 => s_out_Port_151,
    in_Port_152 => s_out_Port_152,
    in_Port_153 => s_out_Port_153,
    in_Port_154 => s_in_Port_154, -- RDO
    in_Port_155 => s_in_Port_155, -- RDO
    in_Port_156 => s_in_Port_156, -- RDO
    in_Port_157 => s_in_Port_157,
    in_Port_158 => s_out_Port_158,
    in_Port_159 => s_in_Port_159, -- RDO
    in_Port_160 => s_in_Port_160, -- RDO
    in_Port_161 => s_in_Port_161, -- RDO
    in_Port_162 => s_in_Port_162, -- RDO
    in_Port_163 => s_in_Port_163, -- RDO
    in_Port_164 => s_in_Port_164, -- RDO
    in_Port_165 => s_in_Port_165, -- RDO
    in_Port_166 => (others => '0'),
    in_Port_167 => (others => '0'),
    in_Port_168 => (others => '0'),
    in_Port_169 => (others => '0'),
    in_Port_170 => (others => '0'),
    in_Port_171 => (others => '0'),
    in_Port_172 => (others => '0'),
    in_Port_173 => (others => '0'),
    in_Port_174 => (others => '0'),
    in_Port_175 => (others => '0'),
    in_Port_176 => (others => '0'),
    in_Port_177 => (others => '0'),
    in_Port_178 => (others => '0'),
    in_Port_179 => (others => '0'),
    in_Port_180 => (others => '0'),
    in_Port_181 => (others => '0'),
    in_Port_182 => (others => '0'),
    in_Port_183 => (others => '0'),
    in_Port_184 => (others => '0'),
    in_Port_185 => (others => '0'),
    in_Port_186 => (others => '0'),
    in_Port_187 => (others => '0'),
    in_Port_188 => (others => '0'),
    in_Port_189 => (others => '0'),
    in_Port_190 => (others => '0'),
    in_Port_191 => (others => '0'),
    in_Port_192 => (others => '0'),
    in_Port_193 => (others => '0'),
    in_Port_194 => (others => '0'),
    in_Port_195 => (others => '0'),
    in_Port_196 => (others => '0'),
    in_Port_197 => (others => '0'),
    in_Port_198 => (others => '0'),
    in_Port_199 => (others => '0'),
    in_Port_200 => (others => '0'),--s_in_Port_200, --rod
    in_Port_201 => (others => '0'),
    in_Port_202 => (others => '0'),
    in_Port_203 => (others => '0'),
    in_Port_204 => (others => '0'),
    in_Port_205 => (others => '0'),
    in_Port_206 => (others => '0'),
    in_Port_207 => (others => '0'),
    in_Port_208 => (others => '0'),
    in_Port_209 => (others => '0'),
    in_Port_210 => (others => '0'),
    in_Port_211 => (others => '0'),
    in_Port_212 => (others => '0'),
    in_Port_213 => (others => '0'),
    in_Port_214 => (others => '0'),
    in_Port_215 => (others => '0'),
    in_Port_216 => (others => '0'),
    in_Port_217 => (others => '0'),
    in_Port_218 => (others => '0'),
    in_Port_219 => (others => '0'),
    in_Port_220 => (others => '0'),
    in_Port_221 => (others => '0'),
    in_Port_222 => (others => '0'),
    in_Port_223 => (others => '0'),
    in_Port_224 => (others => '0'),
    in_Port_225 => (others => '0'),
    in_Port_226 => (others => '0'),
    in_Port_227 => (others => '0'),
    in_Port_228 => (others => '0'),
    in_Port_229 => (others => '0'),
    in_Port_230 => (others => '0'),
    in_Port_231 => (others => '0'),
    in_Port_232 => (others => '0'),
    in_Port_233 => (others => '0'),
    in_Port_234 => (others => '0'),
    in_Port_235 => (others => '0'),
    in_Port_236 => (others => '0'),
    in_Port_237 => (others => '0'),
    in_Port_238 => (others => '0'),
    in_Port_239 => (others => '0'),
    in_Port_240 => (others => '0'),
    in_Port_241 => (others => '0'),
    in_Port_242 => (others => '0'),
    in_Port_243 => (others => '0'),
    in_Port_244 => (others => '0'),
    in_Port_245 => (others => '0'),
    in_Port_246 => (others => '0'),
    in_Port_247 => (others => '0'),
    in_Port_248 => (others => '0'),
    in_Port_249 => (others => '0'),
    in_Port_250 => (others => '0'),
    in_Port_251 => (others => '0'),
    in_Port_252 => (others => '0'),
    in_Port_253 => (others => '0'),
    in_Port_254 => (others => '0'),
    in_Port_255 => (others => '0'),
    -- }}}
    -- OutPort																{{{
    out_Port_000 => s_out_Port_000,
    out_Port_001 => s_out_Port_001,
    out_Port_002 => s_out_Port_002,
    out_Port_003 => s_out_Port_003,
    out_Port_004 => s_out_Port_004,
    out_Port_005 => s_out_Port_005,
    out_Port_006 => s_out_Port_006,
    out_Port_007 => s_out_Port_007,
    out_Port_008 => s_out_Port_008,
    out_Port_009 => s_out_Port_009,
    out_Port_010 => s_out_Port_010,
    out_Port_011 => s_out_Port_011,
    out_Port_012 => s_out_Port_012,
    out_Port_013 => s_out_Port_013,
    out_Port_014 => s_out_Port_014,
    out_Port_015 => s_out_Port_015,
    out_Port_016 => s_out_Port_016,
    out_Port_017 => s_out_Port_017,
    out_Port_018 => s_out_Port_018,
    out_Port_019 => s_out_Port_019,
    out_Port_020 => s_out_Port_020,
    out_Port_021 => s_out_Port_021,
    out_Port_022 => s_out_Port_022,
    out_Port_023 => s_out_Port_023,
    out_Port_024 => s_out_Port_024,
    out_Port_025 => s_out_Port_025,
    out_Port_026 => s_out_Port_026,
    out_Port_027 => s_out_Port_027,
    out_Port_028 => s_out_Port_028,
    out_Port_029 => s_out_Port_029,
    out_Port_030 => s_out_Port_030,
    out_Port_031 => s_out_Port_031,
    out_Port_032 => open, --rdo
    out_Port_033 => open, --rdo
    out_Port_034 => open, --rdo
    out_Port_035 => s_out_Port_035,
    out_Port_036 => s_out_Port_036,
    out_Port_037 => s_out_Port_037,
    out_Port_038 => s_out_Port_038,
    out_Port_039 => s_out_Port_039,
    out_Port_040 => s_out_Port_040,
    out_Port_041 => s_out_Port_041,
    out_Port_042 => s_out_Port_042,
    out_Port_043 => s_out_Port_043,
    out_Port_044 => s_out_Port_044,
    out_Port_045 => s_out_Port_045,
    out_Port_046 => s_out_Port_046,
    out_Port_047 => s_out_Port_047,
    out_Port_048 => s_out_Port_048,
    out_Port_049 => s_out_Port_049,
    out_Port_050 => s_out_Port_050,
    out_Port_051 => s_out_Port_051,
    out_Port_052 => s_out_Port_052,
    out_Port_053 => s_out_Port_053,
    out_Port_054 => s_out_Port_054,
    out_Port_055 => s_out_Port_055,
    out_Port_056 => s_out_Port_056,
    out_Port_057 => s_out_Port_057,
    out_Port_058 => s_out_Port_058,
    out_Port_059 => s_out_Port_059,
    out_Port_060 => s_out_Port_060,
    out_Port_061 => s_out_Port_061,
    out_Port_062 => s_out_Port_062,
    out_Port_063 => s_out_Port_063,
    out_Port_064 => s_out_Port_064,
    out_Port_065 => s_out_Port_065,
    out_Port_066 => s_out_Port_066,
    out_Port_067 => s_out_Port_067,
    out_Port_068 => open, --rod
    out_Port_069 => open, --rod
    out_Port_070 => open, --rod
    out_Port_071 => s_out_Port_071,
    out_Port_072 => s_out_Port_072,
    out_Port_073 => s_out_Port_073,
    out_Port_074 => s_out_Port_074,
    out_Port_075 => open, --rod
    out_Port_076 => s_out_Port_076,
    out_Port_077 => s_out_Port_077,
    out_Port_078 => s_out_Port_078,
    out_Port_079 => open, --rod
    out_Port_080 => open, --rod
    out_Port_081 => s_out_Port_081,
    out_Port_082 => s_out_Port_082,
    out_Port_083 => s_out_Port_083,
    out_Port_084 => s_out_Port_084,
    out_Port_085 => open, --rod
    out_Port_086 => s_out_Port_086,
    out_Port_087 => open, -- rod
    out_Port_088 => open, -- rod
    out_Port_089 => open, -- rod
    out_Port_090 => open, -- rod
    out_Port_091 => open, -- rod
    out_Port_092 => open, -- rod
    out_Port_093 => open, -- rod
    out_Port_094 => open, -- rod
    out_Port_095 => open, -- rod
    out_Port_096 => open, -- rod
    out_Port_097 => open, -- rod
    out_Port_098 => s_out_Port_098,
    out_Port_099 => s_out_Port_099,
    out_Port_100 => s_out_Port_100,
    out_Port_101 => s_out_Port_101,
    out_Port_102 => s_out_Port_102,
    out_Port_103 => s_out_Port_103,
    out_Port_104 => s_out_Port_104,
    out_Port_105 => s_out_Port_105,
    out_Port_106 => s_out_Port_106,
    out_Port_107 => s_out_Port_107,
    out_Port_108 => s_out_Port_108,
    out_Port_109 => s_out_Port_109,
    out_Port_110 => s_out_Port_110,
    out_Port_111 => s_out_Port_111,
    out_Port_112 => s_out_Port_112,
    out_Port_113 => s_out_Port_113,
    out_Port_114 => s_out_Port_114,
    out_Port_115 => s_out_Port_115,
    out_Port_116 => s_out_Port_116,
    out_Port_117 => s_out_Port_117,
    out_Port_118 => s_out_Port_118,
    out_Port_119 => s_out_Port_119,
    out_Port_120 => s_out_Port_120,
    out_Port_121 => s_out_Port_121,
    out_Port_122 => s_out_Port_122,
    out_Port_123 => s_out_Port_123,
    out_Port_124 => open, -- rod
    out_Port_125 => open, -- rod
    out_Port_126 => open, -- rod
    out_Port_127 => s_out_Port_127,
    out_Port_128 => open,  -- rod
    out_Port_129 => s_out_Port_129,
    out_Port_130 => s_out_Port_130,
    out_Port_131 => s_out_Port_131,
    out_Port_132 => s_out_Port_132,
    out_Port_133 => s_out_Port_133,
    out_Port_134 => open, -- rod
    out_Port_135 => open, -- rod
    out_Port_136 => open, -- rod
    out_Port_137 => open, -- rod
    out_Port_138 => s_out_Port_138,
    out_Port_139 => s_out_Port_139,
    out_Port_140 => s_out_Port_140,
    out_Port_141 => s_out_Port_141,
    out_Port_142 => s_out_Port_142,
    out_Port_143 => s_out_Port_143,
    out_Port_144 => open, -- rod
    out_Port_145 => open, -- rod
    out_Port_146 => open, -- rod
    out_Port_147 => open, -- rod
    out_Port_148 => s_out_Port_148,
    out_Port_149 => s_out_Port_149,
    out_Port_150 => s_out_Port_150,
    out_Port_151 => s_out_Port_151,
    out_Port_152 => s_out_Port_152,
    out_Port_153 => s_out_Port_153,
    out_Port_154 => open, -- rod
    out_Port_155 => open, -- rod
    out_Port_156 => open, -- rod
    out_Port_157 => open, -- rod
    out_Port_158 => s_out_Port_158,
    out_Port_159 => open, -- RDO
    out_Port_160 => open, -- RDO
    out_Port_161 => open, -- RDO
    out_Port_162 => open, -- RDO
    out_Port_163 => open, -- RDO
    out_Port_164 => open, -- RDO
    out_Port_165 => open, -- RDO
    out_Port_166 => open,
    out_Port_167 => open,
    out_Port_168 => open,
    out_Port_169 => open,
    out_Port_170 => open,
    out_Port_171 => open,
    out_Port_172 => open,
    out_Port_173 => open,
    out_Port_174 => open,
    out_Port_175 => open,
    out_Port_176 => open,
    out_Port_177 => open,
    out_Port_178 => open,
    out_Port_179 => open,
    out_Port_180 => open,
    out_Port_181 => open,
    out_Port_182 => open,
    out_Port_183 => open,
    out_Port_184 => open,
    out_Port_185 => open,
    out_Port_186 => open,
    out_Port_187 => open,
    out_Port_188 => open,
    out_Port_189 => open,
    out_Port_190 => open,
    out_Port_191 => open,
    out_Port_192 => open,
    out_Port_193 => open,
    out_Port_194 => open,
    out_Port_195 => open,
    out_Port_196 => open,
    out_Port_197 => open,
    out_Port_198 => open,
    out_Port_199 => open,
    out_Port_200 => open, -- ROD
    out_Port_201 => open,
    out_Port_202 => open,
    out_Port_203 => open,
    out_Port_204 => open,
    out_Port_205 => open,
    out_Port_206 => open,
    out_Port_207 => open,
    out_Port_208 => open,
    out_Port_209 => open,
    out_Port_210 => open,
    out_Port_211 => open,
    out_Port_212 => open,
    out_Port_213 => open,
    out_Port_214 => open,
    out_Port_215 => open,
    out_Port_216 => open,
    out_Port_217 => open,
    out_Port_218 => open,
    out_Port_219 => open,
    out_Port_220 => open,
    out_Port_221 => open,
    out_Port_222 => open,
    out_Port_223 => open,
    out_Port_224 => open,
    out_Port_225 => open,
    out_Port_226 => open,
    out_Port_227 => open,
    out_Port_228 => open,
    out_Port_229 => open,
    out_Port_230 => open,
    out_Port_231 => open,
    out_Port_232 => open,
    out_Port_233 => open,
    out_Port_234 => open,
    out_Port_235 => open,
    out_Port_236 => open,
    out_Port_237 => open,
    out_Port_238 => open,
    out_Port_239 => open,
    out_Port_240 => open,
    out_Port_241 => open,
    out_Port_242 => open,
    out_Port_243 => open,
    out_Port_244 => open,
    out_Port_245 => open,
    out_Port_246 => open,
    out_Port_247 => open,
    out_Port_248 => open,
    out_Port_249 => open,
    out_Port_250 => open,
    out_Port_251 => open,
    out_Port_252 => open,
    out_Port_253 => open,
    out_Port_254 => open,
    out_Port_255 => open

  );

  s_rgb(0)        <= REG_RGB_LED(0) or s_GlobalTrip;
  s_rgb(1)        <= REG_RGB_LED(1) or s_GlobalTrip;
  s_rgb(2)        <= REG_RGB_LED(2) or s_GlobalTrip;
  s_relay_ch0_out <= (s_GlobalTrip or REG_RELAY_CH0_EN);
  s_relay_ch1_out <= (s_GlobalTrip or REG_RELAY_CH1_EN);
  s_relay_ch2_out <= (s_GlobalTrip or REG_RELAY_CH2_EN);
  s_relay_ch3_out <= (s_GlobalTrip or REG_RELAY_CH3_EN);
  s_relay_ch4_out <= (s_GlobalTrip or REG_RELAY_CH4_EN);
  s_relay_ch5_out <= (s_GlobalTrip or REG_RELAY_CH5_EN);
  s_relay_ch6_out <= (s_GlobalTrip or REG_RELAY_CH6_EN);
  sRstn           <= iRstn;

  process (s_clk1, sRst)
  begin
    if sRst = '1' then
      o_relay_ch0 <= '0';
      o_relay_ch1 <= '0';
      o_relay_ch2 <= '0';

      o_relay_ch3 <= '0';
      o_relay_ch4 <= '0';
      o_relay_ch5 <= '0';
      o_relay_ch6 <= '0';

      REG_BOOL_TRIP   <= '0';
      REG_GLOBAL_TRIP <= '0';
    elsif rising_edge(s_clk1) then
      o_relay_ch0 <= s_relay_ch0_out;
      o_relay_ch1 <= s_relay_ch1_out;
      o_relay_ch2 <= s_relay_ch2_out;

      o_relay_ch3 <= s_relay_ch3_out;
      o_relay_ch4 <= s_relay_ch4_out;
      o_relay_ch5 <= s_relay_ch5_out;
      o_relay_ch6 <= s_relay_ch6_out;

      REG_BOOL_TRIP   <= s_Boolean_o_trip;
      REG_GLOBAL_TRIP <= s_GlobalTrip;
      o_RGB_LED    <= s_rgb;
    end if;
  end process;
  -- saída
  --signal o_teste : std_logic;


--   process(s_clk1)
-- begin
--   if rising_edge(s_clk1) then
--     o_teste <=  s_Boolean_o_trip or s_prot_81_faseA_trip_e1 or s_prot_81_faseA_trip_e2 or s_prot_81_faseA_alarm_e1 or s_prot_81_faseA_alarm_e2;
--   end if;
-- end process;

  --process(s_clk1)
  --begin
  --  if rising_edge(s_clk1) then
  --    -- "Algum vetor != 0 ?"  => se sim, o_teste = '1'
  --    if (absA_opt /= 0) or (rmsA_opt /= 0) or (angA_opt /= 0) or
  --       (absB_opt /= 0) or (rmsB_opt /= 0) or (angB_opt /= 0) or
  --       (absC_opt /= 0) or (rmsC_opt /= 0) or (angC_opt /= 0) OR
  --	   (s_ph_valid_phaseA = '1') or
  --       (s_ph_valid_phaseB = '1') or
  --       (s_ph_valid_phaseC = '1') or
  --       (s_ph_Real_phaseA  /= 0) or (s_ph_Imag_phaseA  /= 0) or
  --       (s_ph_RMS_phaseA   /= 0) or (s_ph_phase_phaseA /= 0) or
  --       (s_ph_Real_phaseB  /= 0) or (s_ph_Imag_phaseB  /= 0) or
  --       (s_ph_RMS_phaseB   /= 0) or (s_ph_phase_phaseB /= 0) or
  --       (s_ph_Real_phaseC  /= 0) or (s_ph_Imag_phaseC  /= 0) or
  --       (s_ph_RMS_phaseC   /= 0) or (s_ph_phase_phaseC /= 0) then
  --      o_teste <= '1';
  --    else
  --      o_teste <= '0';
  --    end if;
  --  end if;
  --end process;

end Behavioral;
