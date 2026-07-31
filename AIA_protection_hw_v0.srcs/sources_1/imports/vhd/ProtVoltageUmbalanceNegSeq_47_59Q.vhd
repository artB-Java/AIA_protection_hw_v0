----------------------------------------------------------------------------------
-- Bloco      : ProtPhaseUmbalanceNegSeq_46_51Q (ProtVoltageUmbalanceNegSeq_47_59Q)
-- Descrição  : Proteção contra desequilíbrio de tensão baseada puramente em V2.
-- Estados    : IDLE -> MONITORING -> TIME_WAIT_RD -> TIME_ACTIVE -> TRIPPED
--              * Divisor sequencial removido. Proteção baseada diretamente em V2.
--              * Subestado TIME_WAIT_RD alinha a latência da RAM (s_ram_data_valid).
--
-- Autor      : Arthur Biliato Javaroni - UFU Santa Mônica                
-- Revisão    : 20/07/2026 (Simplificação por V2 Absoluto)
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity ProtVoltageUmbalanceNegSeq_47_59Q is
  generic (
    -- Frequência de clock do sistema (Hz). Por padrão, 100 MHz.
    G_CLK_HZ     : natural := 100_000_000;
    -- Histerese em "contagens RMS" para evitar chatter (i_peakup - G_HYST).
    G_HYST       : natural := 0;
    G_TIME_WIDTH : natural := 20;
    -- Larguras da LUT (RAM) usadas para a curva temporizada.
    G_ADDR_BITS  : natural := 12; -- 2^12 = 4096 endereços (RMS 0..4095)
    G_DATA_BITS  : natural := 20  -- tempo em ms, até ~1.048.575 ms
  );
  port (
    --------------------------
    -- Clock / Reset / Start
    --------------------------
    i_clk_100MHz    : in  std_logic; -- usar 100 MHz
    i_rst           : in  std_logic; -- reset síncrono (nível alto)

    --------------------------
    -- Medida seqNeg e limiar
    --------------------------
    i_v2_abs        : in  unsigned(31 downto 0); -- RMS 12b (0..*) de sequência negativa
    i_valid_v_seq   : in  std_logic;             -- '1' quando RMS atual é válido (pulso amostra)
    i_v2_pickup_e1  : in  std_logic_vector(11 downto 0); -- limiar tempo definido (E1)
    i_v2_pickup_e2  : in  std_logic_vector(11 downto 0); -- limiar curva temporizada (E2)
    i_delay_e1_ms   : in  unsigned(G_TIME_WIDTH - 1 downto 0);

    --------------------------
    -- Interface RAM (LUT)
    --------------------------
    o_ram_addr      : out std_logic_vector(G_ADDR_BITS - 1 downto 0);
    o_ram_rd_req    : out std_logic;
    i_ram_data      : in  std_logic_vector(G_DATA_BITS - 1 downto 0);

    --------------------------
    -- Saídas de proteção / debug
    --------------------------
    o_v2_abs_stable : out unsigned(11 downto 0);
    o_v2_abs_u12    : out unsigned(11 downto 0);
    o_time_ms       : out std_logic_vector(G_DATA_BITS - 1 downto 0);
    o_target_ms_reg : out unsigned(G_DATA_BITS - 1 downto 0);
    o_e1_time_cnt   : out unsigned(G_TIME_WIDTH - 1 downto 0);

    -- saídas
    o_alarm_e1       : out std_logic;
    o_alarm_e2       : out std_logic;
    o_trip_47_59Q_e1 : out std_logic;
    o_trip_47_59Q_e2 : out std_logic;
    o_trip_47_59Q    : out std_logic
  );
end entity;

architecture rtl of ProtVoltageUmbalanceNegSeq_47_59Q is

  --------------------------------------------------------------------
  -- Constantes internas
  --------------------------------------------------------------------
  constant C_MS_TICKS : natural := G_CLK_HZ / 1000; -- ciclos por 1 ms

  --------------------------------------------------------------------
  -- Tipos e estados
  --------------------------------------------------------------------
  type t_state is (S_IDLE, S_MONITORING, S_E1_TIMING, S_TIME_WAIT_RD, S_TIME_ACTIVE, S_E2_TRIPPED, S_E1_TRIPPED);
  signal r_state : t_state := S_IDLE;

  --------------------------------------------------------------------
  -- Comparações e limiares baseados em V2
  --------------------------------------------------------------------
  signal s_v2_abs_u12    : unsigned(11 downto 0);
  signal s_v2_mult_temp  : unsigned(35 downto 0);
  signal s_v2_u32_temp   : unsigned(31 downto 0);
  signal peak_e1_u12     : unsigned(11 downto 0);
  signal peak_e2_u12     : unsigned(11 downto 0);
  signal hyst_u12        : unsigned(11 downto 0);
  signal low_thr_e1_u12  : unsigned(11 downto 0);
  signal low_thr_e2_u12  : unsigned(11 downto 0);

  signal e1_above_peak, e1_below_low : std_logic;
  signal e2_above_peak, e2_below_low : std_logic;

  --------------------------------------------------------------------
  -- Temporizadores e Contadores
  --------------------------------------------------------------------
  signal ms_div_cnt      : natural range 0 to C_MS_TICKS - 1 := 0;
  signal ms_tick         : std_logic := '0';
  signal time_ms_reg     : unsigned(G_DATA_BITS - 1 downto 0)  := (others => '0');
  signal time_cnt_en     : std_logic := '0';
  signal e1_ms_cnt       : unsigned(G_TIME_WIDTH - 1 downto 0) := (others => '0');
  signal target_ms_reg   : unsigned(G_DATA_BITS - 1 downto 0)  := (others => '0');

  --------------------------------------------------------------------
  -- Interface RAM (LUT)
  --------------------------------------------------------------------
  signal ram_addr_reg     : unsigned(G_ADDR_BITS - 1 downto 0) := (others => '0');
  signal ram_rd_req_pulse : std_logic := '0';
  signal s_rd_req_d       : std_logic := '0';
  signal s_ram_data_valid : std_logic := '0';

  --------------------------------------------------------------------
  -- Registradores de Saída e Filtro
  --------------------------------------------------------------------
  signal alarm_e1_reg    : std_logic := '0';
  signal alarm_e2_reg    : std_logic := '0';
  signal trip_e1_reg     : std_logic := '0';
  signal trip_e2_reg     : std_logic := '0';
  signal s_v2_abs_stable : unsigned(11 downto 0) := (others => '0');

begin

  -----------------------------------------------------------------------------
  -- Conversões e limiares (combinacionais)
  -----------------------------------------------------------------------------
  s_v2_abs_u12   <= resize(shift_right(i_v2_abs, 19), 12);

  peak_e1_u12  <= unsigned(i_v2_pickup_e1);
  peak_e2_u12  <= unsigned(i_v2_pickup_e2);
  hyst_u12     <= to_unsigned(G_HYST, 12);

  low_thr_e1_u12 <= (others => '0') when (peak_e1_u12 <= hyst_u12) else (peak_e1_u12 - hyst_u12);
  low_thr_e2_u12 <= (others => '0') when (peak_e2_u12 <= hyst_u12) else (peak_e2_u12 - hyst_u12);

  -- Comparações diretas feitas sobre a saída estabilizada do filtro IIR
  e1_above_peak <= '1' when (s_v2_abs_stable > peak_e1_u12) else '0';
  e1_below_low  <= '1' when (s_v2_abs_stable <= low_thr_e1_u12) else '0';

  e2_above_peak <= '1' when (s_v2_abs_stable > peak_e2_u12) else '0';
  e2_below_low  <= '1' when (s_v2_abs_stable <= low_thr_e2_u12) else '0';

  -----------------------------------------------------------------------------
  -- Filtro IIR de V2
  -----------------------------------------------------------------------------
  p_filtro_iir_v2 : process (i_clk_100MHz)
    variable diff_v2   : unsigned(11 downto 0);
    variable filter_v2 : unsigned(11 downto 0);
  begin
    if rising_edge(i_clk_100MHz) then
      if i_rst = '1' then
        diff_v2         := (others => '0');
        filter_v2       := (others => '0');
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
  -- Máquina de Estados Principal (Proteção baseada em V2 Estável)
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
        
        -- Garante que requisição de leitura da RAM dure sempre apenas 1 ciclo
        ram_rd_req_pulse <= '0';

        case r_state is
          when S_IDLE =>
            trip_e1_reg  <= '0';
            trip_e2_reg  <= '0';
            time_cnt_en  <= '0';
            e1_ms_cnt    <= (others => '0');
            alarm_e1_reg <= '0';
            alarm_e2_reg <= '0';

            if i_valid_v_seq = '1' then
              r_state <= S_MONITORING;
            end if;

          when S_MONITORING =>
            time_cnt_en  <= '0';
            e1_ms_cnt    <= (others => '0');
            alarm_e1_reg <= '0';
            alarm_e2_reg <= '0';

            -- Decisões tomadas instantaneamente com a chegada da nova amostra estável
            if i_valid_v_seq = '1' then
              if e2_above_peak = '1' then
                ram_addr_reg     <= s_v2_abs_stable; -- O próprio VUF simulado por V2 mapeia a LUT
                ram_rd_req_pulse <= '1'; 
                time_cnt_en      <= '1';
                alarm_e2_reg     <= '1';
                r_state          <= S_TIME_WAIT_RD;
              elsif e1_above_peak = '1' then
                alarm_e1_reg <= '1';
                if i_delay_e1_ms = 0 then
                  trip_e1_reg <= '1';
                  r_state     <= S_E1_TRIPPED;
                else
                  r_state     <= S_E1_TIMING;
                end if;
              end if;
            end if;

          when S_E1_TIMING =>
            alarm_e1_reg <= '1';
            alarm_e2_reg <= '0';

            if i_valid_v_seq = '1' then
              if e2_above_peak = '1' then
                ram_addr_reg     <= s_v2_abs_stable;
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

            if i_valid_v_seq = '1' then
              if e2_below_low = '1' then
                time_cnt_en  <= '0';
                alarm_e2_reg <= '0';
                r_state      <= S_MONITORING;
              else
                ram_addr_reg     <= s_v2_abs_stable;
                ram_rd_req_pulse <= '1';
              end if;
            end if;

          when S_TIME_ACTIVE =>
            time_cnt_en <= '1';

            if i_valid_v_seq = '1' then
              if e2_below_low = '1' then
                time_cnt_en  <= '0';
                alarm_e2_reg <= '0';
                r_state      <= S_MONITORING;
              else
                ram_addr_reg     <= s_v2_abs_stable;
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

            if i_valid_v_seq = '1' then
              if e2_above_peak = '1' then
                ram_addr_reg     <= s_v2_abs_stable;
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

            if i_valid_v_seq = '1' then
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

  o_v2_abs_stable  <= s_v2_abs_stable;
  o_v2_abs_u12     <= s_v2_abs_u12;

  o_alarm_e1       <= alarm_e1_reg;
  o_alarm_e2       <= alarm_e2_reg;

  o_ram_addr       <= std_logic_vector(ram_addr_reg);
  o_ram_rd_req     <= ram_rd_req_pulse;


end architecture;
