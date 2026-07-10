----------------------------------------------------------------------------------
-- Bloco      : ProtPhaseUmbalanceNegSeq_46_51Q
-- Descrição  : 
-- Estados    : IDLE -> MONITORING -> TIME_WAIT_RD -> TIME_ACTIVE -> TRIPPED
--              * Subestado TIME_WAIT_RD alinha a latência da RAM (s_ram_data_valid).
--
-- Autor      : Arthur Biliato Javaroni - UFU Santa Mônica                
-- Revisão    : 02/07/2026
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ProtPhaseUmbalanceNegSeq_46_51Q is
  generic (
    -- Frequência de clock do sistema (Hz). Por padrão, 100 MHz.
    G_CLK_HZ    : natural := 100_000_000;
    -- Histerese em "contagens RMS" para evitar chatter (i_peakup - G_HYST).
    -- Ex.: se G_HYST=10, sai do temporizado quando RMS <= (peakup-10)
    G_HYST      : natural := 5;
    G_TIME_WIDTH       : natural := 20;
    -- Larguras da LUT (RAM) usadas para a curva temporizada.
    G_ADDR_BITS : natural := 12; -- 2^12 = 4096 endereços (RMS 0..4095)
    G_DATA_BITS : natural := 20  -- tempo em ms, até ~1.048.575 ms
  );
  port (
    --------------------------
    -- Clock / Reset / Start
    --------------------------
    i_clk_100MHz       : in  std_logic; -- usar 100 MHz (ou outro; ajuste G_CLK_HZ)
    i_rst              : in  std_logic; -- reset síncrono (nível alto)
    i_start            : in  std_logic; -- pulso/nível para armar e iniciar monitoramento

    --------------------------
    -- Medida seqNeg e limiar
    --------------------------
    i_seq2_abs          : in  unsigned(31 downto 0); -- RMS 12b (0..*), usado addr[10:0]
    i_seq2_valid        : in  std_logic; -- '1' quando RMS atual é válido (amostras espaçadas)
    i_seq2_pickup_e1    : in  std_logic_vector(11 downto 0); -- limiar de atuação (contagens RMS)
    i_seq2_pickup_e2    : in  std_logic_vector(11 downto 0); -- limiar de atuação (contagens RMS)
    i_delay_e1_ms       : in unsigned(G_TIME_WIDTH-1 downto 0);

    --------------------------
    -- Interface RAM (LUT)
    --------------------------
    o_ram_addr         : out std_logic_vector(G_ADDR_BITS-1 downto 0);  -- endereço (RMS mapeado)
    o_ram_rd_req       : out std_logic;                                 -- pulso de leitura (1 ciclo)
    i_ram_data         : in  std_logic_vector(G_DATA_BITS-1 downto 0);  -- tempo-alvo em ms

    --------------------------
    -- Saídas de proteção / debug
    --------------------------
    o_seq_abs_stable   : out unsigned(11 downto 0);
    o_seq_abs_u12      : out UNSIGNED(11 downto 0);
    o_time_ms          : out std_logic_vector(G_DATA_BITS-1 downto 0);  -- contador de ms (satura)
    o_target_ms_reg    : out unsigned(G_DATA_BITS-1 downto 0);  -- contador de ms (satura)
    o_e1_time_cnt      : out STD_LOGIC_VECTOR(G_TIME_WIDTH-1 downto 0);
    o_alarm_e1         : out std_logic;
    o_alarm_e2         : out std_logic;                        
    o_trip_46_e1       : out std_logic;
    o_trip_46_e2       : out std_logic;
    o_trip_46          : out std_logic                                   
  );
end entity;


architecture rtl of ProtPhaseUmbalanceNegSeq_46_51Q is

  --------------------------------------------------------------------
  -- Constantes internas
  --------------------------------------------------------------------
  constant C_MS_TICKS : natural := G_CLK_HZ / 1000; -- nº de ciclos por 1 ms (100_000 para 100 MHz)

  --------------------------------------------------------------------
  -- Tipos e estados
  --------------------------------------------------------------------
  type t_state is (S_IDLE, S_MONITORING,S_E1_TIMING, S_TIME_WAIT_RD, S_TIME_ACTIVE, S_E2_TRIPPED, S_E1_TRIPPED);

  --------------------------------------------------------------------
  -- Sinais internos
  --------------------------------------------------------------------
  signal state, state_nxt               : t_state;

  -- start edge detect
  signal start_d, start_pulse           : std_logic;

  -- comparações e limiares
  signal seq_abs_u12                    : unsigned(11 downto 0);
  signal seq_abs_mult                   : unsigned(35 downto 0);
  signal seq_abs_reg                    : unsigned(31 downto 0);
  signal peak_e1_u12                    : unsigned(11 downto 0);
  signal peak_e2_u12                    : unsigned(11 downto 0);
  signal hyst_u12                       : unsigned(11 downto 0);
 

  signal low_thr_e1_u12                 : unsigned(11 downto 0);  -- (peak - G_HYST) saturado em 0
  signal low_thr_e2_u12                 : unsigned(11 downto 0);

  signal e1_above_peak, e1_below_low    : std_logic;
  signal e2_above_peak, e2_below_low    : std_logic;

  -- divisor de 1 ms
  signal ms_div_cnt                     : natural range 0 to C_MS_TICKS-1 := 0;
  signal ms_tick                        : std_logic := '0';
  

  -- contador de tempo em ms (saturado)
  signal time_ms_reg          : unsigned(G_DATA_BITS-1 downto 0) := (others => '0');
  signal time_cnt_en       : std_logic := '0';
  signal e1_ms_cnt            : unsigned(G_TIME_WIDTH-1 downto 0) := (others => '0');
  


  -- signal time_ms_e2_reg                    : unsigned(G_DATA_BITS-1 downto 0) := (others => '0');
  -- signal time_cnt_e2_en                    : std_logic := '0';

  -- tempo alvo em ms (lido da RAM)
  signal target_ms_reg                  : unsigned(G_DATA_BITS-1 downto 0) := (others => '0');

  -- interface RAM
  signal ram_addr_reg                   : unsigned(G_ADDR_BITS-1 downto 0) := (others => '0');
  signal ram_rd_req_pulse               : std_logic := '0';
  signal s_rd_req_d               		  : std_logic := '0';
  signal s_ram_data_valid               : std_logic := '0';
  
  -- saída de início de temporização (pulso)
  -- signal start_trip_e1_pulse_reg              : std_logic := '0';
  -- signal start_trip_e2_pulse_reg              : std_logic := '0';

  signal alarm_e1_reg                      : std_logic := '0';
  signal alarm_e2_reg                      : std_logic := '0';

  -- trip latched
  signal trip_e1_reg                       : std_logic := '0';
  signal trip_e2_reg                       : std_logic := '0';

  signal seq_abs_stable : unsigned(11 downto 0) := (others => '0');

  -- utilitários
  -- function sat11_from_u12(x : unsigned(11 downto 0)) return unsigned is
  --   -- Mapeia 12 bits -> 11 bits de endereço [0..2047] com saturação.
  --   variable y : unsigned(10 downto 0);
  -- begin
  --   if x(11) = '1' then
  --     y := (others => '1'); -- >= 2048 -> 2047
  --   else
  --     y := x(10 downto 0);
  --   end if;
  --   return resize(y, G_ADDR_BITS);
  -- end function;

begin
  -----------------------------------------------------------------------------
  -- Conversões e limiares (combinacionais)
  -----------------------------------------------------------------------------
  seq_abs_mult  <= i_seq2_abs * to_unsigned(10, 4);
  seq_abs_reg   <= RESIZE(SHIFT_RIGHT(seq_abs_mult, 19),32);
  seq_abs_u12   <= RESIZE(seq_abs_reg, seq_abs_u12'length);
  peak_e1_u12   <= unsigned(i_seq2_pickup_e1);
  peak_e2_u12   <= unsigned(i_seq2_pickup_e2);
  hyst_u12      <= to_unsigned(G_HYST, 12);

  -- low_thr = max(0, peak - G_HYST)
  low_thr_e1_u12 <= (others => '0') when (peak_e1_u12 <= hyst_u12) else (peak_e1_u12 - hyst_u12);
  low_thr_e2_u12 <= (others => '0') when (peak_e2_u12 <= hyst_u12) else (peak_e2_u12 - hyst_u12);

  -- Comparações são avaliadas quando valid='1' (usadas na FSM)
  e1_above_peak <= '1' when (seq_abs_u12 >  peak_e1_u12) else '0';
  e1_below_low  <= '1' when (seq_abs_u12 <= low_thr_e1_u12) else '0';

  e2_above_peak <= '1' when (seq_abs_u12 >  peak_e2_u12) else '0';
  e2_below_low  <= '1' when (seq_abs_u12 <= low_thr_e2_u12) else '0';

  -----------------------------------------------------------------------------
  -- Filtor Delta com hyterese
  -----------------------------------------------------------------------------
  p_filtro_delta : process (i_clk_100MHz)
    variable diff : unsigned(11 downto 0);
  begin
    if rising_edge(i_clk_100MHz) then
      if i_rst = '1' then
        diff := (others => '0');
        seq_abs_stable <= (others => '0');
      else
        if seq_abs_u12 > seq_abs_stable then
          diff := seq_abs_u12 - seq_abs_stable;
        else
          diff := seq_abs_stable - seq_abs_u12;
        end if;

        if diff > hyst_u12 then
          seq_abs_stable <= seq_abs_u12;
        end if;
      end if;
    end if;
  end process;


  -----------------------------------------------------------------------------
  -- Divisor de 1 ms (gera ms_tick = '1' por 1 ciclo a cada 1 ms)
  -----------------------------------------------------------------------------
  p_ms_div : process(i_clk_100MHz)
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
  -- Contador de ms (habilitado nos estados de temporização; saturado)
  -----------------------------------------------------------------------------
  p_time_cnt : process(i_clk_100MHz)
  begin
    if rising_edge(i_clk_100MHz) then
      if i_rst = '1' then
        time_ms_reg <= (others => '0');
      else
        if time_cnt_en = '0' then
          time_ms_reg <= (others => '0');
        else
          if ms_tick = '1' then
            if time_ms_reg /= (time_ms_reg'range => '1') then
              time_ms_reg <= time_ms_reg + 1;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Detecção de borda em i_start
  -----------------------------------------------------------------------------
  p_start_edge : process(i_clk_100MHz)
  begin
    if rising_edge(i_clk_100MHz) then
      if i_rst = '1' then
        start_d     <= '0';
        start_pulse <= '0';
      else
        start_pulse <= '0';
        if (start_d = '0') and (i_start = '1') then
          start_pulse <= '1';
        end if;
        start_d <= i_start;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- FSM: estados / controles
  -----------------------------------------------------------------------------
  p_fsm_seq : process(i_clk_100MHz)
  begin
    if rising_edge(i_clk_100MHz) then
      if i_rst = '1' then
        state                <= S_IDLE;
        trip_e1_reg          <= '0';
        trip_e2_reg          <= '0';
        target_ms_reg        <= (others => '0');
        ram_addr_reg         <= (others => '0');
        e1_ms_cnt            <= (others => '0');
        ram_rd_req_pulse     <= '0';
		    s_rd_req_d      	   <= '0';
		    s_ram_data_valid     <= '0';		
        alarm_e1_reg         <= '0'; 
        alarm_e2_reg         <= '0';
        time_cnt_en          <= '0';
      else
        state <= state_nxt;
        -- defaults a cada ciclo
        ram_rd_req_pulse     <= '0';
        -- alarm_e1_reg         <= '0'; 
        -- alarm_e2_reg         <= '0';
		
        -- Geração do valid interno da RAM
        s_rd_req_d       <= ram_rd_req_pulse;
        s_ram_data_valid <= s_rd_req_d;      

        -- ações por estado
        case state is
          when S_IDLE =>
            trip_e1_reg          <= '0';
            trip_e2_reg          <= '0';
            time_cnt_en <= '0';
            e1_ms_cnt  <= (others => '0');
            alarm_e1_reg         <= '0'; 
            alarm_e2_reg         <= '0';

          when S_MONITORING =>
            time_cnt_en <= '0';
            e1_ms_cnt  <= (others => '0');
            -- Verifica apenas nos pulsos válidos de RMS
            if i_seq2_valid = '1' then
              if e2_above_peak = '1' then
                ram_addr_reg       <= seq_abs_stable;
                ram_rd_req_pulse   <= '1';           -- requisita leitura da LUT
                time_cnt_en     <= '1';           -- inicia contagem de ms já neste estado
                alarm_e2_reg <= '1';
              elsif e1_above_peak = '1' then
                alarm_e1_reg <= '1';
              end if;
            end if;

          when S_E1_TIMING =>
            alarm_e1_reg <= '1';
            alarm_e2_reg <= '0';
            if i_seq2_valid = '1' then
              if e2_above_peak = '1' then
                e1_ms_cnt  <= (others => '0');
                ram_addr_reg       <= seq_abs_stable;
                ram_rd_req_pulse   <= '1';           -- requisita leitura da LUT
                time_cnt_en        <= '1';           -- inicia contagem de ms já neste estado
                alarm_e2_reg <= '1';
                alarm_e1_reg <= '0';
              elsif e1_below_low = '1' then
                alarm_e1_reg <= '0';
                alarm_e2_reg <= '0';
                e1_ms_cnt  <= (others => '0');
              end if;
            end if;
            if ms_tick = '1' then
              if e1_ms_cnt /= (e1_ms_cnt'range => '1') then
                if e1_ms_cnt >= i_delay_e1_ms then
                  trip_e1_reg <= '1'; 
                else
                  e1_ms_cnt <= e1_ms_cnt + 1;
                end if;
              end if;
            end if;

          when S_TIME_WAIT_RD =>
            time_cnt_en <= '1'; -- contador ativo enquanto aguardamos o dado da RAM
            -- Se chegou dado válido da RAM, travar alvo
            if s_ram_data_valid = '1' then
              target_ms_reg <= unsigned(i_ram_data);
            end if;
            -- Atualizações assíncronas por novos RMS válidos:
            if i_seq2_valid = '1' then
              if e2_below_low = '1' then
                -- aborta temporização e retorna ao monitoramento
                time_cnt_en <= '0';
              else
                -- pode atualizar o endereço (mantém LUT "on-the-fly")
                ram_addr_reg     <= seq_abs_stable;
                ram_rd_req_pulse <= '1';
              end if;
            end if;

          when S_TIME_ACTIVE =>
            time_cnt_en <= '1';
            -- Leitura contínua da LUT em cada novo RMS válido (mantém curva atualizada)
            if i_seq2_valid = '1' then 
              if e2_below_low = '1' then
                time_cnt_en <= '0'; -- será efetivado na próxima transição
              else
                ram_addr_reg     <= seq_abs_stable;--seq_abs_th;
                ram_rd_req_pulse <= '1';
              end if;
            end if;

            -- Quando um novo valor chegar, atualiza o alvo (sem pausar a temporização)
            if s_ram_data_valid = '1' then
              target_ms_reg <= unsigned(i_ram_data);
            end if;

            -- Disparo quando time_ms >= target_ms
            if time_ms_reg >= target_ms_reg and target_ms_reg /= 0 then
              trip_e2_reg <= '1';
            end if;

          when S_E1_TRIPPED =>
            alarm_e1_reg <= '1';
            alarm_e2_reg <= '0';
            trip_e1_reg  <= '1';
            trip_e2_reg  <= '0';
            if i_seq2_valid = '1' then
              if e2_above_peak = '1' then
                e1_ms_cnt  <= (others => '0');
                ram_addr_reg       <= seq_abs_stable;
                ram_rd_req_pulse   <= '1';           -- requisita leitura da LUT
                time_cnt_en        <= '1';           -- inicia contagem de ms já neste estado
                alarm_e2_reg <= '1';
              elsif e1_below_low = '1' then
                e1_ms_cnt  <= (others => '0');
                trip_e1_reg    <= '0';
                alarm_e1_reg   <= '0';
              end if;
            end if; 

          when S_E2_TRIPPED =>
            time_cnt_en <= '0';
            -- trip_reg fica latched até reset ou novo start
			
			      -- Antes ficava latched, mas acho melhor abaixar se cair do bellow low e a proteção de 86 mantentém ativado caso configurada
            if i_seq2_valid = '1' then
              if e2_below_low = '1' then
                time_cnt_en <= '0'; -- será efetivado na próxima transição
                trip_e2_reg    <= '0';
              end if;
            end if;
          when others =>
            null;
        end case;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Próximo estado (combinacional)
  -----------------------------------------------------------------------------
  p_fsm_comb : process(state, i_start, start_pulse, i_seq2_valid, s_ram_data_valid,
                       e1_above_peak, e1_below_low, trip_e1_reg,
                       e2_above_peak, e2_below_low, trip_e2_reg)
  begin
    state_nxt <= state;

    case state is
      when S_IDLE =>
        if (i_start = '1') or (start_pulse = '1') then
          state_nxt <= S_MONITORING;
        end if;

      when S_MONITORING =>
        if (i_seq2_valid = '1') and (e2_above_peak = '1') then
          state_nxt <= S_TIME_WAIT_RD;
        elsif (i_seq2_valid = '1') and (e1_above_peak = '1') then
          if i_delay_e1_ms = 0 then
                state_nxt <= S_E1_TRIPPED;
              else
                state_nxt <= S_E1_TIMING;
              end if;
        end if;

      when S_E1_TIMING =>
        if (i_seq2_valid = '1') and (e2_above_peak = '1') then
          state_nxt <= S_TIME_WAIT_RD;
        elsif (i_seq2_valid = '1') and (e1_below_low = '1') then
          state_nxt <= S_MONITORING;
        elsif trip_e1_reg = '1' then
          state_nxt <= S_E1_TRIPPED;
        else
          state_nxt <= S_E1_TIMING;
        end if;
      
      when S_TIME_WAIT_RD =>
        if (i_seq2_valid = '1') and (e2_below_low = '1') then
          state_nxt <= S_MONITORING;
        elsif (s_ram_data_valid = '1') then
          state_nxt <= S_TIME_ACTIVE;
        end if;

      when S_TIME_ACTIVE =>
        if trip_e2_reg = '1' then
          state_nxt <= S_E2_TRIPPED;
        elsif (i_seq2_valid = '1') and (e2_below_low = '1') then
          state_nxt <= S_MONITORING;
        else
          -- permanece temporizando enquanto acima do limiar inferior
          state_nxt <= S_TIME_ACTIVE;
        end if;

      when S_E1_TRIPPED =>
        if start_pulse = '1' then
          state_nxt <= S_MONITORING;
        end if;
        if (i_seq2_valid = '1') and (e2_above_peak = '1') then
          state_nxt <= S_TIME_WAIT_RD;
        end if;
        if (i_seq2_valid = '1') and (e1_below_low = '1') then
          state_nxt <= S_MONITORING;
        end if;

      when S_E2_TRIPPED =>
        -- libera com reset ou novo start
        if start_pulse = '1' then
          state_nxt <= S_MONITORING;
        end if;
		
        -- Antes deixava em latched, mas agora se cair do bellow low ele vai para monitoring, vou deixar para a funcaoa 86 segurar caso trip caso configurada.
        if (i_seq2_valid = '1') and (e2_below_low = '1') then
          state_nxt <= S_MONITORING;
        end if;

      when others =>
        state_nxt <= S_IDLE;
    end case;
  end process;

  -----------------------------------------------------------------------------
  -- Saídas
  -----------------------------------------------------------------------------
  o_trip_46          <= trip_e1_reg or trip_e2_reg;
  o_trip_46_e1       <= trip_e1_reg;
  o_trip_46_e2       <= trip_e2_reg;
  o_time_ms         <= std_logic_vector(time_ms_reg);
  o_target_ms_reg   <=   target_ms_reg;
  o_e1_time_cnt     <= std_logic_vector(e1_ms_cnt);
  o_seq_abs_u12     <= seq_abs_u12;
  o_seq_abs_stable  <= seq_abs_stable;
  
  o_alarm_e1 <= alarm_e1_reg;          
  o_alarm_e2 <= alarm_e2_reg;         

  o_ram_addr        <= std_logic_vector(ram_addr_reg);
  o_ram_rd_req      <= ram_rd_req_pulse;

end architecture;
