----------------------------------------------------------------------------------
-- Bloco      : ProtPhaseUmbalanceNegSeq_46_51Q (ProtVoltageUmbalanceNegSeq_47_59Q)
-- Descrição  : Proteção contra desequilíbrio e sequência negativa de tensão.
-- Estados    : IDLE -> MONITORING -> TIME_WAIT_RD -> TIME_ACTIVE -> TRIPPED
--              * Arquitetura com controlador de divisão desacoplado (p_div_ctrl)
--              * Subestado TIME_WAIT_RD alinha a latência da RAM (s_ram_data_valid).
--
-- Autor      : Arthur Biliato Javaroni - UFU Santa Mônica                
-- Revisão    : 02/07/2026 (Revisão Arquitetural Completa)
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity ProtVoltageUmbalanceNegSeq_47_59Q is
  generic (
    -- Frequência de clock do sistema (Hz). Por padrão, 100 MHz.
    G_CLK_HZ : natural := 100_000_000;
    -- Histerese em "contagens RMS" para evitar chatter (i_peakup - G_HYST).
    G_HYST       : natural := 0;
    G_TIME_WIDTH : natural := 20;
    -- Larguras da LUT (RAM) usadas para a curva temporizada.
    G_ADDR_BITS : natural := 12; -- 2^12 = 4096 endereços (RMS 0..4095)
    G_DATA_BITS : natural := 20 -- tempo em ms, até ~1.048.575 ms
  );
  port (
    --------------------------
    -- Clock / Reset / Start
    --------------------------
    i_clk_100MHz : in std_logic; -- usar 100 MHz
    i_rst        : in std_logic; -- reset síncrono (nível alto)

    --------------------------
    -- Medida seqNeg e limiar
    --------------------------
    i_v2_abs        : in unsigned(31 downto 0); -- RMS 12b (0..*)
    i_v1_abs        : in unsigned(31 downto 0); -- RMS 12b (0..*)
    i_valid_v_seq   : in std_logic; -- '1' quando RMS atual é válido
    i_v2_pickup_e1  : in std_logic_vector(11 downto 0); -- limiar tempo definido
    i_vuf_pickup_e2 : in std_logic_vector(11 downto 0); -- limiar curva invertida
    i_delay_e1_ms   : in unsigned(G_TIME_WIDTH - 1 downto 0);

    --------------------------
    -- Interface RAM (LUT)
    --------------------------
    o_ram_addr   : out std_logic_vector(G_ADDR_BITS - 1 downto 0);
    o_ram_rd_req : out std_logic;
    i_ram_data   : in std_logic_vector(G_DATA_BITS - 1 downto 0);

    --------------------------
    -- Saídas de proteção / debug
    --------------------------
    o_v2_abs_stable : out unsigned(11 downto 0);
    o_v2_abs_u12    : out unsigned(11 downto 0);
    o_v1_abs_stable : out unsigned(11 downto 0);
    o_v1_abs_u12    : out unsigned(11 downto 0);
    o_time_ms       : out std_logic_vector(G_DATA_BITS - 1 downto 0);
    o_target_ms_reg : out unsigned(G_DATA_BITS - 1 downto 0);
    o_e1_time_cnt   : out unsigned(G_TIME_WIDTH - 1 downto 0);
    o_vuf           : out std_logic_vector(G_ADDR_BITS - 1 downto 0);

    -- saídas
    o_alarm_e1       : out std_logic;
    o_alarm_e2       : out std_logic;
    o_trip_47_59Q_e1 : out std_logic;
    o_trip_47_59Q_e2 : out std_logic;
    o_trip_47_59Q    : out std_logic
  );
end entity;

architecture rtl of ProtVoltageUmbalanceNegSeq_47_59Q is

  component sequencial_divider
    generic (
      W_NUM  : integer := 19;
      W_DEN  : integer := 12;
      W_FRAC : integer := 12
    );
    port (
      i_clk   : in std_logic;
      i_rst   : in std_logic;
      i_start : in std_logic;
      o_ready : out std_logic;
      i_num   : in unsigned(W_NUM - 1 downto 0);
      i_den   : in unsigned(W_DEN - 1 downto 0);
      o_ratio : out unsigned((W_NUM + W_FRAC) - 1 downto 0)
    );
  end component;

  --------------------------------------------------------------------
  -- Constantes internas
  --------------------------------------------------------------------
  constant C_MS_TICKS : natural := G_CLK_HZ / 1000; -- ciclos por 1 ms

  --------------------------------------------------------------------
  -- Tipos e estados (S_WAIT_DIV removido - controle agora é desacoplado)
  --------------------------------------------------------------------
  type t_state is (S_IDLE, S_MONITORING, S_E1_TIMING, S_TIME_WAIT_RD, S_TIME_ACTIVE, S_E2_TRIPPED, S_E1_TRIPPED);
  signal r_state : t_state := S_IDLE;

  --------------------------------------------------------------------
  -- Sinais do Divisor Sequencial e Amostragem
  --------------------------------------------------------------------
  signal s_div_start    : std_logic := '0';
  signal s_div_ready    : std_logic;
  signal s_div_result   : unsigned(30 downto 0) := (others => '0');
  signal reg_div_v1_u12 : unsigned(11 downto 0) := (others => '0');
  signal reg_div_v2_u19 : unsigned(18 downto 0) := (others => '0');
  signal s_sample_ready : std_logic             := '0'; -- Pulso de 1 ciclo: novo VUF disponível!

  --------------------------------------------------------------------
  -- Comparações e limiares
  --------------------------------------------------------------------
  signal s_v1_abs_u12   : unsigned(11 downto 0);
  signal s_v2_abs_u12   : unsigned(11 downto 0);
  signal s_vuf_u12      : unsigned(11 downto 0);
  signal peak_e1_u12    : unsigned(11 downto 0);
  signal peak_e2_u12    : unsigned(11 downto 0);
  signal hyst_u12       : unsigned(11 downto 0);
  signal low_thr_e1_u12 : unsigned(11 downto 0);
  signal low_thr_e2_u12 : unsigned(11 downto 0);

  signal e1_above_peak, e1_below_low : std_logic;
  signal e2_above_peak, e2_below_low : std_logic;

  --------------------------------------------------------------------
  -- Temporizadores e Contadores
  --------------------------------------------------------------------
  signal ms_div_cnt    : natural range 0 to C_MS_TICKS - 1   := 0;
  signal ms_tick       : std_logic                           := '0';
  signal time_ms_reg   : unsigned(G_DATA_BITS - 1 downto 0)  := (others => '0');
  signal time_cnt_en   : std_logic                           := '0';
  signal e1_ms_cnt     : unsigned(G_TIME_WIDTH - 1 downto 0) := (others => '0');
  signal target_ms_reg : unsigned(G_DATA_BITS - 1 downto 0)  := (others => '0');

  --------------------------------------------------------------------
  -- Interface RAM (LUT)
  --------------------------------------------------------------------
  signal ram_addr_reg     : unsigned(G_ADDR_BITS - 1 downto 0) := (others => '0');
  signal ram_rd_req_pulse : std_logic                          := '0';
  signal s_rd_req_d       : std_logic                          := '0';
  signal s_ram_data_valid : std_logic                          := '0';

  --------------------------------------------------------------------
  -- Registradores de Saída e Filtros
  --------------------------------------------------------------------
  signal alarm_e1_reg    : std_logic             := '0';
  signal alarm_e2_reg    : std_logic             := '0';
  signal trip_e1_reg     : std_logic             := '0';
  signal trip_e2_reg     : std_logic             := '0';
  signal s_v2_abs_stable : unsigned(11 downto 0) := (others => '0');
  signal s_v1_abs_stable : unsigned(11 downto 0) := (others => '0');

  -- Utilitário de remoção de ganho
  function gain_removal (x : unsigned(31 downto 0)) return unsigned is
    variable mult_reg        : unsigned(35 downto 0);
    variable y               : unsigned(31 downto 0);
  begin
    mult_reg := x * to_unsigned(10, 4);
    y        := resize(shift_right(mult_reg, 19), 32);
    return resize(y, 12);
  end function;

begin

  inst_seq_div : sequencial_divider
  generic map(
    W_NUM  => 19,
    W_DEN  => 12,
    W_FRAC => 12
  )
  port map
  (
    i_clk   => i_clk_100MHz,
    i_rst   => i_rst,
    i_start => s_div_start,
    o_ready => s_div_ready,
    i_num   => reg_div_v2_u19,
    i_den   => reg_div_v1_u12,
    o_ratio => s_div_result
  );

  -----------------------------------------------------------------------------
  -- Conversões e limiares (combinacionais)
  -----------------------------------------------------------------------------
  s_v1_abs_u12 <= gain_removal(i_v1_abs);
  s_v2_abs_u12 <= gain_removal(i_v2_abs);
  peak_e1_u12  <= unsigned(i_v2_pickup_e1);
  peak_e2_u12  <= unsigned(i_vuf_pickup_e2);
  hyst_u12     <= to_unsigned(G_HYST, 12);
  s_vuf_u12    <= s_div_result(23 downto 12);

  low_thr_e1_u12 <= (others => '0') when (peak_e1_u12 <= hyst_u12) else
    (peak_e1_u12 - hyst_u12);
  low_thr_e2_u12 <= (others => '0') when (peak_e2_u12 <= hyst_u12) else
    (peak_e2_u12 - hyst_u12);

  e1_above_peak <= '1' when (s_v2_abs_u12 > peak_e1_u12) else
    '0';
  e1_below_low <= '1' when (s_v2_abs_u12 <= low_thr_e1_u12) else
    '0';

  e2_above_peak <= '1' when (s_vuf_u12 > peak_e2_u12) else
    '0';
  e2_below_low <= '1' when (s_vuf_u12 <= low_thr_e2_u12) else
    '0';

  -----------------------------------------------------------------------------
  -- Filtros IIR (Com escopo de reset corrigido)
  -----------------------------------------------------------------------------
  p_filtro_iir_v1 : process (i_clk_100MHz)
    variable diff_v1   : unsigned(11 downto 0);
    variable filter_v1 : unsigned(11 downto 0);
  begin
    if rising_edge(i_clk_100MHz) then
      if i_rst = '1' then
        diff_v1   := (others       => '0');
        filter_v1 := (others       => '0');
        s_v1_abs_stable <= (others => '0');
      else
        if s_v1_abs_u12 > filter_v1 then
          diff_v1   := s_v1_abs_u12 - filter_v1;
          filter_v1 := filter_v1 + shift_right(diff_v1, 3);
        else
          diff_v1   := filter_v1 - s_v1_abs_u12;
          filter_v1 := filter_v1 - shift_right(diff_v1, 3);
        end if;
        s_v1_abs_stable <= filter_v1;
      end if;
    end if;
  end process;

  p_filtro_iir_v2 : process (i_clk_100MHz)
    variable diff_v2   : unsigned(11 downto 0);
    variable filter_v2 : unsigned(11 downto 0);
  begin
    if rising_edge(i_clk_100MHz) then
      if i_rst = '1' then
        diff_v2   := (others       => '0');
        filter_v2 := (others       => '0');
        s_v2_abs_stable <= (others => '0');
      else
        if s_v2_abs_u12 > filter_v2 then
          diff_v2   := s_v2_abs_u12 - filter_v2;
          filter_v2 := filter_v2 + shift_right(diff_v2, 3);
        else
          diff_v2   := filter_v2 - s_v2_abs_u12;
          filter_v2 := filter_v2 - shift_right(diff_v2, 3);
        end if;
        s_v2_abs_stable <= filter_v2;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Processo de Controle do Divisor Sequencial (Desacoplado)
  -- Monitora amostras em background sem parar os contadores de tempo da FSM
  -----------------------------------------------------------------------------
  p_div_ctrl : process (i_clk_100MHz)
  begin
    if rising_edge(i_clk_100MHz) then
      if i_rst = '1' then
        reg_div_v1_u12 <= (others => '0');
        reg_div_v2_u19 <= (others => '0');
        s_div_start    <= '0';
        s_sample_ready <= '0';
      else
        -- Atribuições padrão: geram pulsos limpos de exatamente 1 ciclo
        s_div_start    <= '0';
        s_sample_ready <= '0';

        if i_valid_v_seq = '1' then
          -- Trava as tensões filtradas no exato momento da amostra
          reg_div_v1_u12 <= s_v1_abs_stable;
          reg_div_v2_u19 <= s_v2_abs_stable * to_unsigned(100, 7);
          s_div_start    <= '1'; -- Dispara o cálculo do hardware
        elsif s_div_ready = '1' then
          s_sample_ready <= '1'; -- Avisa a FSM que s_vuf_u12 está atualizado!
        end if;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Divisor de 1 ms (Gera ms_tick = '1' por 1 ciclo a cada 1 ms)
  -----------------------------------------------------------------------------
  p_ms_div : process (i_clk_100MHz)
  begin
    if rising_edge(i_clk_100MHz) then
      if i_rst = '1' then
        ms_div_cnt <= 0;
        ms_tick    <= '0';
      else
        if ms_div_cnt = C_MS_TICKS - 1 then
          ms_div_cnt <= 0;
          ms_tick    <= '1';
        else
          ms_div_cnt <= ms_div_cnt + 1;
          ms_tick    <= '0';
        end if;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Contador de tempo em ms (Habilitado na curva E2; saturado)
  -----------------------------------------------------------------------------
  p_time_cnt : process (i_clk_100MHz)
  begin
    if rising_edge(i_clk_100MHz) then
      if i_rst = '1' then
        time_ms_reg <= (others => '0');
      else
        if time_cnt_en = '0' then
          time_ms_reg <= (others => '0');
        elsif ms_tick = '1' then
          if time_ms_reg /= (time_ms_reg'range => '1') then
            time_ms_reg <= time_ms_reg + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Máquina de Estados Principal (Proteção Elétrica 47/59Q)
  -----------------------------------------------------------------------------
  p_fsm : process (i_clk_100MHz)
  begin
    if rising_edge(i_clk_100MHz) then
      if i_rst = '1' then
        r_state          <= S_IDLE;
        trip_e1_reg      <= '0';
        trip_e2_reg      <= '0';
        target_ms_reg    <= (others => '0');
        ram_addr_reg     <= (others => '0');
        e1_ms_cnt        <= (others => '0');
        ram_rd_req_pulse <= '0';
        s_rd_req_d       <= '0';
        s_ram_data_valid <= '0';
        alarm_e1_reg     <= '0';
        alarm_e2_reg     <= '0';
        time_cnt_en      <= '0';
      else
        s_rd_req_d       <= ram_rd_req_pulse;
        s_ram_data_valid <= s_rd_req_d;

        -- Garante que requisição de leitura da RAM dure apenas 1 ciclo
        ram_rd_req_pulse <= '0';

        case r_state is
          when S_IDLE =>
            trip_e1_reg  <= '0';
            trip_e2_reg  <= '0';
            time_cnt_en  <= '0';
            e1_ms_cnt    <= (others => '0');
            alarm_e1_reg <= '0';
            alarm_e2_reg <= '0';

            if s_sample_ready = '1' then
              r_state <= S_MONITORING;
            end if;

          when S_MONITORING =>
            time_cnt_en  <= '0';
            e1_ms_cnt    <= (others => '0');
            alarm_e1_reg <= '0';
            alarm_e2_reg <= '0';

            if s_sample_ready = '1' then
              if e2_above_peak = '1' then
                ram_addr_reg     <= s_vuf_u12;
                ram_rd_req_pulse <= '1'; -- Inicia leitura da LUT para curva
                time_cnt_en      <= '1';
                alarm_e2_reg     <= '1';
                r_state          <= S_TIME_WAIT_RD;
              elsif e1_above_peak = '1' then
                alarm_e1_reg <= '1';
                if i_delay_e1_ms = 0 then
                  trip_e1_reg <= '1';
                  r_state     <= S_E1_TRIPPED;
                else
                  r_state <= S_E1_TIMING;
                end if;
              end if;
            end if;

          when S_E1_TIMING =>
            alarm_e1_reg <= '1';
            alarm_e2_reg <= '0';

            -- Monitora continuamente as novas amostras sem pausar o tempo
            if s_sample_ready = '1' then
              if e2_above_peak = '1' then
                ram_addr_reg     <= s_vuf_u12;
                ram_rd_req_pulse <= '1';
                time_cnt_en      <= '1';
                alarm_e2_reg     <= '1';
                r_state          <= S_TIME_WAIT_RD;
              elsif e1_below_low = '1' then
                alarm_e1_reg <= '0';
                e1_ms_cnt    <= (others => '0');
                r_state      <= S_MONITORING;
              end if;
            end if;

            -- Incremento do temporizador de tempo definido (E1)
            if ms_tick = '1' then
              if e1_ms_cnt /= (e1_ms_cnt'range => '1') then
                if e1_ms_cnt >= i_delay_e1_ms then
                  trip_e1_reg <= '1';
                  r_state     <= S_E1_TRIPPED;
                else
                  e1_ms_cnt <= e1_ms_cnt + 1;
                end if;
              end if;
            end if;

          when S_TIME_WAIT_RD =>
            time_cnt_en <= '1';
            if s_ram_data_valid = '1' then
              target_ms_reg <= unsigned(i_ram_data);
              r_state       <= S_TIME_ACTIVE;
            end if;

            -- Permite abortar ou atualizar endereço on-the-fly
            if s_sample_ready = '1' then
              if e2_below_low = '1' then
                time_cnt_en  <= '0';
                alarm_e2_reg <= '0';
                r_state      <= S_MONITORING;
              else
                ram_addr_reg     <= s_vuf_u12;
                ram_rd_req_pulse <= '1';
              end if;
            end if;

          when S_TIME_ACTIVE =>
            time_cnt_en <= '1';

            if s_sample_ready = '1' then
              if e2_below_low = '1' then
                time_cnt_en  <= '0';
                alarm_e2_reg <= '0';
                r_state      <= S_MONITORING;
              else
                ram_addr_reg     <= s_vuf_u12;
                ram_rd_req_pulse <= '1';
              end if;
            end if;

            if s_ram_data_valid = '1' then
              target_ms_reg <= unsigned(i_ram_data);
            end if;

            if time_ms_reg >= target_ms_reg and target_ms_reg /= 0 then
              trip_e2_reg <= '1';
              r_state     <= S_E2_TRIPPED;
            end if;

          when S_E1_TRIPPED =>
            alarm_e1_reg <= '1';
            alarm_e2_reg <= '0';
            trip_e1_reg  <= '1';
            trip_e2_reg  <= '0';

            if s_sample_ready = '1' then
              if e2_above_peak = '1' then
                ram_addr_reg     <= s_vuf_u12;
                ram_rd_req_pulse <= '1';
                time_cnt_en      <= '1';
                alarm_e2_reg     <= '1';
                e1_ms_cnt        <= (others => '0');
                r_state          <= S_TIME_WAIT_RD;
              elsif e1_below_low = '1' then
                alarm_e1_reg <= '0';
                trip_e1_reg  <= '0';
                e1_ms_cnt    <= (others => '0');
                r_state      <= S_MONITORING;
              end if;
            end if;

          when S_E2_TRIPPED =>
            alarm_e2_reg <= '1';
            alarm_e1_reg <= '0';
            trip_e2_reg  <= '1';
            trip_e1_reg  <= '0';
            time_cnt_en  <= '0';

            if s_sample_ready = '1' then
              if e2_below_low = '1' then
                trip_e2_reg  <= '0';
                alarm_e2_reg <= '0';
                r_state      <= S_MONITORING;
              end if;
            end if;

          when others =>
            null;
        end case;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Mapeamento de Saídas
  -----------------------------------------------------------------------------
  o_trip_47_59Q    <= trip_e1_reg or trip_e2_reg;
  o_trip_47_59Q_e1 <= trip_e1_reg;
  o_trip_47_59Q_e2 <= trip_e2_reg;
  o_time_ms        <= std_logic_vector(time_ms_reg);
  o_target_ms_reg  <= target_ms_reg;
  o_e1_time_cnt    <= e1_ms_cnt;

  o_v1_abs_stable <= s_v1_abs_stable;
  o_v2_abs_stable <= s_v2_abs_stable;

  o_v1_abs_u12 <= s_v1_abs_u12;
  o_v2_abs_u12 <= s_v2_abs_u12;
  o_vuf        <= std_logic_vector(s_vuf_u12);

  o_alarm_e1 <= alarm_e1_reg;
  o_alarm_e2 <= alarm_e2_reg;

  o_ram_addr   <= std_logic_vector(ram_addr_reg);
  o_ram_rd_req <= ram_rd_req_pulse;

end architecture;
