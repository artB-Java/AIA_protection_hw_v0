----------------------------------------------------------------------------------
-- Bloco      : XadcBiasAndDecimate_SingleProc
-- Descrição  :
--   Converte amostra do XADC (12b unsigned, 0..4095) em 12b signed (-2048..+2047)
--   removendo bias por subtração de i_offset (12b). Em seguida, aplica decimação
--   por fator M configurável (i_decimation_factor, 8b).
--
--   Agora com duas saídas:
--     - o_data/o_valid       : fluxo DECIMADO
--     - o_data_nodc/o_valid_nodc : fluxo NA TAXA DE ENTRADA, apenas sem DC
--
--   Convenções:
--     - i_decimation_factor = 0  => tratado como 1 (sem decimação)
--     - i_decimation_factor = 1  => sem decimação
--     - i_decimation_factor = M  => emite 1 amostra a cada M válidas
--
-- Engenheiro : André A. dos Anjos
-- Data       : 20/08/2025
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity XadcBiasAndDecimate_SingleProc is
  port (
    --------------------------
    -- Clock / Reset
    --------------------------
    i_clk               : in  std_logic;
    i_rst               : in  std_logic;  -- ativo-alto
    --------------------------
    -- Entradas
    --------------------------
    i_data              : in  std_logic_vector(11 downto 0); -- 12b unsigned (0..4095)
    i_valid             : in  std_logic;                     -- pulso 1 ciclo
    i_offset            : in  std_logic_vector(11 downto 0); -- 12b unsigned (bias a subtrair)
    i_decimation_factor : in  std_logic_vector(7 downto 0);  -- 0=>1, 1=>1, M=>1/M
    --------------------------
    -- Saídas (decimadas)
    --------------------------
    o_data_decim              : out std_logic_vector(11 downto 0); -- 12b signed (-2048..+2047)
    o_valid_decim             : out std_logic;                     -- pulso 1 ciclo
    --------------------------
    -- Saídas (na taxa de entrada, sem DC)
    --------------------------
    o_data_nodc         : out std_logic_vector(11 downto 0); -- 12b signed (sem DC)
    o_valid_nodc        : out std_logic                      -- pulso 1 ciclo (segue i_valid)
  );
end entity;

architecture rtl of XadcBiasAndDecimate_SingleProc is
  --------------------------
  -- Registradores mínimos
  --------------------------
  signal r_cnt                 : integer range 0 to 255;                -- contador de decimação
  signal r_decimation_factor   : std_logic_vector(7 downto 0) := "01111111";
  signal r_offset              : std_logic_vector(11 downto 0) := "100000000000";
begin

  --------------------------
  -- Processo único
  --------------------------
  proc_main : process(i_clk, i_rst)
    -- variáveis locais apenas para contas do ciclo (não criam lógica extra)
    variable v_M_i     : integer;                 -- fator de decimação (integer)
    variable v_Mm1_i   : integer;                 -- M-1 (integer)
    variable v_diff13  : signed(12 downto 0);     -- [-4095..+4095]
    variable v_data_u  : unsigned(11 downto 0);
    variable v_off_u   : unsigned(11 downto 0);
    variable v_out_s12 : signed(11 downto 0);
  begin
    if i_rst = '1' then
      r_cnt                 <= 0;
      r_decimation_factor   <= (others => '0');
      r_offset              <= (others => '0');
      o_data_decim                <= (others => '0');
      o_valid_decim               <= '0';
      o_data_nodc           <= (others => '0');
      o_valid_nodc          <= '0';

    elsif rising_edge(i_clk) then
      --------------------------
      -- Defaults por ciclo
      --------------------------
      o_valid_decim      <= '0';
      o_valid_nodc <= '0';

      --------------------------
      -- Registrar controles (sincronizar)
      --------------------------
      r_decimation_factor <= i_decimation_factor;
      r_offset            <= i_offset;

      -------------------------------------
      -- Só age quando chega amostra válida
      -------------------------------------
      if i_valid = '1' then
        -----------------------------------
        -- 1) Resolve M (0 => 1) e M-1
        -----------------------------------
        v_M_i := to_integer(unsigned(r_decimation_factor));
        if v_M_i = 0 then
          v_M_i := 1;
        end if;
        v_Mm1_i := v_M_i - 1;

        -----------------------------------
        -- 2) Remove DC: diff = data - offset (sempre, para ambas as saídas)
        -----------------------------------
        v_data_u := unsigned(i_data);
        v_off_u  := unsigned(i_offset);
        v_diff13 := signed(resize(v_data_u, 13)) - signed(resize(v_off_u, 13));

        -- Saturação 13b -> 12b signed
        if v_diff13 > to_signed( 2047, 13) then
          v_out_s12 := to_signed( 2047, 12);
        elsif v_diff13 < to_signed(-2048, 13) then
          v_out_s12 := to_signed(-2048, 12);
        else
          v_out_s12 := resize(v_diff13, 12);
        end if;

        -----------------------------------
        -- 3) Saída NA TAXA DE ENTRADA (sempre)
        -----------------------------------
        o_data_nodc  <= std_logic_vector(v_out_s12);
        o_valid_nodc <= '1';

        -----------------------------------
        -- 4) Atualiza contador (mod M)
        -----------------------------------
        if r_cnt < v_Mm1_i then
          r_cnt <= r_cnt + 1;
        else
          r_cnt <= 0;
        end if;

        -----------------------------------
        -- 5) Fluxo DECIMADO: emite quando r_cnt==0 (pré-update)
        -----------------------------------
        if r_cnt = 0 then
          o_data_decim  <= std_logic_vector(v_out_s12);
          o_valid_decim <= '1';
        end if;

      end if; -- i_valid
    end if; -- rising_edge
  end process;

end architecture;
