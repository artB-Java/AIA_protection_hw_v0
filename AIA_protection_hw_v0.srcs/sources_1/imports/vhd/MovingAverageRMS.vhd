----------------------------------------------------------------------------------
-- Bloco      : MovingAverageRMS
-- Descrição  :
--   Calcula o valor RMS por média móvel de comprimento N, com filtragem leve
--   na saída RMS para reduzir pequenas oscilações.
--
--   A cada amostra válida:
--      x^2 -> soma acumulada com janela deslizante -> média -> sqrt -> filtro IIR
--
--   Filtro de saída:
--      y[k] = y[k-1] + (x[k] - y[k-1]) / 2^C_RMS_FILT_SHIFT
--
--   Saídas:
--      o_sq_reg    : último x^2 registrado
--      o_rms       : RMS filtrado
--      o_rms_valid : pulso 1 ciclo quando o_rms foi atualizado
--
-- Engenheiro : André A. dos Anjos
-- Data       : 19/08/2025
-- Revisão    : versão com filtro IIR leve na saída RMS
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity MovingAverageRMS is
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
        o_sq_reg    : out std_logic_vector(23 downto 0); -- último x^2 registrado
        o_rms       : out std_logic_vector(15 downto 0); -- RMS filtrado
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

    constant C_N_CHECK : boolean := (N = pow2(Log2_N));

    ----------------------------------------------------------------
    -- Constante interna do filtro de saída
    ----------------------------------------------------------------
    -- C_RMS_FILT_SHIFT = 3 -> filtro leve, resposta mais rápida
    -- C_RMS_FILT_SHIFT = 5 -> compromisso bom, divide correção por 32
    -- C_RMS_FILT_SHIFT = 7 -> filtro mais forte, divide correção por 128
    ----------------------------------------------------------------
    constant C_RMS_FILT_SHIFT : natural := 5;
    constant C_FILT_WIDTH     : natural := 16 + C_RMS_FILT_SHIFT + 1;

    --------------------------
    -- Memória circular de x^2
    --------------------------
    type sq_array_t is array (0 to N-1) of unsigned(23 downto 0);
    signal sq_mem : sq_array_t := (others => (others => '0'));
    signal ptr    : integer range 0 to N-1 := 0;

    --------------------------
    -- Acumuladores/registradores
    --------------------------
    signal sum_acc  : unsigned(31 downto 0) := (others => '0');
    signal x_signed : signed(11 downto 0)   := (others => '0');
    signal x_sq     : unsigned(23 downto 0) := (others => '0');

    signal avg_u32  : unsigned(31 downto 0) := (others => '0');
    signal avg_stb  : std_logic             := '0';

    --------------------------
    -- Raiz quadrada
    --------------------------
    component Sqrt_u32 is
      port (
        i_clk   : in  std_logic;
        i_rstn  : in  std_logic;
        i_start : in  std_logic;
        i_x     : in  unsigned(31 downto 0);
        o_root  : out unsigned(15 downto 0);
        o_busy  : out std_logic;
        o_valid : out std_logic
      );
    end component;

    signal rstn       : std_logic;
    signal sqrt_x     : unsigned(31 downto 0) := (others => '0');
    signal sqrt_start : std_logic             := '0';
    signal sqrt_busy  : std_logic;
    signal sqrt_valid : std_logic;
    signal sqrt_root  : unsigned(15 downto 0);

    ----------------------------------------------------------------
    -- Filtro IIR de saída do RMS
    ----------------------------------------------------------------
    signal rms_filt_q    : unsigned(C_FILT_WIDTH-1 downto 0) := (others => '0');
    signal rms_filt_init : std_logic := '0';

begin

    rstn <= not i_rst;

    ----------------------------------------------------------------
    -- Assert de configuração
    ----------------------------------------------------------------
    assert C_N_CHECK
      report "MovingAverageRMS: N deve ser potencia de 2 (N = 2^Log2_N)."
      severity warning;

    --------------------------
    -- Saída do último x^2
    --------------------------
    o_sq_reg <= std_logic_vector(x_sq);

    ----------------------------------------------------------------
    -- Pipeline principal: x^2, soma acumulada e média móvel da potência
    ----------------------------------------------------------------
    process(i_clk, i_rst)
        variable x_sq_now : unsigned(23 downto 0);
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

            avg_stb <= '0';

            if i_valid = '1' then

                -----------------------------------------------------
                -- 1) Calcula x^2
                -----------------------------------------------------
                x_signed <= signed(i_sample);

                x_sq_now := unsigned(signed(i_sample) * signed(i_sample));
                x_sq     <= x_sq_now;

                -----------------------------------------------------
                -- 2) Atualiza soma da janela deslizante
                -----------------------------------------------------
                next_sum := sum_acc
                          + resize(x_sq_now, sum_acc'length)
                          - resize(sq_mem(ptr), sum_acc'length);

                sum_acc <= next_sum;

                -----------------------------------------------------
                -- 3) Atualiza memória circular
                -----------------------------------------------------
                sq_mem(ptr) <= x_sq_now;

                -----------------------------------------------------
                -- 4) Atualiza ponteiro circular
                -----------------------------------------------------
                if ptr = N-1 then
                    ptr <= 0;
                else
                    ptr <= ptr + 1;
                end if;

                -----------------------------------------------------
                -- 5) Média da potência: avg = sum / N
                -----------------------------------------------------
                avg_u32 <= shift_right(next_sum, Log2_N);
                avg_stb <= '1';

            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Controle da raiz quadrada e filtro de saída do RMS
    ----------------------------------------------------------------
    process(i_clk, i_rst)
        variable x_q_v       : unsigned(C_FILT_WIDTH-1 downto 0);
        variable y_ext_v     : signed(C_FILT_WIDTH downto 0);
        variable x_ext_v     : signed(C_FILT_WIDTH downto 0);
        variable delta_v     : signed(C_FILT_WIDTH downto 0);
        variable next_ext_v  : signed(C_FILT_WIDTH downto 0);
        variable next_filt_v : unsigned(C_FILT_WIDTH-1 downto 0);
    begin
        if i_rst = '1' then
            sqrt_start   <= '0';
            sqrt_x       <= (others => '0');

            rms_filt_q    <= (others => '0');
            rms_filt_init <= '0';

            o_rms       <= (others => '0');
            o_rms_valid <= '0';

        elsif rising_edge(i_clk) then

            ---------------------------------------------------------
            -- Defaults de 1 ciclo
            ---------------------------------------------------------
            sqrt_start  <= '0';
            o_rms_valid <= '0';

            ---------------------------------------------------------
            -- Dispara sqrt quando há média nova e o bloco está livre
            ---------------------------------------------------------
            if (avg_stb = '1') and (sqrt_busy = '0') then
                sqrt_x     <= avg_u32;
                sqrt_start <= '1';
            end if;

            ---------------------------------------------------------
            -- Quando a raiz fica pronta, aplica filtro IIR no RMS
            ---------------------------------------------------------
            if sqrt_valid = '1' then

                -----------------------------------------------------
                -- Converte sqrt_root para formato com bits fracionários
                -- internos: x_q = sqrt_root * 2^C_RMS_FILT_SHIFT
                -----------------------------------------------------
                x_q_v := shift_left(resize(sqrt_root, C_FILT_WIDTH), C_RMS_FILT_SHIFT);

                -----------------------------------------------------
                -- Na primeira amostra válida, inicializa diretamente
                -- para evitar uma subida lenta a partir de zero.
                -----------------------------------------------------
                if rms_filt_init = '0' then

                    rms_filt_q    <= x_q_v;
                    rms_filt_init <= '1';

                    o_rms       <= std_logic_vector(sqrt_root);
                    o_rms_valid <= '1';

                else

                    -------------------------------------------------
                    -- y = y + (x - y)/2^C_RMS_FILT_SHIFT
                    -------------------------------------------------
                    y_ext_v := signed('0' & rms_filt_q);
                    x_ext_v := signed('0' & x_q_v);

                    delta_v    := x_ext_v - y_ext_v;
                    next_ext_v := y_ext_v + shift_right(delta_v, C_RMS_FILT_SHIFT);

                    next_filt_v := unsigned(next_ext_v(C_FILT_WIDTH-1 downto 0));

                    rms_filt_q <= next_filt_v;

                    -------------------------------------------------
                    -- Volta para 16 bits inteiros
                    -------------------------------------------------
                    o_rms <= std_logic_vector(
                                resize(
                                    shift_right(next_filt_v, C_RMS_FILT_SHIFT),
                                    16
                                )
                             );

                    o_rms_valid <= '1';

                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Instância do bloco de raiz quadrada
    ----------------------------------------------------------------
    inst_sqrt : Sqrt_u32
      port map (
        i_clk   => i_clk,
        i_rstn  => rstn,
        i_start => sqrt_start,
        i_x     => sqrt_x,
        o_root  => sqrt_root,
        o_busy  => sqrt_busy,
        o_valid => sqrt_valid
      );

end Behavioral;
