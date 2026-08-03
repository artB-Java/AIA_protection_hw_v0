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

  -- Componente da RAM Nativa da Xilinx
  component blk_mem_gen_0
    port (
      clka  : in std_logic;
      ena   : in std_logic;
      wea   : in std_logic_vector(0 downto 0);
      addra : in std_logic_vector(11 downto 0);
      dina  : in std_logic_vector(19 downto 0);
      douta : out std_logic_vector(19 downto 0);
      clkb  : in std_logic;
      enb   : in std_logic;
      web   : in std_logic_vector(0 downto 0);
      addrb : in std_logic_vector(11 downto 0);
      dinb  : in std_logic_vector(19 downto 0);
      doutb : out std_logic_vector(19 downto 0)
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
  signal i_v2_pickup_e1 : std_logic_vector(11 downto 0) := (others => '0');
  signal i_v2_pickup_e2 : std_logic_vector(11 downto 0) := (others => '0');
  signal i_delay_e1_ms  : unsigned(19 downto 0) := (others => '0');
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
  function to_q19(val : integer) return unsigned is
  begin
    return shift_left(to_unsigned(val, 32), 19);
  end function;

begin

  -- Instanciação da Proteção (DUT)
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

  -- Instanciação da Block RAM Real (LUT da Curva)
  inst_ram : blk_mem_gen_0
    port map(
      clka  => clk,
      ena   => o_ram_rd_req,
      wea   => "0", 
      addra => o_ram_addr,
      dina  => (others => '0'),
      douta => i_ram_data,
      clkb  => '0',
      enb   => '0',
      web   => "0",
      addrb => (others => '0'),
      dinb  => (others => '0'),
      doutb => open
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

  -- Geração do pulso i_valid_v_seq (Emula o sinal do bloco de Fasores)
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

  -- Roteiro de Testes Focado no Estágio 1 (E1)
  p_stimulus : process
    variable v_t_start : time;
    variable v_t_trip  : time;
  begin
    ------------------------------------------------------------------
    -- CONFIGURAÇÃO INICIAL
    ------------------------------------------------------------------
    -- Configuração do Estágio 1 (Tempo Definido)
    i_v2_pickup_e1 <= std_logic_vector(to_unsigned(300, 12)); -- Pickup em 300
    i_delay_e1_ms  <= to_unsigned(500, 20);                   -- Tempo definido de 500 ms
    
    -- Configuração do Estágio 2 (Tempo Inverso)
    i_v2_pickup_e2 <= x"FFF"; -- Desativa o E2 para ele não disparar alarmes no nosso teste

    rst <= '1';
    i_v2_abs <= to_q19(0); 
    wait for 50 ns;
    rst <= '0';
    wait for 10 us;

    ------------------------------------------------------------------
    -- TESTE 1: SISTEMA BALANCEADO (V2 = 50) Abaixo do Pickup E1(300)
    ------------------------------------------------------------------
    wait until falling_edge(clk);
    report "====== TESTE 1: SISTEMA BALANCEADO (V2 = 50) ======" severity note;
    i_v2_abs <= to_q19(50);
    
    wait for 100 us; 
    assert o_alarm_e1 = '0' and o_trip_e1 = '0' 
      report "FALHA: Rele desarmou ou gerou alarme indevidamente no E1!" severity error;
    report "--- TESTE 1 PASSOU: Sem trip ou alarmes." severity note;

    ------------------------------------------------------------------
    -- TESTE 2: FALTA TRANSITÓRIA (V2 = 350) - Alarme mas sem Trip
    ------------------------------------------------------------------
    wait until falling_edge(clk);
    report "====== TESTE 2: FALTA TRANSITORIA (V2 = 350) ======" severity warning;
    i_v2_abs <= to_q19(350);
    
    -- Espera detectar o alarme
    wait until o_alarm_e1 = '1' for 500 us;
    report "--- PICKUP E1 DETECTADO! Contando tempo programado (500 ms)..." severity note;

    -- O tempo configurado é 500 ms (que leva 5 ms na nossa simulação acelerada).
    -- Vamos esperar apenas 2 ms de simulação (equivalente a 200 ms reais) e limpar a falha!
    wait for 2 ms;
    
    assert o_trip_e1 = '0' 
      report "FALHA: Rele desarmou ANTES do tempo programado (Trip rapido demais)!" severity error;
      
    report "--- TEMPO PARCIAL OK: Rele aguardou sem desarmar. Limpando a falha..." severity note;
    i_v2_abs <= to_q19(0); -- Normaliza a rede
    
    wait for 100 us;
    assert o_alarm_e1 = '0'
      report "FALHA: O Alarme E1 nao desligou apos a normalizacao da rede!" severity error;
    report "--- TESTE 2 PASSOU: Falha ignorada corretamente e temporizador resetado." severity note;

    ------------------------------------------------------------------
    -- TESTE 3: FALTA SUSTENTADA (V2 = 350) - Confirmação do Trip
    ------------------------------------------------------------------
    wait until falling_edge(clk);
    report "====== TESTE 3: FALTA SUSTENTADA (V2 = 350) ======" severity warning;
    i_v2_abs <= to_q19(350);
    
    wait until o_alarm_e1 = '1' for 500 us;
    v_t_start := now;
    report "--- PICKUP E1 DETECTADO! Aguardando o tempo de Trip (500 ms reais)..." severity note;

    wait until o_trip_e1 = '1' for 10 ms; -- Timeout de segurança
    if o_trip_e1 = '1' then
      v_t_trip := now - v_t_start;
      report "--- TRIP E1 CONFIRMADO! Tempo real na simulacao: " & time'image(v_t_trip) severity note;
      report "NOTA: Lembre-se de multiplicar esse tempo de simulacao por 100. (Ex: 5 ms de simulacao = 500 ms de Hardware)" severity note;
    else
      report "FALHA: Rele nao desarmou no Teste 3!" severity error;
    end if;

    ------------------------------------------------------------------
    -- FIM DA SIMULAÇÃO
    ------------------------------------------------------------------
    sim_done <= true;
    report "====== FIM DE TODOS OS TESTES DO ESTAGIO 1 (E1) ======" severity note;
    wait;
  end process;

end architecture;
