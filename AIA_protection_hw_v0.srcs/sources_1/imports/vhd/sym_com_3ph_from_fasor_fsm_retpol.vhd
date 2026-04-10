
-- ============================================================================
--  Block       : symcomp_3ph_from_phasors_fsm_retpol
--  Author      : Prof. Dr. Andre dos Anjos
--  Description :
--    Cálculo de componentes simétricas (sequências 0, 1 e 2) a partir dos
--    fasores trifásicos (Re/Im) provenientes do bloco
--    phasor_64pts_3ph_unified_fsm.
--
--    Entradas:
--      - i_valid_phaseA/B/C: pulso 1 ciclo quando Re/Im da fase está válido
--      - i_Re_phaseA/B/C, i_Im_phaseA/B/C: fasores Re/Im (mesma escala do bloco)
--
--    Saídas:
--      - o_valid_seq: pulso 1 ciclo quando seq0/seq1/seq2 estão atualizadas
--      - o_seq{0,1,2}_{re,im}: componentes simétricas em ponto fixo
--
--    Fórmulas:
--      V0 = (Va + Vb + Vc)/3
--      V1 = (Va + a*Vb + a^2*Vc)/3
--      V2 = (Va + a^2*Vb + a*Vc)/3
--
--      a  = -1/2 + j*(sqrt(3)/2) --> +120 graus
--      a^2= -1/2 - j*(sqrt(3)/2) --> -120 graus ou +240 graus
--
--    Observações importantes (DSP inference):
--      1) DSP48 (Zynq-7020 / 7-series) é, essencialmente, 25x18.
--         Para multiplicações maiores, o Vivado pode usar cascata de DSPs.
--      2) Para favorecer DSPs, NÃO "infle" o operando antes de multiplicar.
--         Ex.:  resize(vb_re, 52) * K(16) -> 52x16 (tende a LUT)
--         Aqui fazemos vb_re(36) * K(16)  -> 36x16 (cascata de DSPs)
--      3) Opteir por evitar genérica mul_resize() nas multiplicações críticas.
--         Usamos multiplicações explícitas com larguras bem definidas.
--      4) Incluímos atributos use_dsp/mult_style para reforçar a inferência de DPS,
--         pois estava inferindo com lógica e estava ficando com mais de 6000 Slice LUTs.
--    Precisão:
--      - Mesma do cálculo de fasores, lembrar do G = 2.^19 para intepretação mais clara dos resultados
--
--    Extensão (neste módulo):
--      - Cálculo adicional, para cada sequência (0/1/2):
--          * abs  (módulo)  via CORDIC (vetorização) compartilhado
--          * phase (ângulo) via CORDIC (vetorização) compartilhado
--          * RMS ~ abs/sqrt(2)
--
--      - Mantemos o FSM original (captura + cálculo Re/Im das sequências).
--        O estado OUT_PULSE agora:
--          * Apenas registra Re/Im das três sequências (seq*_re_r/seq*_im_r)
--          * Gera um pulso interno "seq_ri_pulse" indicando que Re/Im estão prontos
--        Uma segunda máquina de estados (CORDIC_CTRL_FSM), em paralelo:
--          * Recebe o pulso "seq_ri_pulse"
--          * Usa um único CORDIC compartilhado para:
--              seq0 -> seq1 -> seq2 (handshake interno)
--          * Registra abs/phase/RMS de cada sequência
--          * Por fim, gera o pulso o_valid_seq (tudo pronto e alinhado)
-- Latencia de 74 pulsos de clock após a entrada do último dado válido(camada C) para calculos
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity symcomp_3ph_from_phasors_fsm_retpol is
  generic (
    ACC_WIDTH : integer := 36;
    OUT_WIDTH : integer := 32;
    ANG_WIDTH : integer := 16;
    ITER      : integer := 16
  );
  port (
    i_clk : in  std_logic;
    i_rst : in  std_logic;

    -- Entradas do bloco de fasor (Re/Im por fase)
    i_valid_phaseA : in std_logic;
    i_Re_phaseA    : in signed(ACC_WIDTH-1 downto 0);
    i_Im_phaseA    : in signed(ACC_WIDTH-1 downto 0);

    i_valid_phaseB : in std_logic;
    i_Re_phaseB    : in signed(ACC_WIDTH-1 downto 0);
    i_Im_phaseB    : in signed(ACC_WIDTH-1 downto 0);

    i_valid_phaseC : in std_logic;
    i_Re_phaseC    : in signed(ACC_WIDTH-1 downto 0);
    i_Im_phaseC    : in signed(ACC_WIDTH-1 downto 0);

    -- Saídas (sequências 0,1,2)
    o_valid_seq   : out std_logic;
    o_seq0_re 	  : out signed(ACC_WIDTH-1 downto 0);
    o_seq0_im 	  : out signed(ACC_WIDTH-1 downto 0);
    o_seq0_abs    : out unsigned(OUT_WIDTH-1 downto 0);
    o_seq0_phase  : out signed(ANG_WIDTH-1 downto 0);
    o_seq0_rms    : out unsigned(OUT_WIDTH-1 downto 0);
    o_seq1_abs    : out unsigned(OUT_WIDTH-1 downto 0);
    o_seq1_phase  : out signed(ANG_WIDTH-1 downto 0);
    o_seq1_rms    : out unsigned(OUT_WIDTH-1 downto 0);
    o_seq1_re 	  : out signed(ACC_WIDTH-1 downto 0);
    o_seq1_im     : out signed(ACC_WIDTH-1 downto 0);
    o_seq2_re     : out signed(ACC_WIDTH-1 downto 0);
    o_seq2_im     : out signed(ACC_WIDTH-1 downto 0);
    o_seq2_abs    : out unsigned(OUT_WIDTH-1 downto 0);
    o_seq2_phase  : out signed(ANG_WIDTH-1 downto 0);
    o_seq2_rms    : out unsigned(OUT_WIDTH-1 downto 0)
  );
end entity;

architecture rtl of symcomp_3ph_from_phasors_fsm_retpol is

  -- ==========================================================================
  -- Constantes de ponto fixo
  -- ==========================================================================

  -- k = sqrt(3)/2 ~= 0.8660254 em Q1.15
  -- (multiplicação por k seguida de >>15)
  constant K_FRAC : integer := 15;
  constant K_Q15  : signed(15 downto 0) := to_signed(28378, 16);

  -- inv3 = 1/3 em Q0.16
  -- (multiplicação por inv3 seguida de >>16)
  constant INV3_FRAC : integer := 16;
  constant INV3_Q16  : signed(15 downto 0) := to_signed(21845, 16);

  -- Largura exata do produto: ACC_WIDTH + 16
  -- 36 + 16 = 52 bits
  constant MUL_W : integer := ACC_WIDTH + 16;

  -- ==========================================================================
  -- Constantes CORDIC (mesma filosofia do bloco de fasores)
  -- ==========================================================================
  constant ANG_FRAC : integer := 13;
  constant PI_Q13   : integer := 25736;
  constant PIO2_Q13 : integer := PI_Q13/2;

  constant KINV_CORDIC_Q15 : unsigned(15 downto 0) := to_unsigned(19898, 16);
  constant INV_SQRT2_Q15   : unsigned(15 downto 0) := to_unsigned(23170, 16);

  constant W : integer := ACC_WIDTH + 2;

  -- ==========================================================================
  -- Atributos para reforçar uso de DSP
  -- ==========================================================================
  attribute use_dsp    : string;
  attribute mult_style : string;

  -- ==========================================================================
  -- FSM de captura + cálculo
  -- ==========================================================================
  type state_t is (
    IDLE_WAIT_A, WAIT_B, WAIT_C,

    -- Pipeline aritmético em etapas:
    CALC1,        -- calcula produtos k*V (p_k*) e termos -V/2
    CALC2_KSCALE, -- reescala: kb/kc = (p_k*) >> 15
    CALC3_ALPHA,  -- forma alpha/alpha2 de Vb e Vc
    CALC4_NUM,    -- forma numeradores N0,N1,N2
    CALC5_DIV3,   -- aplica /3 via multiplicação por inv3
    OUT_PULSE     -- registra Re/Im das sequências e gera pulso interno seq_ri_pulse
  );

  signal st : state_t := IDLE_WAIT_A;

  -- ==========================================================================
  -- Registros de entrada (Va,Vb,Vc)
  -- ==========================================================================
  signal va_re, va_im : signed(ACC_WIDTH-1 downto 0) := (others => '0');
  signal vb_re, vb_im : signed(ACC_WIDTH-1 downto 0) := (others => '0');
  signal vc_re, vc_im : signed(ACC_WIDTH-1 downto 0) := (others => '0');

  -- ==========================================================================
  -- Produtos k*V (produto exato 36x16 -> 52 bits)
  -- IMPORTANTE: multiplicamos diretamente ACC_WIDTH x 16 (SEM resize para 52 antes)
  -- Isso facilita o Vivado a inferir DSPs em cascata (precisão total).
  -- ==========================================================================
  signal p_kb_re, p_kb_im : signed(MUL_W-1 downto 0) := (others => '0');
  signal p_kc_re, p_kc_im : signed(MUL_W-1 downto 0) := (others => '0');

  attribute use_dsp    of p_kb_re : signal is "yes";
  attribute use_dsp    of p_kb_im : signal is "yes";
  attribute use_dsp    of p_kc_re : signal is "yes";
  attribute use_dsp    of p_kc_im : signal is "yes";
  attribute mult_style of p_kb_re : signal is "dsp";
  attribute mult_style of p_kb_im : signal is "dsp";
  attribute mult_style of p_kc_re : signal is "dsp";
  attribute mult_style of p_kc_im : signal is "dsp";

  -- ==========================================================================
  -- k*V já reescalonado (>>15)
  -- ==========================================================================
  signal kb_re, kb_im : signed(ACC_WIDTH-1 downto 0) := (others => '0');
  signal kc_re, kc_im : signed(ACC_WIDTH-1 downto 0) := (others => '0');

  -- ==========================================================================
  -- Termos -V/2
  -- ==========================================================================
  signal a_vb_re, a_vb_im : signed(ACC_WIDTH-1 downto 0) := (others => '0');
  signal a_vc_re, a_vc_im : signed(ACC_WIDTH-1 downto 0) := (others => '0');

  -- ==========================================================================
  -- alpha*V e alpha^2*V
  -- ==========================================================================
  signal alpha_b_re,  alpha_b_im  : signed(ACC_WIDTH-1 downto 0) := (others => '0');
  signal alpha2_b_re, alpha2_b_im : signed(ACC_WIDTH-1 downto 0) := (others => '0');
  signal alpha_c_re,  alpha_c_im  : signed(ACC_WIDTH-1 downto 0) := (others => '0');
  signal alpha2_c_re, alpha2_c_im : signed(ACC_WIDTH-1 downto 0) := (others => '0');

  -- ==========================================================================
  -- Numeradores N0/N1/N2 (antes do /3)
  -- ==========================================================================
  signal n0_re, n0_im : signed(ACC_WIDTH-1 downto 0) := (others => '0');
  signal n1_re, n1_im : signed(ACC_WIDTH-1 downto 0) := (others => '0');
  signal n2_re, n2_im : signed(ACC_WIDTH-1 downto 0) := (others => '0');

  -- ==========================================================================
  -- Produtos para divisão por 3: n*inv3 (36x16 -> 52)
  -- ==========================================================================
  signal p0_re, p0_im : signed(MUL_W-1 downto 0) := (others => '0');
  signal p1_re, p1_im : signed(MUL_W-1 downto 0) := (others => '0');
  signal p2_re, p2_im : signed(MUL_W-1 downto 0) := (others => '0');

  attribute use_dsp    of p0_re : signal is "yes";
  attribute use_dsp    of p0_im : signal is "yes";
  attribute use_dsp    of p1_re : signal is "yes";
  attribute use_dsp    of p1_im : signal is "yes";
  attribute use_dsp    of p2_re : signal is "yes";
  attribute use_dsp    of p2_im : signal is "yes";
  attribute mult_style of p0_re : signal is "dsp";
  attribute mult_style of p0_im : signal is "dsp";
  attribute mult_style of p1_re : signal is "dsp";
  attribute mult_style of p1_im : signal is "dsp";
  attribute mult_style of p2_re : signal is "dsp";
  attribute mult_style of p2_im : signal is "dsp";

  -- ==========================================================================
  -- Saídas registradas (Re/Im)
  -- ==========================================================================
  signal seq0_re_r, seq0_im_r : signed(ACC_WIDTH-1 downto 0) := (others => '0');
  signal seq1_re_r, seq1_im_r : signed(ACC_WIDTH-1 downto 0) := (others => '0');
  signal seq2_re_r, seq2_im_r : signed(ACC_WIDTH-1 downto 0) := (others => '0');

  -- ==========================================================================
  -- Saídas registradas (abs/phase/RMS)
  -- ==========================================================================
  signal seq0_abs_r : unsigned(OUT_WIDTH-1 downto 0) := (others => '0');
  signal seq1_abs_r : unsigned(OUT_WIDTH-1 downto 0) := (others => '0');
  signal seq2_abs_r : unsigned(OUT_WIDTH-1 downto 0) := (others => '0');

  signal seq0_ph_r  : signed(ANG_WIDTH-1 downto 0) := (others => '0');
  signal seq1_ph_r  : signed(ANG_WIDTH-1 downto 0) := (others => '0');
  signal seq2_ph_r  : signed(ANG_WIDTH-1 downto 0) := (others => '0');

  signal seq0_rms_r : unsigned(OUT_WIDTH-1 downto 0) := (others => '0');
  signal seq1_rms_r : unsigned(OUT_WIDTH-1 downto 0) := (others => '0');
  signal seq2_rms_r : unsigned(OUT_WIDTH-1 downto 0) := (others => '0');

  -- ==========================================================================
  -- Pulso interno: Re/Im das 3 sequências prontos para o CORDIC_CTRL_FSM
  -- ==========================================================================
  signal seq_ri_pulse : std_logic := '0';

  -- ==========================================================================
  -- Valid final: só sobe quando Re/Im + abs/phase/RMS de seq0/1/2 estiverem prontos
  -- ==========================================================================
  signal valid_r : std_logic := '0';

  -- ==========================================================================
  -- CORDIC (single stream) + POST-FSM: mesmo estilo do bloco de fasores
  -- ==========================================================================
  type svec_t is array (0 to ITER) of signed(W-1 downto 0);
  type avec_t is array (0 to ITER) of signed(ANG_WIDTH-1 downto 0);
  type vvec_t is array (0 to ITER) of std_logic;
  type tvec_t is array (0 to ITER) of unsigned(1 downto 0);
  type rvec_t is array (0 to ITER) of signed(ACC_WIDTH-1 downto 0);

  signal xpipe, ypipe : svec_t;
  signal zpipe        : avec_t;
  signal vpipe        : vvec_t;
  signal tpipe        : tvec_t;

  signal rpipe, ipipe : rvec_t;

  -- Entrada do CORDIC (controlada pela CORDIC_CTRL_FSM)
  signal in_valid : std_logic := '0';
  signal in_tag   : unsigned(1 downto 0) := (others => '0'); -- "00"=seq0, "01"=seq1, "10"=seq2
  signal in_re    : signed(ACC_WIDTH-1 downto 0) := (others => '0');
  signal in_im    : signed(ACC_WIDTH-1 downto 0) := (others => '0');

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

  function rms_from_abs(abs_in : unsigned(OUT_WIDTH-1 downto 0)) return unsigned is
    variable prod : unsigned(OUT_WIDTH+16-1 downto 0);
    variable rmsu : unsigned(OUT_WIDTH-1 downto 0);
  begin
    prod := abs_in * INV_SQRT2_Q15;
    rmsu := prod(15+OUT_WIDTH-1 downto 15);
    return rmsu;
  end function;

  -- ==========================================================================
  -- POST-FSM (substitui P1/P2/P3) para fechar timing
  -- ==========================================================================
  type post_state_t is (S0_IDLE, S1_ABS, S2_MUL, S3_OUT);
  signal post_state : post_state_t := S0_IDLE;

  signal tag_s  : unsigned(1 downto 0) := (others => '0');
  signal x_s    : signed(W-1 downto 0) := (others => '0');
  signal z_s    : signed(ANG_WIDTH-1 downto 0) := (others => '0');
  signal r_s    : signed(ACC_WIDTH-1 downto 0) := (others => '0');
  signal i_s    : signed(ACC_WIDTH-1 downto 0) := (others => '0');

  signal xabs_s : unsigned(W-1 downto 0) := (others => '0');
  signal prod_s : unsigned(W+16-1 downto 0) := (others => '0');

  -- Pulso interno "cordic_done" com resultados estabilizados (1 ciclo)
  signal cordic_done  : std_logic := '0';
  signal cordic_tag   : unsigned(1 downto 0) := (others => '0');
  signal cordic_abs_u : unsigned(OUT_WIDTH-1 downto 0) := (others => '0');
  signal cordic_ang_s : signed(ANG_WIDTH-1 downto 0) := (others => '0');

  -- ==========================================================================
  -- FSM de controle do CORDIC (compartilhado) para seq0->seq1->seq2
  -- ==========================================================================
  type cordic_ctrl_state_t is (
    WAIT_SEQ_REALIMAG,
    START_CORDIC_SEQ0, WAIT_CORDIC_SEQ0, RMS_SEQ0,
    START_CORDIC_SEQ1, WAIT_CORDIC_SEQ1, RMS_SEQ1,
    START_CORDIC_SEQ2, WAIT_CORDIC_SEQ2, RMS_SEQ2,
    SEND_TO_OUTPUTPORTS
  );
  signal cst : cordic_ctrl_state_t := WAIT_SEQ_REALIMAG;

begin

  assert (ITER <= 16) report "ITER must be <= 16 for this implementation." severity failure;

  -- ==========================================================================
  -- Mapeamento de saídas
  -- ==========================================================================
  o_seq0_re   <= seq0_re_r;
  o_seq0_im   <= seq0_im_r;
  o_seq1_re   <= seq1_re_r;
  o_seq1_im   <= seq1_im_r;
  o_seq2_re   <= seq2_re_r;
  o_seq2_im   <= seq2_im_r;

  o_seq0_abs   <= seq0_abs_r;
  o_seq0_phase <= seq0_ph_r;
  o_seq0_rms   <= seq0_rms_r;

  o_seq1_abs   <= seq1_abs_r;
  o_seq1_phase <= seq1_ph_r;
  o_seq1_rms   <= seq1_rms_r;

  o_seq2_abs   <= seq2_abs_r;
  o_seq2_phase <= seq2_ph_r;
  o_seq2_rms   <= seq2_rms_r;

  o_valid_seq <= valid_r;

  -- ==========================================================================
  -- Processo principal (FSM) - MANTIDO (mesma lógica)
  -- Apenas alteração: OUT_PULSE agora gera seq_ri_pulse ao invés de valid_r.
  -- ==========================================================================
  p_main : process(i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then

        -- Reset FSM e registradores
        st <= IDLE_WAIT_A;

        va_re <= (others => '0'); va_im <= (others => '0');
        vb_re <= (others => '0'); vb_im <= (others => '0');
        vc_re <= (others => '0'); vc_im <= (others => '0');

        p_kb_re <= (others => '0'); p_kb_im <= (others => '0');
        p_kc_re <= (others => '0'); p_kc_im <= (others => '0');

        kb_re <= (others => '0'); kb_im <= (others => '0');
        kc_re <= (others => '0'); kc_im <= (others => '0');

        a_vb_re <= (others => '0'); a_vb_im <= (others => '0');
        a_vc_re <= (others => '0'); a_vc_im <= (others => '0');

        alpha_b_re  <= (others => '0'); alpha_b_im  <= (others => '0');
        alpha2_b_re <= (others => '0'); alpha2_b_im <= (others => '0');
        alpha_c_re  <= (others => '0'); alpha_c_im  <= (others => '0');
        alpha2_c_re <= (others => '0'); alpha2_c_im <= (others => '0');

        n0_re <= (others => '0'); n0_im <= (others => '0');
        n1_re <= (others => '0'); n1_im <= (others => '0');
        n2_re <= (others => '0'); n2_im <= (others => '0');

        p0_re <= (others => '0'); p0_im <= (others => '0');
        p1_re <= (others => '0'); p1_im <= (others => '0');
        p2_re <= (others => '0'); p2_im <= (others => '0');

        seq0_re_r <= (others => '0'); seq0_im_r <= (others => '0');
        seq1_re_r <= (others => '0'); seq1_im_r <= (others => '0');
        seq2_re_r <= (others => '0'); seq2_im_r <= (others => '0');

        seq_ri_pulse <= '0';

      else
        -- Pulso interno (1 ciclo)
        seq_ri_pulse <= '0';

        case st is

          -- ==========================================================
          -- Captura Va (espera valid da fase A)
          -- ==========================================================
          when IDLE_WAIT_A =>
            if i_valid_phaseA = '1' then
              va_re <= i_Re_phaseA;
              va_im <= i_Im_phaseA;
              st    <= WAIT_B;
            end if;

          -- ==========================================================
          -- Captura Vb
          -- ==========================================================
          when WAIT_B =>
            if i_valid_phaseB = '1' then
              vb_re <= i_Re_phaseB;
              vb_im <= i_Im_phaseB;
              st    <= WAIT_C;
            end if;

          -- ==========================================================
          -- Captura Vc
          -- ==========================================================
          when WAIT_C =>
            if i_valid_phaseC = '1' then
              vc_re <= i_Re_phaseC;
              vc_im <= i_Im_phaseC;
              st    <= CALC1;
            end if;

          -- ==========================================================
          -- CALC1:
          -- 1) Calcula p_k* = V * k (Q1.15) em precisão total
          --    p_k* tem MUL_W bits (36+16=52)
          -- 2) Calcula a_v* = -V/2 (shift)
          --
          -- IMPORTANTE (DSP inference):
          --   Fazemos vb_re * K_Q15 (36x16) diretamente.
          --   Não fazemos resize(vb_re, 52) antes da multiplicação.
          -- ==========================================================
          when CALC1 =>
            p_kb_re <= vb_re * K_Q15;
            p_kb_im <= vb_im * K_Q15;
            p_kc_re <= vc_re * K_Q15;
            p_kc_im <= vc_im * K_Q15;

            a_vb_re <= -shift_right(vb_re, 1);
            a_vb_im <= -shift_right(vb_im, 1);
            a_vc_re <= -shift_right(vc_re, 1);
            a_vc_im <= -shift_right(vc_im, 1);

            st <= CALC2_KSCALE;

          -- ==========================================================
          -- CALC2_KSCALE:
          -- kb = (V*k)>>15  (retorna para ACC_WIDTH)
          -- ==========================================================
          when CALC2_KSCALE =>
            kb_re <= resize(shift_right(p_kb_re, K_FRAC), ACC_WIDTH);
            kb_im <= resize(shift_right(p_kb_im, K_FRAC), ACC_WIDTH);
            kc_re <= resize(shift_right(p_kc_re, K_FRAC), ACC_WIDTH);
            kc_im <= resize(shift_right(p_kc_im, K_FRAC), ACC_WIDTH);

            st <= CALC3_ALPHA;

          -- ==========================================================
          -- CALC3_ALPHA:
          -- Forma alpha*V e alpha^2*V usando:
          --   a = -1/2 + j*k
          --   a^2 = -1/2 - j*k
          --
          -- Para um fasor V = x + j*y:
          --   a*V   = (-x/2 - k*y) + j( k*x - y/2 )
          --   a^2*V = (-x/2 + k*y) + j(-k*x - y/2 )
          --
          -- Aqui usamos:
          --   -x/2  -> a_v*_re
          --   -y/2  -> a_v*_im
          --   k*x   -> kb_re / kc_re
          --   k*y   -> kb_im / kc_im
          -- ==========================================================
          when CALC3_ALPHA =>
            -- alpha*Vb
            alpha_b_re  <= a_vb_re - kb_im;
            alpha_b_im  <= kb_re + a_vb_im;

            -- alpha^2*Vb
            alpha2_b_re <= a_vb_re + kb_im;
            alpha2_b_im <= -kb_re + a_vb_im;

            -- alpha*Vc
            alpha_c_re  <= a_vc_re - kc_im;
            alpha_c_im  <= kc_re + a_vc_im;

            -- alpha^2*Vc
            alpha2_c_re <= a_vc_re + kc_im;
            alpha2_c_im <= -kc_re + a_vc_im;

            st <= CALC4_NUM;

          -- ==========================================================
          -- CALC4_NUM:
          -- Forma os numeradores (antes da divisão por 3)
          -- ==========================================================
          when CALC4_NUM =>
            -- N0 = Va + Vb + Vc
            n0_re <= va_re + vb_re + vc_re;
            n0_im <= va_im + vb_im + vc_im;

            -- N1 = Va + a*Vb + a^2*Vc
            n1_re <= va_re + alpha_b_re  + alpha2_c_re;
            n1_im <= va_im + alpha_b_im  + alpha2_c_im;

            -- N2 = Va + a^2*Vb + a*Vc
            n2_re <= va_re + alpha2_b_re + alpha_c_re;
            n2_im <= va_im + alpha2_b_im + alpha_c_im;

            st <= CALC5_DIV3;

          -- ==========================================================
          -- CALC5_DIV3:
          -- Implementa /3 via multiplicação por inv3 (Q0.16):
          --   Vseq = (N * inv3) >> 16
          --
          -- IMPORTANTE (DSP inference):
          --  Multiplicamos n*(36) x inv3(16) diretamente => 52 bits.
          -- ==========================================================
          when CALC5_DIV3 =>
            p0_re <= n0_re * INV3_Q16;
            p0_im <= n0_im * INV3_Q16;

            p1_re <= n1_re * INV3_Q16;
            p1_im <= n1_im * INV3_Q16;

            p2_re <= n2_re * INV3_Q16;
            p2_im <= n2_im * INV3_Q16;

            st <= OUT_PULSE;

          -- ==========================================================
          -- OUT_PULSE:
          -- Registra seq0/1/2 (Re/Im) e gera pulso interno seq_ri_pulse
          -- (o_valid_seq agora será gerado apenas ao final do CORDIC_CTRL_FSM)
          -- ==========================================================
          when OUT_PULSE =>
            seq0_re_r <= resize(shift_right(p0_re, INV3_FRAC), ACC_WIDTH);
            seq0_im_r <= resize(shift_right(p0_im, INV3_FRAC), ACC_WIDTH);

            seq1_re_r <= resize(shift_right(p1_re, INV3_FRAC), ACC_WIDTH);
            seq1_im_r <= resize(shift_right(p1_im, INV3_FRAC), ACC_WIDTH);

            seq2_re_r <= resize(shift_right(p2_re, INV3_FRAC), ACC_WIDTH);
            seq2_im_r <= resize(shift_right(p2_im, INV3_FRAC), ACC_WIDTH);

            seq_ri_pulse <= '1';
            st <= IDLE_WAIT_A;

          when others =>
            st <= IDLE_WAIT_A;

        end case;
      end if;
    end if;
  end process;

  -- ==========================================================================
  -- CORDIC_CTRL_FSM:
  --  - Espera seq_ri_pulse (Re/Im prontos)
  --  - Usa CORDIC compartilhado para seq0->seq1->seq2
  --  - Registra abs/phase/RMS
  --  - Emite valid_r no final (tudo pronto e alinhado)
  -- ==========================================================================
  p_cordic_ctrl : process(i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst='1' then
        cst <= WAIT_SEQ_REALIMAG;

        in_valid <= '0';
        in_tag   <= (others=>'0');
        in_re    <= (others=>'0');
        in_im    <= (others=>'0');

        seq0_abs_r <= (others=>'0');
        seq1_abs_r <= (others=>'0');
        seq2_abs_r <= (others=>'0');

        seq0_ph_r  <= (others=>'0');
        seq1_ph_r  <= (others=>'0');
        seq2_ph_r  <= (others=>'0');

        seq0_rms_r <= (others=>'0');
        seq1_rms_r <= (others=>'0');
        seq2_rms_r <= (others=>'0');

        valid_r <= '0';

      else
        -- defaults (pulsos)
        in_valid <= '0';
        valid_r  <= '0';

        case cst is

          -- ==========================================================
          -- Wait_Seq_RealImag:
          -- aguarda as 3 sequências (Re/Im) serem registradas pelo FSM principal
          -- ==========================================================
          when WAIT_SEQ_REALIMAG =>
            if seq_ri_pulse='1' then
              cst <= START_CORDIC_SEQ0;
            end if;

          -- ==========================================================
          -- Start_Cordic_Seq0:
          -- envia seq0 Re/Im para o CORDIC
          -- ==========================================================
          when START_CORDIC_SEQ0 =>
            in_valid <= '1';
            in_tag   <= "00";
            in_re    <= seq0_re_r;
            in_im    <= seq0_im_r;
            cst <= WAIT_CORDIC_SEQ0;

          -- ==========================================================
          -- Wait_Cordic_Seq0:
          -- espera o pulso cordic_done (post-fsm terminou)
          -- ==========================================================
          when WAIT_CORDIC_SEQ0 =>
            if cordic_done='1' and cordic_tag="00" then
              seq0_abs_r <= cordic_abs_u;
              seq0_ph_r  <= cordic_ang_s;
              cst <= RMS_SEQ0;
            end if;

          -- ==========================================================
          -- RMS_Seq0:
          -- calcula RMS em ciclo dedicado (fecha timing)
          -- ==========================================================
          when RMS_SEQ0 =>
            seq0_rms_r <= rms_from_abs(seq0_abs_r);
            cst <= START_CORDIC_SEQ1;

          -- ==========================================================
          -- Start_Cordic_Seq1
          -- ==========================================================
          when START_CORDIC_SEQ1 =>
            in_valid <= '1';
            in_tag   <= "01";
            in_re    <= seq1_re_r;
            in_im    <= seq1_im_r;
            cst <= WAIT_CORDIC_SEQ1;

          when WAIT_CORDIC_SEQ1 =>
            if cordic_done='1' and cordic_tag="01" then
              seq1_abs_r <= cordic_abs_u;
              seq1_ph_r  <= cordic_ang_s;
              cst <= RMS_SEQ1;
            end if;

          when RMS_SEQ1 =>
            seq1_rms_r <= rms_from_abs(seq1_abs_r);
            cst <= START_CORDIC_SEQ2;

          -- ==========================================================
          -- Start_Cordic_Seq2
          -- ==========================================================
          when START_CORDIC_SEQ2 =>
            in_valid <= '1';
            in_tag   <= "10";
            in_re    <= seq2_re_r;
            in_im    <= seq2_im_r;
            cst <= WAIT_CORDIC_SEQ2;

          when WAIT_CORDIC_SEQ2 =>
            if cordic_done='1' and cordic_tag="10" then
              seq2_abs_r <= cordic_abs_u;
              seq2_ph_r  <= cordic_ang_s;
              cst <= RMS_SEQ2;
            end if;

          when RMS_SEQ2 =>
            seq2_rms_r <= rms_from_abs(seq2_abs_r);
            cst <= SEND_TO_OUTPUTPORTS;

          -- ==========================================================
          -- Send_to_OuputPorts:
          -- agora tudo está pronto e alinhado -> pulso valid
          -- ==========================================================
          when SEND_TO_OUTPUTPORTS =>
            valid_r <= '1';
            cst <= WAIT_SEQ_REALIMAG;

          when others =>
            cst <= WAIT_SEQ_REALIMAG;

        end case;
      end if;
    end if;
  end process;

  -- ===========================================================================
  -- CORDIC STAGE0 (quadrant handling) + load pipeline stage 0
  -- (mesmo estilo do seu bloco de fasores)
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
  -- POST-FSM: sequencia 1 operação pesada por ciclo (fecha timing)
  -- Latência: ~3 ciclos após vpipe(ITER)
  -- Gera cordic_done + cordic_abs_u + cordic_ang_s
  -- ===========================================================================
  p_post_fsm : process(i_clk)
    variable abs_u : unsigned(OUT_WIDTH-1 downto 0);
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        post_state <= S0_IDLE;

        tag_s  <= (others => '0');
        x_s    <= (others => '0');
        z_s    <= (others => '0');
        r_s    <= (others => '0');
        i_s    <= (others => '0');
        xabs_s <= (others => '0');
        prod_s <= (others => '0');

        cordic_done  <= '0';
        cordic_tag   <= (others => '0');
        cordic_abs_u <= (others => '0');
        cordic_ang_s <= (others => '0');

      else
        -- pulso 1 ciclo
        cordic_done <= '0';

        case post_state is

          when S0_IDLE =>
            -- espera fim do CORDIC
            if vpipe(ITER) = '1' then
              tag_s <= tpipe(ITER);
              x_s   <= xpipe(ITER);
              z_s   <= zpipe(ITER);
              r_s   <= rpipe(ITER);
              i_s   <= ipipe(ITER);
              post_state <= S1_ABS;
            end if;

          when S1_ABS =>
            -- abs(x) (leve)
            if x_s < 0 then
              xabs_s <= unsigned(-x_s);
            else
              xabs_s <= unsigned(x_s);
            end if;
            post_state <= S2_MUL;

          when S2_MUL =>
            -- multiplicação pesada em ciclo dedicado
            prod_s <= xabs_s * KINV_CORDIC_Q15;
            post_state <= S3_OUT;

          when S3_OUT =>
            abs_u := resize(prod_s(15+W-1 downto 15), OUT_WIDTH);

            -- resultado final (1 ciclo)
            cordic_done  <= '1';
            cordic_tag   <= tag_s;
            cordic_abs_u <= abs_u;
            cordic_ang_s <= z_s;--angle_cos_ref(z_s); tirei essa compensacao dos 90graus

            post_state <= S0_IDLE;

          when others =>
            post_state <= S0_IDLE;

        end case;
      end if;
    end if;
  end process;

end architecture;
