----------------------------------------------------------------------------------
-- Bloco      : Prot51_51N_Time
-- Descrição  : Proteção temporizada (ANSI 51 / 51N) com curva via LUT (RAM).
--              - Entrada RMS (12b) e "valid" esparso (>~1000 ciclos).
--              - Dispara (o_trip_51_51N='1') quando o tempo medido (ms) atingir
--                o valor lido na RAM (LUT) para o RMS corrente.
--              - Possui histerese configurável para evitar chaveamento próximo do limiar.
--              - Saída de debug o_time_ms (contador de ms).
--
-- Estados    : IDLE -> MONITORING -> TIME_WAIT_RD -> TIME_ACTIVE -> TRIPPED
--              * Subestado TIME_WAIT_RD alinha a latência da RAM (s_ram_data_valid).
--
-- Autor      : Prof. André dos Anjos - UFU Campus Patos de Minas
-- Revisão    : 24/08/2025
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Prot51_51N_Time is
  generic (
    -- Frequência de clock do sistema (Hz). Por padrão, 100 MHz.
    G_CLK_HZ    : natural := 100_000_000;
    -- Histerese em "contagens RMS" para evitar chatter (i_peakup - G_HYST).
    -- Ex.: se G_HYST=10, sai do temporizado quando RMS <= (peakup-10).
    G_HYST      : natural := 0;
    -- Larguras da LUT (RAM) usadas para a curva temporizada.
    G_ADDR_BITS : natural := 11; -- 2^11 = 2048 endereços (RMS 0..2047)
    G_DATA_BITS : natural := 20  -- tempo em ms, até ~1.048.575 ms
  );
  port (
    --------------------------
    -- Clock / Reset / Start
    --------------------------
    i_clk_100MHz       : in  std_logic; -- usar 100 MHz (ou outro; ajuste G_CLK_HZ)
    i_rst              : in  std_logic; -- reset síncrono (nível alto)
    i_start_51_51N     : in  std_logic; -- pulso/nível para armar e iniciar monitoramento

    --------------------------
    -- Medida RMS e limiar
    --------------------------
    i_rms_51_51N       : in  std_logic_vector(11 downto 0); -- RMS 12b (0..*), usado addr[10:0]
    i_rms_51_51N_valid : in  std_logic; -- '1' quando RMS atual é válido (amostras espaçadas)
    i_peakup           : in  std_logic_vector(11 downto 0); -- limiar de atuação (contagens RMS)

    --------------------------
    -- Interface RAM (LUT curva 51/51N)
    --------------------------
    o_ram_addr         : out std_logic_vector(G_ADDR_BITS-1 downto 0); -- endereço (RMS mapeado)
    o_ram_rd_req       : out std_logic;                                 -- pulso de leitura (1 ciclo)
    i_ram_data         : in  std_logic_vector(G_DATA_BITS-1 downto 0);  -- tempo-alvo em ms

    --------------------------
    -- Saídas de proteção / debug
    --------------------------
    o_time_ms          : out std_logic_vector(G_DATA_BITS-1 downto 0);  -- contador de ms (satura)
    o_start_trip_time  : out std_logic;                                  -- pulso 1 ciclo ao iniciar temporização
    o_trip_51_51N      : out std_logic                                   -- proteção disparada (latched)
  );
end entity;

architecture rtl of Prot51_51N_Time is

  --------------------------------------------------------------------
  -- Constantes internas
  --------------------------------------------------------------------
  constant C_MS_TICKS : natural := G_CLK_HZ / 1000; -- nº de ciclos por 1 ms (100_000 para 100 MHz)

  --------------------------------------------------------------------
  -- Tipos e estados
  --------------------------------------------------------------------
  type t_state is (S_IDLE, S_MONITORING, S_TIME_WAIT_RD, S_TIME_ACTIVE, S_TRIPPED);

  --------------------------------------------------------------------
  -- Sinais internos
  --------------------------------------------------------------------
  signal state, state_nxt               : t_state;

  -- start edge detect
  signal start_d, start_pulse           : std_logic;

  -- comparações e limiares
  signal rms_u12                        : unsigned(11 downto 0);
  signal peak_u12                       : unsigned(11 downto 0);
  signal hyst_u12                       : unsigned(11 downto 0);
  signal low_thr_u12                    : unsigned(11 downto 0);  -- (peak - G_HYST) saturado em 0
  signal above_peak, below_low          : std_logic;

  -- divisor de 1 ms
  signal ms_div_cnt                     : natural range 0 to C_MS_TICKS-1 := 0;
  signal ms_tick                        : std_logic := '0';

  -- contador de tempo em ms (saturado)
  signal time_ms_reg                    : unsigned(G_DATA_BITS-1 downto 0) := (others => '0');
  signal time_cnt_en                    : std_logic := '0';

  -- tempo alvo em ms (lido da RAM)
  signal target_ms_reg                  : unsigned(G_DATA_BITS-1 downto 0) := (others => '0');

  -- interface RAM
  signal ram_addr_reg                   : unsigned(G_ADDR_BITS-1 downto 0) := (others => '0');
  signal ram_rd_req_pulse               : std_logic := '0';
  signal s_rd_req_d               		: std_logic := '0';
  signal s_ram_data_valid               : std_logic := '0';
  


  -- saída de início de temporização (pulso)
  signal start_trip_pulse_reg           : std_logic := '0';

  -- trip latched
  signal trip_reg                       : std_logic := '0';

  -- utilitários
  function sat11_from_u12(x : unsigned(11 downto 0)) return unsigned is
    -- Mapeia 12 bits -> 11 bits de endereço [0..2047] com saturação.
    variable y : unsigned(10 downto 0);
  begin
    if x(11) = '1' then
      y := (others => '1'); -- >= 2048 -> 2047
    else
      y := x(10 downto 0);
    end if;
    return resize(y, G_ADDR_BITS);
  end function;

begin
  -----------------------------------------------------------------------------
  -- Conversões e limiares (combinacionais)
  -----------------------------------------------------------------------------
  rms_u12   <= unsigned(i_rms_51_51N);
  peak_u12  <= unsigned(i_peakup);
  hyst_u12  <= to_unsigned(G_HYST, 12);

  -- low_thr = max(0, peak - G_HYST)
  low_thr_u12 <= (others => '0') when (peak_u12 <= hyst_u12) else (peak_u12 - hyst_u12);

  -- Comparações são avaliadas quando i_rms_51_51N_valid='1' (usadas na FSM)
  above_peak <= '1' when (rms_u12 >  peak_u12) else '0';
  below_low  <= '1' when (rms_u12 <= low_thr_u12) else '0';

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
  -- Detecção de borda em i_start_51_51N
  -----------------------------------------------------------------------------
  p_start_edge : process(i_clk_100MHz)
  begin
    if rising_edge(i_clk_100MHz) then
      if i_rst = '1' then
        start_d     <= '0';
        start_pulse <= '0';
      else
        start_pulse <= '0';
        if (start_d = '0') and (i_start_51_51N = '1') then
          start_pulse <= '1';
        end if;
        start_d <= i_start_51_51N;
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
        state               <= S_IDLE;
        trip_reg            <= '0';
        target_ms_reg       <= (others => '0');
        ram_addr_reg        <= (others => '0');
        ram_rd_req_pulse    <= '0';
		s_rd_req_d      	<= '0';
		s_ram_data_valid    <= '0';		
        start_trip_pulse_reg<= '0';
        time_cnt_en         <= '0';
      else
        state <= state_nxt;

        -- defaults a cada ciclo
        ram_rd_req_pulse     <= '0';
        start_trip_pulse_reg <= '0';
		
		-- Geração do valid interno da RAM
		s_rd_req_d       <= ram_rd_req_pulse;
		s_ram_data_valid <= s_rd_req_d;      

        -- ações por estado
        case state is
          when S_IDLE =>
            trip_reg    <= '0';
            time_cnt_en <= '0';

          when S_MONITORING =>
            time_cnt_en <= '0';
            -- Verifica apenas nos pulsos válidos de RMS
            if i_rms_51_51N_valid = '1' then
              if above_peak = '1' then
                -- Endereço = RMS mapeado com saturação (11b)
                ram_addr_reg     <= sat11_from_u12(rms_u12);
                ram_rd_req_pulse <= '1';           -- requisita leitura da LUT
                time_cnt_en      <= '1';           -- inicia contagem de ms já neste estado
                start_trip_pulse_reg <= '1';       -- pulso de início de temporização
              end if;
            end if;

          when S_TIME_WAIT_RD =>
            time_cnt_en <= '1'; -- contador ativo enquanto aguardamos o dado da RAM
            -- Se chegou dado válido da RAM, travar alvo
            if s_ram_data_valid = '1' then
              target_ms_reg <= unsigned(i_ram_data);
            end if;

            -- Atualizações assíncronas por novos RMS válidos:
            if i_rms_51_51N_valid = '1' then
              if below_low = '1' then
                -- aborta temporização e retorna ao monitoramento
                time_cnt_en <= '0';
              else
                -- pode atualizar o endereço (mantém LUT "on-the-fly")
                ram_addr_reg     <= sat11_from_u12(rms_u12);
                ram_rd_req_pulse <= '1';
              end if;
            end if;

          when S_TIME_ACTIVE =>
            time_cnt_en <= '1';
            -- Leitura contínua da LUT em cada novo RMS válido (mantém curva atualizada)
            if i_rms_51_51N_valid = '1' then
              if below_low = '1' then
                time_cnt_en <= '0'; -- será efetivado na próxima transição
              else
                ram_addr_reg     <= sat11_from_u12(rms_u12);
                ram_rd_req_pulse <= '1';
              end if;
            end if;

            -- Quando um novo valor chegar, atualiza o alvo (sem pausar a temporização)
            if s_ram_data_valid = '1' then
              target_ms_reg <= unsigned(i_ram_data);
            end if;

            -- Disparo quando time_ms >= target_ms
            if time_ms_reg >= target_ms_reg and target_ms_reg /= 0 then
              trip_reg <= '1';
            end if;

          when S_TRIPPED =>
            time_cnt_en <= '0';
            -- trip_reg fica latched até reset ou novo start
			
			-- Antes ficava latched, mas acho melhor abaixar se cair do bellow low e a proteção de 86 mantentém ativado caso configurada
			if i_rms_51_51N_valid = '1' then
				if below_low = '1' then
					time_cnt_en <= '0'; -- será efetivado na próxima transição
					trip_reg    <= '0';
				end if;
            end if;
			
	
            null;

          when others =>
            null;
        end case;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Próximo estado (combinacional)
  -----------------------------------------------------------------------------
  p_fsm_comb : process(state, i_start_51_51N, start_pulse, i_rms_51_51N_valid,
                       above_peak, below_low, s_ram_data_valid, trip_reg)
  begin
    state_nxt <= state;

    case state is
      when S_IDLE =>
        if (i_start_51_51N = '1') or (start_pulse = '1') then
          state_nxt <= S_MONITORING;
        end if;

      when S_MONITORING =>
        if (i_rms_51_51N_valid = '1') and (above_peak = '1') then
          state_nxt <= S_TIME_WAIT_RD;
        end if;

      when S_TIME_WAIT_RD =>
        if (i_rms_51_51N_valid = '1') and (below_low = '1') then
          state_nxt <= S_MONITORING;
        elsif (s_ram_data_valid = '1') then
          state_nxt <= S_TIME_ACTIVE;
        end if;

      when S_TIME_ACTIVE =>
        if trip_reg = '1' then
          state_nxt <= S_TRIPPED;
        elsif (i_rms_51_51N_valid = '1') and (below_low = '1') then
          state_nxt <= S_MONITORING;
        else
          -- permanece temporizando enquanto acima do limiar inferior
          state_nxt <= S_TIME_ACTIVE;
        end if;

      when S_TRIPPED =>
        -- libera com reset ou novo start
        if start_pulse = '1' then
          state_nxt <= S_MONITORING;
        end if;
		
		-- Antes deixava em latched, mas agora se cair do bellow low ele vai para monitoring, vou deixar para a funcaoa 86 segurar caso trip caso configurada.
		if (i_rms_51_51N_valid = '1') and (below_low = '1') then
			state_nxt <= S_MONITORING;
		end if;

      when others =>
        state_nxt <= S_IDLE;
    end case;
  end process;

  -----------------------------------------------------------------------------
  -- Saídas
  -----------------------------------------------------------------------------
  o_trip_51_51N     <= trip_reg;
  o_time_ms         <= std_logic_vector(time_ms_reg);
  o_start_trip_time <= start_trip_pulse_reg;

  o_ram_addr        <= std_logic_vector(ram_addr_reg);
  o_ram_rd_req      <= ram_rd_req_pulse;

end architecture;
