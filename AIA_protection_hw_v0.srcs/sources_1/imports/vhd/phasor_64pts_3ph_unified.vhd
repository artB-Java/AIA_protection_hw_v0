-- ============================================================================
--  Author      : Prof. Dr. Andre dos Anjos
--  Block       : phasor_64pts_3ph_unified
--  Description :
--    Bloco unificado de estimação de fasor e métricas trifásicas (A, B e C).
--
--    Estima o fasor fundamental por meio de DFT incremental em janela
--    deslizante de 64 pontos, com atualização add/remove, e calcula:
--      - Re/Im do fasor
--      - |X| e ângulo (CORDIC vetorização)
--      - RMS ~= |X|/sqrt(2)
--
--    Implementação:
--      - DFT incremental com estados independentes por fase
--      - Otimização de ROM: apenas cos; sin obtido por deslocamento (k-16)
--      - Um único engine DFT + um único CORDIC compartilhado entre fases
--        (assumindo valids não simultâneos)
--      - Pipeline CORDIC (ITER) + P1/P2/P3 pós-processamento (timing)
--
--    Versão DFT FSM (sem variáveis):
--      - FSM 100% registrada, sem variáveis no engine DFT
--      - RAM rem_cos/rem_sin sem reset para inferir LUTRAM corretamente
--      - Termo antigo tratado como 0 enquanto janela não está cheia
--
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity phasor_64pts_3ph_unified is
  generic (
    SAMPLE_WIDTH : integer := 12;
    COEFF_WIDTH  : integer := 15;
    ACC_WIDTH    : integer := 36;
    OUT_WIDTH    : integer := 32;
    ANG_WIDTH    : integer := 16;
    ITER         : integer := 16
  );
  port (
    -- Clock e reset
    i_clk : in  std_logic;
    i_rst : in  std_logic;

    -- Entradas – Fase A
    i_signal_phaseA_12 : in  signed(SAMPLE_WIDTH-1 downto 0);
    i_valid_phaseA     : in  std_logic;

    -- Entradas – Fase B
    i_signal_phasB_12  : in  signed(SAMPLE_WIDTH-1 downto 0);
    i_valid_phaseB     : in  std_logic;

    -- Entradas – Fase C
    i_signal_phaseC_12 : in  signed(SAMPLE_WIDTH-1 downto 0);
    i_valid_phaseC     : in  std_logic;

    -- Saídas – Fase A
    o_valid_phaseA     : out std_logic;
    o_Real_phaseA      : out signed(ACC_WIDTH-1 downto 0);
    o_Imag_phaseA      : out signed(ACC_WIDTH-1 downto 0);
    o_RMS_phaseA       : out unsigned(OUT_WIDTH-1 downto 0);
    o_phase_phaseA     : out signed(ANG_WIDTH-1 downto 0);

    -- Saídas – Fase B
    o_valid_phaseB     : out std_logic;
    o_Real_phaseB      : out signed(ACC_WIDTH-1 downto 0);
    o_Imag_phaseB      : out signed(ACC_WIDTH-1 downto 0);
    o_RMS_phaseB       : out unsigned(OUT_WIDTH-1 downto 0);
    o_phase_phaseB     : out signed(ANG_WIDTH-1 downto 0);

    -- Saídas – Fase C
    o_valid_phaseC     : out std_logic;
    o_Real_phaseC      : out signed(ACC_WIDTH-1 downto 0);
    o_Imag_phaseC      : out signed(ACC_WIDTH-1 downto 0);
    o_RMS_phaseC       : out unsigned(OUT_WIDTH-1 downto 0);
    o_phase_phaseC     : out signed(ANG_WIDTH-1 downto 0)
  );
end entity;

architecture rtl of phasor_64pts_3ph_unified is

  constant N_POINTS   : integer := 64;
  constant PROD_WIDTH : integer := SAMPLE_WIDTH + COEFF_WIDTH;

  constant ANG_FRAC : integer := 13;
  constant PI_Q13   : integer := 25736;
  constant PIO2_Q13 : integer := PI_Q13/2;

  constant KINV_CORDIC_Q15 : unsigned(15 downto 0) := to_unsigned(19898, 16);
  constant INV_SQRT2_Q15   : unsigned(15 downto 0) := to_unsigned(23170, 16);

  constant W : integer := ACC_WIDTH + 2;

  type cos_array_t  is array (0 to N_POINTS-1) of signed(COEFF_WIDTH-1 downto 0);
  type prod_array_t is array (0 to N_POINTS-1) of signed(PROD_WIDTH-1 downto 0);

  type prod_3x64_t is array (0 to 2) of prod_array_t;
  type acc3_t      is array (0 to 2) of signed(ACC_WIDTH-1 downto 0);
  type idx3_t      is array (0 to 2) of integer range 0 to N_POINTS-1;
  type cnt3_t      is array (0 to 2) of integer range 0 to N_POINTS;
  type bit3_t      is array (0 to 2) of std_logic;

  type uout3_t     is array (0 to 2) of unsigned(OUT_WIDTH-1 downto 0);
  type ang3_t      is array (0 to 2) of signed(ANG_WIDTH-1 downto 0);

  type svec_t is array (0 to ITER) of signed(W-1 downto 0);
  type avec_t is array (0 to ITER) of signed(ANG_WIDTH-1 downto 0);
  type vvec_t is array (0 to ITER) of std_logic;
  type tvec_t is array (0 to ITER) of unsigned(1 downto 0);
  type rvec_t is array (0 to ITER) of signed(ACC_WIDTH-1 downto 0);

  constant COS_TAB : cos_array_t := (
     0 => to_signed( 16383, 15),  1 => to_signed( 16304, 15),
     2 => to_signed( 16068, 15),  3 => to_signed( 15678, 15),
     4 => to_signed( 15136, 15),  5 => to_signed( 14449, 15),
     6 => to_signed( 13622, 15),  7 => to_signed( 12664, 15),
     8 => to_signed( 11585, 15),  9 => to_signed( 10393, 15),
    10 => to_signed(  9102, 15), 11 => to_signed(  7723, 15),
    12 => to_signed(  6270, 15), 13 => to_signed(  4756, 15),
    14 => to_signed(  3196, 15), 15 => to_signed(  1606, 15),
    16 => to_signed(     0, 15), 17 => to_signed( -1606, 15),
    18 => to_signed( -3196, 15), 19 => to_signed( -4756, 15),
    20 => to_signed( -6270, 15), 21 => to_signed( -7723, 15),
    22 => to_signed( -9102, 15), 23 => to_signed(-10393, 15),
    24 => to_signed(-11585, 15), 25 => to_signed(-12664, 15),
    26 => to_signed(-13622, 15), 27 => to_signed(-14449, 15),
    28 => to_signed(-15136, 15), 29 => to_signed(-15678, 15),
    30 => to_signed(-16068, 15), 31 => to_signed(-16304, 15),
    32 => to_signed(-16383, 15), 33 => to_signed(-16304, 15),
    34 => to_signed(-16068, 15), 35 => to_signed(-15678, 15),
    36 => to_signed(-15136, 15), 37 => to_signed(-14449, 15),
    38 => to_signed(-13622, 15), 39 => to_signed(-12664, 15),
    40 => to_signed(-11585, 15), 41 => to_signed(-10393, 15),
    42 => to_signed( -9102, 15), 43 => to_signed( -7723, 15),
    44 => to_signed( -6270, 15), 45 => to_signed( -4756, 15),
    46 => to_signed( -3196, 15), 47 => to_signed( -1606, 15),
    48 => to_signed(     0, 15), 49 => to_signed(  1606, 15),
    50 => to_signed(  3196, 15), 51 => to_signed(  4756, 15),
    52 => to_signed(  6270, 15), 53 => to_signed(  7723, 15),
    54 => to_signed(  9102, 15), 55 => to_signed( 10393, 15),
    56 => to_signed( 11585, 15), 57 => to_signed( 12664, 15),
    58 => to_signed( 13622, 15), 59 => to_signed( 14449, 15),
    60 => to_signed( 15136, 15), 61 => to_signed( 15678, 15),
    62 => to_signed( 16068, 15), 63 => to_signed( 16304, 15)
  );

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

  type atan_tab16_t is array (0 to 15) of signed(ANG_WIDTH-1 downto 0);
  constant ATAN_TAB16 : atan_tab16_t := (
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

  function cordic_mag_q15(x_in : signed(W-1 downto 0)) return unsigned is
    variable x_pos  : unsigned(W-1 downto 0);
    variable prod   : unsigned(W+16-1 downto 0);
    variable mag_u  : unsigned(W-1 downto 0);
    variable res    : unsigned(OUT_WIDTH-1 downto 0);
  begin
    if x_in < 0 then x_pos := unsigned(-x_in); else x_pos := unsigned(x_in); end if;
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
  -- DFT STATE (memórias e somas)
  -- ==========================
  signal rem_cos : prod_3x64_t := (others => (others => (others => '0'))); -- (init opcional p/ sim)
  signal rem_sin : prod_3x64_t := (others => (others => (others => '0')));

  signal sum_cos : acc3_t := (others => (others => '0'));
  signal sum_sin : acc3_t := (others => (others => '0'));

  signal idx     : idx3_t := (others => 0);
  signal cnt     : cnt3_t := (others => 0);
  signal full    : bit3_t := (others => '0');

  -- ==========================
  -- CORDIC INPUT (single stream)
  -- ==========================
  signal in_valid : std_logic := '0';
  signal in_tag   : unsigned(1 downto 0) := (others => '0');
  signal in_re    : signed(ACC_WIDTH-1 downto 0) := (others => '0');
  signal in_im    : signed(ACC_WIDTH-1 downto 0) := (others => '0');

  -- ==========================
  -- CORDIC PIPE (single stream)
  -- ==========================
  signal xpipe, ypipe : svec_t;
  signal zpipe        : avec_t;
  signal vpipe        : vvec_t;
  signal tpipe        : tvec_t;

  signal rpipe, ipipe : rvec_t;

  -- ==========================
  -- EXTRA PIPE P1/P2/P3
  -- ==========================
  signal x1   : signed(W-1 downto 0) := (others => '0');
  signal z1   : signed(ANG_WIDTH-1 downto 0) := (others => '0');
  signal r1   : signed(ACC_WIDTH-1 downto 0) := (others => '0');
  signal i1   : signed(ACC_WIDTH-1 downto 0) := (others => '0');
  signal v1   : std_logic := '0';
  signal t1   : unsigned(1 downto 0) := (others => '0');

  signal abs2 : unsigned(OUT_WIDTH-1 downto 0) := (others => '0');
  signal ang2 : signed(ANG_WIDTH-1 downto 0) := (others => '0');
  signal r2   : signed(ACC_WIDTH-1 downto 0) := (others => '0');
  signal i2   : signed(ACC_WIDTH-1 downto 0) := (others => '0');
  signal v2   : std_logic := '0';
  signal t2   : unsigned(1 downto 0) := (others => '0');

  -- ==========================
  -- OUTPUT REGISTERS
  -- ==========================
  signal ovalid_r : bit3_t := (others => '0');
  signal oRe_r    : acc3_t := (others => (others => '0'));
  signal oIm_r    : acc3_t := (others => (others => '0'));
  signal oRMS_r   : uout3_t := (others => (others => '0'));
  signal oANG_r   : ang3_t  := (others => (others => '0'));

  -- ==========================
  -- DFT FSM (sem variáveis)
  -- ==========================
  type dft_state_t is (
    DFT_IDLE,        -- espera um valid (A>B>C)
    DFT_LATCH,       -- captura fase/amostra/k/flags
	DFT_COEFF,
    DFT_MUL,         -- calcula pcos/psin (registrado)
    DFT_READ_OLD,    -- lê termo antigo (RAM) / zera se não full
    DFT_ACCUM,       -- calcula next_sc/next_ss
    DFT_WRITE_RAM,   -- escreve -pcos/-psin no endereço k
    DFT_UPDATE,      -- atualiza idx/cnt/full
    DFT_SEND         -- emite in_valid + in_re/in_im
  );
  signal dft_state : dft_state_t := DFT_IDLE;

  -- seleção registrada
  signal sel_valid_r : std_logic := '0';
  signal sel_tag_r   : unsigned(1 downto 0) := (others => '0');
  signal sel_x_r     : signed(SAMPLE_WIDTH-1 downto 0) := (others => '0');

  signal ph_r        : integer range 0 to 2 := 0;
  signal k_r         : integer range 0 to N_POINTS-1 := 0;
  signal ksin_r      : integer range 0 to N_POINTS-1 := 0;

  signal cos_k_r     : signed(COEFF_WIDTH-1 downto 0) := (others => '0');
  signal sin_k_r     : signed(COEFF_WIDTH-1 downto 0) := (others => '0');

  signal pcos_r      : signed(PROD_WIDTH-1 downto 0) := (others => '0');
  signal psin_r      : signed(PROD_WIDTH-1 downto 0) := (others => '0');

  signal old_rc_r    : signed(PROD_WIDTH-1 downto 0) := (others => '0');
  signal old_rs_r    : signed(PROD_WIDTH-1 downto 0) := (others => '0');

  signal next_sc_r   : signed(ACC_WIDTH-1 downto 0) := (others => '0');
  signal next_ss_r   : signed(ACC_WIDTH-1 downto 0) := (others => '0');

  signal cnt_i_r     : integer range 0 to N_POINTS := 0;
  signal full_i_r    : std_logic := '0';
  signal send_phasor_r : std_logic := '0';

  -- (opcional) força LUTRAM no Vivado
  attribute ram_style : string;
  attribute ram_style of rem_cos : signal is "distributed";
  attribute ram_style of rem_sin : signal is "distributed";

begin

  assert (ITER <= 16) report "ITER must be <= 16 for this implementation." severity failure;

  -- Output mapping
  o_valid_phaseA <= ovalid_r(0);
  o_Real_phaseA  <= oRe_r(0);
  o_Imag_phaseA  <= oIm_r(0);
  o_RMS_phaseA   <= oRMS_r(0);
  o_phase_phaseA <= oANG_r(0);

  o_valid_phaseB <= ovalid_r(1);
  o_Real_phaseB  <= oRe_r(1);
  o_Imag_phaseB  <= oIm_r(1);
  o_RMS_phaseB   <= oRMS_r(1);
  o_phase_phaseB <= oANG_r(1);

  o_valid_phaseC <= ovalid_r(2);
  o_Real_phaseC  <= oRe_r(2);
  o_Imag_phaseC  <= oIm_r(2);
  o_RMS_phaseC   <= oRMS_r(2);
  o_phase_phaseC <= oANG_r(2);

  -- ===========================================================================
  -- DFT ENGINE (FSM): seleciona A/B/C e calcula fasor (Re/Im) quando janela cheia
  -- Alimenta in_valid/in_tag/in_re/in_im (1 por amostra válida, quando pronto)
  -- ===========================================================================
  p_dft_fsm : process(i_clk)
  begin
    if rising_edge(i_clk) then

      if i_rst = '1' then
        -- IMPORTANTE: não resetar rem_cos/rem_sin para permitir inferência de LUTRAM.
        -- A correção funcional é feita tratando old_rc/old_rs como 0 enquanto full='0'.
        sum_cos <= (others => (others => '0'));
        sum_sin <= (others => (others => '0'));
        idx     <= (others => 0);
        cnt     <= (others => 0);
        full    <= (others => '0');

        in_valid <= '0';
        in_tag   <= (others => '0');
        in_re    <= (others => '0');
        in_im    <= (others => '0');

        dft_state <= DFT_IDLE;

        sel_valid_r <= '0';
        sel_tag_r   <= (others => '0');
        sel_x_r     <= (others => '0');

        ph_r <= 0;
        k_r  <= 0;
        ksin_r <= 0;

        cos_k_r <= (others => '0');
        sin_k_r <= (others => '0');

        pcos_r <= (others => '0');
        psin_r <= (others => '0');

        old_rc_r <= (others => '0');
        old_rs_r <= (others => '0');

        next_sc_r <= (others => '0');
        next_ss_r <= (others => '0');

        cnt_i_r <= 0;
        full_i_r <= '0';
        send_phasor_r <= '0';

      else
        -- default: in_valid é pulso (1 ciclo)
        in_valid <= '0';

        case dft_state is

          -- ==========================================================
          -- IDLE: espera uma amostra válida (prioridade A > B > C)
          -- ==========================================================
          when DFT_IDLE =>
            sel_valid_r <= '0';
            sel_tag_r   <= (others => '0');
            sel_x_r     <= (others => '0');

            if i_valid_phaseA = '1' then
              sel_valid_r <= '1';
              sel_tag_r   <= to_unsigned(0,2);
              sel_x_r     <= i_signal_phaseA_12;
              dft_state   <= DFT_LATCH;

            elsif i_valid_phaseB = '1' then
              sel_valid_r <= '1';
              sel_tag_r   <= to_unsigned(1,2);
              sel_x_r     <= i_signal_phasB_12;
              dft_state   <= DFT_LATCH;

            elsif i_valid_phaseC = '1' then
              sel_valid_r <= '1';
              sel_tag_r   <= to_unsigned(2,2);
              sel_x_r     <= i_signal_phaseC_12;
              dft_state   <= DFT_LATCH;

            else
              dft_state   <= DFT_IDLE;
            end if;

          -- ==========================================================
          -- LATCH: captura fase, k, flags da janela (cnt/full) e LUTs
          -- ==========================================================
          when DFT_LATCH =>
            -- fase selecionada
            ph_r <= to_integer(sel_tag_r);

            -- k atual da fase
            k_r <= idx(to_integer(sel_tag_r));

            -- captura estado de enchimento da janela
            cnt_i_r  <= cnt(to_integer(sel_tag_r));
            full_i_r <= full(to_integer(sel_tag_r));

            -- calcula ksin = k - 16 (mod 64)
            if idx(to_integer(sel_tag_r)) < (N_POINTS/4) then
              ksin_r <= idx(to_integer(sel_tag_r)) + (N_POINTS - (N_POINTS/4));
            else
              ksin_r <= idx(to_integer(sel_tag_r)) - (N_POINTS/4);
            end if;

            -- busca coeficientes (ROM combinacional)
            cos_k_r <= COS_TAB(idx(to_integer(sel_tag_r)));
            sin_k_r <= COS_TAB(ksin_r);

            dft_state <= DFT_COEFF;
		
		  -- ==========================================================
          -- LATCH: captura cosseno
          -- ==========================================================
		 when DFT_COEFF =>
			cos_k_r <= COS_TAB(k_r);
			sin_k_r <= COS_TAB(ksin_r);
			dft_state <= DFT_MUL;

          -- ==========================================================
          -- MUL: registra produtos pcos/psin
          -- (aqui você pode forçar DSP se quiser, via atributos em sinais)
          -- ==========================================================
          when DFT_MUL =>
            pcos_r <= sel_x_r * cos_k_r;
            psin_r <= sel_x_r * sin_k_r;
            dft_state <= DFT_READ_OLD;

          -- ==========================================================
          -- READ_OLD: lê termo antigo da RAM (ou zera se janela não cheia)
          -- ==========================================================
          when DFT_READ_OLD =>
            if full_i_r = '1' then
              old_rc_r <= rem_cos(ph_r)(k_r);
              old_rs_r <= rem_sin(ph_r)(k_r);
            else
              old_rc_r <= (others => '0');
              old_rs_r <= (others => '0');
            end if;
            dft_state <= DFT_ACCUM;

          -- ==========================================================
          -- ACCUM: atualiza somas incrementais (next_sc/next_ss)
          -- sum <- sum + new_term + old_term (old_term já é negativo na RAM)
          -- ==========================================================
          when DFT_ACCUM =>
            next_sc_r <= sum_cos(ph_r) + resize(pcos_r, ACC_WIDTH) + resize(old_rc_r, ACC_WIDTH);
            next_ss_r <= sum_sin(ph_r) + resize(psin_r, ACC_WIDTH) + resize(old_rs_r, ACC_WIDTH);
            dft_state <= DFT_WRITE_RAM;

          -- ==========================================================
          -- WRITE_RAM: escreve o termo de remoção (NEGATIVO) na RAM
          -- rem(k) <= -new_term
          -- ==========================================================
          when DFT_WRITE_RAM =>
            sum_cos(ph_r) <= next_sc_r;
            sum_sin(ph_r) <= next_ss_r;

            rem_cos(ph_r)(k_r) <= -pcos_r;
            rem_sin(ph_r)(k_r) <= -psin_r;

            dft_state <= DFT_UPDATE;

          -- ==========================================================
          -- UPDATE: atualiza idx/cnt/full e decide se envia fasor
          -- ==========================================================
          when DFT_UPDATE =>
            -- idx circular
            if k_r = N_POINTS-1 then
              idx(ph_r) <= 0;
            else
              idx(ph_r) <= k_r + 1;
            end if;

            -- cnt/full (enche uma vez e permanece full)
            if cnt_i_r < N_POINTS then
              cnt(ph_r) <= cnt_i_r + 1;
              if cnt_i_r = N_POINTS-1 then
                full(ph_r) <= '1';
              end if;
            end if;

            -- decide envio: quando já estava cheio, ou no instante que completa (cnt_i=63)
            if (full_i_r = '1') or (cnt_i_r = N_POINTS-1) then
              send_phasor_r <= '1';
            else
              send_phasor_r <= '0';
            end if;

            dft_state <= DFT_SEND;

          -- ==========================================================
          -- SEND: gera pulso para o CORDIC (in_valid) e entrega Re/Im
          -- Im = -sum_sin (mesma convenção do seu código original)
          -- ==========================================================
          when DFT_SEND =>
            if send_phasor_r = '1' then
              in_valid <= '1';
              in_tag   <= sel_tag_r;
              in_re    <= next_sc_r;
              in_im    <= -next_ss_r;
            end if;
            dft_state <= DFT_IDLE;

          when others =>
            dft_state <= DFT_IDLE;

        end case;
      end if;
    end if;
  end process;

  -- ===========================================================================
  -- CORDIC STAGE0 (quadrant handling) + load pipeline stage 0
  -- ===========================================================================
  p_stage0 : process(i_clk)
    variable x0, y0 : signed(W-1 downto 0);
    variable z0     : signed(ANG_WIDTH-1 downto 0);
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        xpipe(0) <= (others => '0');
        ypipe(0) <= (others => '0');
        zpipe(0) <= (others => '0');
        vpipe(0) <= '0';
        tpipe(0) <= (others => '0');

        rpipe(0) <= (others => '0');
        ipipe(0) <= (others => '0');
      else
        vpipe(0) <= in_valid;
        tpipe(0) <= in_tag;

        rpipe(0) <= in_re;
        ipipe(0) <= in_im;

        if in_valid = '1' then
          x0 := resize(in_re, W);
          y0 := resize(in_im, W);
          z0 := (others => '0');

          if x0 < 0 then
            x0 := -x0;
            y0 := -y0;
            if y0 >= 0 then
              z0 := to_signed( PI_Q13, ANG_WIDTH);
            else
              z0 := to_signed(-PI_Q13, ANG_WIDTH);
            end if;
          end if;

          xpipe(0) <= x0;
          ypipe(0) <= y0;
          zpipe(0) <= z0;
        end if;
      end if;
    end if;
  end process;

  -- ===========================================================================
  -- CORDIC PIPELINE (vectoring), single stream
  -- ===========================================================================
  gen_cordic : for i in 0 to ITER-1 generate
    p_cordic : process(i_clk)
      variable x_i, y_i   : signed(W-1 downto 0);
      variable z_i        : signed(ANG_WIDTH-1 downto 0);
      variable x_sh, y_sh : signed(W-1 downto 0);
    begin
      if rising_edge(i_clk) then
        if i_rst = '1' then
          xpipe(i+1) <= (others => '0');
          ypipe(i+1) <= (others => '0');
          zpipe(i+1) <= (others => '0');
          vpipe(i+1) <= '0';
          tpipe(i+1) <= (others => '0');

          rpipe(i+1) <= (others => '0');
          ipipe(i+1) <= (others => '0');
        else
          vpipe(i+1) <= vpipe(i);
          tpipe(i+1) <= tpipe(i);

          rpipe(i+1) <= rpipe(i);
          ipipe(i+1) <= ipipe(i);

          if vpipe(i) = '1' then
            x_i := xpipe(i);
            y_i := ypipe(i);
            z_i := zpipe(i);

            x_sh := shift_right(x_i, i);
            y_sh := shift_right(y_i, i);

            if y_i < 0 then
              xpipe(i+1) <= x_i - y_sh;
              ypipe(i+1) <= y_i + x_sh;
              zpipe(i+1) <= z_i - ATAN_TAB16(i);
            else
              xpipe(i+1) <= x_i + y_sh;
              ypipe(i+1) <= y_i - x_sh;
              zpipe(i+1) <= z_i + ATAN_TAB16(i);
            end if;
          end if;
        end if;
      end if;
    end process;
  end generate;

  -- ===========================================================================
  -- POST: P1/P2/P3 + route per phase + valid pulse per phase
  -- ===========================================================================
  p_post : process(i_clk)
    variable abs_v : unsigned(OUT_WIDTH-1 downto 0);
    variable ang_v : signed(ANG_WIDTH-1 downto 0);
    variable ph    : integer range 0 to 2;
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        oRe_r    <= (others => (others => '0'));
        oIm_r    <= (others => (others => '0'));
        oRMS_r   <= (others => (others => '0'));
        oANG_r   <= (others => (others => '0'));
        ovalid_r <= (others => '0');

        x1 <= (others => '0'); z1 <= (others => '0');
        r1 <= (others => '0'); i1 <= (others => '0');
        v1 <= '0'; t1 <= (others => '0');

        abs2 <= (others => '0'); ang2 <= (others => '0');
        r2 <= (others => '0'); i2 <= (others => '0');
        v2 <= '0'; t2 <= (others => '0');

      else
        -- clear output pulses (1-cycle)
        ovalid_r(0) <= '0';
        ovalid_r(1) <= '0';
        ovalid_r(2) <= '0';

        -- P1
        v1 <= vpipe(ITER);
        t1 <= tpipe(ITER);
        if vpipe(ITER) = '1' then
          x1 <= xpipe(ITER);
          z1 <= zpipe(ITER);
          r1 <= rpipe(ITER);
          i1 <= ipipe(ITER);
        end if;

        -- P2
        v2 <= v1;
        t2 <= t1;
        if v1 = '1' then
          abs_v := cordic_mag_q15(x1);
          ang_v := angle_cos_ref(z1);

          abs2 <= abs_v;
          ang2 <= ang_v;

          r2 <= r1;
          i2 <= i1;
        end if;

        -- P3 (final)
        if v2 = '1' then
          ph := to_integer(t2);

          oRe_r(ph)  <= r2;
          oIm_r(ph)  <= i2;
          oANG_r(ph) <= ang2;
          oRMS_r(ph) <= rms_from_abs(abs2);

          ovalid_r(ph) <= '1';
        end if;
      end if;
    end if;
  end process;

end architecture;