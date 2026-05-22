-- ============================================================================
--  Autor       : Prof. Dr. Andre dos Anjos / ChatGPT
--  Bloco       : rocof_from_phasor_shortwin
--  Descricao   :
--
--    Estima o ROCOF (Rate Of Change Of Frequency) para a funcao ANSI 81R
--    a partir da fase do fasor fundamental em Q13.
--
--    Etapas:
--      1) Captura a fase wrapped do fasor fundamental
--      2) Calcula dphi com unwrap em 32 bits
--      3) Acumula a fase unwrap em theta_unw
--      4) Estima uma frequencia curta por janela K_FREQ
--      5) Estima o ROCOF pela diferenca entre frequencias separadas por R_ROCOF
--      6) Aplica IIR leve na saida de ROCOF
--
--    Saidas:
--      o_dfreq_mHz   : frequencia auxiliar em mHz
--      o_rocof_mHzps : ROCOF em mHz/s
--
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rocof_from_phasor_shortwin is
  generic (
    ANG_WIDTH : integer := 16;
    ANG_FRAC  : integer := 13;

    FS_HZ     : integer := 3844;
    K_FREQ    : integer := 8;
    R_ROCOF   : integer := 8;

    FREQ_MUL  : integer := 9562;
    FREQ_SH   : integer := 10;

    ROCOF_MUL : integer := 492032;
    ROCOF_SH  : integer := 10;

    IIR_SH    : integer := 3
  );
  port (
    i_clk          : in  std_logic;
    i_rst          : in  std_logic;

    i_valid_phasor : in  std_logic;
    i_phase_q13    : in  signed(ANG_WIDTH-1 downto 0);

    o_valid        : out std_logic;
    o_dphi_q13     : out signed(ANG_WIDTH-1 downto 0);
    o_dfreq_mHz    : out signed(31 downto 0);
    o_rocof_mHzps  : out signed(31 downto 0)
  );
end entity;

architecture rtl of rocof_from_phasor_shortwin is

  --------------------------------------------------------------------
  -- Constantes Q13
  --------------------------------------------------------------------
  constant PI_Q13     : integer := 25736;
  constant TWO_PI_Q13 : integer := 51472;

  constant PI_Q13_32     : signed(31 downto 0) := to_signed(PI_Q13, 32);
  constant TWO_PI_Q13_32 : signed(31 downto 0) := to_signed(TWO_PI_Q13, 32);

  --------------------------------------------------------------------
  -- Memorias circulares
  --------------------------------------------------------------------
  type theta_mem_t is array (0 to K_FREQ-1) of signed(31 downto 0);
  signal theta_mem : theta_mem_t := (others => (others => '0'));
  signal theta_ptr : integer range 0 to K_FREQ-1 := 0;

  type freq_mem_t is array (0 to R_ROCOF-1) of signed(31 downto 0);
  signal freq_mem  : freq_mem_t := (others => (others => '0'));
  signal freq_ptr  : integer range 0 to R_ROCOF-1 := 0;

  --------------------------------------------------------------------
  -- Registradores principais
  --------------------------------------------------------------------
  signal phi_prev    : signed(ANG_WIDTH-1 downto 0) := (others => '0');
  signal phase_now   : signed(ANG_WIDTH-1 downto 0) := (others => '0');
  signal theta_unw   : signed(31 downto 0) := (others => '0');

  signal dphi_raw_32 : signed(31 downto 0) := (others => '0');
  signal dphi_unw_32 : signed(31 downto 0) := (others => '0');
  signal dphi_s      : signed(ANG_WIDTH-1 downto 0) := (others => '0');

  signal theta_new   : signed(31 downto 0) := (others => '0');
  signal theta_old_s : signed(31 downto 0) := (others => '0');

  --------------------------------------------------------------------
  -- Frequencia curta
  --------------------------------------------------------------------
  signal dthetaK_s   : signed(31 downto 0) := (others => '0');
  signal mul_freq_s  : signed(63 downto 0) := (others => '0');
  signal dfreq_mHz_s : signed(31 downto 0) := (others => '0');
  signal freq_old_s  : signed(31 downto 0) := (others => '0');

  --------------------------------------------------------------------
  -- ROCOF
  --------------------------------------------------------------------
  signal ddfreq_s      : signed(31 downto 0) := (others => '0');
  signal mul_rocof_s   : signed(63 downto 0) := (others => '0');
  signal rocof_raw_s   : signed(31 downto 0) := (others => '0');

  signal rocof_err_s     : signed(31 downto 0) := (others => '0');
  signal rocof_filt_s    : signed(31 downto 0) := (others => '0');
  signal rocof_next_s    : signed(31 downto 0) := (others => '0');
  signal rocof_filt_init : std_logic := '0';

  --------------------------------------------------------------------
  -- Controle de preenchimento
  --------------------------------------------------------------------
  signal theta_fill_cnt : integer range 0 to K_FREQ := 0;
  signal theta_full     : std_logic := '0';

  signal freq_fill_cnt  : integer range 0 to R_ROCOF := 0;
  signal freq_full      : std_logic := '0';

  --------------------------------------------------------------------
  -- Saidas registradas
  --------------------------------------------------------------------
  signal ovalid_r : std_logic := '0';
  signal dphi_r   : signed(ANG_WIDTH-1 downto 0) := (others => '0');
  signal dfreq_r  : signed(31 downto 0) := (others => '0');
  signal rocof_r  : signed(31 downto 0) := (others => '0');

  --------------------------------------------------------------------
  -- FSM
  --------------------------------------------------------------------
  type state_t is (
    S_IDLE,
    S_RX,
    S_DPHI_RAW,
    S_DPHI_UNW,
    S_RESIZE,
    S_THETA,
    S_TREAD,
    S_TWRITE,
    S_DFREQ,
    S_MUL_FREQ,
    S_SHIFT_FREQ,
    S_FREAD,
    S_FWRITE,
    S_DROCOF,
    S_MUL_ROCOF,
    S_SHIFT_ROCOF,
    S_IIR_ERR,
    S_IIR_UPDATE,
    S_OUT
  );

  signal st : state_t := S_IDLE;

begin

  o_valid       <= ovalid_r;
  o_dphi_q13    <= dphi_r;
  o_dfreq_mHz   <= dfreq_r;
  o_rocof_mHzps <= rocof_r;

  process(i_clk)
  begin
    if rising_edge(i_clk) then

      if i_rst = '1' then

        st <= S_IDLE;

        phi_prev    <= (others => '0');
        phase_now   <= (others => '0');
        theta_unw   <= (others => '0');

        dphi_raw_32 <= (others => '0');
        dphi_unw_32 <= (others => '0');
        dphi_s      <= (others => '0');

        theta_new   <= (others => '0');
        theta_old_s <= (others => '0');

        dthetaK_s   <= (others => '0');
        mul_freq_s  <= (others => '0');
        dfreq_mHz_s <= (others => '0');
        freq_old_s  <= (others => '0');

        ddfreq_s    <= (others => '0');
        mul_rocof_s <= (others => '0');
        rocof_raw_s <= (others => '0');

        rocof_err_s     <= (others => '0');
        rocof_filt_s    <= (others => '0');
        rocof_next_s    <= (others => '0');
        rocof_filt_init <= '0';

        theta_ptr      <= 0;
        freq_ptr       <= 0;
        theta_fill_cnt <= 0;
        freq_fill_cnt  <= 0;
        theta_full     <= '0';
        freq_full      <= '0';

        ovalid_r <= '0';
        dphi_r   <= (others => '0');
        dfreq_r  <= (others => '0');
        rocof_r  <= (others => '0');

      else

        ovalid_r <= '0';

        case st is

          ----------------------------------------------------------------
          -- Inicializa referencia de fase
          ----------------------------------------------------------------
          when S_IDLE =>
            if i_valid_phasor = '1' then
              phi_prev <= i_phase_q13;

              theta_unw <= (others => '0');

              theta_ptr      <= 0;
              freq_ptr       <= 0;
              theta_fill_cnt <= 0;
              freq_fill_cnt  <= 0;
              theta_full     <= '0';
              freq_full      <= '0';

              rocof_filt_s    <= (others => '0');
              rocof_next_s    <= (others => '0');
              rocof_filt_init <= '0';

              st <= S_RX;
            end if;

          ----------------------------------------------------------------
          -- Aguarda nova fase valida
          ----------------------------------------------------------------
          when S_RX =>
            if i_valid_phasor = '1' then
              phase_now <= i_phase_q13;
              st <= S_DPHI_RAW;
            end if;

          ----------------------------------------------------------------
          -- Subtracao em 32 bits para evitar overflow
          ----------------------------------------------------------------
          when S_DPHI_RAW =>
            dphi_raw_32 <= resize(phase_now, 32) - resize(phi_prev, 32);
            st <= S_DPHI_UNW;

          ----------------------------------------------------------------
          -- Unwrap
          ----------------------------------------------------------------
          when S_DPHI_UNW =>
            if dphi_raw_32 > PI_Q13_32 then
              dphi_unw_32 <= dphi_raw_32 - TWO_PI_Q13_32;
            elsif dphi_raw_32 < -PI_Q13_32 then
              dphi_unw_32 <= dphi_raw_32 + TWO_PI_Q13_32;
            else
              dphi_unw_32 <= dphi_raw_32;
            end if;

            st <= S_RESIZE;

          ----------------------------------------------------------------
          -- Reduz dphi e atualiza referencia
          ----------------------------------------------------------------
          when S_RESIZE =>
            dphi_s   <= resize(dphi_unw_32, ANG_WIDTH);
            phi_prev <= phase_now;

            st <= S_THETA;

          ----------------------------------------------------------------
          -- Acumula fase unwrap
          ----------------------------------------------------------------
          when S_THETA =>
            theta_new <= theta_unw + resize(dphi_s, 32);
            st <= S_TREAD;

          ----------------------------------------------------------------
          -- Le theta antigo
          ----------------------------------------------------------------
          when S_TREAD =>
            theta_old_s <= theta_mem(theta_ptr);
            st <= S_TWRITE;

          ----------------------------------------------------------------
          -- Escreve theta novo
          ----------------------------------------------------------------
          when S_TWRITE =>
            theta_mem(theta_ptr) <= theta_new;

            if theta_ptr = K_FREQ-1 then
              theta_ptr <= 0;
            else
              theta_ptr <= theta_ptr + 1;
            end if;

            if theta_full = '0' then
              if theta_fill_cnt = K_FREQ-1 then
                theta_fill_cnt <= K_FREQ;
                theta_full     <= '1';
              else
                theta_fill_cnt <= theta_fill_cnt + 1;
              end if;
            end if;

            theta_unw <= theta_new;

            st <= S_DFREQ;

          ----------------------------------------------------------------
          -- Calcula dthetaK
          ----------------------------------------------------------------
          when S_DFREQ =>
            if theta_full = '1' then
              dthetaK_s <= theta_new - theta_old_s;
            else
              dthetaK_s <= (others => '0');
            end if;

            st <= S_MUL_FREQ;

          ----------------------------------------------------------------
          -- Multiplica para frequencia
          -- 32 x 32 = 64 bits
          ----------------------------------------------------------------
          when S_MUL_FREQ =>
            if theta_full = '1' then
              mul_freq_s <= resize(
                              dthetaK_s * to_signed(FREQ_MUL, 32),
                              64
                            );
            else
              mul_freq_s <= (others => '0');
            end if;

            st <= S_SHIFT_FREQ;

          ----------------------------------------------------------------
          -- Shift para obter dfreq em mHz
          ----------------------------------------------------------------
          when S_SHIFT_FREQ =>
            if theta_full = '1' then
              dfreq_mHz_s <= resize(shift_right(mul_freq_s, FREQ_SH), 32);
            else
              dfreq_mHz_s <= (others => '0');
            end if;

            st <= S_FREAD;

          ----------------------------------------------------------------
          -- Le frequencia antiga
          ----------------------------------------------------------------
          when S_FREAD =>
            freq_old_s <= freq_mem(freq_ptr);
            st <= S_FWRITE;

          ----------------------------------------------------------------
          -- Escreve frequencia atual
          ----------------------------------------------------------------
          when S_FWRITE =>
            if theta_full = '1' then
              freq_mem(freq_ptr) <= dfreq_mHz_s;
            else
              freq_mem(freq_ptr) <= (others => '0');
            end if;

            if freq_ptr = R_ROCOF-1 then
              freq_ptr <= 0;
            else
              freq_ptr <= freq_ptr + 1;
            end if;

            if theta_full = '1' then
              if freq_full = '0' then
                if freq_fill_cnt = R_ROCOF-1 then
                  freq_fill_cnt <= R_ROCOF;
                  freq_full     <= '1';
                else
                  freq_fill_cnt <= freq_fill_cnt + 1;
                end if;
              end if;
            else
              freq_fill_cnt <= 0;
              freq_full     <= '0';
            end if;

            st <= S_DROCOF;

          ----------------------------------------------------------------
          -- Diferenca entre frequencias
          ----------------------------------------------------------------
          when S_DROCOF =>
            if (theta_full = '1') and (freq_full = '1') then
              ddfreq_s <= dfreq_mHz_s - freq_old_s;
            else
              ddfreq_s <= (others => '0');
            end if;

            st <= S_MUL_ROCOF;

          ----------------------------------------------------------------
          -- Multiplica para ROCOF
          -- 32 x 32 = 64 bits
          ----------------------------------------------------------------
          when S_MUL_ROCOF =>
            if (theta_full = '1') and (freq_full = '1') then
              mul_rocof_s <= resize(
                               ddfreq_s * to_signed(ROCOF_MUL, 32),
                               64
                             );
            else
              mul_rocof_s <= (others => '0');
            end if;

            st <= S_SHIFT_ROCOF;

          ----------------------------------------------------------------
          -- Shift para obter ROCOF em mHz/s
          ----------------------------------------------------------------
          when S_SHIFT_ROCOF =>
            if (theta_full = '1') and (freq_full = '1') then
              rocof_raw_s <= resize(shift_right(mul_rocof_s, ROCOF_SH), 32);
            else
              rocof_raw_s <= (others => '0');
            end if;

            st <= S_IIR_ERR;

          ----------------------------------------------------------------
          -- Calcula erro do IIR
          ----------------------------------------------------------------
          when S_IIR_ERR =>
            if (theta_full = '1') and (freq_full = '1') then
              rocof_err_s <= rocof_raw_s - rocof_filt_s;
            else
              rocof_err_s <= (others => '0');
            end if;

            st <= S_IIR_UPDATE;

          ----------------------------------------------------------------
          -- Atualiza filtro IIR
          ----------------------------------------------------------------
          when S_IIR_UPDATE =>
            if (theta_full = '1') and (freq_full = '1') then

              if rocof_filt_init = '0' then
                rocof_filt_s    <= rocof_raw_s;
                rocof_next_s    <= rocof_raw_s;
                rocof_filt_init <= '1';
              else
                rocof_next_s <= rocof_filt_s + shift_right(rocof_err_s, IIR_SH);
                rocof_filt_s <= rocof_filt_s + shift_right(rocof_err_s, IIR_SH);
              end if;

            else
              rocof_filt_s    <= (others => '0');
              rocof_next_s    <= (others => '0');
              rocof_filt_init <= '0';
            end if;

            st <= S_OUT;

          ----------------------------------------------------------------
          -- Atualiza saidas
          ----------------------------------------------------------------
          when S_OUT =>
            dphi_r <= dphi_s;

            if theta_full = '1' then
              dfreq_r <= dfreq_mHz_s;
            else
              dfreq_r <= (others => '0');
            end if;

            if (theta_full = '1') and (freq_full = '1') then
              rocof_r <= rocof_next_s;
            else
              rocof_r <= (others => '0');
            end if;

            ovalid_r <= '1';
            st <= S_RX;

          when others =>
            st <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

end architecture;