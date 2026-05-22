-- ============================================================================
--  Autor       : Prof. Dr. Andre dos Anjos
--  Bloco       : rocof_from_dfreq
--  Descricao   :
--
--    Estima grandezas proporcionais ao ROCOF (Rate of Change of Frequency)
--    a partir de um sinal de desvio de frequencia ja estimado em mHz.
--
--    A entrada i_dfreq_mHz deve representar o desvio de frequencia em mHz,
--    por exemplo:
--
--      +1000  -> +1 Hz
--      -500   -> -0.5 Hz
--
--    Nesta versao, antes do calculo do ROCOF, aplica-se um filtro IIR
--    de primeira ordem ao sinal de desvio de frequencia:
--
--      dfreq_filt[n] = dfreq_filt[n-1] +
--                      (dfreq[n] - dfreq_filt[n-1]) / 2^IIR_SH
--
--    Assim, as diferencas usadas para estimar o ROCOF sao calculadas
--    a partir de dfreq_filt, e nao diretamente a partir de i_dfreq_mHz.
--
--    O bloco fornece duas saidas principais:
--
--    1) o_rocof_diff_1samp_mHz
--
--       Diferenca entre a amostra filtrada atual e a amostra filtrada
--       imediatamente anterior:
--
--          diff_1[n] = dfreq_filt[n] - dfreq_filt[n-1]
--
--       Unidade:
--
--          mHz/amostra
--
--       Conversao para mHz/s no processador:
--
--          ROCOF_1[mHz/s] = diff_1[mHz] * FS_HZ
--
--       Conversao para Hz/s:
--
--          ROCOF_1[Hz/s] = diff_1[mHz] * FS_HZ / 1000
--
--
--    2) o_rocof_diff_win_mHz
--
--       Diferenca entre a amostra filtrada atual e a amostra filtrada
--       atrasada por WIN_SIZE amostras validas:
--
--          diff_M[n] = dfreq_filt[n] - dfreq_filt[n-WIN_SIZE]
--
--       Unidade:
--
--          mHz por janela WIN_SIZE
--
--       Conversao para mHz/s no processador:
--
--          ROCOF_M[mHz/s] = diff_M[mHz] * FS_HZ / WIN_SIZE
--
--       Conversao para Hz/s:
--
--          ROCOF_M[Hz/s] = diff_M[mHz] * FS_HZ / (1000*WIN_SIZE)
--
--    Para a protecao 81R, recomenda-se usar a saida de janela
--    o_rocof_diff_win_mHz, pois a diferenca de uma amostra normalmente
--    tem resolucao insuficiente para pickups baixos, como 0.5 a 2 Hz/s.
--
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rocof_from_dfreq is
  generic (
    DATA_WIDTH : integer := 32;

    -- Tamanho da janela em amostras validas de dfreq filtrado.
    -- Exemplos:
    --   WIN_SIZE = 64   -> janela de aproximadamente 16.65 ms para FS=3844 Hz
    --   WIN_SIZE = 128  -> janela de aproximadamente 33.30 ms para FS=3844 Hz
    --   WIN_SIZE = 256  -> janela de aproximadamente 66.60 ms para FS=3844 Hz
    WIN_SIZE   : integer := 128;

    -- Filtro IIR aplicado ao dfreq antes da derivada.
    --
    --   dfreq_filt = dfreq_filt + (dfreq_in - dfreq_filt)/2^IIR_SH
    --
    -- Sugestoes:
    --   IIR_SH = 2 -> filtro leve, resposta mais rapida
    --   IIR_SH = 3 -> compromisso inicial recomendado
    --   IIR_SH = 4 -> mais suavizacao
    --   IIR_SH = 5 -> mais lento, mais filtrado
    IIR_SH     : integer := 3
  );
  port (
    --------------------------------------------------------------------------
    -- Clock / Reset
    --------------------------------------------------------------------------
    i_clk        : in  std_logic;
    i_rst        : in  std_logic;

    --------------------------------------------------------------------------
    -- Entrada do estimador de frequencia
    --------------------------------------------------------------------------
    i_valid      : in  std_logic;
    i_dfreq_mHz  : in  signed(DATA_WIDTH-1 downto 0);

    --------------------------------------------------------------------------
    -- Saidas
    --------------------------------------------------------------------------
    o_valid              : out std_logic;

    -- Desvio de frequencia filtrado, para debug/monitoramento
    o_dfreq_filt_mHz     : out signed(DATA_WIDTH-1 downto 0);

    -- Diferenca de 1 amostra:
    --   dfreq_filt[n] - dfreq_filt[n-1]
    -- Unidade: mHz/amostra
    o_rocof_diff_1samp_mHz : out signed(DATA_WIDTH-1 downto 0);

    -- Diferenca em janela configuravel:
    --   dfreq_filt[n] - dfreq_filt[n-WIN_SIZE]
    -- Unidade: mHz por janela WIN_SIZE
    o_rocof_diff_win_mHz   : out signed(DATA_WIDTH-1 downto 0)
  );
end entity;

architecture rtl of rocof_from_dfreq is

  --------------------------------------------------------------------
  -- Memoria circular para armazenar as amostras antigas de dfreq filtrado
  --------------------------------------------------------------------
  type dfreq_mem_t is array (0 to WIN_SIZE-1) of signed(DATA_WIDTH-1 downto 0);
  signal dfreq_mem : dfreq_mem_t := (others => (others => '0'));

  signal wr_ptr : integer range 0 to WIN_SIZE-1 := 0;

  --------------------------------------------------------------------
  -- Registradores do filtro de entrada
  --------------------------------------------------------------------
  signal dfreq_filt_s      : signed(DATA_WIDTH-1 downto 0) := (others => '0');
  signal dfreq_filt_next_s : signed(DATA_WIDTH-1 downto 0) := (others => '0');
  signal dfreq_filt_init   : std_logic := '0';

  --------------------------------------------------------------------
  -- Registradores para derivadas
  --------------------------------------------------------------------
  signal dfreq_prev        : signed(DATA_WIDTH-1 downto 0) := (others => '0');
  signal dfreq_old_win     : signed(DATA_WIDTH-1 downto 0) := (others => '0');

  signal diff_1samp_s      : signed(DATA_WIDTH-1 downto 0) := (others => '0');
  signal diff_win_s        : signed(DATA_WIDTH-1 downto 0) := (others => '0');

  signal valid_r           : std_logic := '0';

  --------------------------------------------------------------------
  -- Controle de preenchimento da memoria
  --------------------------------------------------------------------
  signal fill_cnt : integer range 0 to WIN_SIZE := 0;
  signal mem_full : std_logic := '0';

begin

  o_valid                  <= valid_r;
  o_dfreq_filt_mHz         <= dfreq_filt_s;
  o_rocof_diff_1samp_mHz   <= diff_1samp_s;
  o_rocof_diff_win_mHz     <= diff_win_s;

  --------------------------------------------------------------------
  -- Processo principal
  --------------------------------------------------------------------
  process(i_clk)
  begin
    if rising_edge(i_clk) then

      if i_rst = '1' then

        dfreq_filt_s      <= (others => '0');
        dfreq_filt_next_s <= (others => '0');
        dfreq_filt_init   <= '0';

        dfreq_prev        <= (others => '0');
        dfreq_old_win     <= (others => '0');

        diff_1samp_s      <= (others => '0');
        diff_win_s        <= (others => '0');

        wr_ptr            <= 0;
        fill_cnt          <= 0;
        mem_full          <= '0';

        valid_r           <= '0';

      else

        ----------------------------------------------------------------
        -- Pulso de saida com duracao de 1 ciclo
        ----------------------------------------------------------------
        valid_r <= '0';

        if i_valid = '1' then

          ----------------------------------------------------------------
          -- Filtro IIR de entrada aplicado ao dfreq_mHz
          --
          -- Na primeira amostra valida, inicializa o filtro diretamente
          -- com a entrada para evitar transitorio artificial vindo de zero.
          ----------------------------------------------------------------
          if dfreq_filt_init = '0' then

            dfreq_filt_next_s <= i_dfreq_mHz;
            dfreq_filt_s      <= i_dfreq_mHz;
            dfreq_filt_init   <= '1';

            ----------------------------------------------------------------
            -- Na inicializacao, nao gera derivada valida ainda.
            ----------------------------------------------------------------
            diff_1samp_s <= (others => '0');
            diff_win_s   <= (others => '0');

            dfreq_prev <= i_dfreq_mHz;

            dfreq_mem(wr_ptr) <= i_dfreq_mHz;

          else

            ----------------------------------------------------------------
            -- Calcula proxima amostra filtrada:
            --
            --   y[n] = y[n-1] + (x[n] - y[n-1]) / 2^IIR_SH
            --
            -- Como VHDL atualiza sinais no fim do processo, a variavel
            -- conceitual dfreq_filt_next_s e usada neste mesmo ciclo
            -- para calcular as diferencas.
            ----------------------------------------------------------------
            dfreq_filt_next_s <= dfreq_filt_s +
                                 shift_right(i_dfreq_mHz - dfreq_filt_s, IIR_SH);

            ----------------------------------------------------------------
            -- Le amostra antiga da janela antes de sobrescrever memoria.
            --
            -- Como a memoria circular tem exatamente WIN_SIZE posicoes,
            -- a posicao atual wr_ptr contem a amostra filtrada
            -- dfreq_filt[n-WIN_SIZE] apos a memoria estar cheia.
            ----------------------------------------------------------------
            dfreq_old_win <= dfreq_mem(wr_ptr);

            ----------------------------------------------------------------
            -- Diferenca de 1 amostra, usando dfreq filtrado
            --
            -- Observacao:
            -- A expressao repete o calculo de dfreq_filt_next_s porque,
            -- neste mesmo ciclo, o sinal dfreq_filt_next_s ainda contem
            -- o valor antigo.
            ----------------------------------------------------------------
            diff_1samp_s <= (dfreq_filt_s +
                             shift_right(i_dfreq_mHz - dfreq_filt_s, IIR_SH))
                             - dfreq_prev;

            ----------------------------------------------------------------
            -- Diferenca de janela configuravel, usando dfreq filtrado.
            --
            -- Enquanto a memoria ainda nao encheu, a saida e mantida em zero
            -- para evitar comparar com amostras iniciais invalidas.
            ----------------------------------------------------------------
            if mem_full = '1' then
              diff_win_s <= (dfreq_filt_s +
                             shift_right(i_dfreq_mHz - dfreq_filt_s, IIR_SH))
                             - dfreq_mem(wr_ptr);
            else
              diff_win_s <= (others => '0');
            end if;

            ----------------------------------------------------------------
            -- Atualiza historico de 1 amostra com a amostra filtrada atual
            ----------------------------------------------------------------
            dfreq_prev <= (dfreq_filt_s +
                           shift_right(i_dfreq_mHz - dfreq_filt_s, IIR_SH));

            ----------------------------------------------------------------
            -- Atualiza memoria circular com a amostra filtrada atual
            ----------------------------------------------------------------
            dfreq_mem(wr_ptr) <= (dfreq_filt_s +
                                  shift_right(i_dfreq_mHz - dfreq_filt_s, IIR_SH));

          end if;

          ----------------------------------------------------------------
          -- Ponteiro da memoria circular
          ----------------------------------------------------------------
          if wr_ptr = WIN_SIZE-1 then
            wr_ptr <= 0;
          else
            wr_ptr <= wr_ptr + 1;
          end if;

          ----------------------------------------------------------------
          -- Controle de preenchimento da memoria
          ----------------------------------------------------------------
          if mem_full = '0' then
            if fill_cnt = WIN_SIZE-1 then
              fill_cnt <= WIN_SIZE;
              mem_full <= '1';
            else
              fill_cnt <= fill_cnt + 1;
            end if;
          end if;

          ----------------------------------------------------------------
          -- Atualiza registrador principal do filtro
          --
          -- Na primeira amostra, dfreq_filt_s ja foi inicializado acima.
          -- Nas proximas, recebe o valor filtrado calculado.
          ----------------------------------------------------------------
          if dfreq_filt_init = '1' then
            dfreq_filt_s <= dfreq_filt_s +
                            shift_right(i_dfreq_mHz - dfreq_filt_s, IIR_SH);
          end if;

          valid_r <= '1';

        end if;

      end if;

    end if;
  end process;

end architecture;