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
-- Autor      : Arthur B. Javaroni
--              Prof. André dos Anjos - UFU Campus Patos de Minas
-- Revisão    : 24/08/2025
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Prot51_51N_ACC is
  generic (
    -- Frequência de clock do sistema (Hz). Por padrão, 100 MHz.
    G_CLK_HZ    : natural := 100_000_000;
    -- Histerese em "contagens RMS" para evitar chatter (i_peakup - G_HYST).
    G_HYST      : natural := 0;
    -- Larguras da LUT (RAM) usadas para a curva temporizada.
    G_ADDR_BITS : natural := 11; -- 2^11 = 2048 endereços (RMS 0..2047)
    G_DATA_BITS : natural := 20  -- Taxa de incremento (velocidade), máximo 20 bits
  );
  port (
    --------------------------
    -- Clock / Reset / Start
    --------------------------
    i_clk_100MHz       : in  std_logic; 
    i_rst              : in  std_logic; 
    i_start_51_51N     : in  std_logic; 

    --------------------------
    -- Medida RMS e limiar
    --------------------------
    i_rms_51_51N       : in  std_logic_vector(11 downto 0); 
    i_rms_51_51N_valid : in  std_logic; 
    i_peakup           : in  std_logic_vector(11 downto 0); 

    --------------------------
    -- Interface RAM (LUT curva 51/51N)
    --------------------------
    o_ram_addr         : out std_logic_vector(G_ADDR_BITS-1 downto 0); 
    o_ram_rd_req       : out std_logic;                                
    i_ram_data         : in  std_logic_vector(G_DATA_BITS-1 downto 0);  

    --------------------------
    -- Saídas de proteção / debug
    --------------------------
    o_time_ms          : out std_logic_vector(G_DATA_BITS-1 downto 0);  
    o_start_trip_time  : out std_logic;                                 
    o_trip_51_51N      : out std_logic                                  
  );
end entity;

architecture rtl of Prot51_51N_ACC is

  --------------------------------------------------------------------
  -- Constantes internas
  --------------------------------------------------------------------
  constant C_MS_TICKS : natural := G_CLK_HZ / 1000; 

  -- Constante de Limite de Disparo (Acumulador a 100%)
  constant C_TRIP_LIMIT : unsigned(31 downto 0) := to_unsigned(1000000, 32);

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
  signal low_thr_u12                    : unsigned(11 downto 0);  
  signal above_peak, below_low          : std_logic;

  -- divisor de 1 ms
  signal ms_div_cnt                     : natural range 0 to C_MS_TICKS-1 := 0;
  signal ms_tick                        : std_logic := '0';

  -- Acumulador de Viagem (True Integration)
  signal r_acc                          : unsigned(31 downto 0) := (others => '0');

  -- contador de tempo em ms (saturado - mantido para debug/HMI)
  signal time_ms_reg                    : unsigned(G_DATA_BITS-1 downto 0) := (others => '0');
  signal time_cnt_en                    : std_logic := '0';

  -- Taxa de incremento instantânea (lida da RAM)
  signal rate_reg                       : unsigned(G_DATA_BITS-1 downto 0) := (others => '0');

  -- interface RAM
  signal ram_addr_reg                   : unsigned(G_ADDR_BITS-1 downto 0) := (others => '0');
  signal ram_rd_req_pulse               : std_logic := '0';
  signal s_rd_req_d                     : std_logic := '0';
  signal s_ram_data_valid               : std_logic := '0';
  
  -- saída de início de temporização (pulso)
  signal start_trip_pulse_reg           : std_logic := '0';

  -- trip latched
  signal trip_reg                       : std_logic := '0';

  -- utilitários
  function sat11_from_u12(x : unsigned(11 downto 0)) return unsigned is
    variable y : unsigned(10 downto 0);
  begin
    if x(11) = '1' then
      y := (others => '1'); 
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

  low_thr_u12 <= (others => '0') when (peak_u12 <= hyst_u12) else (peak_u12 - hyst_u12);

  above_peak <= '1' when (rms_u12 >  peak_u12) else '0';
  below_low  <= '1' when (rms_u12 <= low_thr_u12) else '0';

  -----------------------------------------------------------------------------
  -- Divisor de 1 ms
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
  -- Acumulador de Viagem e Contador de ms (Integrador Real)
  -----------------------------------------------------------------------------
  p_accumulator : process(i_clk_100MHz)
  begin
    if rising_edge(i_clk_100MHz) then
      if i_rst = '1' then
        time_ms_reg <= (others => '0');
        r_acc       <= (others => '0');
      else
        if time_cnt_en = '0' then
          time_ms_reg <= (others => '0');
          r_acc       <= (others => '0'); -- Descarrega o disco se a falta sumir
        else
          if ms_tick = '1' then
            -- MÁGICA DA INTEGRAÇÃO: Soma a taxa instantânea da RAM ao acumulador
            r_acc <= r_acc + rate_reg;

            -- Mantido apenas para fins de monitoramento na interface
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
        rate_reg            <= (others => '0');
        ram_addr_reg        <= (others => '0');
        ram_rd_req_pulse    <= '0';
        s_rd_req_d          <= '0';
        s_ram_data_valid    <= '0';   
        start_trip_pulse_reg<= '0';
        time_cnt_en         <= '0';
      else
        state <= state_nxt;

        ram_rd_req_pulse     <= '0';
        start_trip_pulse_reg <= '0';
    
        s_rd_req_d       <= ram_rd_req_pulse;
        s_ram_data_valid <= s_rd_req_d;      

        case state is
          when S_IDLE =>
            trip_reg    <= '0';
            time_cnt_en <= '0';

          when S_MONITORING =>
            time_cnt_en <= '0';
            if i_rms_51_51N_valid = '1' then
              if above_peak = '1' then
                ram_addr_reg         <= sat11_from_u12(rms_u12);
                ram_rd_req_pulse     <= '1';           
                time_cnt_en          <= '1';           
                start_trip_pulse_reg <= '1';       
              end if;
            end if;

          when S_TIME_WAIT_RD =>
            time_cnt_en <= '1'; 
            -- Grava a velocidade no registrador de taxa
            if s_ram_data_valid = '1' then
              rate_reg <= unsigned(i_ram_data);
            end if;

            if i_rms_51_51N_valid = '1' then
              if below_low = '1' then
                time_cnt_en <= '0';
              else
                ram_addr_reg     <= sat11_from_u12(rms_u12);
                ram_rd_req_pulse <= '1';
              end if;
            end if;

          when S_TIME_ACTIVE =>
            time_cnt_en <= '1';
            
            if i_rms_51_51N_valid = '1' then
              if below_low = '1' then
                time_cnt_en <= '0'; 
              else
                ram_addr_reg     <= sat11_from_u12(rms_u12);
                ram_rd_req_pulse <= '1';
              end if;
            end if;

            -- Atualiza a velocidade dinamicamente com base no RMS instantâneo
            if s_ram_data_valid = '1' then
              rate_reg <= unsigned(i_ram_data);
            end if;

            -- DISPARO: Ocorre quando o acumulador enche (100% da viagem)
            if r_acc >= C_TRIP_LIMIT and rate_reg /= 0 then
              trip_reg <= '1';
            end if;

          when S_TRIPPED =>
            time_cnt_en <= '0';
            
            if i_rms_51_51N_valid = '1' then
              if below_low = '1' then
                time_cnt_en <= '0'; 
                trip_reg    <= '0';
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
          state_nxt <= S_TIME_ACTIVE;
        end if;

      when S_TRIPPED =>
        if start_pulse = '1' then
          state_nxt <= S_MONITORING;
        end if;
    
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
