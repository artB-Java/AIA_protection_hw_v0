----------------------------------------------------------------------------------
-- Bloco      : ProtVoltageUmbalanceNegSeq_47
-- Descricao  : Protecao temporizada ANSI 47 - Desequilibrio de Tensao (VUF).
--
--   FSM estados:
--     * S_IDLE        : aguarda primeiro i_valid_seq
--     * S_DIV_LOAD    : carrega operandos 
--     * S_DIV_ITER    : C_DIV_ITER ciclos de divisao Restoring
--     * S_DIV_DONE    : carrega o resultado e saturacao do VUF (1 ciclo)
--     * S_CHECK_VUF   : roteamento pos-divisao com VUF ja estavel
--     * S_MONITORING  : VUF abaixo do pickup; aguarda proximo valid_seq
--                        -> SEMPRE vai para S_DIV_LOAD no valid_seq
--                           para garantir VUF atualizado antes de qualquer decisao
--     * S_LUT_WAIT_RD : aguarda latencia da BRAM (2 ciclos)
--     * S_TIME_ACTIVE : temporizando: conta ms ate target
--     * S_TRIPPED     : trip ativo: aguarda VUF cair abaixo de pickup-hyst
--
--   Regra fundamental:
--     Toda decisao sobre pickup/histerese e feita SOMENTE em S_CHECK_VUF,
--     com r_vuf garantidamente atualizado. S_MONITORING nao avalia VUF.
--   
--   Autor  : Arthur B. Javaroni
--          * Com base no "ProtectInstant_51_51N.vhd" do Prof. André Antônio dos Anjos. 
--   Data   : 2026
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ProtVoltageUmbalanceNegSeq_47 is
  generic (
    G_CLK_HZ    : natural := 100_000_000; -- Frequencia do clock (Hz)
    G_HYST_VUF  : natural := 5;           -- Histerese em unidades de 0.05% (5 = 0.25%)
    G_ADDR_BITS : natural := 11;          -- Bits de endereco da LUT (2^11=2048, igual ao blk_mem_gen_0)
    G_DATA_BITS : natural := 20           -- Bits de dado da LUT (tempo em ms)
  );
  port (
    -- Clock / Reset
    i_clk        : in  std_logic;
    i_rst        : in  std_logic;  -- Reset sincrono, ativo alto

    -- Entradas das componentes simetricas de tensao (saidas do inst_symcom_retpol)
    i_seq2_abs   : in  std_logic_vector(31 downto 0); -- |V2|, unsigned 32b
    i_seq1_abs   : in  std_logic_vector(31 downto 0); -- |V1|, unsigned 32b
    i_valid_seq  : in  std_logic;                     -- Pulso ~60 Hz

    -- Setpoint configuravel via Core_Regs
    -- Unidade: 1 = 0.05%  ->  Pickup 5.0% = 100 unidades
    i_pickup_vuf : in  std_logic_vector(G_ADDR_BITS-1 downto 0);

    -- Interface RAM - mesmo padrao do Prot51_51N_Time
    o_ram_addr   : out std_logic_vector(G_ADDR_BITS-1 downto 0);
    o_ram_rd_req : out std_logic;
    i_ram_data   : in  std_logic_vector(G_DATA_BITS-1 downto 0);

    -- Saidas
    o_vuf        : out std_logic_vector(G_ADDR_BITS-1 downto 0); -- VUF calculado (debug)
    o_time_ms    : out std_logic_vector(G_DATA_BITS-1 downto 0); -- Contador de ms (debug)
    o_trip       : out std_logic
  );
end entity;

architecture rtl of ProtVoltageUmbalanceNegSeq_47 is

  -- =========================================================================
  -- Constantes
  -- =========================================================================
  constant C_MS_TICKS : natural := G_CLK_HZ / 1000;
  constant C_MUL_BITS : natural := 11;               -- bits para representar 2000 (2^11=2048>2000)
  constant C_DIV_BITS : natural := 32 + C_MUL_BITS; -- largura numerador: 32b+11b = 43b
  constant C_DIV_ITER : natural := C_DIV_BITS;

  -- =========================================================================
  -- FSM
  -- =========================================================================
  type t_state is (
    S_IDLE,
    S_DIV_LOAD,
    S_DIV_ITER,
    S_DIV_DONE,
    S_CHECK_VUF,
    S_MONITORING,
    S_LUT_WAIT_RD,
    S_TIME_ACTIVE,
    S_TRIPPED
  );
  signal r_state : t_state := S_IDLE;

  -- '1' quando divisao foi disparada por TIME_ACTIVE ou TRIPPED (reavaliacao)
  -- '0' quando disparada por MONITORING ou IDLE (primeira avaliacao)
  signal r_was_timing : std_logic := '0';

  -- =========================================================================
  -- Divisao Restoring
  -- =========================================================================
  signal r_div_reg  : unsigned(C_DIV_BITS-1 downto 0) := (others => '0');
  signal r_divisor  : unsigned(C_DIV_BITS-1 downto 0) := (others => '0');
  signal r_partial  : unsigned(C_DIV_BITS   downto 0) := (others => '0');
  signal r_quotient : unsigned(C_DIV_BITS-1 downto 0) := (others => '0');
  signal r_div_cnt  : natural range 0 to C_DIV_ITER   := 0;

  -- =========================================================================
  -- VUF resultado
  -- =========================================================================
  signal r_vuf      : unsigned(G_ADDR_BITS-1 downto 0) := (others => '0');

  -- =========================================================================
  -- Limiares combinacionais (baseados em r_vuf atual)
  -- =========================================================================
  signal s_pickup   : unsigned(G_ADDR_BITS-1 downto 0);
  signal s_hyst_low : unsigned(G_ADDR_BITS-1 downto 0);
  signal s_above    : std_logic; -- r_vuf >  pickup
  signal s_below    : std_logic; -- r_vuf <= hyst_low

  -- =========================================================================
  -- Interface BRAM
  -- =========================================================================
  signal r_ram_addr   : unsigned(G_ADDR_BITS-1 downto 0) := (others => '0');
  signal r_ram_rd_req : std_logic := '0';
  signal r_rd_d1      : std_logic := '0';
  signal r_rd_d2      : std_logic := '0';
  signal s_ram_vld    : std_logic;
  signal r_target_ms  : unsigned(G_DATA_BITS-1 downto 0) := (others => '0');

  -- =========================================================================
  -- Tick de 1 ms
  -- =========================================================================
  signal r_ms_div   : natural range 0 to C_MS_TICKS-1 := 0;
  signal s_ms_tick  : std_logic := '0';

  -- =========================================================================
  -- Contador de ms saturado
  -- =========================================================================
  signal r_time_ms  : unsigned(G_DATA_BITS-1 downto 0) := (others => '0');
  signal r_time_en  : std_logic := '0';

  -- =========================================================================
  -- Trip
  -- =========================================================================
  signal r_trip     : std_logic := '0';

begin

  -- =========================================================================
  -- Limiares combinacionais
  -- =========================================================================
  s_pickup   <= unsigned(i_pickup_vuf);

  s_hyst_low <= (others => '0')
                when (s_pickup <= to_unsigned(G_HYST_VUF, G_ADDR_BITS))
                else (s_pickup - to_unsigned(G_HYST_VUF, G_ADDR_BITS));

  s_above <= '1' when (r_vuf >  s_pickup)   else '0';
  s_below <= '1' when (r_vuf <= s_hyst_low) else '0';

  -- =========================================================================
  -- Tick de 1 ms
  -- =========================================================================
  p_ms_tick : process(i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        r_ms_div  <= 0;
        s_ms_tick <= '0';
      else
        if r_ms_div = C_MS_TICKS - 1 then
          r_ms_div  <= 0;
          s_ms_tick <= '1';
        else
          r_ms_div  <= r_ms_div + 1;
          s_ms_tick <= '0';
        end if;
      end if;
    end if;
  end process;

  -- =========================================================================
  -- Contador de ms saturado
  -- =========================================================================
  p_time_cnt : process(i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        r_time_ms <= (others => '0');
      else
        if r_time_en = '0' then
          r_time_ms <= (others => '0');
        elsif s_ms_tick = '1' then
          if r_time_ms /= (r_time_ms'range => '1') then
            r_time_ms <= r_time_ms + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- =========================================================================
  -- Pipeline valid da BRAM (2 ciclos de latencia)
  -- =========================================================================
  p_ram_vld : process(i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        r_rd_d1 <= '0';
        r_rd_d2 <= '0';
      else
        r_rd_d1 <= r_ram_rd_req;
        r_rd_d2 <= r_rd_d1;
      end if;
    end if;
  end process;
  s_ram_vld <= r_rd_d2;

  -- =========================================================================
  -- FSM principal + Divisor Restoring
  -- =========================================================================
  p_fsm : process(i_clk)
    variable v_partial_sh : unsigned(C_DIV_BITS downto 0);
    variable v_quot_bit   : std_logic;
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        r_state       <= S_IDLE;
        r_trip        <= '0';
        r_time_en     <= '0';
        r_was_timing  <= '0';
        r_ram_rd_req  <= '0';
        r_ram_addr    <= (others => '0');
        r_target_ms   <= (others => '0');
        r_vuf         <= (others => '0');
        r_partial     <= (others => '0');
        r_quotient    <= (others => '0');
        r_div_reg     <= (others => '0');
        r_divisor     <= (others => '0');
        r_div_cnt     <= 0;
      else
        r_ram_rd_req <= '0'; -- default pulso

        case r_state is

          -- --------------------------------------------------------------
          -- IDLE: aguarda primeiro valid_seq
          -- --------------------------------------------------------------
          when S_IDLE =>
            r_trip       <= '0';
            r_time_en    <= '0';
            r_was_timing <= '0';
            if i_valid_seq = '1' then
              r_state <= S_DIV_LOAD;
            end if;

          -- --------------------------------------------------------------
          -- DIV_LOAD: carrega operandos (1 ciclo)
          --   Numerador  = |V2| x 2000  (C_DIV_BITS bits)
          --   Denominador = |V1|
          --   Protecao div/0: seq1=0 -> VUF max, pula iteracoes
          -- --------------------------------------------------------------
          when S_DIV_LOAD =>
            if unsigned(i_seq1_abs) = 0 then
              r_vuf   <= (others => '1');
              r_state <= S_CHECK_VUF;
            else
              r_div_reg  <= resize(unsigned(i_seq2_abs), 32) *
                            to_unsigned(2000, C_MUL_BITS);
              r_divisor  <= resize(unsigned(i_seq1_abs), C_DIV_BITS);
              r_partial  <= (others => '0');
              r_quotient <= (others => '0');
              r_div_cnt  <= 0;
              r_state    <= S_DIV_ITER;
            end if;

          -- --------------------------------------------------------------
          -- DIV_ITER: C_DIV_ITER ciclos de divisao Restoring
          -- --------------------------------------------------------------
          when S_DIV_ITER =>
            v_partial_sh := (r_partial(C_DIV_BITS-1 downto 0) & r_div_reg(C_DIV_BITS-1));

            if v_partial_sh >= ('0' & r_divisor) then
              r_partial  <= v_partial_sh - ('0' & r_divisor);
              v_quot_bit := '1';
            else
              r_partial  <= v_partial_sh;
              v_quot_bit := '0';
            end if;

            r_div_reg  <= r_div_reg(C_DIV_BITS-2 downto 0) & '0';
            r_quotient <= r_quotient(C_DIV_BITS-2 downto 0) & v_quot_bit;

            if r_div_cnt = C_DIV_ITER - 1 then
              r_div_cnt <= 0;
              r_state   <= S_DIV_DONE;
            else
              r_div_cnt <= r_div_cnt + 1;
            end if;

          -- --------------------------------------------------------------
          -- DIV_DONE: satura quociente e latcha r_vuf (1 ciclo)
          -- Sempre avanca para S_CHECK_VUF no ciclo seguinte,
          -- garantindo que r_vuf esta estavel quando a decisao e feita.
          -- --------------------------------------------------------------
          when S_DIV_DONE =>
            if r_quotient(C_DIV_BITS-1 downto G_ADDR_BITS) /=
               (C_DIV_BITS-1 downto G_ADDR_BITS => '0')
            then
              r_vuf <= (others => '1');
            else
              r_vuf <= r_quotient(G_ADDR_BITS-1 downto 0);
            end if;
            r_state <= S_CHECK_VUF;

          -- --------------------------------------------------------------
          -- CHECK_VUF: unico ponto de decisao de pickup/histerese.
          -- r_vuf esta garantidamente atualizado neste estado.
          --
          -- r_was_timing = '0' (vindo de MONITORING/IDLE):
          --   s_above = '1' -> inicia temporizacao: req BRAM, vai para LUT_WAIT_RD
          --   caso contrario -> vai para MONITORING aguardar proximo valid_seq
          --
          -- r_was_timing = '1' (reavaliacao de TIME_ACTIVE/TRIPPED):
          --   s_below = '1'               -> limpa trip, vai para MONITORING
          --   s_above = '1', trip = '1'   -> mantem TRIPPED
          --   s_above = '1', trip = '0'   -> atualiza LUT, vai para LUT_WAIT_RD
          --   zona de histerese, trip = '1'-> mantem TRIPPED
          --   zona de histerese, trip = '0'-> mantem TIME_ACTIVE
          -- --------------------------------------------------------------
          when S_CHECK_VUF =>
            r_was_timing <= '0'; -- limpa flag sempre

            if r_was_timing = '0' then
              -- Primeira avaliacao (vindo de MONITORING ou IDLE)
              if s_above = '1' then
                r_ram_addr   <= r_vuf;
                r_ram_rd_req <= '1';
                r_state      <= S_LUT_WAIT_RD;
              else
                r_state <= S_MONITORING;
              end if;

            else
              -- Reavaliacao periodica (vindo de TIME_ACTIVE ou TRIPPED)
              if s_below = '1' then
                -- Saiu da zona de atuacao: cancela tudo
                r_trip    <= '0';
                r_time_en <= '0';
                r_state   <= S_MONITORING;

              elsif s_above = '1' then
                -- Ainda acima do pickup
                if r_trip = '1' then
                  r_state <= S_TRIPPED;       -- mantem trip
                else
                  -- Atualiza target com VUF atual
                  r_ram_addr   <= r_vuf;
                  r_ram_rd_req <= '1';
                  r_state      <= S_LUT_WAIT_RD;
                end if;

              else
                -- Zona de histerese: mantem estado anterior
                if r_trip = '1' then
                  r_state <= S_TRIPPED;
                else
                  r_state <= S_TIME_ACTIVE;
                end if;
              end if;
            end if;

          -- --------------------------------------------------------------
          -- MONITORING: VUF confirmado abaixo do pickup.
          -- Aguarda valid_seq e SEMPRE refaz a divisao antes de decidir.
          -- Nao avalia s_above/s_below diretamente aqui.
          -- --------------------------------------------------------------
          when S_MONITORING =>
            r_trip    <= '0';
            r_time_en <= '0';
            if i_valid_seq = '1' then
              -- r_was_timing = '0': CHECK_VUF vai avaliar como 1a avaliacao
              r_was_timing <= '0';
              r_state      <= S_DIV_LOAD;
            end if;

          -- --------------------------------------------------------------
          -- LUT_WAIT_RD: aguarda 2 ciclos de latencia da BRAM
          -- --------------------------------------------------------------
          when S_LUT_WAIT_RD =>
            if s_ram_vld = '1' then
              r_target_ms <= unsigned(i_ram_data);
              r_time_en   <= '1';
              r_state     <= S_TIME_ACTIVE;
            end if;

          -- --------------------------------------------------------------
          -- TIME_ACTIVE: conta ms ate atingir o valor da LUT
          -- --------------------------------------------------------------
          when S_TIME_ACTIVE =>
            if r_time_ms >= r_target_ms then
              r_trip  <= '1';
              r_state <= S_TRIPPED;
            elsif i_valid_seq = '1' then
              r_was_timing <= '1';
              r_state      <= S_DIV_LOAD;
            end if;

          -- --------------------------------------------------------------
          -- TRIPPED: trip ativo, reavalia a cada valid_seq
          -- --------------------------------------------------------------
          when S_TRIPPED =>
            r_trip <= '1';
            if i_valid_seq = '1' then
              r_was_timing <= '1';
              r_state      <= S_DIV_LOAD;
            end if;

          when others =>
            r_state <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

  -- =========================================================================
  -- Saidas
  -- =========================================================================
  o_trip       <= r_trip;
  o_time_ms    <= std_logic_vector(r_time_ms);
  o_vuf        <= std_logic_vector(r_vuf);
  o_ram_addr   <= std_logic_vector(r_ram_addr);
  o_ram_rd_req <= r_ram_rd_req;

end architecture rtl;
