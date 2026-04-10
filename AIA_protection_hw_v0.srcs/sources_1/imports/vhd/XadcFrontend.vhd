----------------------------------------------------------------------------------
-- Bloco  : XadcFrontend
-- Versão : v2.0 (28/10/2025)
-- Descrição:
--   Encapsula o IP XADC (xadc_wiz_0) e a lógica DRP em round-robin para ler
--   Temperatura e VAUX[0..10]. Entrega dados de 12 bits (MSBs do XADC) e um
--   pulso de válido por canal. Propaga também os alarmes do XADC.
--
-- Autor  : André A. dos Anjos
-- Notas  : i_clk = 100 MHz (compatível com o XADC Wizard). Reset ativo-alto (i_rst).
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity XadcFrontend is
  port (
    --------------------------
    -- Clock/reset do XADC/DRP
    --------------------------
    i_clk                    : in  std_logic;  -- 100 MHz
    i_rst                    : in  std_logic;  -- ativo-alto

    ---------------------------------
    -- Entradas analógicas auxiliares
    ---------------------------------
    i_vauxp0                 : in  std_logic;
    i_vauxn0                 : in  std_logic;
    i_vauxp1                 : in  std_logic;
    i_vauxn1                 : in  std_logic;
    i_vauxp2                 : in  std_logic;
    i_vauxn2                 : in  std_logic;
    i_vauxp3                 : in  std_logic;
    i_vauxn3                 : in  std_logic;
    i_vauxp4                 : in  std_logic;
    i_vauxn4                 : in  std_logic;
    i_vauxp5                 : in  std_logic;
    i_vauxn5                 : in  std_logic;
    i_vauxp6                 : in  std_logic;
    i_vauxn6                 : in  std_logic;
    i_vauxp7                 : in  std_logic;
    i_vauxn7                 : in  std_logic;
    i_vauxp8                 : in  std_logic;
    i_vauxn8                 : in  std_logic;
    i_vauxp9                 : in  std_logic;
    i_vauxn9                 : in  std_logic;
    i_vauxp10                : in  std_logic;
    i_vauxn10                : in  std_logic;

    -------------------------------------------------------------
    -- Saídas: dados (12b) e "valid" por canal (pulso de 1 ciclo)
    -------------------------------------------------------------
    o_temp_data              : out std_logic_vector(11 downto 0);
    o_temp_valid             : out std_logic;

    o_vaux0_data             : out std_logic_vector(11 downto 0);
    o_vaux0_valid            : out std_logic;
    o_vaux1_data             : out std_logic_vector(11 downto 0);
    o_vaux1_valid            : out std_logic;
    o_vaux2_data             : out std_logic_vector(11 downto 0);
    o_vaux2_valid            : out std_logic;
    o_vaux3_data             : out std_logic_vector(11 downto 0);
    o_vaux3_valid            : out std_logic;
    o_vaux4_data             : out std_logic_vector(11 downto 0);
    o_vaux4_valid            : out std_logic;
    o_vaux5_data             : out std_logic_vector(11 downto 0);
    o_vaux5_valid            : out std_logic;
    o_vaux6_data             : out std_logic_vector(11 downto 0);
    o_vaux6_valid            : out std_logic;
    o_vaux7_data             : out std_logic_vector(11 downto 0);
    o_vaux7_valid            : out std_logic;
    o_vaux8_data             : out std_logic_vector(11 downto 0);
    o_vaux8_valid            : out std_logic;
    o_vaux9_data             : out std_logic_vector(11 downto 0);
    o_vaux9_valid            : out std_logic;
    o_vaux10_data            : out std_logic_vector(11 downto 0);
    o_vaux10_valid           : out std_logic;

    ------------------------------------------------
    -- Saídas de alarme (em PT, sufixo *_alarme_out)
    ------------------------------------------------
    o_user_temp_alarme_out   : out std_logic;
    o_vccint_alarme_out      : out std_logic;
    o_vccaux_alarme_out      : out std_logic;
    o_alarme_out             : out std_logic
  );
end XadcFrontend;

architecture rtl of XadcFrontend is

  component xadc_wiz_0
    port (
      di_in               : in  std_logic_vector(15 downto 0);
      daddr_in            : in  std_logic_vector(6 downto 0);
      den_in              : in  std_logic;
      dwe_in              : in  std_logic;
      drdy_out            : out std_logic;
      do_out              : out std_logic_vector(15 downto 0);
      dclk_in             : in  std_logic;
      reset_in            : in  std_logic;

      vp_in               : in  std_logic;
      vn_in               : in  std_logic;

      -- VAUX[0..10] habilitados no Wizard
      vauxp0              : in  std_logic; vauxn0 : in std_logic;
      vauxp1              : in  std_logic; vauxn1 : in std_logic;
      vauxp2              : in  std_logic; vauxn2 : in std_logic;
      vauxp3              : in  std_logic; vauxn3 : in std_logic;
      vauxp4              : in  std_logic; vauxn4 : in std_logic;
      vauxp5              : in  std_logic; vauxn5 : in std_logic;
      vauxp6              : in  std_logic; vauxn6 : in std_logic;
      vauxp7              : in  std_logic; vauxn7 : in std_logic;
      vauxp8              : in  std_logic; vauxn8 : in std_logic;
      vauxp9              : in  std_logic; vauxn9 : in std_logic;
      vauxp10             : in  std_logic; vauxn10: in std_logic;

      user_temp_alarm_out : out std_logic;
      vccint_alarm_out    : out std_logic;
      vccaux_alarm_out    : out std_logic;
      channel_out         : out std_logic_vector(4 downto 0);
      eoc_out             : out std_logic;
      alarm_out           : out std_logic;
      eos_out             : out std_logic;
      busy_out            : out std_logic
    );
  end component;

  -- DRP
  signal di         : std_logic_vector(15 downto 0) := (others => '0');
  signal daddr      : std_logic_vector(6 downto 0)  := (others => '0');
  signal den        : std_logic := '0';
  signal dwe        : std_logic := '0';
  signal do_out     : std_logic_vector(15 downto 0);
  signal drdy_out   : std_logic;

  -- Status do XADC
  signal xadc_eoc   : std_logic;
  signal xadc_busy  : std_logic;
  signal xadc_alarm : std_logic;
  signal xadc_eos   : std_logic;
  signal xadc_chan  : std_logic_vector(4 downto 0);
  signal xadc_utemp : std_logic;
  signal xadc_vccint: std_logic;
  signal xadc_vccaux: std_logic;

  -- Round-robin de leitura (Temp + 11 VAUX = 12 entradas)
  type addr_tab_t is array(0 to 12) of std_logic_vector(6 downto 0);
  constant ADDR_TAB : addr_tab_t := (
    std_logic_vector(to_unsigned(16#00#,7)), -- 0: 0x00 Temp
    std_logic_vector(to_unsigned(16#10#,7)), -- 1: 0x10 VAUX0
    std_logic_vector(to_unsigned(16#11#,7)), -- 2: 0x11 VAUX1
    std_logic_vector(to_unsigned(16#12#,7)), -- 3: 0x12 VAUX2
    std_logic_vector(to_unsigned(16#13#,7)), -- 4: 0x13 VAUX3
    std_logic_vector(to_unsigned(16#14#,7)), -- 5: 0x14 VAUX4
    std_logic_vector(to_unsigned(16#15#,7)), -- 6: 0x15 VAUX5
    std_logic_vector(to_unsigned(16#16#,7)), -- 7: 0x16 VAUX6
    std_logic_vector(to_unsigned(16#17#,7)), -- 8: 0x17 VAUX7
    std_logic_vector(to_unsigned(16#18#,7)), -- 9:  0x18 VAUX8
    std_logic_vector(to_unsigned(16#19#,7)), -- 10: 0x19 VAUX9
    std_logic_vector(to_unsigned(16#1A#,7)),  -- 11: 0x1A VAUX10
	std_logic_vector(to_unsigned(16#1B#,7))  -- 12: 0x1B VAUX11
  );

  signal idx, idx_d : unsigned(3 downto 0) := (others => '0'); -- 0..12

  -- Regs de dados e valids
  signal temp_r     : std_logic_vector(11 downto 0) := (others => '0');
  signal vaux0_r    : std_logic_vector(11 downto 0) := (others => '0');
  signal vaux1_r    : std_logic_vector(11 downto 0) := (others => '0');
  signal vaux2_r    : std_logic_vector(11 downto 0) := (others => '0');
  signal vaux3_r    : std_logic_vector(11 downto 0) := (others => '0');
  signal vaux4_r    : std_logic_vector(11 downto 0) := (others => '0');
  signal vaux5_r    : std_logic_vector(11 downto 0) := (others => '0');
  signal vaux6_r    : std_logic_vector(11 downto 0) := (others => '0');
  signal vaux7_r    : std_logic_vector(11 downto 0) := (others => '0');
  signal vaux8_r    : std_logic_vector(11 downto 0) := (others => '0');
  signal vaux9_r    : std_logic_vector(11 downto 0) := (others => '0');
  signal vaux10_r   : std_logic_vector(11 downto 0) := (others => '0');
  signal vaux11_r   : std_logic_vector(11 downto 0) := (others => '0');

  signal temp_v     : std_logic := '0';
  signal vaux0_v    : std_logic := '0';
  signal vaux1_v    : std_logic := '0';
  signal vaux2_v    : std_logic := '0';
  signal vaux3_v    : std_logic := '0';
  signal vaux4_v    : std_logic := '0';
  signal vaux5_v    : std_logic := '0';
  signal vaux6_v    : std_logic := '0';
  signal vaux7_v    : std_logic := '0';
  signal vaux8_v    : std_logic := '0';
  signal vaux9_v    : std_logic := '0';
  signal vaux10_v   : std_logic := '0';
  signal vaux11_v   : std_logic := '0';

  -- Extrai 12 MSBs (bits 15..4)
  function xadc12(d: std_logic_vector(15 downto 0)) return std_logic_vector is
  begin
    return d(15 downto 4);
  end function;

begin
  -- Saídas de dados/valid
  o_temp_data    <= temp_r;
  o_vaux0_data   <= vaux0_r;
  o_vaux1_data   <= vaux1_r;
  o_vaux2_data   <= vaux2_r;
  o_vaux3_data   <= vaux3_r;
  o_vaux4_data   <= vaux4_r;
  o_vaux5_data   <= vaux5_r;
  o_vaux6_data   <= vaux6_r;
  o_vaux7_data   <= vaux7_r;
  o_vaux8_data   <= vaux8_r;
  o_vaux9_data   <= vaux9_r;
  o_vaux10_data  <= vaux10_r;

  o_temp_valid   <= temp_v;
  o_vaux0_valid  <= vaux0_v;
  o_vaux1_valid  <= vaux1_v;
  o_vaux2_valid  <= vaux2_v;
  o_vaux3_valid  <= vaux3_v;
  o_vaux4_valid  <= vaux4_v;
  o_vaux5_valid  <= vaux5_v;
  o_vaux6_valid  <= vaux6_v;
  o_vaux7_valid  <= vaux7_v;
  o_vaux8_valid  <= vaux8_v;
  o_vaux9_valid  <= vaux9_v;
  o_vaux10_valid <= vaux10_v;

  -- Saídas de alarme (propagadas)
  o_user_temp_alarme_out <= xadc_utemp;
  o_vccint_alarme_out    <= xadc_vccint;
  o_vccaux_alarme_out    <= xadc_vccaux;
  o_alarme_out           <= xadc_alarm;

  -- IP do XADC
  u_xadc : xadc_wiz_0
    port map (
      di_in               => di,
      daddr_in            => daddr,
      den_in              => den,
      dwe_in              => dwe,
      drdy_out            => drdy_out,
      do_out              => do_out,
      dclk_in             => i_clk,
      reset_in            => i_rst,
      vp_in               => '0',
      vn_in               => '0',

      vauxp0  => i_vauxp0,  vauxn0  => i_vauxn0,
      vauxp1  => i_vauxp1,  vauxn1  => i_vauxn1,
      vauxp2  => i_vauxp2,  vauxn2  => i_vauxn2,
      vauxp3  => i_vauxp3,  vauxn3  => i_vauxn3,
      vauxp4  => i_vauxp4,  vauxn4  => i_vauxn4,
      vauxp5  => i_vauxp5,  vauxn5  => i_vauxn5,
      vauxp6  => i_vauxp6,  vauxn6  => i_vauxn6,
      vauxp7  => i_vauxp7,  vauxn7  => i_vauxn7,
      vauxp8  => i_vauxp8,  vauxn8  => i_vauxn8,
      vauxp9  => i_vauxp9,  vauxn9  => i_vauxn9,
      vauxp10 => i_vauxp10, vauxn10 => i_vauxn10,

      user_temp_alarm_out => xadc_utemp,
      vccint_alarm_out    => xadc_vccint,
      vccaux_alarm_out    => xadc_vccaux,
      channel_out         => xadc_chan,
      eoc_out             => xadc_eoc,
      alarm_out           => xadc_alarm,
      eos_out             => xadc_eos,
      busy_out            => xadc_busy
    );

  -- Controle DRP + demux de resultados + geração dos valids
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      den     <= '0';
      daddr   <= (others => '0');
      idx     <= (others => '0');
      idx_d   <= (others => '0');

      temp_r   <= (others => '0');
      vaux0_r  <= (others => '0');
      vaux1_r  <= (others => '0');
      vaux2_r  <= (others => '0');
      vaux3_r  <= (others => '0');
      vaux4_r  <= (others => '0');
      vaux5_r  <= (others => '0');
      vaux6_r  <= (others => '0');
      vaux7_r  <= (others => '0');
      vaux8_r  <= (others => '0');
      vaux9_r  <= (others => '0');
      vaux10_r <= (others => '0');
	  vaux11_r <= (others => '0');

      temp_v   <= '0';
      vaux0_v  <= '0';
      vaux1_v  <= '0';
      vaux2_v  <= '0';
      vaux3_v  <= '0';
      vaux4_v  <= '0';
      vaux5_v  <= '0';
      vaux6_v  <= '0';
      vaux7_v  <= '0';
      vaux8_v  <= '0';
      vaux9_v  <= '0';
      vaux10_v <= '0';
	  vaux11_v <= '0';

    elsif rising_edge(i_clk) then
      -- default: valids em 0 (pulso de 1 ciclo)
      temp_v   <= '0';
      vaux0_v  <= '0';
      vaux1_v  <= '0';
      vaux2_v  <= '0';
      vaux3_v  <= '0';
      vaux4_v  <= '0';
      vaux5_v  <= '0';
      vaux6_v  <= '0';
      vaux7_v  <= '0';
      vaux8_v  <= '0';
      vaux9_v  <= '0';
      vaux10_v <= '0';
	  vaux11_v <= '0';

      den <= '0';  -- default

      -- A cada EOC, solicite próxima leitura (round-robin)
      if xadc_eoc = '1' then
        daddr <= ADDR_TAB(to_integer(idx));
        den   <= '1';
        idx_d <= idx;

        if idx = to_unsigned(12, idx'length) then
          idx <= (others => '0');
        else
          idx <= idx + 1;
        end if;
      end if;

      -- Quando DRDY=1, DO_OUT contém a conversão pedida
      if drdy_out = '1' then
        case std_logic_vector(idx_d) is
          when "0000" => temp_r   <= xadc12(do_out); temp_v   <= '1';
          when "0001" => vaux0_r  <= xadc12(do_out); vaux0_v  <= '1';
          when "0010" => vaux1_r  <= xadc12(do_out); vaux1_v  <= '1';
          when "0011" => vaux2_r  <= xadc12(do_out); vaux2_v  <= '1';
          when "0100" => vaux3_r  <= xadc12(do_out); vaux3_v  <= '1';
          when "0101" => vaux4_r  <= xadc12(do_out); vaux4_v  <= '1';
          when "0110" => vaux5_r  <= xadc12(do_out); vaux5_v  <= '1';
          when "0111" => vaux6_r  <= xadc12(do_out); vaux6_v  <= '1';
          when "1000" => vaux7_r  <= xadc12(do_out); vaux7_v  <= '1';
          when "1001" => vaux8_r  <= xadc12(do_out); vaux8_v  <= '1';
          when "1010" => vaux9_r  <= xadc12(do_out); vaux9_v  <= '1';
		  when "1011" => vaux10_r  <= xadc12(do_out); vaux10_v  <= '1';
          when others => vaux11_r <= xadc12(do_out); vaux11_v <= '1'; -- "1011"
        end case;
      end if;
    end if;
  end process;

end rtl;
