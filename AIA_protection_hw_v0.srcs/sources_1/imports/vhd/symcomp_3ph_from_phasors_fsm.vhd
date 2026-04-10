-- ============================================================================
--  Block       : symcomp_3ph_from_phasors_fsm
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
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity symcomp_3ph_from_phasors_fsm is
  generic (
    ACC_WIDTH : integer := 36
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
    o_valid_seq : out std_logic;

    o_seq0_re : out signed(ACC_WIDTH-1 downto 0);
    o_seq0_im : out signed(ACC_WIDTH-1 downto 0);

    o_seq1_re : out signed(ACC_WIDTH-1 downto 0);
    o_seq1_im : out signed(ACC_WIDTH-1 downto 0);

    o_seq2_re : out signed(ACC_WIDTH-1 downto 0);
    o_seq2_im : out signed(ACC_WIDTH-1 downto 0)
  );
end entity;

architecture rtl of symcomp_3ph_from_phasors_fsm is

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
    OUT_PULSE     -- registra saídas e gera pulso o_valid_seq
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
  -- Saídas registradas
  -- ==========================================================================
  signal seq0_re_r, seq0_im_r : signed(ACC_WIDTH-1 downto 0) := (others => '0');
  signal seq1_re_r, seq1_im_r : signed(ACC_WIDTH-1 downto 0) := (others => '0');
  signal seq2_re_r, seq2_im_r : signed(ACC_WIDTH-1 downto 0) := (others => '0');
  signal valid_r              : std_logic := '0';

begin

  -- ==========================================================================
  -- Mapeamento de saídas
  -- ==========================================================================
  o_seq0_re   <= seq0_re_r;
  o_seq0_im   <= seq0_im_r;
  o_seq1_re   <= seq1_re_r;
  o_seq1_im   <= seq1_im_r;
  o_seq2_re   <= seq2_re_r;
  o_seq2_im   <= seq2_im_r;
  o_valid_seq <= valid_r;

  -- ==========================================================================
  -- Processo principal (FSM)
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

        valid_r <= '0';

      else
        -- Pulso de valid (1 ciclo)
        valid_r <= '0';

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
          -- Registra seq0/1/2 e gera pulso o_valid_seq
          -- ==========================================================
          when OUT_PULSE =>
            seq0_re_r <= resize(shift_right(p0_re, INV3_FRAC), ACC_WIDTH);
            seq0_im_r <= resize(shift_right(p0_im, INV3_FRAC), ACC_WIDTH);

            seq1_re_r <= resize(shift_right(p1_re, INV3_FRAC), ACC_WIDTH);
            seq1_im_r <= resize(shift_right(p1_im, INV3_FRAC), ACC_WIDTH);

            seq2_re_r <= resize(shift_right(p2_re, INV3_FRAC), ACC_WIDTH);
            seq2_im_r <= resize(shift_right(p2_im, INV3_FRAC), ACC_WIDTH);

            valid_r <= '1';
            st <= IDLE_WAIT_A;

          when others =>
            st <= IDLE_WAIT_A;

        end case;
      end if;
    end if;
  end process;

end architecture;
