-- ============================================================================
--  Author      : Prof. Dr. Andre dos Anjos
--  Block       : phasor_metrics_3ph
--  Description :
--    Pós-processamento dos fasores trifásicos (Re/Im) calculados por DFT/Phasor:
--      - Módulo |X| (abs)
--      - Ângulo ?X (atan2)  -> saída em radianos (formato fixo Q3.13)
--      - RMS aproximado     -> RMS = |X| / sqrt(2) (constante Q15)
--
--    Implementação:
--      - CORDIC em modo vetorização (vectoring) com pipeline (ITER estágios)
--      - Throughput = 1 amostra por clock por fase
--      - Latência ~ ITER clocks
--
--    CORRECAO DE TIMING:
--      - Pipeline extra POS-CORDIC em 3 estágios (P1/P2/P3)
--      - Registradores SEM clock-enable (evita otimização/retiming agressivo)
--      - Atributos KEEP/DONT_TOUCH nos regs intermediários
--      - Quebra o caminho critico: CORDIC_last_reg -> (mul abs) -> (mul rms) -> saida
--
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity phasor_metrics_3ph is
  generic (
    IN_WIDTH   : integer := 36;
    OUT_WIDTH  : integer := 32;
    ANG_WIDTH  : integer := 16;  -- Q3.13
    ITER       : integer := 16
  );
  port (
    i_clk           : in  std_logic;
    i_rst           : in  std_logic;

    -- Fase A
    i_valid_phaseA  : in  std_logic;
    i_real_phaseA   : in  signed(IN_WIDTH-1 downto 0);
    i_imag_phaseA   : in  signed(IN_WIDTH-1 downto 0);

    -- Fase B
    i_valid_phaseB  : in  std_logic;
    i_real_phaseB   : in  signed(IN_WIDTH-1 downto 0);
    i_imag_phaseB   : in  signed(IN_WIDTH-1 downto 0);

    -- Fase C
    i_valid_phaseC  : in  std_logic;
    i_real_phaseC   : in  signed(IN_WIDTH-1 downto 0);
    i_imag_phaseC   : in  signed(IN_WIDTH-1 downto 0);

    -- Saídas fase A
    o_rms_phaseA    : out unsigned(OUT_WIDTH-1 downto 0);
    o_angle_phaseA  : out signed(ANG_WIDTH-1 downto 0);
    o_abs_phaseA    : out unsigned(OUT_WIDTH-1 downto 0);

    -- Saídas fase B
    o_rms_phaseB    : out unsigned(OUT_WIDTH-1 downto 0);
    o_angle_phaseB  : out signed(ANG_WIDTH-1 downto 0);
    o_abs_phaseB    : out unsigned(OUT_WIDTH-1 downto 0);

    -- Saídas fase C
    o_rms_phaseC    : out unsigned(OUT_WIDTH-1 downto 0);
    o_angle_phaseC  : out signed(ANG_WIDTH-1 downto 0);
    o_abs_phaseC    : out unsigned(OUT_WIDTH-1 downto 0)
  );
end entity;

architecture rtl of phasor_metrics_3ph is

  constant PI_Q13   : integer := 25736;        -- round(pi * 2^13)
  constant PIO2_Q13 : integer := PI_Q13/2;     -- pi/2 em Q13

  function angle_cos_ref(angle_in : signed(ANG_WIDTH-1 downto 0)) return signed is
    variable a : integer;
  begin
    a := to_integer(angle_in) + PIO2_Q13;

    if a < -PI_Q13 then
      a := a + (2*PI_Q13);
    elsif a > PI_Q13 then
      a := a - (2*PI_Q13);
    end if;

    return to_signed(a, ANG_WIDTH);
  end function;

  type atan_tab_t is array (0 to ITER-1) of signed(ANG_WIDTH-1 downto 0);
  constant ATAN_TAB : atan_tab_t := (
    0  => to_signed( 6434, ANG_WIDTH),
    1  => to_signed( 3798, ANG_WIDTH),
    2  => to_signed( 2007, ANG_WIDTH),
    3  => to_signed( 1019, ANG_WIDTH),
    4  => to_signed(  511, ANG_WIDTH),
    5  => to_signed(  256, ANG_WIDTH),
    6  => to_signed(  128, ANG_WIDTH),
    7  => to_signed(   64, ANG_WIDTH),
    8  => to_signed(   32, ANG_WIDTH),
    9  => to_signed(   16, ANG_WIDTH),
    10 => to_signed(    8, ANG_WIDTH),
    11 => to_signed(    4, ANG_WIDTH),
    12 => to_signed(    2, ANG_WIDTH),
    13 => to_signed(    1, ANG_WIDTH),
    14 => to_signed(    0, ANG_WIDTH),
    15 => to_signed(    0, ANG_WIDTH)
  );

  constant KINV_CORDIC_Q15 : unsigned(15 downto 0) := to_unsigned(19898, 16);
  constant INV_SQRT2_Q15   : unsigned(15 downto 0) := to_unsigned(23170, 16);

  constant W : integer := IN_WIDTH + 2;

  type svec_t is array (0 to ITER) of signed(W-1 downto 0);
  type avec_t is array (0 to ITER) of signed(ANG_WIDTH-1 downto 0);
  type vvec_t is array (0 to ITER) of std_logic;

  function cordic_mag_q15(x_in : signed(W-1 downto 0)) return unsigned is
    variable x_pos  : unsigned(W-1 downto 0);
    variable prod   : unsigned(W+16-1 downto 0);
    variable mag_u  : unsigned(W-1 downto 0);
    variable res    : unsigned(OUT_WIDTH-1 downto 0);
  begin
    if x_in < 0 then
      x_pos := unsigned(-x_in);
    else
      x_pos := unsigned(x_in);
    end if;

    prod  := x_pos * KINV_CORDIC_Q15;
    mag_u := prod(15+W-1 downto 15);

    res := resize(mag_u, OUT_WIDTH);
    return res;
  end function;

  function rms_from_abs(abs_in : unsigned(OUT_WIDTH-1 downto 0)) return unsigned is
    variable prod : unsigned(OUT_WIDTH+16-1 downto 0);
    variable rmsu : unsigned(OUT_WIDTH-1 downto 0);
  begin
    prod := abs_in * INV_SQRT2_Q15;
    rmsu := prod(15+OUT_WIDTH-1 downto 15);
    return rmsu;
  end function;

  -- ==========================
  -- CORDIC PIPELINES (A/B/C)
  -- ==========================
  signal xa, ya : svec_t;
  signal za     : avec_t;
  signal va     : vvec_t;

  signal xb, yb : svec_t;
  signal zb     : avec_t;
  signal vb     : vvec_t;

  signal xc, yc : svec_t;
  signal zc     : avec_t;
  signal vc     : vvec_t;

  -- ==========================
  -- PIPE EXTRA (TIMING FIX)
  -- ==========================
  -- P1: regs SEM enable (captura todo clock)
  signal x1_a, x1_b, x1_c : signed(W-1 downto 0) := (others => '0');
  signal z1_a, z1_b, z1_c : signed(ANG_WIDTH-1 downto 0) := (others => '0');
  signal v1_a, v1_b, v1_c : std_logic := '0';

  -- P2: abs/angle registrados
  signal abs2_a, abs2_b, abs2_c : unsigned(OUT_WIDTH-1 downto 0) := (others => '0');
  signal ang2_a, ang2_b, ang2_c : signed(ANG_WIDTH-1 downto 0)   := (others => '0');
  signal v2_a, v2_b, v2_c       : std_logic := '0';

  -- P3: rms registrado
  signal v3_a, v3_b, v3_c : std_logic := '0';

  -- Atributos para evitar retiming/otimizacao dos regs intermediarios
  attribute keep : string;
  attribute dont_touch : string;
  
  attribute keep_hierarchy : string;
  attribute keep_hierarchy of rtl : architecture is "yes";

  attribute keep       of x1_a   : signal is "true";
  attribute keep       of x1_b   : signal is "true";
  attribute keep       of x1_c   : signal is "true";
  attribute keep       of z1_a   : signal is "true";
  attribute keep       of z1_b   : signal is "true";
  attribute keep       of z1_c   : signal is "true";
  attribute keep       of abs2_a : signal is "true";
  attribute keep       of abs2_b : signal is "true";
  attribute keep       of abs2_c : signal is "true";
  attribute keep       of ang2_a : signal is "true";
  attribute keep       of ang2_b : signal is "true";
  attribute keep       of ang2_c : signal is "true";

  attribute dont_touch of x1_a   : signal is "true";
  attribute dont_touch of x1_b   : signal is "true";
  attribute dont_touch of x1_c   : signal is "true";
  attribute dont_touch of z1_a   : signal is "true";
  attribute dont_touch of z1_b   : signal is "true";
  attribute dont_touch of z1_c   : signal is "true";
  attribute dont_touch of abs2_a : signal is "true";
  attribute dont_touch of abs2_b : signal is "true";
  attribute dont_touch of abs2_c : signal is "true";
  attribute dont_touch of ang2_a : signal is "true";
  attribute dont_touch of ang2_b : signal is "true";
  attribute dont_touch of ang2_c : signal is "true";

begin

  ------------------------------------------------------------------------------
  -- STAGE 0 (quadrant handling) - A
  ------------------------------------------------------------------------------
  p_stage0_a : process(i_clk)
    variable x0, y0 : signed(W-1 downto 0);
    variable z0     : signed(ANG_WIDTH-1 downto 0);
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        xa(0) <= (others => '0');
        ya(0) <= (others => '0');
        za(0) <= (others => '0');
        va(0) <= '0';
      else
        va(0) <= i_valid_phaseA;

        x0 := resize(i_real_phaseA, W);
        y0 := resize(i_imag_phaseA, W);
        z0 := (others => '0');

        if i_valid_phaseA = '1' then
          if x0 < 0 then
            x0 := -x0;
            y0 := -y0;
            if y0 >= 0 then
              z0 := to_signed( PI_Q13, ANG_WIDTH);
            else
              z0 := to_signed(-PI_Q13, ANG_WIDTH);
            end if;
          end if;

          xa(0) <= x0;
          ya(0) <= y0;
          za(0) <= z0;
        end if;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- STAGE 0 - B
  ------------------------------------------------------------------------------
  p_stage0_b : process(i_clk)
    variable x0, y0 : signed(W-1 downto 0);
    variable z0     : signed(ANG_WIDTH-1 downto 0);
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        xb(0) <= (others => '0');
        yb(0) <= (others => '0');
        zb(0) <= (others => '0');
        vb(0) <= '0';
      else
        vb(0) <= i_valid_phaseB;

        x0 := resize(i_real_phaseB, W);
        y0 := resize(i_imag_phaseB, W);
        z0 := (others => '0');

        if i_valid_phaseB = '1' then
          if x0 < 0 then
            x0 := -x0;
            y0 := -y0;
            if y0 >= 0 then
              z0 := to_signed( PI_Q13, ANG_WIDTH);
            else
              z0 := to_signed(-PI_Q13, ANG_WIDTH);
            end if;
          end if;

          xb(0) <= x0;
          yb(0) <= y0;
          zb(0) <= z0;
        end if;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- STAGE 0 - C
  ------------------------------------------------------------------------------
  p_stage0_c : process(i_clk)
    variable x0, y0 : signed(W-1 downto 0);
    variable z0     : signed(ANG_WIDTH-1 downto 0);
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        xc(0) <= (others => '0');
        yc(0) <= (others => '0');
        zc(0) <= (others => '0');
        vc(0) <= '0';
      else
        vc(0) <= i_valid_phaseC;

        x0 := resize(i_real_phaseC, W);
        y0 := resize(i_imag_phaseC, W);
        z0 := (others => '0');

        if i_valid_phaseC = '1' then
          if x0 < 0 then
            x0 := -x0;
            y0 := -y0;
            if y0 >= 0 then
              z0 := to_signed( PI_Q13, ANG_WIDTH);
            else
              z0 := to_signed(-PI_Q13, ANG_WIDTH);
            end if;
          end if;

          xc(0) <= x0;
          yc(0) <= y0;
          zc(0) <= z0;
        end if;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- PIPELINE CORDIC (ITER estágios) - A/B/C (vectoring mode)
  ------------------------------------------------------------------------------
  gen_cordic : for i in 0 to ITER-1 generate

    -- A
    p_cordic_a : process(i_clk)
      variable x_i, y_i   : signed(W-1 downto 0);
      variable z_i        : signed(ANG_WIDTH-1 downto 0);
      variable x_sh, y_sh : signed(W-1 downto 0);
    begin
      if rising_edge(i_clk) then
        if i_rst = '1' then
          xa(i+1) <= (others => '0');
          ya(i+1) <= (others => '0');
          za(i+1) <= (others => '0');
          va(i+1) <= '0';
        else
          va(i+1) <= va(i);
          if va(i) = '1' then
            x_i := xa(i);
            y_i := ya(i);
            z_i := za(i);

            x_sh := shift_right(x_i, i);
            y_sh := shift_right(y_i, i);

            if y_i < 0 then
              xa(i+1) <= x_i - y_sh;
              ya(i+1) <= y_i + x_sh;
              za(i+1) <= z_i - ATAN_TAB(i);
            else
              xa(i+1) <= x_i + y_sh;
              ya(i+1) <= y_i - x_sh;
              za(i+1) <= z_i + ATAN_TAB(i);
            end if;
          end if;
        end if;
      end if;
    end process;

    -- B
    p_cordic_b : process(i_clk)
      variable x_i, y_i   : signed(W-1 downto 0);
      variable z_i        : signed(ANG_WIDTH-1 downto 0);
      variable x_sh, y_sh : signed(W-1 downto 0);
    begin
      if rising_edge(i_clk) then
        if i_rst = '1' then
          xb(i+1) <= (others => '0');
          yb(i+1) <= (others => '0');
          zb(i+1) <= (others => '0');
          vb(i+1) <= '0';
        else
          vb(i+1) <= vb(i);
          if vb(i) = '1' then
            x_i := xb(i);
            y_i := yb(i);
            z_i := zb(i);

            x_sh := shift_right(x_i, i);
            y_sh := shift_right(y_i, i);

            if y_i < 0 then
              xb(i+1) <= x_i - y_sh;
              yb(i+1) <= y_i + x_sh;
              zb(i+1) <= z_i - ATAN_TAB(i);
            else
              xb(i+1) <= x_i + y_sh;
              yb(i+1) <= y_i - x_sh;
              zb(i+1) <= z_i + ATAN_TAB(i);
            end if;
          end if;
        end if;
      end if;
    end process;

    -- C
    p_cordic_c : process(i_clk)
      variable x_i, y_i   : signed(W-1 downto 0);
      variable z_i        : signed(ANG_WIDTH-1 downto 0);
      variable x_sh, y_sh : signed(W-1 downto 0);
    begin
      if rising_edge(i_clk) then
        if i_rst = '1' then
          xc(i+1) <= (others => '0');
          yc(i+1) <= (others => '0');
          zc(i+1) <= (others => '0');
          vc(i+1) <= '0';
        else
          vc(i+1) <= vc(i);
          if vc(i) = '1' then
            x_i := xc(i);
            y_i := yc(i);
            z_i := zc(i);

            x_sh := shift_right(x_i, i);
            y_sh := shift_right(y_i, i);

            if y_i < 0 then
              xc(i+1) <= x_i - y_sh;
              yc(i+1) <= y_i + x_sh;
              zc(i+1) <= z_i - ATAN_TAB(i);
            else
              xc(i+1) <= x_i + y_sh;
              yc(i+1) <= y_i - x_sh;
              zc(i+1) <= z_i + ATAN_TAB(i);
            end if;
          end if;
        end if;
      end if;
    end process;

  end generate;

  ------------------------------------------------------------------------------
  -- P1: REGISTRA SAIDAS DO CORDIC (SEM ENABLE)
  ------------------------------------------------------------------------------
  p_post_p1 : process(i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        x1_a <= (others => '0'); z1_a <= (others => '0'); v1_a <= '0';
        x1_b <= (others => '0'); z1_b <= (others => '0'); v1_b <= '0';
        x1_c <= (others => '0'); z1_c <= (others => '0'); v1_c <= '0';
      else
        -- captura SEMPRE (quebra caminho critico com certeza)
        x1_a <= xa(ITER);  z1_a <= za(ITER);  v1_a <= va(ITER);
        x1_b <= xb(ITER);  z1_b <= zb(ITER);  v1_b <= vb(ITER);
        x1_c <= xc(ITER);  z1_c <= zc(ITER);  v1_c <= vc(ITER);
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- P2: CALCULA E REGISTRA ABS/ANGLE (1 multiplicador aqui)
  ------------------------------------------------------------------------------
  p_post_p2 : process(i_clk)
    variable abs_a, abs_b, abs_c : unsigned(OUT_WIDTH-1 downto 0);
    variable ang_a, ang_b, ang_c : signed(ANG_WIDTH-1 downto 0);
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        abs2_a <= (others => '0'); ang2_a <= (others => '0'); v2_a <= '0';
        abs2_b <= (others => '0'); ang2_b <= (others => '0'); v2_b <= '0';
        abs2_c <= (others => '0'); ang2_c <= (others => '0'); v2_c <= '0';

        o_abs_phaseA   <= (others => '0');
        o_angle_phaseA <= (others => '0');
        o_abs_phaseB   <= (others => '0');
        o_angle_phaseB <= (others => '0');
        o_abs_phaseC   <= (others => '0');
        o_angle_phaseC <= (others => '0');
      else
        v2_a <= v1_a;
        v2_b <= v1_b;
        v2_c <= v1_c;

        if v1_a = '1' then
          abs_a := cordic_mag_q15(x1_a);
          ang_a := angle_cos_ref(z1_a);
          abs2_a <= abs_a;
          ang2_a <= ang_a;
          o_abs_phaseA   <= abs_a;
          o_angle_phaseA <= ang_a;
        end if;

        if v1_b = '1' then
          abs_b := cordic_mag_q15(x1_b);
          ang_b := angle_cos_ref(z1_b);
          abs2_b <= abs_b;
          ang2_b <= ang_b;
          o_abs_phaseB   <= abs_b;
          o_angle_phaseB <= ang_b;
        end if;

        if v1_c = '1' then
          abs_c := cordic_mag_q15(x1_c);
          ang_c := angle_cos_ref(z1_c);
          abs2_c <= abs_c;
          ang2_c <= ang_c;
          o_abs_phaseC   <= abs_c;
          o_angle_phaseC <= ang_c;
        end if;

      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- P3: CALCULA E REGISTRA RMS (2o multiplicador aqui, separado)
  ------------------------------------------------------------------------------
  p_post_p3 : process(i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        o_rms_phaseA <= (others => '0');
        o_rms_phaseB <= (others => '0');
        o_rms_phaseC <= (others => '0');
        v3_a <= '0'; v3_b <= '0'; v3_c <= '0';
      else
        v3_a <= v2_a;
        v3_b <= v2_b;
        v3_c <= v2_c;

        if v2_a = '1' then
          o_rms_phaseA <= rms_from_abs(abs2_a);
        end if;

        if v2_b = '1' then
          o_rms_phaseB <= rms_from_abs(abs2_b);
        end if;

        if v2_c = '1' then
          o_rms_phaseC <= rms_from_abs(abs2_c);
        end if;

      end if;
    end if;
  end process;

end architecture;
