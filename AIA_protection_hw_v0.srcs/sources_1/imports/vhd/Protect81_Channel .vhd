-- ============================================================================
--  Autor       : Prof. Dr. André Antônio dos Anjos
--  Bloco       : Protect81_Channel
--  Função      : ANSI 81 - Proteção de Frequência por canal
--
--  Descrição   :
--
--    Este bloco implementa a função de proteção ANSI 81 para um único canal
--    de medição, utilizando como entrada o desvio de frequência em mHz
--    proveniente de um estimador externo de frequência.
--
--    A lógica implementada segue a filosofia de proteção escalonada, com:
--
--      * Estágio 1 (E1):
--          - destinado a desvios moderados de frequência;
--          - utiliza temporização configurável em milissegundos;
--          - gera sinalização de alarme e, caso a condição persista por tempo
--            suficiente, gera trip do estágio 1.
--
--      * Estágio 2 (E2):
--          - destinado a desvios severos de frequência;
--          - possui prioridade sobre o estágio 1;
--          - utiliza temporização própria, normalmente menor que a de E1;
--          - gera alarme e, caso a condição persista, gera trip do estágio 2.
--
--      * Tempo de inicialização (t_init):
--          - bloqueia a atuação da função logo após reset/inicialização;
--          - evita disparos indevidos durante o transitório inicial da medição.
--
--      * Histerese configurável:
--          - evita comutação repetitiva de estados quando o valor medido
--            oscila próximo aos limiares de atuação.
--
--    O bloco recebe o desvio de frequência em mHz:
--
--      - i_dfreq_mHz = 0      : frequência nominal
--      - i_dfreq_mHz > 0      : sobrefrequência
--      - i_dfreq_mHz < 0      : subfrequência
--
--    A comparação é feita contra quatro regiões de decisão:
--
--      - Subfrequência E1
--      - Sobrefrequência E1
--      - Subfrequência E2
--      - Sobrefrequência E2
--
--    Os limiares de E2 são definidos a partir dos limiares de E1 acrescidos
--    de uma margem configurável, tornando E2 mais severo que E1.
--
--  Filosofia de Operação :
--
--    1) Após reset, o bloco entra em inicialização e aguarda o término do
--       tempo configurado em i_init_time_ms.
--
--    2) Finalizada a inicialização, o bloco passa ao estado de monitoramento.
--
--    3) Se o desvio de frequência atingir a região de E2, o bloco prioriza
--       imediatamente o estágio 2.
--
--    4) Caso não haja violação de E2, mas haja violação de E1, o bloco inicia
--       a temporização do estágio 1.
--
--    5) Se, durante a temporização de E1, a condição se agravar e atingir E2,
--       o bloco abandona E1 e transfere a lógica para E2.
--
--    6) Se o sinal retornar à região normal antes do fim do atraso, com margem
--       de histerese, o temporizador é cancelado e o bloco retorna ao estado
--       de monitoramento.
--
--    7) Se o tempo configurado for atingido, o respectivo trip é acionado.
--
--  Estados da FSM :
--
--    S_IDLE
--      - estado inicial após reset;
--      - zera saídas, flags e habilitações internas;
--      - encaminha o bloco para a fase de inicialização.
--
--    S_INIT
--      - realiza o bloqueio temporário da função 81;
--      - mantém a proteção inibida até o contador atingir i_init_time_ms.
--
--    S_MONITORING
--      - estado normal de supervisão;
--      - analisa continuamente o desvio de frequência válido;
--      - verifica inicialmente a condição de E2 e, na ausência desta,
--        verifica a condição de E1.
--
--    S_E1_TIMING
--      - estágio 1 detectado;
--      - mantém alarme de E1 ativo;
--      - habilita o contador de atraso de E1;
--      - cancela a temporização caso a grandeza retorne à região normal com
--        histerese;
--      - migra para E2 caso o desvio se agrave;
--      - gera trip E1 se o atraso configurado for atingido.
--
--    S_E2_TIMING
--      - estágio 2 detectado;
--      - mantém alarme de E2 ativo;
--      - habilita o contador de atraso de E2;
--      - possui prioridade sobre E1;
--      - cancela a temporização caso a grandeza retorne à região normal com
--        histerese;
--      - gera trip E2 se o atraso configurado for atingido.
--
--    S_TRIPPED_E1
--      - estado de trip por estágio 1;
--      - mantém o trip E1 ativo até reset.
--
--    S_TRIPPED_E2
--      - estado de trip por estágio 2;
--      - mantém o trip E2 ativo até reset.
--
--  Organização da Implementação :
--
--    * Processo 1:
--        - máquina de estados principal;
--        - lógica de decisão;
--        - controle de alarmes, trips e habilitação dos temporizadores.
--
--    * Processo 2:
--        - geração da base de tempo em milissegundos;
--        - contadores de inicialização, E1 e E2;
--        - contagem habilitada somente quando solicitado pela FSM.
--
--  Observações :
--
--    - Este bloco processa apenas um canal/fase.
--    - Para implementação trifásica, recomenda-se instanciar três canais em
--      paralelo e combinar os trips/alarmes em um nível hierárquico superior.
--    - A entrada i_valid deve indicar que o valor de i_dfreq_mHz é válido e
--      atualizado pelo estimador de frequência anterior.
--
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Protect81_Channel is
  generic (
    --------------------------------------------------------------------------
    -- G_CLK_TICKS_PER_MS:
    --   quantidade de ciclos de clock correspondentes a 1 ms.
    --   Ex.: para clock de 100 MHz -> 100_000 ciclos = 1 ms
    --
    -- G_DATA_WIDTH:
    --   largura do barramento do desvio de frequência em mHz.
    --
    -- G_TIME_WIDTH:
    --   largura dos contadores/entradas de tempo em ms.
    --------------------------------------------------------------------------
    G_CLK_TICKS_PER_MS : natural := 100_000;
    G_DATA_WIDTH       : natural := 32;
    G_TIME_WIDTH       : natural := 20
  );
  port (
    ----------------------------------------------------------------
    -- Clock / Reset
    ----------------------------------------------------------------
    i_clk                  : in  std_logic;
    i_rst                  : in  std_logic;

    ----------------------------------------------------------------
    -- Entrada do estimador de frequência
    --
    -- i_valid:
    --   indica que o valor presente em i_dfreq_mHz é válido
    --
    -- i_dfreq_mHz:
    --   desvio de frequência em mHz
    --   negativo -> subfrequência
    --   positivo -> sobrefrequência
    ----------------------------------------------------------------
    i_valid                : in  std_logic;
    i_dfreq_mHz            : in  signed(G_DATA_WIDTH-1 downto 0);

    ----------------------------------------------------------------
    -- Configurações
    --
    -- Todos os pickups e margens devem ser fornecidos como valores
    -- positivos, na mesma unidade da entrada (mHz).
    ----------------------------------------------------------------
    i_pickup_under_e1_mHz  : in  signed(G_DATA_WIDTH-1 downto 0);
    i_pickup_over_e1_mHz   : in  signed(G_DATA_WIDTH-1 downto 0);
    i_margin_e2_mHz        : in  signed(G_DATA_WIDTH-1 downto 0);
    i_hyst_mHz             : in  signed(G_DATA_WIDTH-1 downto 0);

    i_delay_e1_ms          : in  unsigned(G_TIME_WIDTH-1 downto 0);
    i_delay_e2_ms          : in  unsigned(G_TIME_WIDTH-1 downto 0);
    i_init_time_ms         : in  unsigned(G_TIME_WIDTH-1 downto 0);

    ----------------------------------------------------------------
    -- Saídas
    ----------------------------------------------------------------
    o_alarm_e1             : out std_logic;
    o_alarm_e2             : out std_logic;
    o_trip_e1              : out std_logic;
    o_trip_e2              : out std_logic;
	o_trip_81			   : out std_logic
  );
end entity;

architecture rtl of Protect81_Channel is

  --------------------------------------------------------------------
  -- Tipo enumerado da máquina de estados
  --------------------------------------------------------------------
  type t_state is (
    S_IDLE,         -- estado inicial após reset
    S_INIT,         -- tempo de bloqueio inicial
    S_MONITORING,   -- supervisão normal
    S_E1_TIMING,    -- temporização do estágio 1
    S_E2_TIMING,    -- temporização do estágio 2
    S_TRIPPED_E1,   -- trip por E1
    S_TRIPPED_E2    -- trip por E2
  );

  --------------------------------------------------------------------
  -- Registrador de estado
  --------------------------------------------------------------------
  signal r_state          : t_state := S_IDLE;

  --------------------------------------------------------------------
  -- Registradores de saída
  --------------------------------------------------------------------
  signal r_alarm_e1       : std_logic := '0';
  signal r_alarm_e2       : std_logic := '0';
  signal r_trip_e1        : std_logic := '0';
  signal r_trip_e2        : std_logic := '0';

  --------------------------------------------------------------------
  -- Habilitação dos contadores
  --
  -- r_init_timer_en : habilita temporização do tempo de inicialização
  -- r_e1_timer_en   : habilita temporização de E1
  -- r_e2_timer_en   : habilita temporização de E2
  --------------------------------------------------------------------
  signal r_init_timer_en  : std_logic := '0';
  signal r_e1_timer_en    : std_logic := '0';
  signal r_e2_timer_en    : std_logic := '0';

  --------------------------------------------------------------------
  -- Base de tempo e contadores em ms
  --
  -- r_ms_div       : divisor de clock para gerar passo de 1 ms
  -- r_time_init_ms : contador do tempo de inicialização
  -- r_time_e1_ms   : contador do atraso de E1
  -- r_time_e2_ms   : contador do atraso de E2
  --------------------------------------------------------------------
  signal r_ms_div         : natural range 0 to G_CLK_TICKS_PER_MS-1 := 0;
  signal r_time_init_ms   : unsigned(G_TIME_WIDTH-1 downto 0) := (others => '0');
  signal r_time_e1_ms     : unsigned(G_TIME_WIDTH-1 downto 0) := (others => '0');
  signal r_time_e2_ms     : unsigned(G_TIME_WIDTH-1 downto 0) := (others => '0');

  --------------------------------------------------------------------
  -- Limiares absolutos de entrada
  --
  -- E1 under : valor negativo
  -- E1 over  : valor positivo
  -- E2 under : mais severo (mais negativo)
  -- E2 over  : mais severo (mais positivo)
  --------------------------------------------------------------------
  signal s_e1_under_pick  : signed(G_DATA_WIDTH-1 downto 0);
  signal s_e1_over_pick   : signed(G_DATA_WIDTH-1 downto 0);
  signal s_e2_under_pick  : signed(G_DATA_WIDTH-1 downto 0);
  signal s_e2_over_pick   : signed(G_DATA_WIDTH-1 downto 0);

  --------------------------------------------------------------------
  -- Limiares de retorno com histerese
  --
  -- Utilizados para cancelar a temporização e retornar ao estado de
  -- monitoramento quando a grandeza medida volta para a região normal.
  --------------------------------------------------------------------
  signal s_e1_under_ret   : signed(G_DATA_WIDTH-1 downto 0);
  signal s_e1_over_ret    : signed(G_DATA_WIDTH-1 downto 0);
  signal s_e2_under_ret   : signed(G_DATA_WIDTH-1 downto 0);
  signal s_e2_over_ret    : signed(G_DATA_WIDTH-1 downto 0);

  --------------------------------------------------------------------
  -- Flags combinacionais de decisão
  --
  -- s_in_e1    : indica entrada na região de atuação de E1
  -- s_in_e2    : indica entrada na região de atuação de E2
  -- s_leave_e1 : indica retorno para dentro da faixa normal de E1
  -- s_leave_e2 : indica retorno para dentro da faixa normal de E2
  --------------------------------------------------------------------
  signal s_in_e1          : std_logic;
  signal s_in_e2          : std_logic;
  signal s_leave_e1       : std_logic;
  signal s_leave_e2       : std_logic;

begin

  --------------------------------------------------------------------
  -- Conversões dos limiares
  --
  -- Convenção adotada:
  --   * entradas de configuração são positivas
  --   * subfrequência é comparada com valores negativos
  --   * sobrefrequência é comparada com valores positivos
  --------------------------------------------------------------------

  -- Limiares do estágio 1
  s_e1_under_pick <= -i_pickup_under_e1_mHz;
  s_e1_over_pick  <=  i_pickup_over_e1_mHz;

  -- Limiares do estágio 2 (mais severos que E1)
  s_e2_under_pick <= -(i_pickup_under_e1_mHz + i_margin_e2_mHz);
  s_e2_over_pick  <=  (i_pickup_over_e1_mHz  + i_margin_e2_mHz);

  -- Limiares de retorno de E1 com histerese
  s_e1_under_ret  <= -(i_pickup_under_e1_mHz - i_hyst_mHz);
  s_e1_over_ret   <=  (i_pickup_over_e1_mHz  - i_hyst_mHz);

  -- Limiares de retorno de E2 com histerese
  s_e2_under_ret  <= -((i_pickup_under_e1_mHz + i_margin_e2_mHz) - i_hyst_mHz);
  s_e2_over_ret   <=  ((i_pickup_over_e1_mHz  + i_margin_e2_mHz) - i_hyst_mHz);

  --------------------------------------------------------------------
  -- Detectores combinacionais das regiões de atuação
  --------------------------------------------------------------------

  -- Entra em E1 se a frequência ficar abaixo do pickup de subfrequência
  -- ou acima do pickup de sobrefrequência de E1
  s_in_e1 <= '1' when (i_dfreq_mHz <= s_e1_under_pick) or
                     (i_dfreq_mHz >= s_e1_over_pick)
             else '0';

  -- Entra em E2 se a frequência atingir a região severa
  s_in_e2 <= '1' when (i_dfreq_mHz <= s_e2_under_pick) or
                     (i_dfreq_mHz >= s_e2_over_pick)
             else '0';

  -- Retorno de E1: volta para dentro da faixa com histerese
  s_leave_e1 <= '1' when (i_dfreq_mHz > s_e1_under_ret) and
                         (i_dfreq_mHz < s_e1_over_ret)
                else '0';

  -- Retorno de E2: volta para dentro da faixa com histerese
  s_leave_e2 <= '1' when (i_dfreq_mHz > s_e2_under_ret) and
                         (i_dfreq_mHz < s_e2_over_ret)
                else '0';

  --------------------------------------------------------------------
  -- PROCESSO 1: FSM principal
  --
  -- Responsável por:
  --   * controlar os estados
  --   * avaliar as condições de entrada
  --   * gerar alarmes e trips
  --   * habilitar/desabilitar os temporizadores
  --------------------------------------------------------------------
  process(i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        ----------------------------------------------------------------
        -- Reset síncrono: zera estado, saídas e habilitações
        ----------------------------------------------------------------
        r_state         <= S_IDLE;
        r_alarm_e1      <= '0';
        r_alarm_e2      <= '0';
        r_trip_e1       <= '0';
        r_trip_e2       <= '0';
        r_init_timer_en <= '0';
        r_e1_timer_en   <= '0';
        r_e2_timer_en   <= '0';

      else
        case r_state is

          ----------------------------------------------------------------
          -- S_IDLE
          --   * limpa todas as saídas
          --   * prepara entrada no tempo de inicialização
          ----------------------------------------------------------------
          when S_IDLE =>
            r_alarm_e1      <= '0';
            r_alarm_e2      <= '0';
            r_trip_e1       <= '0';
            r_trip_e2       <= '0';
            r_init_timer_en <= '0';
            r_e1_timer_en   <= '0';
            r_e2_timer_en   <= '0';

            -- Vai para inicialização e habilita contador de t_init
            r_state         <= S_INIT;
            r_init_timer_en <= '1';

          ----------------------------------------------------------------
          -- S_INIT
          --   * bloqueia a função por i_init_time_ms
          --   * não há atuação durante este intervalo
          ----------------------------------------------------------------
          when S_INIT =>
            r_alarm_e1      <= '0';
            r_alarm_e2      <= '0';
            r_trip_e1       <= '0';
            r_trip_e2       <= '0';
            r_init_timer_en <= '1';
            r_e1_timer_en   <= '0';
            r_e2_timer_en   <= '0';

            -- Ao atingir o tempo de inicialização, libera monitoramento
            if r_time_init_ms >= i_init_time_ms then
              r_init_timer_en <= '0';
              r_state         <= S_MONITORING;
            end if;

          ----------------------------------------------------------------
          -- S_MONITORING
          --   * estado normal de supervisão
          --   * prioridade para E2
          --   * se não houver E2, avalia E1
          ----------------------------------------------------------------
          when S_MONITORING =>
            r_alarm_e1      <= '0';
            r_alarm_e2      <= '0';
            r_e1_timer_en   <= '0';
            r_e2_timer_en   <= '0';

            if i_valid = '1' then

              ------------------------------------------------------------
              -- Prioridade do estágio 2
              ------------------------------------------------------------
              if s_in_e2 = '1' then
                r_alarm_e2 <= '1';

                -- Se delay E2 = 0, atua imediatamente
                if i_delay_e2_ms = 0 then
                  r_trip_e2 <= '1';
                  r_state   <= S_TRIPPED_E2;
                else
                  -- Caso contrário, inicia temporização de E2
                  r_e2_timer_en <= '1';
                  r_state       <= S_E2_TIMING;
                end if;

              ------------------------------------------------------------
              -- Se não entrou em E2, verifica E1
              ------------------------------------------------------------
              elsif s_in_e1 = '1' then
                r_alarm_e1 <= '1';

                -- Se delay E1 = 0, atua imediatamente
                if i_delay_e1_ms = 0 then
                  r_trip_e1 <= '1';
                  r_state   <= S_TRIPPED_E1;
                else
                  -- Caso contrário, inicia temporização de E1
                  r_e1_timer_en <= '1';
                  r_state       <= S_E1_TIMING;
                end if;
              end if;
            end if;

          ----------------------------------------------------------------
          -- S_E1_TIMING
          --   * condição de E1 detectada
          --   * alarme E1 ativo
          --   * contador E1 habilitado
          --   * pode:
          --       - cancelar se voltar ao normal
          --       - migrar para E2 se piorar
          --       - gerar trip se delay for atingido
          ----------------------------------------------------------------
          when S_E1_TIMING =>
            r_alarm_e1    <= '1';
            r_alarm_e2    <= '0';
            r_e1_timer_en <= '1';
            r_e2_timer_en <= '0';

            if i_valid = '1' then

              ------------------------------------------------------------
              -- Se agravar e atingir E2, E2 tem prioridade
              ------------------------------------------------------------
              if s_in_e2 = '1' then
                r_alarm_e1    <= '0';
                r_alarm_e2    <= '1';
                r_e1_timer_en <= '0';

                if i_delay_e2_ms = 0 then
                  r_trip_e2 <= '1';
                  r_state   <= S_TRIPPED_E2;
                else
                  r_e2_timer_en <= '1';
                  r_state       <= S_E2_TIMING;
                end if;

              ------------------------------------------------------------
              -- Se voltou à região normal com histerese, cancela E1
              ------------------------------------------------------------
              elsif s_leave_e1 = '1' then
                r_alarm_e1    <= '0';
                r_e1_timer_en <= '0';
                r_state       <= S_MONITORING;
              end if;
            end if;

            --------------------------------------------------------------
            -- Se temporização de E1 foi cumprida, gera trip E1
            --------------------------------------------------------------
            if r_time_e1_ms >= i_delay_e1_ms then
              r_trip_e1     <= '1';
              r_alarm_e1    <= '0';
              r_e1_timer_en <= '0';
              r_state       <= S_TRIPPED_E1;
            end if;

          ----------------------------------------------------------------
          -- S_E2_TIMING
          --   * condição de E2 detectada
          --   * alarme E2 ativo
          --   * contador E2 habilitado
          --   * pode:
          --       - cancelar se voltar ao normal
          --       - gerar trip se delay for atingido
          ----------------------------------------------------------------
          when S_E2_TIMING =>
            r_alarm_e1    <= '0';
            r_alarm_e2    <= '1';
            r_e1_timer_en <= '0';
            r_e2_timer_en <= '1';

            if i_valid = '1' then
              ------------------------------------------------------------
              -- Se voltar à região normal com histerese, cancela E2
              ------------------------------------------------------------
              if s_leave_e2 = '1' then
                r_alarm_e2    <= '0';
                r_e2_timer_en <= '0';
                r_state       <= S_MONITORING;
              end if;
            end if;

            --------------------------------------------------------------
            -- Se temporização de E2 foi cumprida, gera trip E2
            --------------------------------------------------------------
            if r_time_e2_ms >= i_delay_e2_ms then
              r_trip_e2     <= '1';
              r_alarm_e2    <= '0';
              r_e2_timer_en <= '0';
              r_state       <= S_TRIPPED_E2;
            end if;

          ----------------------------------------------------------------
          -- S_TRIPPED_E1
          --   * mantém trip E1 ativo até reset
          ----------------------------------------------------------------
          when S_TRIPPED_E1 =>
            r_alarm_e1      <= '0';
            r_alarm_e2      <= '0';
            r_trip_e1       <= '1';
            r_trip_e2       <= '0';
            r_init_timer_en <= '0';
            r_e1_timer_en   <= '0';
            r_e2_timer_en   <= '0';
            r_state         <= S_TRIPPED_E1;

          ----------------------------------------------------------------
          -- S_TRIPPED_E2
          --   * mantém trip E2 ativo até reset
          ----------------------------------------------------------------
          when S_TRIPPED_E2 =>
            r_alarm_e1      <= '0';
            r_alarm_e2      <= '0';
            r_trip_e1       <= '0';
            r_trip_e2       <= '1';
            r_init_timer_en <= '0';
            r_e1_timer_en   <= '0';
            r_e2_timer_en   <= '0';
            r_state         <= S_TRIPPED_E2;

        end case;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------
  -- PROCESSO 2: base de tempo e contadores em ms
  --
  -- Responsável por:
  --   * dividir o clock para gerar 1 ms
  --   * incrementar contadores apenas quando habilitados
  --   * zerar contadores quando não estiverem habilitados
  --------------------------------------------------------------------
  process(i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        ----------------------------------------------------------------
        -- Reset dos contadores
        ----------------------------------------------------------------
        r_ms_div       <= 0;
        r_time_init_ms <= (others => '0');
        r_time_e1_ms   <= (others => '0');
        r_time_e2_ms   <= (others => '0');

      else
        ----------------------------------------------------------------
        -- O divisor só funciona se algum timer estiver habilitado
        ----------------------------------------------------------------
        if (r_init_timer_en = '1') or (r_e1_timer_en = '1') or (r_e2_timer_en = '1') then

          --------------------------------------------------------------
          -- Ao completar 1 ms, incrementa os contadores habilitados
          --------------------------------------------------------------
          if r_ms_div = G_CLK_TICKS_PER_MS - 1 then
            r_ms_div <= 0;

            ------------------------------------------------------------
            -- Contador de inicialização
            ------------------------------------------------------------
            if r_init_timer_en = '1' then
              if r_time_init_ms /= (r_time_init_ms'range => '1') then
                r_time_init_ms <= r_time_init_ms + 1;
              end if;
            else
              r_time_init_ms <= (others => '0');
            end if;

            ------------------------------------------------------------
            -- Contador de E1
            ------------------------------------------------------------
            if r_e1_timer_en = '1' then
              if r_time_e1_ms /= (r_time_e1_ms'range => '1') then
                r_time_e1_ms <= r_time_e1_ms + 1;
              end if;
            else
              r_time_e1_ms <= (others => '0');
            end if;

            ------------------------------------------------------------
            -- Contador de E2
            ------------------------------------------------------------
            if r_e2_timer_en = '1' then
              if r_time_e2_ms /= (r_time_e2_ms'range => '1') then
                r_time_e2_ms <= r_time_e2_ms + 1;
              end if;
            else
              r_time_e2_ms <= (others => '0');
            end if;

          else
            ------------------------------------------------------------
            -- Ainda não completou 1 ms: segue dividindo o clock
            ------------------------------------------------------------
            r_ms_div <= r_ms_div + 1;
          end if;

        else
          ----------------------------------------------------------------
          -- Nenhum timer habilitado:
          --   zera divisor e contadores
          ----------------------------------------------------------------
          r_ms_div       <= 0;
          r_time_init_ms <= (others => '0');
          r_time_e1_ms   <= (others => '0');
          r_time_e2_ms   <= (others => '0');
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------
  -- Mapeamento das saídas registradas para as portas
  --------------------------------------------------------------------
  o_alarm_e1 <= r_alarm_e1;
  o_alarm_e2 <= r_alarm_e2;
  o_trip_e1  <= r_trip_e1;
  o_trip_e2  <= r_trip_e2;
  o_trip_81  <= r_trip_e1 or r_trip_e2;

end architecture;