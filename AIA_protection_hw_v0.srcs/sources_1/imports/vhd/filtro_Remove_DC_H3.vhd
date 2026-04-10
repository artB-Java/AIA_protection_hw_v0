-- ============================================================================
--  Block       : filtro_Remove_DC_H3
--  Author      : Prof. Dr. André A. dos Anjos
--  Description :
--    Implementação em VHDL de um filtro IIR em cascata (SOS) para pré-processamento
--    de sinais de tensão/corrente em relés digitais.
--
--    Objetivo do bloco:
--      - Rejeitar componente DC (0 Hz) presente no sinal amostrado (ADC).
--      - Atenuar fortemente a 3ª harmônica (180 Hz) e demais componentes fora da
--        banda de interesse.
--      - Preservar a fundamental de 60 Hz, entregando uma senoide limpa para os
--        estágios seguintes (cálculo de fasor/RMS/funções de proteção).
--
--    Arquitetura adotada:
--      - Filtro em 4 seções biquad (SOS) na forma DF2T (Direct Form II Transposed).
--      - Processamento por amostra com máquina de estados (micro-FSM).
--      - Reuso de 3 multiplicadores (DSP) ao longo de todo o cálculo:
--          * Primeiro calcula b0*x, b1*x, b2*x
--          * Depois calcula a1*y, a2*y
--      - Estados extras (MS_REG_B e MS_REG_A) foram introduzidos para registrar
--        os produtos do DSP e, assim, fechar timing no FPGA.
--
--    Formatos numéricos:
--      - Entrada i_sample: 12 bits NÃO sinalizado (0..4095), típico de ADC.
--      - O sinal é centralizado em zero subtraindo 2048.
--      - Internamente, opero em ponto fixo Q?.16 (C_FRAC = 16) com largura C_W = 40.
--      - Coeficientes estão em Q2.16 (armazenados em 18 bits).
--      - Saída o_sample: 12 bits SINALIZADO (-2048..2047), com saturação e
--        arredondamento (0.5 LSB em Q16).
--
--    Handshake:
--      - O processamento inicia quando i_sample_valid = '1'.
--      - A saída o_sample_valid é um pulso quando a amostra filtrada final está pronta.
--
--    Observação:
--      - Este código é a versão final validada em ModelSim e no FPGA, e também
--        passou no timing após o pipeline dos produtos dos DSPs.
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity filtro_Remove_DC_H3 is
  port (
    i_clk          : in  std_logic;
    i_rst          : in  std_logic;  -- reset assíncrono, ativo em '1'
    i_sample_valid : in  std_logic;
    i_sample       : in  std_logic_vector(11 downto 0);

    o_sample_valid : out std_logic;
    o_sample       : out std_logic_vector(11 downto 0)
  );
end entity;

architecture rtl of filtro_Remove_DC_H3 is

  -----------------------------------------------------------------------------
  -- Fix-point / larguras internas
  -- C_FRAC define a quantidade de bits fracionários (Q?.16).
  -- C_W define a largura interna (folga contra overflow nas acumulações).
  -----------------------------------------------------------------------------
  constant C_FRAC : integer := 16;
  constant C_W    : integer := 40;

  -- t_fp   : formato interno base (signed) com C_W bits, em Q?.16.
  -- t_wide : formato para produto completo (2*C_W bits).
  -- t_c18  : formato dos coeficientes Q2.16 em 18 bits.
  subtype t_fp    is signed(C_W-1 downto 0);
  subtype t_wide  is signed(2*C_W-1 downto 0);
  subtype t_c18   is signed(17 downto 0);

  -----------------------------------------------------------------------------
  -- Coeficientes SOS (4 seções, mesmo conjunto validado no "golden")
  -- Cada biquad DF2T usa (b0,b1,b2,a1,a2), com a0=1 implícito.
  -----------------------------------------------------------------------------
  constant B0_1 : t_c18 := to_signed(   2100, 18);
  constant B1_1 : t_c18 := to_signed(   4200, 18);
  constant B2_1 : t_c18 := to_signed(   2100, 18);
  constant A1_1 : t_c18 := to_signed(-125978, 18);
  constant A2_1 : t_c18 := to_signed(  61164, 18);

  constant B0_2 : t_c18 := to_signed(   2100, 18);
  constant B1_2 : t_c18 := to_signed(   4200, 18);
  constant B2_2 : t_c18 := to_signed(   2100, 18);
  constant A1_2 : t_c18 := to_signed(-127343, 18);
  constant A2_2 : t_c18 := to_signed(  62218, 18);

  constant B0_3 : t_c18 := to_signed(   2100, 18);
  constant B1_3 : t_c18 := to_signed(  -4200, 18);
  constant B2_3 : t_c18 := to_signed(   2100, 18);
  constant A1_3 : t_c18 := to_signed(-127900, 18);
  constant A2_3 : t_c18 := to_signed(  63418, 18);

  constant B0_4 : t_c18 := to_signed(   2100, 18);
  constant B1_4 : t_c18 := to_signed(  -4200, 18);
  constant B2_4 : t_c18 := to_signed(   2100, 18);
  constant A1_4 : t_c18 := to_signed(-129662, 18);
  constant A2_4 : t_c18 := to_signed(  64417, 18);

  -----------------------------------------------------------------------------
  -- Estados DF2T por seção (registradores "reais" do filtro)
  -- Para cada biquad DF2T existem dois estados (z1 e z2).
  -----------------------------------------------------------------------------
  signal z1_1, z2_1 : t_fp := (others => '0');
  signal z1_2, z2_2 : t_fp := (others => '0');
  signal z1_3, z2_3 : t_fp := (others => '0');
  signal z1_4, z2_4 : t_fp := (others => '0');

  -----------------------------------------------------------------------------
  -- Conversão de entrada
  -- i_sample vem como unsigned 12 bits (0..4095).
  -- Eu estendo para 13 bits e centralizo em zero subtraindo 2048,
  -- obtendo x_s13 no intervalo (-2048..2047).
  -----------------------------------------------------------------------------
  signal x_u13  : unsigned(12 downto 0) := (others => '0');
  signal x_s13  : signed(12 downto 0)   := (others => '0');

  -----------------------------------------------------------------------------
  -- Datapath interno
  -- x_cur : entrada da seção atual em Q?.16.
  -- y_reg : saída y da seção atual (resultado parcial do biquad).
  -- pb*   : termos b0*x, b1*x, b2*x já escalados de volta para Q?.16.
  -- pa*   : termos a1*y, a2*y já escalados de volta para Q?.16.
  -----------------------------------------------------------------------------
  signal x_cur  : t_fp := (others => '0');  -- entrada da seção atual (Q?.16)
  signal y_reg  : t_fp := (others => '0');  -- y da seção atual

  signal pb0, pb1, pb2 : t_fp := (others => '0');
  signal pa1, pa2      : t_fp := (others => '0');

  -----------------------------------------------------------------------------
  -- Coeficientes/estados "selecionados" da seção atual
  -- Eu não faço o cálculo com constantes diretamente a cada ciclo: primeiro
  -- capturo os coeficientes e estados da seção corrente em registradores
  -- (r_b*, r_a*, r_z*) para tornar o datapath mais regular e facilitar timing.
  -----------------------------------------------------------------------------
  signal r_b0, r_b1, r_b2 : t_fp := (others => '0');
  signal r_a1, r_a2       : t_fp := (others => '0');
  signal r_z1, r_z2       : t_fp := (others => '0');

  -----------------------------------------------------------------------------
  -- Multiplicações com reuso de DSP
  -- mulA* e mulB* são as entradas registradas dos multiplicadores.
  -- mulP* é o produto combinacional (A*B) e mulP*_r registra esse produto.
  --
  -- Observação importante:
  --   Eu uso 3 multiplicações em paralelo (mulP0..mulP2), o suficiente para:
  --     - b0*x, b1*x, b2*x   (fase B)
  --     - a1*y, a2*y         (fase A)  (o terceiro multiplicador é "zerado")
  --   O registro mulP*_r é exatamente o que garantiu o fechamento de timing.
  -----------------------------------------------------------------------------
  signal mulA0, mulA1, mulA2 : t_fp := (others => '0');
  signal mulB0, mulB1, mulB2 : t_fp := (others => '0');
  signal mulP0_r, mulP1_r, mulP2_r : t_wide := (others => '0');

  signal mulP0, mulP1, mulP2, mulP3, mulP4 : t_wide := (others => '0');

  -- Atributos para orientar o Vivado a inferir DSP nas multiplicações.
  attribute use_dsp : string;
  attribute use_dsp of mulP0 : signal is "yes";
  attribute use_dsp of mulP1 : signal is "yes";
  attribute use_dsp of mulP2 : signal is "yes";

  -----------------------------------------------------------------------------
  -- Saída registrada
  -- r_out   : saída final saturada em 12 bits signed.
  -- r_valid : pulso indicando que r_out é válido.
  -----------------------------------------------------------------------------
  signal r_valid : std_logic := '0';
  signal r_out   : signed(11 downto 0) := (others => '0');

  -- Constantes de arredondamento e saturação
  constant C_ROUND : t_fp := to_signed(2**(C_FRAC-1), C_W); -- 0.5 LSB em Q16
  constant C_MAX12 : signed(11 downto 0) := to_signed( 2047, 12);
  constant C_MIN12 : signed(11 downto 0) := to_signed(-2048, 12);

  signal y_round : t_fp := (others => '0');
  signal y_int16 : signed(15 downto 0) := (others => '0');

  -----------------------------------------------------------------------------
  -- Micro-FSM
  -- Eu divido o processamento de 1 amostra em vários microestados.
  -- A ideia é manter o datapath bem registrado e com poucos níveis lógicos
  -- entre flip-flops, garantindo resultado correto + timing fechado.
  -----------------------------------------------------------------------------
  type t_micro is (
    MS_IDLE,     -- espera i_sample_valid
    MS_CAP,      -- captura coefs/estados da seção atual (sec)
    MS_MUL_B,    -- programa DSPs para b0*x, b1*x, b2*x
    MS_REG_B,    -- registra os produtos do DSP (pipeline de timing)
    MS_SHR_B,    -- aplica shift_right e gera pb0,pb1,pb2 em Q?.16
    MS_CALC_Y,   -- calcula y = b0*x + z1
    MS_MUL_A,    -- programa DSPs para a1*y e a2*y
    MS_REG_A,    -- registra os produtos do DSP (pipeline de timing)
    MS_SHR_A,    -- aplica shift_right e gera pa1,pa2 em Q?.16
    MS_UPDATE,   -- atualiza z1,z2 e avança para próxima seção (ou finaliza)
    MS_OUT       -- arredonda/satura após a seção 4
  );

  signal micro : t_micro := MS_IDLE;

  -- sec indica qual seção SOS estou processando (1..4).
  signal sec   : unsigned(2 downto 0) := (others => '0');

begin

  -----------------------------------------------------------------------------
  -- Saídas (registradas)
  -----------------------------------------------------------------------------
  o_sample_valid <= r_valid;
  o_sample       <= std_logic_vector(r_out);

  -----------------------------------------------------------------------------
  -- Conversão de entrada (unsigned -> signed centrado em zero)
  -----------------------------------------------------------------------------
  x_u13 <= unsigned('0' & i_sample);
  x_s13 <= signed(x_u13) - to_signed(2048, 13);

  -----------------------------------------------------------------------------
  -- Produtos (3 DSPs)
  -- Aqui eu descrevo explicitamente as três multiplicações paralelas.
  -----------------------------------------------------------------------------
  mulP0 <= mulA0 * mulB0;
  mulP1 <= mulA1 * mulB1;
  mulP2 <= mulA2 * mulB2;

  -----------------------------------------------------------------------------
  -- FSM sequencial: todo o datapath é controlado e atualizado na borda de subida
  -- do clock. O reset é assíncrono e zera estados, registradores e saídas.
  -----------------------------------------------------------------------------
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      -------------------------------------------------------------------------
      -- Reset: zera os estados do filtro (z1/z2), datapath, registradores de
      -- coeficientes, multiplicadores, arredondamento e saídas.
      -------------------------------------------------------------------------
      z1_1 <= (others => '0'); z2_1 <= (others => '0');
      z1_2 <= (others => '0'); z2_2 <= (others => '0');
      z1_3 <= (others => '0'); z2_3 <= (others => '0');
      z1_4 <= (others => '0'); z2_4 <= (others => '0');

      x_cur   <= (others => '0');
      y_reg   <= (others => '0');
      pb0     <= (others => '0'); pb1 <= (others => '0'); pb2 <= (others => '0');
      pa1     <= (others => '0'); pa2 <= (others => '0');

      r_b0 <= (others => '0'); r_b1 <= (others => '0'); r_b2 <= (others => '0');
      r_a1 <= (others => '0'); r_a2 <= (others => '0');
      r_z1 <= (others => '0'); r_z2 <= (others => '0');

      mulA0 <= (others => '0'); mulA1 <= (others => '0'); mulA2 <= (others => '0');
      mulB0 <= (others => '0'); mulB1 <= (others => '0'); mulB2 <= (others => '0');

      mulP0_r <= (others => '0');
      mulP1_r <= (others => '0');
      mulP2_r <= (others => '0');

      y_round <= (others => '0');
      y_int16 <= (others => '0');

      r_valid <= '0';
      r_out   <= (others => '0');

      sec     <= (others => '0');
      micro   <= MS_IDLE;

    elsif rising_edge(i_clk) then
      -------------------------------------------------------------------------
      -- Default a cada clock: r_valid volta para '0'. Ele só vira '1' no estado
      -- MS_OUT, quando uma amostra final é gerada.
      -------------------------------------------------------------------------
      r_valid <= '0';

      case micro is

        -----------------------------------------------------------------------
        -- MS_IDLE:
        --   - Fico aguardando i_sample_valid.
        --   - Quando chega uma amostra, converto para Q?.16 e inicio na seção 1.
        -----------------------------------------------------------------------
        when MS_IDLE =>
          if i_sample_valid = '1' then
            x_cur <= shift_left(resize(x_s13, C_W), C_FRAC);
            sec   <= to_unsigned(1, sec'length);
            micro <= MS_CAP;
          end if;

        -----------------------------------------------------------------------
        -- MS_CAP:
        --   - Capturo (registradores r_*) os coeficientes e os estados z1/z2
        --     da seção selecionada por 'sec'.
        --   - Isso evita que eu tenha multiplexação grande no datapath durante
        --     o cálculo e ajuda no fechamento de timing.
        -----------------------------------------------------------------------
        when MS_CAP =>
          if sec = to_unsigned(1, sec'length) then
            r_b0 <= resize(B0_1, C_W); r_b1 <= resize(B1_1, C_W); r_b2 <= resize(B2_1, C_W);
            r_a1 <= resize(A1_1, C_W); r_a2 <= resize(A2_1, C_W);
            r_z1 <= z1_1; r_z2 <= z2_1;
          elsif sec = to_unsigned(2, sec'length) then
            r_b0 <= resize(B0_2, C_W); r_b1 <= resize(B1_2, C_W); r_b2 <= resize(B2_2, C_W);
            r_a1 <= resize(A1_2, C_W); r_a2 <= resize(A2_2, C_W);
            r_z1 <= z1_2; r_z2 <= z2_2;
          elsif sec = to_unsigned(3, sec'length) then
            r_b0 <= resize(B0_3, C_W); r_b1 <= resize(B1_3, C_W); r_b2 <= resize(B2_3, C_W);
            r_a1 <= resize(A1_3, C_W); r_a2 <= resize(A2_3, C_W);
            r_z1 <= z1_3; r_z2 <= z2_3;
          else
            r_b0 <= resize(B0_4, C_W); r_b1 <= resize(B1_4, C_W); r_b2 <= resize(B2_4, C_W);
            r_a1 <= resize(A1_4, C_W); r_a2 <= resize(A2_4, C_W);
            r_z1 <= z1_4; r_z2 <= z2_4;
          end if;

          micro <= MS_MUL_B;

        -----------------------------------------------------------------------
        -- MS_MUL_B:
        --   - Programo as entradas dos 3 DSPs para calcular:
        --       mulP0 = x_cur * r_b0
        --       mulP1 = x_cur * r_b1
        --       mulP2 = x_cur * r_b2
        --   - A multiplicação é descrita fora da FSM (mulP* <= mulA* * mulB*).
        -----------------------------------------------------------------------
        when MS_MUL_B =>
          mulA0 <= x_cur;  mulB0 <= r_b0;
          mulA1 <= x_cur;  mulB1 <= r_b1;
          mulA2 <= x_cur;  mulB2 <= r_b2;

          micro <= MS_REG_B;

        -----------------------------------------------------------------------
        -- MS_REG_B:
        --   - Estado criado propositalmente para registrar os produtos do DSP.
        --   - Essa etapa reduz o caminho combinacional DSP -> shift/resize e foi
        --     essencial para fechar timing no FPGA.
        -----------------------------------------------------------------------
        when MS_REG_B =>
          mulP0_r <= mulP0;
          mulP1_r <= mulP1;
          mulP2_r <= mulP2;
          micro   <= MS_SHR_B;

        -----------------------------------------------------------------------
        -- MS_SHR_B:
        --   - Faço o reescalonamento do produto (Q?.16 * Q2.16 -> Q?.32)
        --     voltando para Q?.16 com shift_right(C_FRAC).
        --   - Resultado são os termos pb0, pb1, pb2.
        -----------------------------------------------------------------------
        when MS_SHR_B =>
          pb0 <= resize(shift_right(mulP0_r, C_FRAC), C_W);
          pb1 <= resize(shift_right(mulP1_r, C_FRAC), C_W);
          pb2 <= resize(shift_right(mulP2_r, C_FRAC), C_W);
          micro <= MS_CALC_Y;

        -----------------------------------------------------------------------
        -- MS_CALC_Y:
        --   - DF2T: y = b0*x + z1
        --   - Aqui eu gero a saída parcial da seção e salvo em y_reg.
        -----------------------------------------------------------------------
        when MS_CALC_Y =>
          y_reg <= pb0 + r_z1;
          micro <= MS_MUL_A;

        -----------------------------------------------------------------------
        -- MS_MUL_A:
        --   - Programo os DSPs para calcular os termos de realimentação:
        --       mulP0 = y_reg * r_a1
        --       mulP1 = y_reg * r_a2
        --   - O terceiro multiplicador é zerado para manter estrutura fixa.
        -----------------------------------------------------------------------
        when MS_MUL_A =>
          mulA0 <= y_reg;  mulB0 <= r_a1;
          mulA1 <= y_reg;  mulB1 <= r_a2;
          mulA2 <= (others => '0'); mulB2 <= (others => '0');
          micro <= MS_REG_A;

        -----------------------------------------------------------------------
        -- MS_REG_A:
        --   - Registro os produtos do DSP (pipeline), novamente por requisito de
        --     timing (mesma ideia do MS_REG_B).
        -----------------------------------------------------------------------
        when MS_REG_A =>
          mulP0_r <= mulP0;
          mulP1_r <= mulP1;
          micro   <= MS_SHR_A;

        -----------------------------------------------------------------------
        -- MS_SHR_A:
        --   - Reescala a1*y e a2*y para Q?.16 (shift_right de C_FRAC).
        --   - Resultado são pa1 e pa2.
        -----------------------------------------------------------------------
        when MS_SHR_A =>
          pa1 <= resize(shift_right(mulP0_r, C_FRAC), C_W);
          pa2 <= resize(shift_right(mulP1_r, C_FRAC), C_W);
          micro <= MS_UPDATE;

        -----------------------------------------------------------------------
        -- MS_UPDATE:
        --   - Atualizo os estados DF2T da seção corrente:
        --       z1 <- b1*x - a1*y + z2
        --       z2 <- b2*x - a2*y
        --   - Como pb* e pa* já estão em Q?.16, a expressão fica direta.
        --   - Também avanço para a próxima seção (sec++), alimentando x_cur com
        --     a saída y_reg da seção atual.
        -----------------------------------------------------------------------
        when MS_UPDATE =>
          if sec = to_unsigned(1, sec'length) then
            z1_1 <= pb1 - pa1 + r_z2;
            z2_1 <= pb2 - pa2;
          elsif sec = to_unsigned(2, sec'length) then
            z1_2 <= pb1 - pa1 + r_z2;
            z2_2 <= pb2 - pa2;
          elsif sec = to_unsigned(3, sec'length) then
            z1_3 <= pb1 - pa1 + r_z2;
            z2_3 <= pb2 - pa2;
          else
            z1_4 <= pb1 - pa1 + r_z2;
            z2_4 <= pb2 - pa2;
          end if;

          -- Saída desta seção vira entrada da próxima
          x_cur <= y_reg;

          -- Se ainda não cheguei na seção 4, volto a capturar os coeficientes
          -- da próxima seção. Caso contrário, vou para o estágio final.
          if sec /= to_unsigned(4, sec'length) then
            sec   <= sec + 1;
            micro <= MS_CAP;
          else
            micro <= MS_OUT;
          end if;

        -----------------------------------------------------------------------
        -- MS_OUT:
        --   - Após finalizar a seção 4, faço o pós-processamento final:
        --       * arredondamento (soma de 0.5 LSB em Q16)
        --       * conversão para inteiro
        --       * saturação em 12 bits signed (-2048..2047)
        --   - Por fim, emito o pulso r_valid.
        -----------------------------------------------------------------------
        when MS_OUT =>
          y_round <= y_reg + C_ROUND;
          y_int16 <= resize(shift_right(y_round, C_FRAC), 16);

          if y_int16 > resize(C_MAX12, y_int16'length) then
            r_out <= C_MAX12;
          elsif y_int16 < resize(C_MIN12, y_int16'length) then
            r_out <= C_MIN12;
          else
            r_out <= resize(y_int16, 12);
          end if;

          r_valid <= '1';
          micro   <= MS_IDLE;

        when others =>
          micro <= MS_IDLE;

      end case;
    end if;
  end process;

end architecture;
