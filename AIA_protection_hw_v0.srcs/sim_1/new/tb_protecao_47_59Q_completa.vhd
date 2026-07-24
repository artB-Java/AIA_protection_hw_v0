
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all; -- Biblioteca de cálculo real (suportada por simuladores)

entity tb_protecao_47_59Q_completa is
end entity;

architecture sim of tb_protecao_47_59Q_completa is

  -- Constantes de Clock (100 MHz -> 10 ns)[cite: 2, 4]
  constant C_CLK_PERIOD    : time := 10 ns;
  
  -- Frequência de amostragem: 60 Hz * 64 pontos = 3840 Hz (~260.416 us)
  constant C_SAMPLE_PERIOD : time := 260416 ns; 

  -- Sinais de Clock e Reset
  signal s_clk : std_logic := '0';
  signal s_rst : std_logic := '1';

  -- Amostras digitais (12 bits, intervalo -2048 a +2047)[cite: 1, 3]
  signal s_sig_A, s_sig_B, s_sig_C : signed(11 downto 0) := (others => '0');
  signal s_val_A, s_val_B, s_val_C : std_logic := '0';

  -- Interconexão: Fasores -> Componentes Simétricas[cite: 3, 4]
  signal s_oval_A, s_oval_B, s_oval_C : std_logic;
  signal s_re_A, s_re_B, s_re_C       : signed(35 downto 0);
  signal s_im_A, s_im_B, s_im_C       : signed(35 downto 0);
  signal s_rms_A, s_rms_B, s_rms_C    : unsigned(31 downto 0);
  signal s_ph_A, s_ph_B, s_ph_C       : signed(15 downto 0);

  -- Interconexão: Componentes Simétricas -> Relé ANSI 47[cite: 4]
  signal s_val_seq : std_logic;
  signal s_seq0_re, s_seq0_im   : signed(35 downto 0);
  signal s_seq1_re, s_seq1_im   : signed(35 downto 0);
  signal s_seq2_re, s_seq2_im   : signed(35 downto 0);
  signal s_seq0_abs, s_seq1_abs : unsigned(31 downto 0);
  signal s_seq2_abs             : unsigned(31 downto 0); -- Módulo absoluto de V2
  signal s_seq0_ph, s_seq1_ph   : signed(15 downto 0);
  signal s_seq2_ph              : signed(15 downto 0);
  signal s_seq0_rms, s_seq1_rms : unsigned(31 downto 0);
  signal s_seq2_rms             : unsigned(31 downto 0);

  -- Sinais da Função de Proteção ANSI 47
  signal s_v2_pickup_e1 : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(500, 12)); -- Limiar E1 (Tempo Definido)
  signal s_v2_pickup_e2 : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(150, 12)); -- Limiar E2 (Curva Inversa)
  signal s_delay_e1_ms  : unsigned(19 downto 0) := to_unsigned(30, 20); -- Atraso E1 = 30 ms
  signal s_alarm_e1, s_alarm_e2           : std_logic;
  signal s_trip_e1, s_trip_e2, s_trip_tot : std_logic;
  signal s_v2_stable, s_v2_u12            : unsigned(11 downto 0);
  signal s_time_ms_vec, s_ram_addr        : std_logic_vector(19 downto 0);
  signal s_ram_rd_req                     : std_logic;
  signal s_ram_data                       : std_logic_vector(19 downto 0) := std_logic_vector(to_unsigned(15, 20)); -- Curva simulada em 15 ms

  -- Parâmetros do Gerador de Senoides Simulado
  signal s_amp_A : real := 2047.0; -- Amplitude nominal (1 pu)
  signal s_amp_B : real := 2047.0;
  signal s_amp_C : real := 2047.0;
  signal s_fas_A : real := 0.0;
  signal s_fas_B : real := -2.0 * MATH_PI / 3.0; -- -120 graus
  signal s_fas_C : real :=  2.0 * MATH_PI / 3.0; -- +120 graus[cite: 1]

begin

  -- Geração do Clock de 100 MHz[cite: 2, 4]
  p_clk : process
  begin
    while true loop
      s_clk <= '0'; wait for C_CLK_PERIOD / 2;
      s_clk <= '1'; wait for C_CLK_PERIOD / 2;
    end loop;
  end process;

  -- Geração de Amostras Multiplexadas (Simulando o XADC)[cite: 2, 3]
  p_stimulus : process
    variable v_t      : real := 0.0;
    variable v_step   : real := 1.0 / (60.0 * 64.0); -- 64 pontos por ciclo de 60 Hz
    variable v_samp_A : integer;
    variable v_samp_B : integer;
    variable v_samp_C : integer;
  begin
    -- 1. Manter o reset ativo no início
    s_rst <= '1';
    wait for 100 ns;
    s_rst <= '0';
    wait for 100 ns;

    -- 2. Loop principal de amostragem
    while true loop
      -- Cálculo das senoides instantâneas[cite: 1]
      v_samp_A := integer(round(s_amp_A * sin(2.0 * MATH_PI * 60.0 * v_t + s_fas_A)));
      v_samp_B := integer(round(s_amp_B * sin(2.0 * MATH_PI * 60.0 * v_t + s_fas_B)));
      v_samp_C := integer(round(s_amp_C * sin(2.0 * MATH_PI * 60.0 * v_t + s_fas_C)));

      -- Envio multiplexado (1 ciclo de validação com intervalo entre as fases)[cite: 3]
      s_sig_A <= to_signed(v_samp_A, 12);
      s_val_A <= '1';
      wait for C_CLK_PERIOD;
      s_val_A <= '0';

      wait for 10 * C_CLK_PERIOD; -- Intervalo interno de conversão

      s_sig_B <= to_signed(v_samp_B, 12);
      s_val_B <= '1';
      wait for C_CLK_PERIOD;
      s_val_B <= '0';

      wait for 10 * C_CLK_PERIOD;

      s_sig_C <= to_signed(v_samp_C, 12);
      s_val_C <= '1';
      wait for C_CLK_PERIOD;
      s_val_C <= '0';

      -- Avança no tempo para a próxima amostra da janela
      v_t := v_t + v_step;
      wait for (C_SAMPLE_PERIOD - (22 * C_CLK_PERIOD));
    end loop;
  end process;

  -- Controle de Cenários de Teste (Falhas no Sistema)
  p_scenarios : process
  begin
    -- CENÁRIO 1: Sistema 100% equilibrado durante os primeiros 50 ms (enchimento da janela + estabilização)[cite: 1]
    wait for 50 ms;
    
    -- CENÁRIO 2: Injeção de Falta Assimétrica (Queda de 50% na amplitude da Fase A)
    -- Isso gerará abruptamente um vetor de sequência negativa (V2), disparando o relé!
    report ">>> INJETANDO FALTA: Reduzindo amplitude da Fase A para 50% <<<" severity note;
    s_amp_A <= 1023.0; 
    
    -- Aguarda o relé atuar pela curva inversa (configurada no teste para 15 ms)
    wait for 40 ms;
    
    -- CENÁRIO 3: Retorno ao regime equilibrado (O relé deve desarmar após fechar a janela)
    report ">>> RESTABELECENDO SISTEMA: Regime equilibrado <<<" severity note;
    s_amp_A <= 2047.0;
    
    wait for 30 ms;
    report ">>> SIMULACAO CONCLUIDA COM SUCESSO <<<" severity note;
    std.env.finish;
  end process;

  -- Simulação da RAM (Curva Inversa do Relé)
  p_ram_emulation : process(s_clk)
  begin
    if rising_edge(s_clk) then
      if s_ram_rd_req = '1' then
        -- Quando a FSM requisita a leitura, devolvemos 15 ms no próximo clock
        s_ram_data <= std_logic_vector(to_unsigned(15, 20));
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Instanciação do Estágio 1: Estimação Fasorial (DFT Incremental)[cite: 3]
  -----------------------------------------------------------------------------
  u_phasor : entity work.phasor_64pts_3ph_unified_fsm
    generic map (
      SAMPLE_WIDTH => 12, COEFF_WIDTH => 15, ACC_WIDTH => 36,
      OUT_WIDTH    => 32, ANG_WIDTH   => 16, ITER      => 16
    )
    port map (
      i_clk => s_clk, i_rst => s_rst,
      i_signal_phaseA_12 => s_sig_A, i_valid_phaseA => s_val_A,
      i_signal_phasB_12  => s_sig_B, i_valid_phaseB => s_val_B,
      i_signal_phaseC_12 => s_sig_C, i_valid_phaseC => s_val_C,
      o_valid_phaseA => s_oval_A, o_Real_phaseA => s_re_A, o_Imag_phaseA => s_im_A, o_RMS_phaseA => s_rms_A, o_phase_phaseA => s_ph_A,
      o_valid_phaseB => s_oval_B, o_Real_phaseB => s_re_B, o_Imag_phaseB => s_im_B, o_RMS_phaseB => s_rms_B, o_phase_phaseB => s_ph_B,
      o_valid_phaseC => s_oval_C, o_Real_phaseC => s_re_C, o_Imag_phaseC => s_im_C, o_RMS_phaseC => s_rms_C, o_phase_phaseC => s_ph_C
    );

  -----------------------------------------------------------------------------
  -- Instanciação do Estágio 2: Componentes Simétricas + CORDIC[cite: 4]
  -----------------------------------------------------------------------------
  u_symcomp : entity work.symcomp_3ph_from_phasors_fsm_retpol
    generic map (
      ACC_WIDTH => 36, OUT_WIDTH => 32, ANG_WIDTH => 16, ITER => 16
    )
    port map (
      i_clk => s_clk, i_rst => s_rst,
      i_valid_phaseA => s_oval_A, i_Re_phaseA => s_re_A, i_Im_phaseA => s_im_A,
      i_valid_phaseB => s_oval_B, i_Re_phaseB => s_re_B, i_Im_phaseB => s_im_B,
      i_valid_phaseC => s_oval_C, i_Re_phaseC => s_re_C, i_Im_phaseC => s_im_C,
      o_valid_seq => s_val_seq,
      o_seq0_re => s_seq0_re, o_seq0_im => s_seq0_im, o_seq0_abs => s_seq0_abs, o_seq0_phase => s_seq0_ph, o_seq0_rms => s_seq0_rms,
      o_seq1_re => s_seq1_re, o_seq1_im => s_seq1_im, o_seq1_abs => s_seq1_abs, o_seq1_phase => s_seq1_ph, o_seq1_rms => s_seq1_rms,
      o_seq2_re => s_seq2_re, o_seq2_im => s_seq2_im, o_seq2_abs => s_seq2_abs, o_seq2_phase => s_seq2_ph, o_seq2_rms => s_seq2_rms
    );

  -----------------------------------------------------------------------------
  -- Instanciação do Estágio 3: Proteção ANSI 47 (Desequilíbrio de Tensão)
  -----------------------------------------------------------------------------
  u_prot47 : entity work.ProtVoltageUmbalanceNegSeq_47_59Q
    generic map (
      G_CLK_HZ => 100_000_000, G_HYST => 5, G_TIME_WIDTH => 20, G_ADDR_BITS => 12, G_DATA_BITS => 20
    )
    port map (
      i_clk_100MHz => s_clk, i_rst => s_rst,
      i_v2_abs => s_seq2_abs, i_valid_v_seq => s_val_seq,
      i_v2_pickup_e1 => s_v2_pickup_e1, i_v2_pickup_e2 => s_v2_pickup_e2, i_delay_e1_ms => s_delay_e1_ms,
      o_ram_addr => s_ram_addr(11 downto 0), o_ram_rd_req => s_ram_rd_req, i_ram_data => s_ram_data,
      o_v2_abs_stable => s_v2_stable, o_v2_abs_u12 => s_v2_u12,
      o_alarm_e1 => s_alarm_e1, o_alarm_e2 => s_alarm_e2,
      o_trip_47_59Q_e1 => s_trip_e1, o_trip_47_59Q_e2 => s_trip_e2, o_trip_47_59Q => s_trip_tot
    );

end architecture;