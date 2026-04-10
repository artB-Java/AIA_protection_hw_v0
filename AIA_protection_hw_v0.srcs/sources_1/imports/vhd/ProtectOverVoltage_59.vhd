-- =====================================================================
-- Bloco      : ProtectOverVoltage_59
-- Função     : ANSI 59 (Sobretensão) com atraso intencional (ms) e histerese.
--              * IDLE -> (primeiro i_valid) -> MONITORING
--              * MONITORING:
--                  - se sample >= pickup e delay == 0  -> TRIPPED (o_trip='1')
--                  - se sample >= pickup e delay > 0   -> ACTIVATED_TIMER (zera time_ms)
--              * ACTIVATED_TIMER:
--                  - se sample < pickup - HYST         -> MONITORING (desarma timer)
--                  - se time_ms >= delay               -> TRIPPED (o_trip='1')
--              * TRIPPED:
--                  - fica travado com o_trip='1'
--                  - se sample < pickup - HYST         -> sai para MONITORING (auto-reset)
-- Autor      : Prof. André Antônio dos Anjos 
-- Data       : 29/11/2025
-- =====================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ProtectOverVoltage_59 is
  generic (
    G_MS_TICKS : natural := 100_000; -- ciclos de i_clk por 1 ms (100MHz -> 100_000)
    G_HYST_U12 : natural := 0        -- histerese (0..4095) na mesma unidade de i_peakup_u12
  );
  port (
    --------------------------
    -- Clock / Reset
    --------------------------
    i_clk               : in  std_logic;
    i_rst               : in  std_logic;  -- reset síncrono, ativo-alto
    --------------------------
    -- Entradas
    --------------------------
    i_vsample_u12       : in  std_logic_vector(11 downto 0); -- tensão (0..4095)
    i_valid             : in  std_logic;                     -- pulso de amostra válida
    i_peakup_u12        : in  std_logic_vector(11 downto 0); -- pickup (U12)
    i_intentional_delay : in  std_logic_vector(19 downto 0); -- atraso intencional [ms]
    --------------------------
    -- Saída
    --------------------------
    o_trip              : out std_logic
  );
end entity;

architecture rtl of ProtectOverVoltage_59 is
  -- Estados
  type t_state is (S_IDLE, S_MONITORING, S_ACTIVATED_TIMER, S_TRIPPED);
  signal r_state      : t_state := S_IDLE;

  -- Saídas/flags
  signal r_trip       : std_logic := '0';
  signal r_timer_en   : std_logic := '0'; -- habilita tick + contador (somente em S_ACTIVATED_TIMER)

  -- Tick de 1ms e contador ms (processo separado)
  signal r_ms_div     : natural range 0 to G_MS_TICKS-1 := 0;
  signal r_time_ms    : unsigned(19 downto 0) := (others => '0');

  -- Limiar de retorno por histerese: max(0, pickup - G_HYST_U12)
  signal s_hyst_low   : unsigned(11 downto 0);

begin

  --------------------------------------------------------------------
  -- Histerese (concorrente) para SOBRETENSÃO
  --   * entrar em sobretensão: V >= pickup
  --   * sair (cancelar temporização / resetar trip): V < pickup - HYST
  --------------------------------------------------------------------
  s_hyst_low <= to_unsigned(
                  (to_integer(unsigned(i_peakup_u12)) - G_HYST_U12),
                  12
                ) when to_integer(unsigned(i_peakup_u12)) > G_HYST_U12
           else (others => '0');

  --------------------------------------------------------------------
  -- PROCESSO 1: FSM + atuações 
  --------------------------------------------------------------------
  process(i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        r_state    <= S_IDLE;
        r_trip     <= '0';
        r_timer_en <= '0';

      else
        case r_state is

          ----------------------------------------------------------------
          when S_IDLE =>
            r_trip     <= '0';
            r_timer_en <= '0';
            -- Após reset, vai direto a MONITORING
            r_state    <= S_MONITORING;

          ----------------------------------------------------------------
          when S_MONITORING =>
            r_trip     <= '0';
            r_timer_en <= '0';  -- contadores parados neste estado

            if i_valid = '1' then
              -- SOBRETENSÃO: condição de entrada quando V >= pickup
              if unsigned(i_vsample_u12) >= unsigned(i_peakup_u12) then
                if unsigned(i_intentional_delay) = 0 then
                  -- Instantâneo: arma e trava
                  r_trip  <= '1';
                  r_state <= S_TRIPPED;
                else
                  -- Com atraso: habilita temporização
                  r_timer_en <= '1';
                  r_state    <= S_ACTIVATED_TIMER;
                end if;
              end if;
            end if;

          ----------------------------------------------------------------
          when S_ACTIVATED_TIMER =>
            r_timer_en <= '1'; -- habilita tick + contador ms somente neste estado

            -- Se cair abaixo de (pickup - histerese), cancela o timer e volta
            if i_valid = '1' then
              if unsigned(i_vsample_u12) < s_hyst_low then
                r_timer_en <= '0';
                r_state    <= S_MONITORING;
              end if;
            end if;

            -- Disparo quando tempo atingiu atraso
            if (r_time_ms >= unsigned(i_intentional_delay)) then
              r_trip     <= '1';
              r_timer_en <= '0';
              r_state    <= S_TRIPPED;
            end if;

          ----------------------------------------------------------------
          when S_TRIPPED =>
            r_trip     <= '1';  -- travado enquanto estiver em sobretensão
            r_timer_en <= '0';
            r_state    <= S_TRIPPED;

            -- Auto-reset: quando tensão cai abaixo do (pickup - histerese),
            -- considera que voltou para faixa segura.
            if i_valid = '1' then
              if unsigned(i_vsample_u12) < s_hyst_low then
                r_trip     <= '0';
                r_state    <= S_MONITORING;
              end if;
            end if;

        end case;
      end if;
    end if;
  end process;

  -- envia registro do processo anterior para saída
  o_trip <= r_trip;

  --------------------------------------------------------------------
  -- PROCESSO do TIMER (tick 1ms + r_time_ms)
  --   * Só contam quando r_timer_en='1'
  --   * Desabilitados: ficam zerados e sem tick
  --------------------------------------------------------------------
  process(i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        r_ms_div  <= 0;
        r_time_ms <= (others => '0');

      else
        if r_timer_en = '1' then
          -- Divisor de 1 ms + incremento do contador de ms
          if r_ms_div = G_MS_TICKS - 1 then
            r_ms_div <= 0;
            if r_time_ms /= (r_time_ms'range => '1') then  -- saturação
              r_time_ms <= r_time_ms + 1;
            end if;
          else
            r_ms_div <= r_ms_div + 1;
          end if;
        else
          -- Timer desabilitado: zera tudo e não gera tick
          r_ms_div  <= 0;
          r_time_ms <= (others => '0');
        end if;
      end if;
    end if;
  end process;

end architecture;
