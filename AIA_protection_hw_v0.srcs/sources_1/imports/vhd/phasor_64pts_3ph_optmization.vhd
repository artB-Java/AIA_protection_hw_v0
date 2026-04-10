-- ============================================================================
--  Author      : Prof. Dr. Andre dos Anjos
--  Block       : phasor_64pts_3ph_optmization
--  Description :
--    Estimador de fasor fundamental (1º harmônico) via DFT em janela deslizante
--    de 64 pontos para três fases (A, B, C), com atualização incremental
--    (add novo termo + remove termo antigo).
--
--    Entradas possuem valid individual (i_va_valid/i_vb_valid/i_vc_valid),
--    e saídas possuem valid individual (o_a_valid/o_b_valid/o_c_valid).
--
--    Otimizacaoo de ROM:
--      Usa apenas tabela de cosseno (COS_TAB). O seno é obtido por deslocamento:
--        sin(k) = cos(k - N/4)  -> para N=64: sin(k) = cos(k - 16)
--      Ou seja, índice do seno = k-16 (mod 64) = (k<16 ? k+48 : k-16).
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity phasor_64pts_3ph_optmization is
    generic (
        SAMPLE_WIDTH : integer := 12;  -- bits do sinal de entrada
        COEFF_WIDTH  : integer := 15;  -- bits dos coeficientes cos/sin
        ACC_WIDTH    : integer := 36   -- bits dos acumuladores
    );
    port (
        i_clk           : in  std_logic;
        i_rst           : in  std_logic;

        -- valid individual de cada fase (permite atualizar fases separadamente)
        i_va_valid      : in  std_logic;
        i_vb_valid      : in  std_logic;
        i_vc_valid      : in  std_logic;

        -- entradas trifásicas 12 bits sinalizadas (-2048..2047)
        i_va_12         : in  signed(SAMPLE_WIDTH-1 downto 0);
        i_vb_12         : in  signed(SAMPLE_WIDTH-1 downto 0);
        i_vc_12         : in  signed(SAMPLE_WIDTH-1 downto 0);

        -- saídas: fasores (Re/Im) de cada fase
        o_a_re, o_a_im  : out signed(ACC_WIDTH-1 downto 0);
        o_b_re, o_b_im  : out signed(ACC_WIDTH-1 downto 0);
        o_c_re, o_c_im  : out signed(ACC_WIDTH-1 downto 0);

        -- pulso 1 clk quando cada janela de 64 pontos enche (por fase)
        o_a_valid       : out std_logic;
        o_b_valid       : out std_logic;
        o_c_valid       : out std_logic;

        -- opcional: indica que algum fasor ficou válido neste ciclo
        o_phasor_valid  : out std_logic
    );
end entity;

architecture rtl of phasor_64pts_3ph_optmization is

    constant N_POINTS   : integer := 64;
    constant PROD_WIDTH : integer := SAMPLE_WIDTH + COEFF_WIDTH; -- 12+15 = 27 bits

    -- tipos auxiliares
    type cos_array_t  is array (0 to N_POINTS-1) of signed(COEFF_WIDTH-1 downto 0);
    type prod_array_t is array (0 to N_POINTS-1) of signed(PROD_WIDTH-1 downto 0);

    -- Tabela COS 64 pontos (escala 16383 ~ Q1.14/Q1.15)
    constant COS_TAB : cos_array_t := (
         0 => to_signed( 16383, 15),
         1 => to_signed( 16304, 15),
         2 => to_signed( 16068, 15),
         3 => to_signed( 15678, 15),
         4 => to_signed( 15136, 15),
         5 => to_signed( 14449, 15),
         6 => to_signed( 13622, 15),
         7 => to_signed( 12664, 15),
         8 => to_signed( 11585, 15),
         9 => to_signed( 10393, 15),
        10 => to_signed(  9102, 15),
        11 => to_signed(  7723, 15),
        12 => to_signed(  6270, 15),
        13 => to_signed(  4756, 15),
        14 => to_signed(  3196, 15),
        15 => to_signed(  1606, 15),
        16 => to_signed(     0, 15),
        17 => to_signed( -1606, 15),
        18 => to_signed( -3196, 15),
        19 => to_signed( -4756, 15),
        20 => to_signed( -6270, 15),
        21 => to_signed( -7723, 15),
        22 => to_signed( -9102, 15),
        23 => to_signed(-10393, 15),
        24 => to_signed(-11585, 15),
        25 => to_signed(-12664, 15),
        26 => to_signed(-13622, 15),
        27 => to_signed(-14449, 15),
        28 => to_signed(-15136, 15),
        29 => to_signed(-15678, 15),
        30 => to_signed(-16068, 15),
        31 => to_signed(-16304, 15),
        32 => to_signed(-16383, 15),
        33 => to_signed(-16304, 15),
        34 => to_signed(-16068, 15),
        35 => to_signed(-15678, 15),
        36 => to_signed(-15136, 15),
        37 => to_signed(-14449, 15),
        38 => to_signed(-13622, 15),
        39 => to_signed(-12664, 15),
        40 => to_signed(-11585, 15),
        41 => to_signed(-10393, 15),
        42 => to_signed( -9102, 15),
        43 => to_signed( -7723, 15),
        44 => to_signed( -6270, 15),
        45 => to_signed( -4756, 15),
        46 => to_signed( -3196, 15),
        47 => to_signed( -1606, 15),
        48 => to_signed(     0, 15),
        49 => to_signed(  1606, 15),
        50 => to_signed(  3196, 15),
        51 => to_signed(  4756, 15),
        52 => to_signed(  6270, 15),
        53 => to_signed(  7723, 15),
        54 => to_signed(  9102, 15),
        55 => to_signed( 10393, 15),
        56 => to_signed( 11585, 15),
        57 => to_signed( 12664, 15),
        58 => to_signed( 13622, 15),
        59 => to_signed( 14449, 15),
        60 => to_signed( 15136, 15),
        61 => to_signed( 15678, 15),
        62 => to_signed( 16068, 15),
        63 => to_signed( 16304, 15)
    );

    -- buffers com os termos a remover (armazenamos o NEGATIVO do termo antigo)
    signal rem_cos_a, rem_sin_a : prod_array_t := (others => (others => '0'));
    signal rem_cos_b, rem_sin_b : prod_array_t := (others => (others => '0'));
    signal rem_cos_c, rem_sin_c : prod_array_t := (others => (others => '0'));

    -- acumuladores (somatórios)
    signal sum_cos_a, sum_sin_a : signed(ACC_WIDTH-1 downto 0) := (others => '0');
    signal sum_cos_b, sum_sin_b : signed(ACC_WIDTH-1 downto 0) := (others => '0');
    signal sum_cos_c, sum_sin_c : signed(ACC_WIDTH-1 downto 0) := (others => '0');

    -- índices e contadores independentes por fase (suporta valids independentes)
    signal idx_a, idx_b, idx_c : integer range 0 to N_POINTS-1 := 0;
    signal cnt_a, cnt_b, cnt_c : integer range 0 to N_POINTS   := 0;

    signal a_valid_r, b_valid_r, c_valid_r : std_logic := '0';

begin

    -- saídas (DFT: Re = soma(x*cos), Im = -soma(x*sin))
    o_a_re <= sum_cos_a;
    o_a_im <= -sum_sin_a;

    o_b_re <= sum_cos_b;
    o_b_im <= -sum_sin_b;

    o_c_re <= sum_cos_c;
    o_c_im <= -sum_sin_c;

    o_a_valid <= a_valid_r;
    o_b_valid <= b_valid_r;
    o_c_valid <= c_valid_r;

    --o_phasor_valid <= a_valid_r or b_valid_r or c_valid_r;

    process(i_clk,i_rst)
        -- fase A
        variable v_idx_a   : integer range 0 to N_POINTS-1;
        variable v_sin_a   : integer range 0 to N_POINTS-1;
        variable cos_a     : signed(COEFF_WIDTH-1 downto 0);
        variable sin_a     : signed(COEFF_WIDTH-1 downto 0);
        variable pcos_a    : signed(PROD_WIDTH-1 downto 0);
        variable psin_a    : signed(PROD_WIDTH-1 downto 0);

        -- fase B
        variable v_idx_b   : integer range 0 to N_POINTS-1;
        variable v_sin_b   : integer range 0 to N_POINTS-1;
        variable cos_b     : signed(COEFF_WIDTH-1 downto 0);
        variable sin_b     : signed(COEFF_WIDTH-1 downto 0);
        variable pcos_b    : signed(PROD_WIDTH-1 downto 0);
        variable psin_b    : signed(PROD_WIDTH-1 downto 0);

        -- fase C
        variable v_idx_c   : integer range 0 to N_POINTS-1;
        variable v_sin_c   : integer range 0 to N_POINTS-1;
        variable cos_c     : signed(COEFF_WIDTH-1 downto 0);
        variable sin_c     : signed(COEFF_WIDTH-1 downto 0);
        variable pcos_c    : signed(PROD_WIDTH-1 downto 0);
        variable psin_c    : signed(PROD_WIDTH-1 downto 0);
    begin
        
		if i_rst = '1' then
			idx_a <= 0; idx_b <= 0; idx_c <= 0;
			cnt_a <= 0; cnt_b <= 0; cnt_c <= 0;

			a_valid_r <= '0';
			b_valid_r <= '0';
			c_valid_r <= '0';

			sum_cos_a <= (others => '0'); sum_sin_a <= (others => '0');
			sum_cos_b <= (others => '0'); sum_sin_b <= (others => '0');
			sum_cos_c <= (others => '0'); sum_sin_c <= (others => '0');

			rem_cos_a <= (others => (others => '0'));
			rem_sin_a <= (others => (others => '0'));
			rem_cos_b <= (others => (others => '0'));
			rem_sin_b <= (others => (others => '0'));
			rem_cos_c <= (others => (others => '0'));
			rem_sin_c <= (others => (others => '0'));
			o_phasor_valid <= '0';
		
		
		elsif rising_edge(i_clk) then
  

                -- pulso de 1 ciclo quando cada fase completa 64 amostras
			----------------------------------------------------------------
			-- FASE A
			----------------------------------------------------------------
			if i_va_valid = '1' then
				v_idx_a := idx_a;

				-- sin(k)=cos(k-16) => (k<16 ? k+48 : k-16)
				if v_idx_a < (N_POINTS/4) then
					v_sin_a := v_idx_a + (N_POINTS - (N_POINTS/4)); -- +48
				else
					v_sin_a := v_idx_a - (N_POINTS/4);              -- -16
				end if;

				cos_a := COS_TAB(v_idx_a);
				sin_a := COS_TAB(v_sin_a);

				pcos_a := i_va_12 * cos_a;
				psin_a := i_va_12 * sin_a;

				sum_cos_a <= sum_cos_a
							 + resize(pcos_a, ACC_WIDTH)
							 + resize(rem_cos_a(v_idx_a), ACC_WIDTH);
				sum_sin_a <= sum_sin_a
							 + resize(psin_a, ACC_WIDTH)
							 + resize(rem_sin_a(v_idx_a), ACC_WIDTH);

				rem_cos_a(v_idx_a) <= -pcos_a;
				rem_sin_a(v_idx_a) <= -psin_a;
				
				a_valid_r <= '1';
				

				if idx_a = N_POINTS-1 then idx_a <= 0; else idx_a <= idx_a + 1; end if;

				if cnt_a < N_POINTS then cnt_a <= cnt_a + 1; end if;
				if cnt_a = N_POINTS-1 then o_phasor_valid <= '1'; end if;
				
			else
				  a_valid_r <= '0';
			end if;

			----------------------------------------------------------------
			-- FASE B
			----------------------------------------------------------------
			if i_vb_valid = '1' then
				v_idx_b := idx_b;

				if v_idx_b < (N_POINTS/4) then
					v_sin_b := v_idx_b + (N_POINTS - (N_POINTS/4));
				else
					v_sin_b := v_idx_b - (N_POINTS/4);
				end if;

				cos_b := COS_TAB(v_idx_b);
				sin_b := COS_TAB(v_sin_b);

				pcos_b := i_vb_12 * cos_b;
				psin_b := i_vb_12 * sin_b;

				sum_cos_b <= sum_cos_b
							 + resize(pcos_b, ACC_WIDTH)
							 + resize(rem_cos_b(v_idx_b), ACC_WIDTH);
				sum_sin_b <= sum_sin_b
							 + resize(psin_b, ACC_WIDTH)
							 + resize(rem_sin_b(v_idx_b), ACC_WIDTH);

				rem_cos_b(v_idx_b) <= -pcos_b;
				rem_sin_b(v_idx_b) <= -psin_b;
				
				 b_valid_r <= '1';

				if idx_b = N_POINTS-1 then idx_b <= 0; else idx_b <= idx_b + 1; end if;

				if cnt_b < N_POINTS then cnt_b <= cnt_b + 1; end if;
				if cnt_b = N_POINTS-1 then o_phasor_valid <= '1'; end if;
			else
				  b_valid_r <= '0';
			end if;

			----------------------------------------------------------------
			-- FASE C
			----------------------------------------------------------------
			if i_vc_valid = '1' then
				v_idx_c := idx_c;

				if v_idx_c < (N_POINTS/4) then
					v_sin_c := v_idx_c + (N_POINTS - (N_POINTS/4));
				else
					v_sin_c := v_idx_c - (N_POINTS/4);
				end if;

				cos_c := COS_TAB(v_idx_c);
				sin_c := COS_TAB(v_sin_c);

				pcos_c := i_vc_12 * cos_c;
				psin_c := i_vc_12 * sin_c;

				sum_cos_c <= sum_cos_c
							 + resize(pcos_c, ACC_WIDTH)
							 + resize(rem_cos_c(v_idx_c), ACC_WIDTH);
				sum_sin_c <= sum_sin_c
							 + resize(psin_c, ACC_WIDTH)
							 + resize(rem_sin_c(v_idx_c), ACC_WIDTH);

				rem_cos_c(v_idx_c) <= -pcos_c;
				rem_sin_c(v_idx_c) <= -psin_c;
				
				 c_valid_r <= '1';

				if idx_c = N_POINTS-1 then idx_c <= 0; else idx_c <= idx_c + 1; end if;

				if cnt_c < N_POINTS then cnt_c <= cnt_c + 1; end if;
				if cnt_c = N_POINTS-1 then o_phasor_valid <= '1'; end if;
			else
				  c_valid_r <= '0';
			end if;

        end if; -- rising edge
    end process;

end architecture;
