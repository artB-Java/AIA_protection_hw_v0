library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_prot_47_unit is
end entity tb_prot_47_unit;

architecture sim of tb_prot_47_unit is

  -- Componente da Proteção (DUT)
  component ProtVoltageUmbalanceNegSeq_47_59Q is
    generic (
      G_CLK_HZ     : natural := 100_000_000;
      G_HYST       : natural := 0;
      G_TIME_WIDTH : natural := 20;
      G_ADDR_BITS  : natural := 12;
      G_DATA_BITS  : natural := 20 
    );
    port (
      i_clk_100MHz    : in  std_logic;
      i_rst           : in  std_logic;
      i_v2_abs        : in  unsigned(31 downto 0);
      i_valid_v_seq   : in  std_logic;
      i_v2_pickup_e1  : in  std_logic_vector(11 downto 0);
      i_v2_pickup_e2  : in  std_logic_vector(11 downto 0);
      i_delay_e1_ms   : in  unsigned(G_TIME_WIDTH - 1 downto 0);
      o_ram_addr      : out std_logic_vector(G_ADDR_BITS - 1 downto 0);
      o_ram_rd_req    : out std_logic;
      i_ram_data      : in  std_logic_vector(G_DATA_BITS - 1 downto 0);
      o_v2_abs_stable : out unsigned(11 downto 0);
      o_v2_abs_u12    : out unsigned(11 downto 0);
      o_time_ms       : out std_logic_vector(G_DATA_BITS - 1 downto 0);
      o_target_ms_reg : out unsigned(G_DATA_BITS - 1 downto 0);
      o_e1_time_cnt   : out unsigned(G_TIME_WIDTH - 1 downto 0);
      o_alarm_e1       : out std_logic;
      o_alarm_e2       : out std_logic;
      o_trip_47_59Q_e1 : out std_logic;
      o_trip_47_59Q_e2 : out std_logic;
      o_trip_47_59Q    : out std_logic
    );
  end component;

  -- Sinais Globais
  constant clk_period : time := 10 ns;
  signal clk          : std_logic := '0';
  signal rst          : std_logic := '1';
  signal sim_done     : boolean := false;

  -- Entradas do DUT
  signal i_v2_abs       : unsigned(31 downto 0) := (others => '0');
  signal i_valid_v_seq  : std_logic := '0';
  signal i_v2_pickup_e1 : std_logic_vector(11 downto 0) := x"FFF"; -- Desativado
  signal i_v2_pickup_e2 : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(100, 12)); -- Pickup em 100
  signal i_delay_e1_ms  : unsigned(19 downto 0) := (others => '1');
  signal i_ram_data     : std_logic_vector(19 downto 0) := (others => '0');

  -- Saídas do DUT
  signal o_ram_addr      : std_logic_vector(11 downto 0);
  signal o_ram_rd_req    : std_logic;
  signal o_v2_abs_stable : unsigned(11 downto 0);
  signal o_v2_abs_u12    : unsigned(11 downto 0);
  signal o_time_ms       : std_logic_vector(19 downto 0);
  signal o_target_ms_reg : unsigned(19 downto 0);
  signal o_e1_time_cnt   : unsigned(19 downto 0);
  signal o_alarm_e1      : std_logic;
  signal o_alarm_e2      : std_logic;
  signal o_trip_e1       : std_logic;
  signal o_trip_e2       : std_logic;
  signal o_trip          : std_logic;

  -- Função auxiliar para injetar o valor correto na escala Q12.19
  -- A proteção faz shift_right(i_v2_abs, 19), então precisamos multiplicar por 2^19.
  function to_q19(val : integer) return unsigned is
  begin
    return shift_left(to_unsigned(val, 32), 19);
  end function;

begin

  -- Instanciação do DUT (Device Under Test)
  DUT : ProtVoltageUmbalanceNegSeq_47_59Q
    generic map (
      G_CLK_HZ     => 1_000_000, -- MÁQUINA DO TEMPO: 1 MHz acelera o tempo em 100x na simulação
      G_HYST       => 0,
      G_TIME_WIDTH => 20,
      G_ADDR_BITS  => 12,
      G_DATA_BITS  => 20
    )
    port map (
      i_clk_100MHz    => clk,
      i_rst           => rst,
      i_v2_abs        => i_v2_abs,
      i_valid_v_seq   => i_valid_v_seq,
      i_v2_pickup_e1  => i_v2_pickup_e1,
      i_v2_pickup_e2  => i_v2_pickup_e2,
      i_delay_e1_ms   => i_delay_e1_ms,
      o_ram_addr      => o_ram_addr,
      o_ram_rd_req    => o_ram_rd_req,
      i_ram_data      => i_ram_data,
      o_v2_abs_stable => o_v2_abs_stable,
      o_v2_abs_u12    => o_v2_abs_u12,
      o_time_ms       => o_time_ms,
      o_target_ms_reg => o_target_ms_reg,
      o_e1_time_cnt   => o_e1_time_cnt,
      o_alarm_e1       => o_alarm_e1,
      o_alarm_e2       => o_alarm_e2,
      o_trip_47_59Q_e1 => o_trip_e1,
      o_trip_47_59Q_e2 => o_trip_e2,
      o_trip_47_59Q    => o_trip
    );

  -- Geração do Clock
  p_clock : process
  begin
    while not sim_done loop
      clk <= '0'; wait for clk_period / 2;
      clk <= '1'; wait for clk_period / 2;
    end loop;
    wait;
  end process;

  -- Geração do pulso i_valid_v_seq (Emula o sinal que viria do bloco de Fasores)
  p_valid_gen : process
  begin
    while not sim_done loop
      i_valid_v_seq <= '0';
      wait for 840 ns;
      wait until falling_edge(clk);
      i_valid_v_seq <= '1';
      wait until falling_edge(clk);
    end loop;
    wait;
  end process;

  -- SIMULADOR DE RAM (MOCK DA LUT DA CURVA INVERSA)
  -- Quando o bloco pede leitura, devolvemos um tempo de atuação após 1 clock.
  p_ram_mock : process(clk)
  begin
    if rising_edge(clk) then
      if o_ram_rd_req = '1' then
        -- Se o endereço de V2 for maior que 100, devolve 200 ms.
        -- Como aceleramos o relógio para 1 MHz, 200 ms levará 2 ms no simulador!
        i_ram_data <= std_logic_vector(to_unsigned(200, 20)); 
      else
        i_ram_data <= (others => '0');
      end if;
    end if;
  end process;

  -- Roteiro de Testes
  p_stimulus : process
    variable v_t_start : time;
    variable v_t_trip  : time;
  begin
    ------------------------------------------------------------------
    -- RESET INICIAL
    ------------------------------------------------------------------
    rst <= '1';
    i_v2_abs <= to_q19(0); -- Valor normal, sem desbalanço
    wait for 50 ns;
    rst <= '0';
    wait for 10 us;

    ------------------------------------------------------------------
    -- TESTE 1: SISTEMA BALANCEADO (V2 = 50) Abaixo do Pickup(100)
    ------------------------------------------------------------------
    wait until falling_edge(clk);
    report "====== TESTE 1: SISTEMA BALANCEADO (V2 = 50) ======" severity note;
    i_v2_abs <= to_q19(50);
    
    -- O filtro IIR precisa de algumas dezenas de amostras para subir e estabilizar
    wait for 100 us; 
    assert o_alarm_e2 = '0' and o_trip = '0' 
      report "FALHA: Rele desarmou indevidamente abaixo do Pickup!" severity error;
    report "--- TESTE 1 PASSOU: Sem trip." severity note;

    ------------------------------------------------------------------
    -- TESTE 2: DESBALANÇO MODERADO (V2 = 150) Acima do Pickup
    ------------------------------------------------------------------
    wait until falling_edge(clk);
    report "====== TESTE 2: INJETANDO DESBALANÇO (V2 = 150) ======" severity warning;
    i_v2_abs <= to_q19(150);
    
    -- Marca o tempo assim que o Alarme de Pickup ligar
    wait until o_alarm_e2 = '1' for 500 us;
    v_t_start := now;
    report "--- PICKUP DETECTADO! Contando tempo da curva..." severity note;

    -- Espera o trip final
    wait until o_trip = '1' for 10 ms;
    if o_trip = '1' then
      v_t_trip := now - v_t_start;
      report "--- TRIP 2 CONFIRMADO! Tempo real na simulacao: " & time'image(v_t_trip) &
             " (Corresponde a ~200 ms no hardware devido a aceleracao do G_CLK_HZ)" severity note;
    else
      report "FALHA: Rele nao desarmou no Teste 2!" severity error;
    end if;

    ------------------------------------------------------------------
    -- TESTE 3: LIMPEZA DE FALHA E RESET DO RELÉ
    ------------------------------------------------------------------
    wait until falling_edge(clk);
    report "====== TESTE 3: LIMPANDO A FALHA (V2 = 0) ======" severity note;
    rst <= '1';
    wait for 20 ns;
    rst <= '0';
    i_v2_abs <= to_q19(0);
    
    wait for 100 us;
    assert o_trip = '0' and o_alarm_e2 = '0'
      report "FALHA: Rele nao reiniciou apos limpeza da falha!" severity error;
    report "--- TESTE 3 PASSOU: Rele resetado." severity note;

    -- Finaliza Simulação
    sim_done <= true;
    report "====== FIM DE TODOS OS TESTES UNITARIOS ======" severity note;
    wait;
  end process;

end architecture;
