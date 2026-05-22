-- ============================================================================
--  Autor       : Prof. Dr. Andre dos Anjos
--  Bloco       : Protect81R_Channel
--  Descricao   :
--
--    Implementa a logica de protecao ANSI 81R (Rate Of Change Of Frequency)
--    para uma fase do sistema eletrico.
--
--    Este bloco foi desenvolvido para operar em conjunto com o estimador:
--
--      rocof_from_dfreq
--
--    utilizando especificamente a saida:
--
--      o_rocof_diff_win_mHz
--
--    Essa saida representa a diferenca entre duas estimativas de desvio de
--    frequencia, em mHz, separadas por uma janela de WIN_SIZE amostras:
--
--      diff_win_mHz[n] = dfreq_mHz[n] - dfreq_mHz[n - WIN_SIZE]
--
--    Portanto, a unidade de entrada deste bloco e:
--
--      mHz por janela
--
--    e nao diretamente Hz/s.
--
-- ============================================================================
--  CONVERSOES IMPORTANTES
-- ============================================================================
--
--    Considere:
--
--      FS_HZ    = taxa de atualizacao do estimador de frequencia
--      WIN_SIZE = janela usada no estimador de ROCOF
--
--    No projeto atual:
--
--      FS_HZ    = 3844 Hz
--      WIN_SIZE = 128 amostras
--
--    O tempo correspondente a uma janela e:
--
--      T_win = WIN_SIZE / FS_HZ
--
--    Para FS_HZ = 3844 e WIN_SIZE = 128:
--
--      T_win = 128 / 3844 ~= 33.30 ms
--
-- ----------------------------------------------------------------------------
--  1) Conversao de Hz/s para mHz/s
-- ----------------------------------------------------------------------------
--
--      ROCOF_mHz_s = ROCOF_Hz_s * 1000
--
--    Exemplo:
--
--      1 Hz/s = 1000 mHz/s
--
-- ----------------------------------------------------------------------------
--  2) Conversao de Hz/s para mHz/amostra
-- ----------------------------------------------------------------------------
--
--    A variacao esperada de frequencia em uma unica amostra e:
--
--      diff_1sample_mHz = ROCOF_Hz_s * 1000 / FS_HZ
--
--    Para FS_HZ = 3844:
--
--      diff_1sample_mHz = ROCOF_Hz_s * 1000 / 3844
--
--    Exemplos:
--
--      1 Hz/s  -> 0.260 mHz/amostra
--      5 Hz/s  -> 1.301 mHz/amostra
--      10 Hz/s -> 2.601 mHz/amostra
--
--    Observacao:
--
--      A diferenca de uma amostra e muito pequena para pickups baixos,
--      por isso a protecao 81R deve preferencialmente usar a diferenca
--      em janela.
--
-- ----------------------------------------------------------------------------
--  3) Conversao de Hz/s para mHz/janela
-- ----------------------------------------------------------------------------
--
--    A variacao esperada de frequencia ao longo de WIN_SIZE amostras e:
--
--      diff_win_mHz = ROCOF_Hz_s * 1000 * WIN_SIZE / FS_HZ
--
--    Para FS_HZ = 3844 e WIN_SIZE = 128:
--
--      diff_win_mHz = ROCOF_Hz_s * 1000 * 128 / 3844
--
--      diff_win_mHz ~= ROCOF_Hz_s * 33.30
--
--    Exemplos para WIN_SIZE = 128:
--
--      0.5 Hz/s ->  16.65 mHz/janela  -> usar aproximadamente 17
--      1.0 Hz/s ->  33.30 mHz/janela  -> usar aproximadamente 33
--      2.0 Hz/s ->  66.60 mHz/janela  -> usar aproximadamente 67
--      3.0 Hz/s ->  99.90 mHz/janela  -> usar aproximadamente 100
--      5.0 Hz/s -> 166.49 mHz/janela  -> usar aproximadamente 166
--      10  Hz/s -> 332.99 mHz/janela  -> usar aproximadamente 333
--
-- ----------------------------------------------------------------------------
--  4) Conversao de mHz/janela para Hz/s
-- ----------------------------------------------------------------------------
--
--    Caso se deseje interpretar o valor medido pela entrada deste bloco:
--
--      ROCOF_Hz_s = diff_win_mHz * FS_HZ / (1000 * WIN_SIZE)
--
--    Para FS_HZ = 3844 e WIN_SIZE = 128:
--
--      ROCOF_Hz_s = diff_win_mHz * 3844 / (1000 * 128)
--
--      ROCOF_Hz_s ~= diff_win_mHz * 0.03003
--
--    Exemplos:
--
--      diff_win_mHz = 33   -> aproximadamente 0.99 Hz/s
--      diff_win_mHz = 64   -> aproximadamente 1.92 Hz/s
--      diff_win_mHz = 100  -> aproximadamente 3.00 Hz/s
--      diff_win_mHz = 166  -> aproximadamente 4.98 Hz/s
--      diff_win_mHz = 333  -> aproximadamente 10.00 Hz/s
--
-- ============================================================================
--  OPERACAO DA PROTECAO
-- ============================================================================
--
--    O bloco trabalha com o valor absoluto do ROCOF:
--
--      abs(diff_win_mHz)
--
--    Portanto, a funcao 81R atua tanto para aumento rapido de frequencia
--    quanto para queda rapida de frequencia.
--
--    A protecao possui dois estagios:
--
--      E1: estagio mais sensivel, normalmente com maior temporizacao
--      E2: estagio mais severo, normalmente com menor temporizacao
--
--    Os sinais de trip permanecem retidos ate reset.
--
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Protect81R_Channel is
  generic (
    --------------------------------------------------------------------------
    -- Numero de ciclos de clock por milissegundo.
    --
    -- Exemplo:
    --   Clock = 100 MHz -> 100000 ciclos/ms
    --------------------------------------------------------------------------
    G_CLK_TICKS_PER_MS : natural := 100_000;

    --------------------------------------------------------------------------
    -- Largura dos sinais de ROCOF/pickup
    --------------------------------------------------------------------------
    G_DATA_WIDTH       : natural := 32;

    --------------------------------------------------------------------------
    -- Largura dos temporizadores em ms
    --------------------------------------------------------------------------
    G_TIME_WIDTH       : natural := 20
  );
  port (
    --------------------------------------------------------------------------
    -- Clock / Reset
    --------------------------------------------------------------------------
    i_clk  : in std_logic;
    i_rst  : in std_logic;

    --------------------------------------------------------------------------
    -- Entrada do estimador de ROCOF
    --
    -- i_valid:
    --   Pulso indicando que i_rocof_diff_win_mHz e valido.
    --
    -- i_rocof_diff_win_mHz:
    --   Diferenca de frequencia em mHz sobre a janela do estimador.
    --
    --   Unidade:
    --     mHz por janela
    --
    --   Exemplo com WIN_SIZE = 128 e FS_HZ = 3844:
    --     +33  -> aproximadamente +1 Hz/s
    --     -33  -> aproximadamente -1 Hz/s
    --     +100 -> aproximadamente +3 Hz/s
    --     -100 -> aproximadamente -3 Hz/s
    --------------------------------------------------------------------------
    i_valid               : in std_logic;
    i_rocof_diff_win_mHz  : in signed(G_DATA_WIDTH-1 downto 0);

    --------------------------------------------------------------------------
    -- Configuracoes
    --
    -- Todos os pickups e a histerese devem estar na mesma unidade da entrada:
    --
    --   mHz por janela
    --
    -- Para WIN_SIZE = 128 e FS_HZ = 3844:
    --
    --   1 Hz/s  ->  33 mHz/janela
    --   3 Hz/s  -> 100 mHz/janela
    --   5 Hz/s  -> 166 mHz/janela
    --   10 Hz/s -> 333 mHz/janela
    --------------------------------------------------------------------------
    i_pickup_e1_mHz_win : in signed(G_DATA_WIDTH-1 downto 0);
    i_pickup_e2_mHz_win : in signed(G_DATA_WIDTH-1 downto 0);
    i_hyst_mHz_win      : in signed(G_DATA_WIDTH-1 downto 0);

    i_delay_e1_ms       : in unsigned(G_TIME_WIDTH-1 downto 0);
    i_delay_e2_ms       : in unsigned(G_TIME_WIDTH-1 downto 0);
    i_init_time_ms      : in unsigned(G_TIME_WIDTH-1 downto 0);

    --------------------------------------------------------------------------
    -- Saidas principais
    --------------------------------------------------------------------------
    o_alarm_e1          : out std_logic;
    o_alarm_e2          : out std_logic;

    o_trip_e1           : out std_logic;
    o_trip_e2           : out std_logic;
    o_trip_81R          : out std_logic;

    --------------------------------------------------------------------------
    -- Saida auxiliar para debug/monitoramento
    --
    -- Valor absoluto de i_rocof_diff_win_mHz.
    --------------------------------------------------------------------------
    o_rocof_abs_mHz_win : out signed(G_DATA_WIDTH-1 downto 0)
  );
end entity;

architecture rtl of Protect81R_Channel is

  --------------------------------------------------------------------------
  -- Estados da maquina
  --------------------------------------------------------------------------
  type state_t is (
    S_IDLE,
    S_INIT,
    S_MONITORING,
    S_E1_TIMING,
    S_E2_TIMING,
    S_TRIPPED_E1,
    S_TRIPPED_E2
  );

  signal st : state_t := S_IDLE;

  --------------------------------------------------------------------------
  -- Registradores internos
  --------------------------------------------------------------------------
  signal rocof_abs_r : signed(G_DATA_WIDTH-1 downto 0) := (others => '0');

  signal alarm_e1_r : std_logic := '0';
  signal alarm_e2_r : std_logic := '0';

  signal trip_e1_r  : std_logic := '0';
  signal trip_e2_r  : std_logic := '0';
  signal trip_81r_r : std_logic := '0';

  --------------------------------------------------------------------------
  -- Temporizadores
  --------------------------------------------------------------------------
  signal tick_cnt : natural range 0 to G_CLK_TICKS_PER_MS-1 := 0;

  signal init_ms_cnt : unsigned(G_TIME_WIDTH-1 downto 0) := (others => '0');
  signal e1_ms_cnt   : unsigned(G_TIME_WIDTH-1 downto 0) := (others => '0');
  signal e2_ms_cnt   : unsigned(G_TIME_WIDTH-1 downto 0) := (others => '0');

  --------------------------------------------------------------------------
  -- Thresholds de retorno com histerese
  --------------------------------------------------------------------------
  signal pickup_e1_release_s : signed(G_DATA_WIDTH-1 downto 0);
  signal pickup_e2_release_s : signed(G_DATA_WIDTH-1 downto 0);

  --------------------------------------------------------------------------
  -- Funcao auxiliar: subtrai com saturacao inferior em zero.
  --
  -- Usada para formar:
  --
  --   pickup_release = max(pickup - hyst, 0)
  --------------------------------------------------------------------------
  function sub_floor_zero(
    a : signed;
    b : signed
  ) return signed is
    variable r : signed(a'range);
  begin
    if a > b then
      r := a - b;
    else
      r := (others => '0');
    end if;

    return r;
  end function;

begin

  --------------------------------------------------------------------------
  -- Saidas
  --------------------------------------------------------------------------
  o_alarm_e1          <= alarm_e1_r;
  o_alarm_e2          <= alarm_e2_r;

  o_trip_e1           <= trip_e1_r;
  o_trip_e2           <= trip_e2_r;
  o_trip_81R          <= trip_81r_r;

  o_rocof_abs_mHz_win <= rocof_abs_r;

  --------------------------------------------------------------------------
  -- Limiar de retorno com histerese
  --------------------------------------------------------------------------
  pickup_e1_release_s <= sub_floor_zero(i_pickup_e1_mHz_win, i_hyst_mHz_win);
  pickup_e2_release_s <= sub_floor_zero(i_pickup_e2_mHz_win, i_hyst_mHz_win);

  --------------------------------------------------------------------------
  -- Processo principal
  --------------------------------------------------------------------------
  process(i_clk)
  begin
    if rising_edge(i_clk) then

      if i_rst = '1' then

        st <= S_IDLE;

        rocof_abs_r <= (others => '0');

        alarm_e1_r <= '0';
        alarm_e2_r <= '0';

        trip_e1_r  <= '0';
        trip_e2_r  <= '0';
        trip_81r_r <= '0';

        tick_cnt    <= 0;
        init_ms_cnt <= (others => '0');
        e1_ms_cnt   <= (others => '0');
        e2_ms_cnt   <= (others => '0');

      else

        --------------------------------------------------------------------
        -- Atualiza valor absoluto do ROCOF somente quando houver dado valido.
        --------------------------------------------------------------------
        if i_valid = '1' then
          if i_rocof_diff_win_mHz < 0 then
            rocof_abs_r <= -i_rocof_diff_win_mHz;
          else
            rocof_abs_r <= i_rocof_diff_win_mHz;
          end if;
        end if;

        case st is

          ------------------------------------------------------------------
          -- Estado inicial
          ------------------------------------------------------------------
          when S_IDLE =>

            alarm_e1_r <= '0';
            alarm_e2_r <= '0';

            trip_e1_r  <= '0';
            trip_e2_r  <= '0';
            trip_81r_r <= '0';

            tick_cnt    <= 0;
            init_ms_cnt <= (others => '0');
            e1_ms_cnt   <= (others => '0');
            e2_ms_cnt   <= (others => '0');

            st <= S_INIT;

          ------------------------------------------------------------------
          -- Tempo inicial de bloqueio.
          --
          -- Evita atuacao durante preenchimento dos estimadores e logo apos
          -- reset.
          ------------------------------------------------------------------
          when S_INIT =>

            alarm_e1_r <= '0';
            alarm_e2_r <= '0';

            if i_init_time_ms = 0 then
              st <= S_MONITORING;
            else
              if tick_cnt = G_CLK_TICKS_PER_MS-1 then
                tick_cnt <= 0;

                if init_ms_cnt >= i_init_time_ms then
                  init_ms_cnt <= (others => '0');
                  st <= S_MONITORING;
                else
                  init_ms_cnt <= init_ms_cnt + 1;
                end if;

              else
                tick_cnt <= tick_cnt + 1;
              end if;
            end if;

          ------------------------------------------------------------------
          -- Monitoramento normal
          ------------------------------------------------------------------
          when S_MONITORING =>

            alarm_e1_r <= '0';
            alarm_e2_r <= '0';

            e1_ms_cnt <= (others => '0');
            e2_ms_cnt <= (others => '0');
            tick_cnt  <= 0;

            ----------------------------------------------------------------
            -- Prioridade para E2
            ----------------------------------------------------------------
            if rocof_abs_r >= i_pickup_e2_mHz_win then

              alarm_e2_r <= '1';

              if i_delay_e2_ms = 0 then
                st <= S_TRIPPED_E2;
              else
                st <= S_E2_TIMING;
              end if;

            elsif rocof_abs_r >= i_pickup_e1_mHz_win then

              alarm_e1_r <= '1';

              if i_delay_e1_ms = 0 then
                st <= S_TRIPPED_E1;
              else
                st <= S_E1_TIMING;
              end if;

            else

              st <= S_MONITORING;

            end if;

          ------------------------------------------------------------------
          -- Temporizacao do estagio E1
          ------------------------------------------------------------------
          when S_E1_TIMING =>

            alarm_e1_r <= '1';
            alarm_e2_r <= '0';

            ----------------------------------------------------------------
            -- Se agravar para E2, muda imediatamente para temporizacao E2
            ----------------------------------------------------------------
            if rocof_abs_r >= i_pickup_e2_mHz_win then

              alarm_e1_r <= '0';
              alarm_e2_r <= '1';
              e1_ms_cnt  <= (others => '0');
              tick_cnt   <= 0;

              if i_delay_e2_ms = 0 then
                st <= S_TRIPPED_E2;
              else
                st <= S_E2_TIMING;
              end if;

            ----------------------------------------------------------------
            -- Se cair abaixo do limiar de retorno E1, cancela temporizacao
            ----------------------------------------------------------------
            elsif rocof_abs_r < pickup_e1_release_s then

              alarm_e1_r <= '0';
              e1_ms_cnt  <= (others => '0');
              tick_cnt   <= 0;
              st         <= S_MONITORING;

            ----------------------------------------------------------------
            -- Permanece em E1 e conta tempo
            ----------------------------------------------------------------
            else

              if tick_cnt = G_CLK_TICKS_PER_MS-1 then
                tick_cnt <= 0;

                if e1_ms_cnt >= i_delay_e1_ms then
                  st <= S_TRIPPED_E1;
                else
                  e1_ms_cnt <= e1_ms_cnt + 1;
                end if;

              else
                tick_cnt <= tick_cnt + 1;
              end if;

            end if;

          ------------------------------------------------------------------
          -- Temporizacao do estagio E2
          ------------------------------------------------------------------
          when S_E2_TIMING =>

            alarm_e1_r <= '0';
            alarm_e2_r <= '1';

            ----------------------------------------------------------------
            -- Se cair abaixo do retorno E2, verifica se ainda permanece em E1
            ----------------------------------------------------------------
            if rocof_abs_r < pickup_e2_release_s then

              alarm_e2_r <= '0';
              e2_ms_cnt  <= (others => '0');
              tick_cnt   <= 0;

              if rocof_abs_r >= i_pickup_e1_mHz_win then

                alarm_e1_r <= '1';

                if i_delay_e1_ms = 0 then
                  st <= S_TRIPPED_E1;
                else
                  st <= S_E1_TIMING;
                end if;

              else

                st <= S_MONITORING;

              end if;

            ----------------------------------------------------------------
            -- Permanece em E2 e conta tempo
            ----------------------------------------------------------------
            else

              if tick_cnt = G_CLK_TICKS_PER_MS-1 then
                tick_cnt <= 0;

                if e2_ms_cnt >= i_delay_e2_ms then
                  st <= S_TRIPPED_E2;
                else
                  e2_ms_cnt <= e2_ms_cnt + 1;
                end if;

              else
                tick_cnt <= tick_cnt + 1;
              end if;

            end if;

          ------------------------------------------------------------------
          -- Trip E1 retido ate reset
          ------------------------------------------------------------------
          when S_TRIPPED_E1 =>

            alarm_e1_r <= '1';
            alarm_e2_r <= '0';

            trip_e1_r  <= '1';
            trip_e2_r  <= '0';
            trip_81r_r <= '1';

            st <= S_TRIPPED_E1;

          ------------------------------------------------------------------
          -- Trip E2 retido ate reset
          ------------------------------------------------------------------
          when S_TRIPPED_E2 =>

            alarm_e1_r <= '0';
            alarm_e2_r <= '1';

            trip_e1_r  <= '0';
            trip_e2_r  <= '1';
            trip_81r_r <= '1';

            st <= S_TRIPPED_E2;

          when others =>

            st <= S_IDLE;

        end case;

      end if;
    end if;
  end process;

end architecture;