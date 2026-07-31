library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

-- 1. Entidade Vazia
entity tb_unbalance is
end entity tb_unbalance;

architecture sim of tb_unbalance is

  component stim_3ph_rom_64pts is
    generic (
      G_WIDTH : integer := 12;
      G_NPTS  : integer := 64
    );
    port (
      i_clk : in std_logic;
      i_rst : in std_logic;

      i_valid_fase_A : in std_logic;
      i_valid_fase_B : in std_logic;
      i_valid_fase_C : in std_logic;

      o_phase_A       : out signed(G_WIDTH - 1 downto 0);
      o_valid_phase_A : out std_logic;

      o_phase_B       : out signed(G_WIDTH - 1 downto 0);
      o_valid_phase_B : out std_logic;

      o_phase_C       : out signed(G_WIDTH - 1 downto 0);
      o_valid_phase_C : out std_logic
    );
  end component;

  component unbalance_controller is
    generic (
      G_WIDTH : integer := 12
    );
    port (
      i_clk : in std_logic;
      i_rst : in std_logic;

      i_phase_A : in signed(G_WIDTH - 1 downto 0);
      i_valid_A : in std_logic;
      i_phase_B : in signed(G_WIDTH - 1 downto 0);
      i_valid_B : in std_logic;
      i_phase_C : in signed(G_WIDTH - 1 downto 0);
      i_valid_C : in std_logic;

      i_seq_neg : in std_logic; 
      i_mag_sel_A : in std_logic_vector(1 downto 0);
      i_mag_sel_B : in std_logic_vector(1 downto 0);
      i_mag_sel_C : in std_logic_vector(1 downto 0);

      o_phase_A : out signed(G_WIDTH - 1 downto 0);
      o_valid_A : out std_logic;
      o_phase_B : out signed(G_WIDTH - 1 downto 0);
      o_valid_B : out std_logic;
      o_phase_C : out signed(G_WIDTH - 1 downto 0);
      o_valid_C : out std_logic
    );
  end component;

  component phasor_64pts_3ph_unified_fsm is
    generic (
      SAMPLE_WIDTH : integer := 12;
      COEFF_WIDTH  : integer := 15;
      ACC_WIDTH    : integer := 36;
      OUT_WIDTH    : integer := 32;
      ANG_WIDTH    : integer := 16;
      ITER         : integer := 16
    );
    port (
      i_clk : in std_logic;
      i_rst : in std_logic;

      i_signal_phaseA_12 : in signed(SAMPLE_WIDTH - 1 downto 0);
      i_valid_phaseA     : in std_logic;
      i_signal_phasB_12  : in signed(SAMPLE_WIDTH - 1 downto 0);
      i_valid_phaseB     : in std_logic;
      i_signal_phaseC_12 : in signed(SAMPLE_WIDTH - 1 downto 0);
      i_valid_phaseC     : in std_logic;

      o_valid_phaseA : out std_logic;
      o_Real_phaseA  : out signed(ACC_WIDTH - 1 downto 0);
      o_Imag_phaseA  : out signed(ACC_WIDTH - 1 downto 0);
      o_RMS_phaseA   : out unsigned(OUT_WIDTH - 1 downto 0);
      o_phase_phaseA : out signed(ANG_WIDTH - 1 downto 0);

      o_valid_phaseB : out std_logic;
      o_Real_phaseB  : out signed(ACC_WIDTH - 1 downto 0);
      o_Imag_phaseB  : out signed(ACC_WIDTH - 1 downto 0);
      o_RMS_phaseB   : out unsigned(OUT_WIDTH - 1 downto 0);
      o_phase_phaseB : out signed(ANG_WIDTH - 1 downto 0);

      o_valid_phaseC : out std_logic;
      o_Real_phaseC  : out signed(ACC_WIDTH - 1 downto 0);
      o_Imag_phaseC  : out signed(ACC_WIDTH - 1 downto 0);
      o_RMS_phaseC   : out unsigned(OUT_WIDTH - 1 downto 0);
      o_phase_phaseC : out signed(ANG_WIDTH - 1 downto 0)
    );
  end component;

  component symcomp_3ph_from_phasors_fsm_retpol is
    generic (
      ACC_WIDTH : integer := 36;
      OUT_WIDTH : integer := 32;
      ANG_WIDTH : integer := 16;
      ITER      : integer := 16
    );
    port (
      i_clk : in std_logic;
      i_rst : in std_logic;

      i_valid_phaseA : in std_logic;
      i_Re_phaseA    : in signed(ACC_WIDTH - 1 downto 0);
      i_Im_phaseA    : in signed(ACC_WIDTH - 1 downto 0);

      i_valid_phaseB : in std_logic;
      i_Re_phaseB    : in signed(ACC_WIDTH - 1 downto 0);
      i_Im_phaseB    : in signed(ACC_WIDTH - 1 downto 0);

      i_valid_phaseC : in std_logic;
      i_Re_phaseC    : in signed(ACC_WIDTH - 1 downto 0);
      i_Im_phaseC    : in signed(ACC_WIDTH - 1 downto 0);

      o_valid_seq  : out std_logic;
      o_seq0_re    : out signed(ACC_WIDTH - 1 downto 0);
      o_seq0_im    : out signed(ACC_WIDTH - 1 downto 0);
      o_seq0_abs   : out unsigned(OUT_WIDTH - 1 downto 0);
      o_seq0_phase : out signed(ANG_WIDTH - 1 downto 0);
      o_seq0_rms   : out unsigned(OUT_WIDTH - 1 downto 0);
      o_seq1_abs   : out unsigned(OUT_WIDTH - 1 downto 0);
      o_seq1_phase : out signed(ANG_WIDTH - 1 downto 0);
      o_seq1_rms   : out unsigned(OUT_WIDTH - 1 downto 0);
      o_seq1_re    : out signed(ACC_WIDTH - 1 downto 0);
      o_seq1_im    : out signed(ACC_WIDTH - 1 downto 0);
      o_seq2_re    : out signed(ACC_WIDTH - 1 downto 0);
      o_seq2_im    : out signed(ACC_WIDTH - 1 downto 0);
      o_seq2_abs   : out unsigned(OUT_WIDTH - 1 downto 0);
      o_seq2_phase : out signed(ANG_WIDTH - 1 downto 0);
      o_seq2_rms   : out unsigned(OUT_WIDTH - 1 downto 0)
    );
  end component;

  component ProtVoltageUmbalanceNegSeq_47_59Q is
  generic (
    G_CLK_HZ     : natural := 1_000_000;
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

  -- 2. Declaração de Sinais Globais
  constant clk_period : time    := 10 ns;
  signal sim_done     : boolean := false;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  -- Sinais entre o Gerador e o Controlador
  signal gen_phase_A, gen_phase_B, gen_phase_C : signed(11 downto 0);
  signal gen_vld_A, gen_vld_B, gen_vld_C       : std_logic := '0';

  -- Sinais de Controle de Falha
  signal ctrl_seq_neg   : std_logic                    := '0';
  signal ctrl_mag_sel_A : std_logic_vector(1 downto 0) := "00";
  signal ctrl_mag_sel_B : std_logic_vector(1 downto 0) := "00";
  signal ctrl_mag_sel_C : std_logic_vector(1 downto 0) := "00";

  -- Sinais de Saída Finais do Controlador (Sinal Limpo)
  signal out_phase_A, out_phase_B, out_phase_C : signed(11 downto 0);
  signal out_vld_A, out_vld_B, out_vld_C       : std_logic;

  -- NOVOS SINAIS: Saídas com Ruído e Escala Realista
  signal noisy_phase_A, noisy_phase_B, noisy_phase_C : signed(11 downto 0) := (others => '0');
  signal noisy_vld_A, noisy_vld_B, noisy_vld_C       : std_logic := '0';

  signal s_Imag_phaseA, s_Imag_phaseB, s_Imag_phaseC          : signed(35 downto 0);
  signal s_Real_phaseA, s_Real_phaseB, s_Real_phaseC          : signed(35 downto 0);
  signal s_phasor_A_valid, s_phasor_B_valid, s_phasor_C_valid : std_logic := '0';

  signal s_seq0_abs,s_seq1_abs,s_seq2_abs : unsigned(31 downto 0);
  signal s_seq0_rms,s_seq1_rms,s_seq2_rms : unsigned(31 downto 0);
  signal s_valid_seq : std_logic := '0';

  -- NOVOS SINAIS: Valores de Sequência formatados (Q12.19 -> Inteiro de 12 bits)
  signal s_seq0_abs_u12 : unsigned(11 downto 0);
  signal s_seq1_abs_u12 : unsigned(11 downto 0);
  signal s_seq2_abs_u12 : unsigned(11 downto 0);

  -- SINAIS PARA O BLOCO DE PROTEÇÃO
  signal i_v2_pickup_e1  : std_logic_vector(11 downto 0) := x"FFF"; -- Max para desativar T.Definido
  signal i_v2_pickup_e2  : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(100, 12));
  signal i_delay_e1_ms   : unsigned(19 downto 0) := (others => '1');
  
  signal o_ram_addr      : std_logic_vector(11 downto 0);
  signal o_ram_rd_req    : std_logic;
  signal i_ram_data      : std_logic_vector(19 downto 0);
  
  signal o_v2_abs_stable : unsigned(11 downto 0);
  signal o_v2_abs_u12    : unsigned(11 downto 0);
  signal o_time_ms       : std_logic_vector(19 downto 0);
  signal o_target_ms_reg : unsigned(19 downto 0);
  signal o_e1_time_cnt   : unsigned(19 downto 0);
  
  signal o_alarm_e1      : std_logic;
  signal o_alarm_e2      : std_logic;
  signal o_trip_47_59Q_e1: std_logic;
  signal o_trip_47_59Q_e2: std_logic;
  signal o_trip_47_59Q   : std_logic;

begin

  -- Lógica Concorrente para o acerto de escala Q12.19
  s_seq0_abs_u12 <= RESIZE(SHIFT_RIGHT(s_seq0_abs, 19), 12);
  s_seq1_abs_u12 <= RESIZE(SHIFT_RIGHT(s_seq1_abs, 19), 12);
  s_seq2_abs_u12 <= RESIZE(SHIFT_RIGHT(s_seq2_abs, 19), 12);

  -- 3. Instanciação dos Módulos
  U_GERADOR : stim_3ph_rom_64pts
  generic map(G_WIDTH => 12, G_NPTS => 64)
  port map (
    i_clk           => clk,
    i_rst           => rst,
    i_valid_fase_A  => gen_vld_A, 
    i_valid_fase_B  => gen_vld_B,
    i_valid_fase_C  => gen_vld_C,
    o_phase_A       => gen_phase_A, o_valid_phase_A => open,
    o_phase_B       => gen_phase_B, o_valid_phase_B => open,
    o_phase_C       => gen_phase_C, o_valid_phase_C => open
  );

  U_CONTROLADOR : unbalance_controller
  generic map(G_WIDTH => 12)
  port map (
    i_clk => clk,
    i_rst => rst,
    i_phase_A => gen_phase_A, i_valid_A => gen_vld_A,
    i_phase_B => gen_phase_B, i_valid_B => gen_vld_B,
    i_phase_C => gen_phase_C, i_valid_C => gen_vld_C,

    i_seq_neg   => ctrl_seq_neg,
    i_mag_sel_A => ctrl_mag_sel_A,
    i_mag_sel_B => ctrl_mag_sel_B,
    i_mag_sel_C => ctrl_mag_sel_C,

    o_phase_A => out_phase_A, o_valid_A => out_vld_A,
    o_phase_B => out_phase_B, o_valid_B => out_vld_B,
    o_phase_C => out_phase_C, o_valid_C => out_vld_C
  );

  ProtVoltageUmbalanceNegSeq_47_59Q_inst : ProtVoltageUmbalanceNegSeq_47_59Q
   generic map(
      G_CLK_HZ => 1_000_000,
      G_HYST => 0,
      G_TIME_WIDTH => 20,
      G_ADDR_BITS => 12,
      G_DATA_BITS => 20
  )
   port map(
      i_clk_100MHz => clk,
      i_rst => rst,
      i_v2_abs => s_seq2_abs,
      i_valid_v_seq => s_valid_seq,
      i_v2_pickup_e1 => i_v2_pickup_e1,
      i_v2_pickup_e2 => i_v2_pickup_e2,
      i_delay_e1_ms => i_delay_e1_ms,
      o_ram_addr => o_ram_addr,
      o_ram_rd_req => o_ram_rd_req,
      i_ram_data => i_ram_data,
      o_v2_abs_stable => o_v2_abs_stable,
      o_v2_abs_u12 => o_v2_abs_u12,
      o_time_ms => o_time_ms,
      o_target_ms_reg => o_target_ms_reg,
      o_e1_time_cnt => o_e1_time_cnt,
      o_alarm_e1 => o_alarm_e1,
      o_alarm_e2 => o_alarm_e2,
      o_trip_47_59Q_e1 => o_trip_47_59Q_e1,
      o_trip_47_59Q_e2 => o_trip_47_59Q_e2,
      o_trip_47_59Q => o_trip_47_59Q
  );

  -- Ligação da LUT nativa simulada (Porta A para leitura)
  blk_mem_gen_0_inst: blk_mem_gen_0
   port map(
      clka => clk,
      ena => o_ram_rd_req,
      wea => "0", -- Proteção apenas lê da memória
      addra => o_ram_addr,
      dina => (others => '0'),
      douta => i_ram_data,
      clkb => '0',
      enb => '0',
      web => "0",
      addrb => (others => '0'),
      dinb => (others => '0'),
      doutb => open
  );

  --========================================================================
  -- INJETOR DE RUÍDO: Escala o sinal para 15% (pico ~307) e ruído forte (+/- 120 LSBs)
  --========================================================================
  p_noise_injector : process(clk)
    variable seed1, seed2 : integer := 2026; 
    variable rand : real;
    variable nA, nB, nC : integer;
    constant GAIN : integer := 15; 
  begin
    if rising_edge(clk) then
      noisy_vld_A <= out_vld_A;
      noisy_vld_B <= out_vld_B;
      noisy_vld_C <= out_vld_C;

      if out_vld_A = '1' then
         uniform(seed1, seed2, rand); 
         nA := integer((rand * 240.0) - 120.0); 
         noisy_phase_A <= to_signed( (to_integer(out_phase_A) * GAIN / 100) + nA, 12 );
      end if;
      
      if out_vld_B = '1' then
         uniform(seed1, seed2, rand);
         nB := integer((rand * 240.0) - 120.0);
         noisy_phase_B <= to_signed( (to_integer(out_phase_B) * GAIN / 100) + nB, 12 );
      end if;
      
      if out_vld_C = '1' then
         uniform(seed1, seed2, rand);
         nC := integer((rand * 240.0) - 120.0);
         noisy_phase_C <= to_signed( (to_integer(out_phase_C) * GAIN / 100) + nC, 12 );
      end if;
    end if;
  end process;

  U_PHASOR : phasor_64pts_3ph_unified_fsm
  generic map(
    SAMPLE_WIDTH => 12, COEFF_WIDTH  => 15, ACC_WIDTH    => 36,
    OUT_WIDTH    => 32, ANG_WIDTH    => 16, ITER         => 16
  )
  port map (
    i_clk              => clk,
    i_rst              => rst,
    i_signal_phaseA_12 => noisy_phase_A,  
    i_valid_phaseA     => noisy_vld_A,    
    i_signal_phasB_12  => noisy_phase_B,  
    i_valid_phaseB     => noisy_vld_B,    
    i_signal_phaseC_12 => noisy_phase_C,  
    i_valid_phaseC     => noisy_vld_C,    
    
    o_valid_phaseA     => s_phasor_A_valid, o_Real_phaseA => s_Real_phaseA, o_Imag_phaseA => s_Imag_phaseA,
    o_RMS_phaseA       => open, o_phase_phaseA => open,
    o_valid_phaseB     => s_phasor_B_valid, o_Real_phaseB => s_Real_phaseB, o_Imag_phaseB => s_Imag_phaseB,
    o_RMS_phaseB       => open, o_phase_phaseB => open,
    o_valid_phaseC     => s_phasor_C_valid, o_Real_phaseC => s_Real_phaseC, o_Imag_phaseC => s_Imag_phaseC,
    o_RMS_phaseC       => open, o_phase_phaseC => open
  );

  U_SYM : symcomp_3ph_from_phasors_fsm_retpol
   generic map(
      ACC_WIDTH => 36, OUT_WIDTH => 32, ANG_WIDTH => 16, ITER => 16
  )
   port map(
      i_clk => clk,
      i_rst => rst,
      i_valid_phaseA => s_phasor_A_valid, i_Re_phaseA => s_Real_phaseA, i_Im_phaseA => s_Imag_phaseA,
      i_valid_phaseB => s_phasor_B_valid, i_Re_phaseB => s_Real_phaseB, i_Im_phaseB => s_Imag_phaseB,
      i_valid_phaseC => s_phasor_C_valid, i_Re_phaseC => s_Real_phaseC, i_Im_phaseC => s_Imag_phaseC,
      
      o_valid_seq => s_valid_seq,
      o_seq0_re => open, o_seq0_im => open, o_seq0_abs => s_seq0_abs, o_seq0_phase => open, o_seq0_rms => s_seq0_rms,
      o_seq1_abs => s_seq1_abs, o_seq1_phase => open, o_seq1_rms => s_seq1_rms, o_seq1_re => open, o_seq1_im => open,
      o_seq2_re => open, o_seq2_im => open, o_seq2_abs => s_seq2_abs, o_seq2_phase => open, o_seq2_rms => s_seq2_rms
  );

  -- 4. Geração de Clock e Valids
  p_clock : process
  begin
    while not sim_done loop
      clk <= '0';
      wait for clk_period / 2;
      clk <= '1';
      wait for clk_period / 2;
    end loop;
    wait;
  end process;

  p_valid_gen : process
  begin
    while not sim_done loop
      gen_vld_A <= '0'; gen_vld_B <= '0'; gen_vld_C <= '0';
      wait for 500 ns; 
      
      wait until falling_edge(clk); gen_vld_A <= '1';
      wait until falling_edge(clk); gen_vld_A <= '0';
      wait for 150 ns;
      
      wait until falling_edge(clk); gen_vld_B <= '1';
      wait until falling_edge(clk); gen_vld_B <= '0';
      wait for 150 ns;
      
      wait until falling_edge(clk); gen_vld_C <= '1';
      wait until falling_edge(clk); gen_vld_C <= '0';
    end loop;
    wait;
  end process;

  -- 5. O Roteiro de Estímulos e Validação de Proteção
  p_stimulus : process
    variable v_t_start : time;
    variable v_t_trip  : time;
  begin
    -- ==========================================
    -- CONFIGURAÇÃO INICIAL
    -- ==========================================
    i_v2_pickup_e2 <= std_logic_vector(to_unsigned(100, 12)); -- Pickup 100 para T. Inverso
    i_v2_pickup_e1 <= x"FFF"; -- Desabilita Tempo Definido E1
    i_delay_e1_ms  <= (others => '1');

    rst            <= '1';
    ctrl_seq_neg   <= '0';
    ctrl_mag_sel_A <= "00"; 
    ctrl_mag_sel_B <= "00"; 
    ctrl_mag_sel_C <= "00";
    wait for 100 ns;
    
    -- ==========================================
    -- TESTE 1: SISTEMA BALANCEADO (NO TRIP)
    -- ==========================================
    wait until falling_edge(clk);
    report "====== INICIANDO TESTE 1: SISTEMA NORMAL ====== Tempo: " & time'image(now) severity note;
    rst <= '0';
    wait for 70 us; -- Espera a matemática preencher a janela

    -- Verifica por um tempo se ocorre um trip falso
    wait for 20 ms;
    assert o_trip_47_59Q = '0' 
      report "FALHA: Trip inesperado ocorreu no estado normal!" severity error;
    
    -- ==========================================
    -- TESTE 2: FALHA 50% FASE A
    -- ==========================================
    wait until falling_edge(clk);
    rst <= '1';
    ctrl_mag_sel_A <= "00";
    wait for 100 ns;
    rst <= '0';
    wait for 70 us; -- Estabiliza

    wait until falling_edge(clk);
    report ">>> INJETANDO FALHA 1 (Fase A 50%) <<< Tempo: " & time'image(now) severity warning;
    ctrl_mag_sel_A <= "10";
    v_t_start := now;

    -- Espera o trip com timeout de seguranca de 500ms
    wait until o_trip_47_59Q = '1' for 500 ms;
    if o_trip_47_59Q = '1' then
        v_t_trip := now - v_t_start;
        report "--- TRIP 1 CONFIRMADO --- Tempo de atuacao: " & time'image(v_t_trip) & 
               " | Seq2 Lida: " & to_string(to_integer(s_seq2_abs_u12)) severity note;
    else
        report "FALHA: Rele nao desarmou na Falha 1 dentro do timeout!" severity error;
    end if;

    -- ==========================================
    -- TESTE 3: CURTO FASE C
    -- ==========================================
    wait until falling_edge(clk);
    rst <= '1';
    ctrl_mag_sel_A <= "00";
    wait for 100 ns;
    rst <= '0';
    wait for 70 us; -- Estabiliza

    wait until falling_edge(clk);
    report ">>> INJETANDO FALHA 2 (Curto Fase C) <<< Tempo: " & time'image(now) severity warning;
    ctrl_mag_sel_C <= "11";
    v_t_start := now;

    wait until o_trip_47_59Q = '1' for 500 ms;
    if o_trip_47_59Q = '1' then
        v_t_trip := now - v_t_start;
        report "--- TRIP 2 CONFIRMADO --- Tempo de atuacao: " & time'image(v_t_trip) & 
               " | Seq2 Lida: " & to_string(to_integer(s_seq2_abs_u12)) severity note;
    else
        report "FALHA: Rele nao desarmou na Falha 2 dentro do timeout!" severity error;
    end if;

    -- ==========================================
    -- TESTE 4: INVERSAO DE SEQUENCIA (ACB)
    -- ==========================================
    wait until falling_edge(clk);
    rst <= '1';
    ctrl_mag_sel_C <= "00";
    wait for 100 ns;
    rst <= '0';
    wait for 70 us; -- Estabiliza

    wait until falling_edge(clk);
    report ">>> INJETANDO FALHA 3 (Seq Negativa ACB) <<< Tempo: " & time'image(now) severity warning;
    ctrl_seq_neg <= '1';
    v_t_start := now;

    wait until o_trip_47_59Q = '1' for 500 ms;
    if o_trip_47_59Q = '1' then
        v_t_trip := now - v_t_start;
        report "--- TRIP 3 CONFIRMADO --- Tempo de atuacao: " & time'image(v_t_trip) & 
               " | Seq2 Lida: " & to_string(to_integer(s_seq2_abs_u12)) severity note;
    else
        report "FALHA: Rele nao desarmou na Falha 3 dentro do timeout!" severity error;
    end if;

    -- ==========================================
    -- FIM DA SIMULAÇÃO
    -- ==========================================
    sim_done <= true;
    report "====== FIM DE TODA A BATERIA DE TESTES ====== Tempo: " & time'image(now) severity note;
    wait;
  end process;

end architecture;