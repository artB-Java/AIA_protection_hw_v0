----------------------------------------------------------------------------------
-- Bloco      : MovingAverageRMS
-- Descrição  :
--   Calcula o valor RMS por média móvel de comprimento N (potência de 2).
--   A cada amostra válida, atualiza: x.^2, soma acumulada (com janela deslizante),
--   média = sum/N, e dispara um cálculo de raiz (Sqrt_u32).
--   Saídas: último x.^2 (o_sq_reg), RMS (o_rms) e strobe (o_rms_valid).
--
-- Engenheiro : André A. dos Anjos
-- Data       : 19/08/2025
-- Notas      :
--   - Entrada i_sample é signed 12b (two’s complement: -2048..+2047).
--   - x.^2 cabe em 24b; soma usa 32b (sobra para N até 256).
--   - N deve ser potência de 2: N = 2^Log2_N.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

Entity MovingAverageRMS is
    generic (
        N       : natural := 64;  -- comprimento da média móvel
        Log2_N  : natural := 6    -- log2(N)
    );
    port (
        --------------------------
        -- Clock / Reset
        --------------------------
        i_clk       : in  std_logic;
        i_rst       : in  std_logic;  -- ativo-alto

        --------------------------
        -- Amostra de entrada
        --------------------------
        i_sample    : in  std_logic_vector(11 downto 0); -- signed 12b (-2048..+2047)
        i_valid     : in  std_logic;                     -- pulso 1 ciclo por amostra

        -------------------------------------------------------------
        -- Saídas
        -------------------------------------------------------------
        o_sq_reg    : out std_logic_vector(23 downto 0); -- último x.^2 registrado
        o_rms       : out std_logic_vector(15 downto 0); -- RMS (16b)
        o_rms_valid : out std_logic                      -- pulso 1 ciclo quando o_rms válido
    );
end MovingAverageRMS;

architecture Behavioral of MovingAverageRMS is

    --------------------------
    -- Checagem de parâmetros
    --------------------------
    function pow2(x : natural) return natural is
        variable r : natural := 1;
    begin
        for i in 1 to x loop
            r := r * 2;
        end loop;
        return r;
    end function;

    -- Garante N = 2^Log2_N
    constant C_N_CHECK : boolean := (N = pow2(Log2_N));

    --------------------------
    -- Memória circular (x.^2)
    --------------------------
    type sq_array_t is array (0 to N-1) of unsigned(23 downto 0);
    signal sq_mem     : sq_array_t := (others => (others => '0'));
    signal ptr        : integer range 0 to N-1 := 0;

    --------------------------
    -- Acumuladores/registradores
    --------------------------
    signal sum_acc    : unsigned(31 downto 0) := (others => '0'); -- soma dos N x.^2
    signal x_signed   : signed(11 downto 0)   := (others => '0');
    signal x_sq       : unsigned(23 downto 0) := (others => '0');

    -- média (sum/N) registrada
    signal avg_u32    : unsigned(31 downto 0) := (others => '0');
    signal avg_stb    : std_logic             := '0';  -- 1 ciclo quando avg_u32 atualizada

    --------------------------
    -- Raiz quadrada (Sqrt_u32)
    --------------------------
    component Sqrt_u32 is
      port (
        i_clk   : in  std_logic;
        i_rstn  : in  std_logic;              -- reset assíncrono ativo-baixo
        i_start : in  std_logic;              -- pulso 1 ciclo
        i_x     : in  unsigned(31 downto 0);
        o_root  : out unsigned(15 downto 0);
        o_busy  : out std_logic;
        o_valid : out std_logic
      );
    end component;

    signal sqrt_x     : unsigned(31 downto 0) := (others => '0');
    signal sqrt_start : std_logic             := '0';
    signal sqrt_busy  : std_logic;
    signal sqrt_valid : std_logic;
    signal sqrt_root  : unsigned(15 downto 0);

begin

    ----------------------------------------------------------------
    -- Assert de configuração (gera aviso em simulação/síntese)
    ----------------------------------------------------------------
    assert C_N_CHECK
      report "MovingAverageRMS: N deve ser potencia de 2 (N = 2^Log2_N)."
      severity warning;

    --------------------------
    -- Saída do último x.^2
    --------------------------
    o_sq_reg <= std_logic_vector(x_sq);

    --------------------------
    -- Pipeline principal
    --------------------------
    process(i_clk, i_rst)
        variable next_sum : unsigned(31 downto 0);
    begin
        if i_rst = '1' then
            ptr      <= 0;
            sum_acc  <= (others => '0');
            sq_mem   <= (others => (others => '0'));
            x_signed <= (others => '0');
            x_sq     <= (others => '0');
            avg_u32  <= (others => '0');
            avg_stb  <= '0';
        elsif rising_edge(i_clk) then
    

            if i_valid = '1' then
                --------------------
                -- 1) x -> x.^2 (24b)
                --------------------
                x_signed <= signed(i_sample);
                x_sq     <= unsigned( signed(i_sample) * signed(i_sample) );

                -------------------------------------------------------------
                -- 2) Atualiza soma: soma novo x.^2 e remove o que sai da janela
                -------------------------------------------------------------
                next_sum := sum_acc
                          + resize(unsigned( signed(i_sample) * signed(i_sample) ), sum_acc'length)
                          - resize(sq_mem(ptr), sum_acc'length);
                sum_acc  <= next_sum;

                ---------------------------------------
                -- 3) Escreve x.^2 na memória circular
                ---------------------------------------
                sq_mem(ptr) <= unsigned( signed(i_sample) * signed(i_sample) );

                -------------------------------------------------
                -- 4) Avança ponteiro circular (0..N-1)
                -------------------------------------------------
                if ptr = N-1 then
                    ptr <= 0;
                else
                    ptr <= ptr + 1;
                end if;

                ------------------------------------------
                -- 5) Média inteira: avg = sum_acc / N
                ------------------------------------------
                avg_u32 <= shift_right(next_sum, Log2_N);
                avg_stb <= '1';
				
			else
				-- default
				avg_stb <= '0';			
				
            end if;
        end if;
    end process;

    --------------------------
    -- Controle do Sqrt_u32
    --------------------------
    process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            sqrt_start  <= '0';
            sqrt_x      <= (others => '0');
            o_rms       <= (others => '0');
            o_rms_valid <= '0';
        elsif rising_edge(i_clk) then
  

            --------------------
            -- Dispara sqrt se:
            --  - chegou média nova (avg_stb=1)
            --  - e o IP do sqrt não está ocupado
            --------------------
            if (avg_stb = '1') and (sqrt_busy = '0') then
                sqrt_x     <= avg_u32;  -- "latch" da média atual
                sqrt_start <= '1';      -- pulso de start
            else
				 -- defaults 1-ciclo
				sqrt_start  <= '0';
				o_rms_valid <= '0';
			end if;

            --------------------
            -- Captura resultado -- Vou proteger aqui para não dar overflow depois
            --------------------
            if sqrt_valid = '1' then
                o_rms       <= std_logic_vector(sqrt_root); 
                o_rms_valid <= '1';
            end if;
        end if;
    end process;

    --------------------------
    -- Instância do Sqrt_u32
    --------------------------
    inst_sqrt : Sqrt_u32
      port map (
        i_clk   => i_clk,
        i_rstn  => not i_rst,     -- ativo-baixo
        i_start => sqrt_start,
        i_x     => sqrt_x,
        o_root  => sqrt_root,
        o_busy  => sqrt_busy,
        o_valid => sqrt_valid
      );

end Behavioral;
