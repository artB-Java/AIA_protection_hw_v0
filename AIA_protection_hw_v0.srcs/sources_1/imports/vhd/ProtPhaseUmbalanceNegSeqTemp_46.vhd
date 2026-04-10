-- =====================================================================
-- Bloco      : ProtPhaseUmbalanceNegSeqTemp_46
-- Função     : ANSI 46-2.
--                * IDLE:
--                    - primeiro i_valid -> Monitoring
--                    - consverção dos parametros de entrada para um registrador unsgined
--                * CALC_PARAM:
--                   - calculo das variaveis de corrente de treshold(r_ith)
--                   - calculo da Histerese
--                   - calculo de In^2
--                * CALC_ACC:
--                   - calculo do limite do acumulador (I2^2)divido em 2 partes para melhor eficiencia            
--                * MONITORING:
--                    - se sample >= pickup e delay == 0  -> TRIPPED (o_trip='1')
--                    - se sample >= pickup e delay > 0   -> ACTIVATED_TIMER (zera time_ms)
--                * ACTIVATED_TIMER:
--                    - se sample < pickup - HYST         -> MONITORING (desarma timer)
--                    - se sample >= pickup e time_ms >= delay -> TRIPPED (o_trip='1')
--                * TRIPPED: sai quando o valor da amostra sai da condicao de trip
--              - FSM e ações em um único processo.
--              - Contadores (tick 1ms e r_time_ms) em OUTRO processo.
--              - Contador funciona adicionado um valor calculado em base na sample até atingir o limite definido pelos parametros de config, o que causa um trip
--              - Contadores só contam em S_ACTIVATED_TIMER.
-- Autor      : Arthur B. Javaroni
--                * Com base no "ProtectInstant_50_50N.vhd" do Prof. André Antônio dos Anjos. 
-- Data		  : rev 26/02/2026
-- =====================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ProtPhaseUmbalanceNegSeqTemp_46 is
  generic (
    G_MS_TICKS      : natural := 100_000; -- ciclos de i_clk por 1 ms (100MHz -> 100_000)
    G_HYST_U12      : natural := 0;        -- histerese (0..4095) na mesma unidade de i_peakup_u12
    G_IN_WIDTH      : integer := 12;
    G_IPICKUP_WIDTH : integer := 12;
    G_I2_WIDTH      : integer := 32;
    G_K_WIDTH       : integer := 16;
    G_ACC_WIDTH     : integer := 80
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
    i_seq2_abs          : in  std_logic_vector(G_I2_WIDTH-1 downto 0); -- unsigned (0..4095(2047))
    i_valid             : in  std_logic;                     -- pulso de amostra válida
    i_peakup_u12        : in  std_logic_vector(G_IPICKUP_WIDTH-1 downto 0); -- unsigned (0..4095)
    --i_intentional_delay : in  std_logic_vector(19 downto 0); -- atraso intencional [ms]
    i_in                : in std_logic_vector(G_IN_WIDTH-1 downto 0);
    i_k_const           : in std_logic_vector(G_K_WIDTH-1 downto 0);
    
    --------------------------
    -- Saída
    --------------------------
    o_trip              : out std_logic
  );
end entity;

architecture rtl of ProtPhaseUmbalanceNegSeqTemp_46 is
 -- threshold
 signal r_ith   : unsigned(G_I2_WIDTH-1 downto 0) := (others => '0');
 signal r_in_sq : unsigned((G_I2_WIDTH*2)-1 downto 0) := (others => '0');
 signal r_acc_limit : unsigned(G_ACC_WIDTH-1 downto 0) := (others => '0');
 signal r_acc_count : unsigned(G_ACC_WIDTH-1 downto 0) := (others => '0');
  
  -- Estados
  type t_state is (S_IDLE, S_CALC_PARAM, S_CALC_ACC_LIMIT_1, S_CALC_ACC_LIMIT_2, S_MONITORING, S_ACTIVATED_TIMER, S_TRIPPED);
  signal r_state      : t_state := S_IDLE;

  -- Saídas/flags
  signal r_trip       : std_logic := '0';
  signal r_timer_en   : std_logic := '0'; -- habilita tick + contador (somente em S_ACTIVATED_TIMER)

  -- Tick de 1ms e contador ms (processo separado)
  signal r_ms_div     : natural range 0 to G_MS_TICKS-1 := 0;

  -- Limiar de retorno por histerese: max(0, pickup - G_HYST_U12)
  signal r_ith_hyst_low : unsigned(G_I2_WIDTH-1 downto 0) := (others => '0');
  
  signal r_pickup_u12   : unsigned(G_IPICKUP_WIDTH-1 downto 0) := (others => '0');
  signal r_inom     : unsigned(G_IN_WIDTH-1 downto 0) := (others => '0');
  
  signal r_i2_abs_sq : unsigned((G_I2_WIDTH*2)-1 downto 0) := (others => '0');
  signal r_sum_req   : std_logic := '0';

begin
  
  --------------------------------------------------------------------
  -- PROCESSO 1: FSM + atuações 
  --------------------------------------------------------------------
  process(i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        r_state     <= S_IDLE;
        r_trip      <= '0';
        r_timer_en  <= '0';
        r_ith       <= (others => '0');
        r_in_sq     <= (others => '0');
        r_acc_limit <= (others => '0');
        r_pickup_u12 <= (others => '0');
        r_inom <= (others => '0');
      else
        case r_state is
          when S_IDLE =>
            r_trip     <= '0';
            r_timer_en <= '0';
            r_pickup_u12 <= unsigned(i_peakup_u12);
            r_inom       <= unsigned(i_in);
            r_state    <= S_CALC_PARAM;
          when S_CALC_PARAM =>
            -- calculo do threshold antes de começar o monitoramento
            r_ith <= resize(r_inom * r_pickup_u12, G_I2_WIDTH);
            -- Novo calculo Histerese
            if to_integer(r_pickup_u12) > G_HYST_U12 then
              r_ith_hyst_low <= resize(r_inom * (r_pickup_u12 - to_unsigned(G_HYST_U12, G_IPICKUP_WIDTH)), G_I2_WIDTH);
            else
              r_ith_hyst_low <= (others => '0');
            end if;
            -- calculo de In^2
            r_in_sq <= resize(r_inom * r_inom, 64);   
            r_state <= S_CALC_ACC_LIMIT_1;
          when S_CALC_ACC_LIMIT_1 =>
            -- calculo do limite com base nos parametros
            r_acc_limit <= resize(r_in_sq * unsigned(i_k_const), G_ACC_WIDTH);
            r_state <= S_CALC_ACC_LIMIT_2;
          when S_CALC_ACC_LIMIT_2 =>
            -- multiplicação pelo tempo com base no tick(ocorre a cada 1ms -> esse valor pode mudar devido ao CLK(100MHz))
            r_acc_limit <= resize(r_acc_limit * to_unsigned(1000, 10), G_ACC_WIDTH);
            r_state <= S_MONITORING;
          when S_MONITORING =>
            r_trip     <= '0';
            r_timer_en <= '0';  -- contadores parados neste estado
            if i_valid = '1' then
              if unsigned(i_seq2_abs) >= r_ith then
                  -- Com atraso: habilita temporização
                  r_timer_en <= '1';
                  r_state    <= S_ACTIVATED_TIMER;
              end if;
            end if;
          when S_ACTIVATED_TIMER =>
            r_timer_en <= '1'; -- habilita tick + contador ms somente neste estado
            -- Se cair abaixo do (pickup - histerese), cancela o timer e volta
            if i_valid = '1' then
              if unsigned(i_seq2_abs) <= r_ith_hyst_low then
                r_timer_en <= '0';
                r_state    <= S_MONITORING;
              end if;
            end if;
            -- Disparo quando acumulador encher
              if (r_acc_count >= r_acc_limit) then
                r_trip     <= '1';
                r_timer_en <= '0';
                r_state    <= S_TRIPPED;
              end if;
          when S_TRIPPED =>
            r_trip     <= '1';  -- travado até reset
            r_timer_en <= '0';
            r_state    <= S_TRIPPED;
			-- Se cair abaixo do (pickup - histerese), cancela o timer e volta
            if i_valid = '1' then
              if unsigned(i_seq2_abs) <= r_ith_hyst_low then
                r_timer_en <= '0';
                r_state    <= S_MONITORING;
				r_trip     <= '0'; 
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;
  
 -- envia registro do processo anterior para saída
 o_trip <= r_trip;

  --------------------------------------------------------------------
  -- PROCESSO do DFT do S Iabs^2 dt = K*In^2*dt
  --   * Só contam quando r_timer_en='1'
  --   * Desabilitados: ficam zerados e sem tick
  --------------------------------------------------------------------
  
  process(i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        r_ms_div  <= 0;
        r_acc_count <= (others => '0');
        r_i2_abs_sq <= (others => '0');
        r_sum_req <= '0';
      else
        if r_timer_en = '1' then
          -- Divisor de 1 ms + incremento do contador de ms
          if r_ms_div = G_MS_TICKS - 1 then
            r_ms_div <= 0;
            -- A cada um ms recalcula
            r_i2_abs_sq <= unsigned(i_seq2_abs) * unsigned(i_seq2_abs);
            r_sum_req <= '1';
          else
            r_ms_div <= r_ms_div + 1;
          end if;
          
          if r_sum_req = '1' then
          -- Proteção contra overflow
            if r_acc_count < (r_acc_count'range => '1') - resize(r_i2_abs_sq, G_ACC_WIDTH) then  -- saturação
              r_acc_count <= r_acc_count + resize(r_i2_abs_sq, G_ACC_WIDTH);
            else
                r_acc_count <= (others => '1');
            end if;
            r_sum_req <= '0';
          end if;
          
        else
          -- Timer desabilitado: zera tudo e não gera tick
          -- Talvez decrementar isso aos poucos
          r_ms_div  <= 0;
          r_acc_count <= (others => '0');
          r_sum_req <= '0';
        end if;
      end if;
    end if;
  end process;

end architecture;
