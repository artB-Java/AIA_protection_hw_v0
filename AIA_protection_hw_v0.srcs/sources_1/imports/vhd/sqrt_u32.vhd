----------------------------------------------------------------------------------
-- Bloco      : Sqrt_u32
-- Descrição  : 
--   Raiz quadrada inteira (unsigned) de um valor de 32 bits usando método
--   digit-by-digit (restoring). Executa 16 iterações (2 bits por passo) e
--   entrega um resultado de 16 bits com handshake simples:
--     - i_start: pulso de 1 ciclo para iniciar quando o_busy='0'
--     - o_busy : '1' enquanto a operação está em andamento
--     - o_valid: pulso de 1 ciclo quando o_root está válido
--
-- Autor : André A. dos Anjos
-- Data       : 19/08/2025
-- Notas      :
--   - Reset assíncrono ativo-baixo (i_rstn).
--   - Latência determinística: 16 ciclos após aceitar i_start (quando o_busy='0').
--   - Algoritmo opera em pares de bits (MSB?LSB) do radicando (i_x).
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

----------------------------------------------------------------------------------
-- Entity / Interface
----------------------------------------------------------------------------------
entity Sqrt_u32 is
  port (
    --------------------
    -- Clock e Reset
    --------------------
    i_clk   : in  std_logic;
    i_rstn  : in  std_logic;  -- reset assíncrono ativo em '0'

    --------------------
    -- Controle / Dados
    --------------------
    i_start : in  std_logic;  -- pulso de 1 ciclo
    i_x     : in  unsigned(31 downto 0);

    --------------------
    -- Resultados
    --------------------
    o_root  : out unsigned(15 downto 0);
    o_busy  : out std_logic;
    o_valid : out std_logic
  );
end entity;

----------------------------------------------------------------------------------
-- Arquitetura
----------------------------------------------------------------------------------
architecture rtl of Sqrt_u32 is

  --------------------
  -- Registradores
  --------------------
  signal src_reg   : unsigned(31 downto 0) := (others => '0'); -- radicando “andante”
  signal rem_reg   : unsigned(18 downto 0) := (others => '0'); -- resto parcial (19b)
  signal root_reg  : unsigned(15 downto 0) := (others => '0'); -- resultado (acumulado)
  signal iter_cnt  : unsigned(4 downto 0)  := (others => '0'); -- 16 iterações
  signal busy_reg  : std_logic := '0';
  signal valid_reg : std_logic := '0';

begin
  --------------------
  -- Saídas mapeadas
  --------------------
  o_root  <= root_reg;
  o_busy  <= busy_reg;
  o_valid <= valid_reg;

  --------------------------------------------------------------------------------
  -- Máquina de cálculo (digit-by-digit)
  -- Passos por ciclo quando busy='1':
  --   1) Trazer 2 MSBs do radicando (next_bits) e atualizar resto (rem_next).
  --   2) Formar “trial” = (root<<2)+1.
  --   3) Comparar rem_next vs trial: decide o próximo bit do root.
  --   4) Deslocar radicando (descarta os 2 MSBs já usados).
  --   5) Decrementar contador; quando zera, sinaliza o_valid.
  --------------------------------------------------------------------------------
  process(i_clk, i_rstn)
    -- Variáveis locais (uso combinacional dentro do processo)
    variable rem_next  : unsigned(18 downto 0);
    variable trial     : unsigned(18 downto 0);
    variable next_bits : unsigned(1 downto 0);
  begin
    if i_rstn = '0' then
      --------------------
      -- Reset assíncrono
      --------------------
      src_reg   <= (others => '0');
      rem_reg   <= (others => '0');
      root_reg  <= (others => '0');
      iter_cnt  <= (others => '0');
      busy_reg  <= '0';
      valid_reg <= '0';

    elsif rising_edge(i_clk) then
      --------------------
      -- Default por ciclo
      --------------------
      valid_reg <= '0';

      --------------------
      -- Aceitação do start
      --------------------
      if (i_start = '1') and (busy_reg = '0') then
        -- Carrega radicando e inicializa estado
        src_reg   <= i_x;
        rem_reg   <= (others => '0');
        root_reg  <= (others => '0');
        iter_cnt  <= to_unsigned(16, iter_cnt'length);
        busy_reg  <= '1';

      --------------------
      -- Laço de iteração
      --------------------
      elsif busy_reg = '1' then
        -- 1) Traz o próximo par de MSBs
        next_bits := src_reg(31 downto 30);
        rem_next  := (rem_reg sll 2) + resize(next_bits, rem_next'length);

        -- 2) trial = (root << 2) + 1   (*** correção aqui ***)
        trial := resize((root_reg sll 2), trial'length) + 1;

        -- 3) Decide o bit atual
        if rem_next >= trial then
          rem_reg  <= rem_next - trial;
          root_reg <= (root_reg sll 1) + 1;
        else
          rem_reg  <= rem_next;
          root_reg <= (root_reg sll 1);
        end if;

        -- 4) Avança o radicando (descarta 2 MSBs já usados)
        src_reg <= src_reg sll 2;

        -- 5) Controle de iterações / término
        if iter_cnt = 1 then
          busy_reg  <= '0';
          valid_reg <= '1';
          iter_cnt  <= (others => '0');
        else
          iter_cnt <= iter_cnt - 1;
        end if;
      end if;
    end if;
  end process;
end architecture;
