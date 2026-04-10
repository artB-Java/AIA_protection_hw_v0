----------------------------------------------------------------------------------
-- Bloco      : BiasRemovalMA
-- Descrição  :
--   Remove o componente DC (bias) de um sinal do XADC.
--   Passos:
--     1) Converte entrada 12b NÃO-sinalizada (0..4095) para 12b sinalizada:
--        x = u12 - 2048   --> faixa: -2048..+2047
--     2) Estima o bias por MÉDIA MÓVEL de comprimento N (N = 2^Log2_N).
--     3) Saída: y = x - média  (com saturação para 12b signed).
--   Pronto para alimentar o bloco de cálculo de RMS.
--
-- Engenheiro : André A. dos Anjos
-- Data       : 20/08/2025
-- Notas      :
--   - Janela N deve ser potência de 2 (N = 2^Log2_N).
--   - A janela avança somente quando i_valid='1' (N amostras válidas).
--   - Warm-up: nas primeiras N amostras a média converge ao DC real.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity BiasRemovalMA is
  generic (
    N       : natural := 64;  -- comprimento da média móvel
    Log2_N  : natural := 6    -- log2(N)
  );
  port (
    --------------------
    -- Clock / Reset
    --------------------
    i_clk     : in  std_logic;
    i_rst     : in  std_logic;  -- ativo-alto

    --------------------
    -- Entrada (XADC)
    --------------------
    i_u12     : in  std_logic_vector(11 downto 0); -- 12b não-sinalizado (0..4095)
    i_valid   : in  std_logic;                     -- 1 ciclo por amostra

    --------------------
    -- Saída (bias removido)
    --------------------
    o_sample  : out std_logic_vector(11 downto 0); -- 12b signed (two's complement)
    o_valid   : out std_logic                      -- pulso 1 ciclo
  );
end entity;

architecture Behavioral of BiasRemovalMA is

  --------------------
  -- Checagem de parâmetros
  --------------------
  function pow2(x : natural) return natural is
    variable r : natural := 1;
  begin
    for i in 1 to x loop
      r := r * 2;
    end loop;
    return r;
  end function;

  constant C_N_CHECK : boolean := (N = pow2(Log2_N));

  --------------------
  -- Tipos e sinais
  --------------------
  -- memória circular com as últimas N amostras x (12b signed)
  type x_array_t is array (0 to N-1) of signed(11 downto 0);

  signal x_mem       : x_array_t := (others => (others => '0'));
  signal ptr         : integer range 0 to N-1 := 0;

  -- conversões e acumuladores
  constant C_SUM_W   : natural := 12 + Log2_N + 2;           -- margem p/ soma
  signal sum_acc     : signed(C_SUM_W-1 downto 0) := (others => '0');

  -- amostra atual (signed) e versão estendida
  signal s_u12_u     : unsigned(11 downto 0);
  signal s_x_s12     : signed(11 downto 0);                  -- x = u12-2048
  signal s_x_ext     : signed(C_SUM_W-1 downto 0);

  -- leitura do valor antigo da janela (mesmo endereço)
  signal s_old_x     : signed(11 downto 0);

  -- soma e média “próximas” (combinacionais)
  signal s_next_sum  : signed(C_SUM_W-1 downto 0);
  signal s_mean_next : signed(C_SUM_W-1 downto 0);

  -- saída (y = x - média) e saturação
  signal s_y_ext     : signed(C_SUM_W-1 downto 0);
  signal y_s12       : signed(11 downto 0) := (others => '0');

  -- strobe de saída
  signal v_out       : std_logic := '0';

  --------------------
  -- Função: saturação para 12b signed
  --------------------
  function sat_s12(x : signed) return signed is
    variable res : signed(11 downto 0);
  begin
    if x > to_signed( 2047, x'length) then
      res := to_signed( 2047, 12);
    elsif x < to_signed(-2048, x'length) then
      res := to_signed(-2048, 12);
    else
      res := resize(x, 12);
    end if;
    return res;
  end function;

begin

  --------------------
  -- Assert (aviso) para N != 2^Log2_N
  --------------------
  assert C_N_CHECK
    report "BiasRemovalMA: N deve ser potencia de 2 (N = 2^Log2_N)."
    severity warning;

  --------------------
  -- Conversões combinacionais
  --------------------
  s_u12_u <= unsigned(i_u12);
  s_x_s12 <= signed(resize(s_u12_u, 12)) - to_signed(2048, 12);
  s_x_ext <= resize(s_x_s12, C_SUM_W);

  --------------------
  -- Leitura do elemento que sai da janela
  --------------------
  s_old_x <= x_mem(ptr);

  --------------------
  -- Próximos valores da soma/média (combinacionais)
  --------------------
  s_next_sum  <= sum_acc + s_x_ext - resize(s_old_x, C_SUM_W);
  s_mean_next <= shift_right(s_next_sum, Log2_N);

  --------------------
  -- Cálculo da saída (combinacional)
  --------------------
  s_y_ext <= s_x_ext - s_mean_next;

  --------------------
  -- Processo sequencial (registrador de estado/saída)
  --------------------
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      x_mem   <= (others => (others => '0'));
      ptr     <= 0;
      sum_acc <= (others => '0');
      y_s12   <= (others => '0');
      v_out   <= '0';

    elsif rising_edge(i_clk) then
      v_out <= '0';  -- default

      if i_valid = '1' then
        --------------------
        -- Atualiza soma (janela deslizante)
        --------------------
        sum_acc <= s_next_sum;

        --------------------
        -- Escreve amostra atual na memória circular
        --------------------
        x_mem(ptr) <= s_x_s12;

        --------------------
        -- Avança ponteiro circular
        --------------------
        if ptr = N-1 then
          ptr <= 0;
        else
          ptr <= ptr + 1;
        end if;

        --------------------
        -- Atualiza saída (com saturação)
        --------------------
        y_s12 <= sat_s12(s_y_ext);
        v_out <= '1';
      end if;
    end if;
  end process;

  --------------------
  -- Mapeamento de saídas
  --------------------
  o_sample <= std_logic_vector(y_s12);
  o_valid  <= v_out;

end architecture;
