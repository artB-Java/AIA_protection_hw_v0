-- ============================================================================
--  Autor       : Prof. Dr. Andre dos Anjos
--  Bloco       : rocof_d2theta_from_phasor
--  Descricao   :
--
--    Estima uma grandeza proporcional ao ROCOF para a funcao ANSI 81R
--    diretamente a partir da segunda diferenca da fase acumulada.
--
--    Diferente da versao que calcula:
--
--      fase -> frequencia em mHz -> ROCOF em mHz/s
--
--    esta versao calcula diretamente:
--
--      d2theta[n] = (theta[n] - theta[n-K]) -
--                   (theta[n-R] - theta[n-R-K])
--
--    Essa grandeza e proporcional ao ROCOF:
--
--      ROCOF ~= (1 / 2*pi) * d2theta / (K*R*Ts^2)
--
--    Para a logica de protecao, nao e necessario converter internamente
--    para mHz/s. O processador pode converter o pickup configurado pelo
--    usuario para o dominio interno d2theta_scaled.
--
--    Saidas:
--
--      o_dphi_q13:
--        incremento de fase unwrap, para debug
--
--      o_d2theta_q13:
--        segunda diferenca da fase acumulada, em contagens Q13
--
--      o_d2theta_scaled:
--        segunda diferenca escalada por 2^G_D2_SCALE_SH, util para
--        comparacao com pickup convertido pelo processador
--
--      o_valid:
--        pulso de 1 ciclo indicando saida valida
--
--  Observacoes:
--
--    - Esta arquitetura evita a conversao intermediaria para dfreq_mHz,
--      reduzindo multiplicadores e evitando uma etapa adicional de
--      quantizacao antes da derivada.
--
--    - A protecao 81R deve comparar abs(o_d2theta_scaled) com um pickup
--      tambem convertido para o mesmo dominio.
--
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rocof_d2theta_from_phasor is
  generic (
    ANG_WIDTH       : integer := 16;
    ANG_FRAC        : integer := 13;

    K_FREQ          : integer := 16;
    R_ROCOF         : integer := 16;

    -- Escala adicional para melhorar resolucao na comparacao.
    -- Ex.: d2theta_scaled = d2theta_q13 * 2^16.
    G_D2_SCALE_SH   : integer := 16
  );
  port (
    i_clk          : in  std_logic;
    i_rst          : in  std_logic;

    i_valid_phasor : in  std_logic;
    i_phase_q13    : in  signed(ANG_WIDTH-1 downto 0);

    o_valid        : out std_logic;
    o_dphi_q13     : out signed(ANG_WIDTH-1 downto 0);
    o_d2theta_q13  : out signed(31 downto 0);
    o_d2theta_scaled : out signed(47 downto 0);
	o_d2theta_scaled_filt : out signed(47 downto 0)
  );
end entity;

architecture rtl of rocof_d2theta_from_phasor is

  --------------------------------------------------------------------
  -- Constantes Q13
  --------------------------------------------------------------------
  constant PI_Q13     : integer := 25736;
  constant TWO_PI_Q13 : integer := 51472;

  constant PI_Q13_32     : signed(31 downto 0) := to_signed(PI_Q13, 32);
  constant TWO_PI_Q13_32 : signed(31 downto 0) := to_signed(TWO_PI_Q13, 32);

  --------------------------------------------------------------------
  -- Memoria circular da fase acumulada.
  --
  -- Para calcular:
  --   theta[n]
  --   theta[n-K]
  --   theta[n-R]
  --   theta[n-R-K]
  --
  -- A memoria precisa guardar pelo menos K+R amostras antigas.
  --------------------------------------------------------------------
  constant MEM_LEN : integer := K_FREQ + R_ROCOF + 1;

  type theta_mem_t is array (0 to MEM_LEN-1) of signed(31 downto 0);
  signal theta_mem : theta_mem_t := (others => (others => '0'));

  signal wr_ptr : integer range 0 to MEM_LEN-1 := 0;

  --------------------------------------------------------------------
  -- Registradores principais
  --------------------------------------------------------------------
  signal phi_prev    : signed(ANG_WIDTH-1 downto 0) := (others => '0');
  signal phase_now   : signed(ANG_WIDTH-1 downto 0) := (others => '0');

  signal dphi_raw_32 : signed(31 downto 0) := (others => '0');
  signal dphi_unw_32 : signed(31 downto 0) := (others => '0');
  signal dphi_s      : signed(ANG_WIDTH-1 downto 0) := (others => '0');

  signal theta_unw   : signed(31 downto 0) := (others => '0');
  signal theta_new   : signed(31 downto 0) := (others => '0');

  --------------------------------------------------------------------
  -- Amostras antigas da fase acumulada
  --------------------------------------------------------------------
  signal theta_n_k     : signed(31 downto 0) := (others => '0');
  signal theta_n_r     : signed(31 downto 0) := (others => '0');
  signal theta_n_r_k   : signed(31 downto 0) := (others => '0');

  --------------------------------------------------------------------
  -- Termos da segunda diferenca
  --------------------------------------------------------------------
  signal dtheta_now_s  : signed(31 downto 0) := (others => '0');
  signal dtheta_old_s  : signed(31 downto 0) := (others => '0');
  signal d2theta_s     : signed(31 downto 0) := (others => '0');

  signal d2theta_scaled_s : signed(47 downto 0) := (others => '0');

  --------------------------------------------------------------------
  -- Controle de preenchimento
  --------------------------------------------------------------------
  signal fill_cnt : integer range 0 to MEM_LEN := 0;
  signal mem_full : std_logic := '0';

  --------------------------------------------------------------------
  -- Saidas registradas
  --------------------------------------------------------------------
  signal ovalid_r          : std_logic := '0';
  signal dphi_r            : signed(ANG_WIDTH-1 downto 0) := (others => '0');
  signal d2theta_r         : signed(31 downto 0) := (others => '0');
  signal d2theta_scaled_r  : signed(47 downto 0) := (others => '0');
  
  signal d2theta_filt_s    : signed(47 downto 0) := (others => '0');
  signal d2theta_filt_r    : signed(47 downto 0) := (others => '0');

  --------------------------------------------------------------------
  -- Funcoes auxiliares para enderecamento circular
  --------------------------------------------------------------------
function circ_sub(
  idx  : integer;
  dist : integer;
  len  : integer
) return integer is
  variable tmp : integer;
begin
  tmp := idx - dist;

  if tmp < 0 then
    tmp := tmp + len;
  elsif tmp >= len then
    tmp := tmp - len;
  end if;

  return tmp;
end function;

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
    S_READ,
    S_WRITE,
    S_D2_0,
    S_D2_1,
    S_SCALE,
	S_FILTER,
    S_OUT
  );

  signal st : state_t := S_IDLE;

begin

  o_valid          <= ovalid_r;
  o_dphi_q13       <= dphi_r;
  o_d2theta_q13    <= d2theta_r;
  o_d2theta_scaled <= d2theta_scaled_r;
  o_d2theta_scaled_filt <= d2theta_filt_r;

  process(i_clk)
  begin
    if rising_edge(i_clk) then

      if i_rst = '1' then

        st <= S_IDLE;

        wr_ptr <= 0;

        phi_prev    <= (others => '0');
        phase_now   <= (others => '0');
        dphi_raw_32 <= (others => '0');
        dphi_unw_32 <= (others => '0');
        dphi_s      <= (others => '0');

        theta_unw <= (others => '0');
        theta_new <= (others => '0');

        theta_n_k   <= (others => '0');
        theta_n_r   <= (others => '0');
        theta_n_r_k <= (others => '0');

        dtheta_now_s <= (others => '0');
        dtheta_old_s <= (others => '0');
        d2theta_s    <= (others => '0');
        d2theta_scaled_s <= (others => '0');

        fill_cnt <= 0;
        mem_full <= '0';

        ovalid_r <= '0';
        dphi_r <= (others => '0');
        d2theta_r <= (others => '0');
        d2theta_scaled_r <= (others => '0');
		d2theta_filt_s <= (others => '0');
		d2theta_filt_r <= (others => '0');

      else

        ovalid_r <= '0';

        case st is

          ----------------------------------------------------------------
          -- Inicializa referencia de fase
          ----------------------------------------------------------------
          when S_IDLE =>
            if i_valid_phasor = '1' then
              phi_prev  <= i_phase_q13;
              theta_unw <= (others => '0');

              wr_ptr <= 0;
              fill_cnt <= 0;
              mem_full <= '0';

              st <= S_RX;
            end if;

          ----------------------------------------------------------------
          -- Aguarda fase valida
          ----------------------------------------------------------------
          when S_RX =>
            if i_valid_phasor = '1' then
              phase_now <= i_phase_q13;
              st <= S_DPHI_RAW;
            end if;

          ----------------------------------------------------------------
          -- Delta bruto em 32 bits
          ----------------------------------------------------------------
          when S_DPHI_RAW =>
            dphi_raw_32 <= resize(phase_now, 32) - resize(phi_prev, 32);
            st <= S_DPHI_UNW;

          ----------------------------------------------------------------
          -- Unwrap do delta
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
          -- Reduz dphi e atualiza referencia de fase
          ----------------------------------------------------------------
          when S_RESIZE =>
            dphi_s   <= resize(dphi_unw_32, ANG_WIDTH);
            phi_prev <= phase_now;
            st <= S_THETA;

          ----------------------------------------------------------------
          -- Atualiza fase acumulada
          ----------------------------------------------------------------
          when S_THETA =>
            theta_new <= theta_unw + resize(dphi_s, 32);
            st <= S_READ;

          ----------------------------------------------------------------
          -- Le amostras antigas da fase acumulada
          ----------------------------------------------------------------
          when S_READ =>
            theta_n_k   <= theta_mem(circ_sub(wr_ptr, K_FREQ, MEM_LEN));
            theta_n_r   <= theta_mem(circ_sub(wr_ptr, R_ROCOF, MEM_LEN));
            theta_n_r_k <= theta_mem(circ_sub(wr_ptr, K_FREQ + R_ROCOF, MEM_LEN));

            st <= S_WRITE;

          ----------------------------------------------------------------
          -- Escreve theta_new na memoria circular
          ----------------------------------------------------------------
          when S_WRITE =>
            theta_mem(wr_ptr) <= theta_new;

            if wr_ptr = MEM_LEN-1 then
              wr_ptr <= 0;
            else
              wr_ptr <= wr_ptr + 1;
            end if;

            if mem_full = '0' then
              if fill_cnt = MEM_LEN-1 then
                fill_cnt <= MEM_LEN;
                mem_full <= '1';
              else
                fill_cnt <= fill_cnt + 1;
              end if;
            end if;

            theta_unw <= theta_new;

            st <= S_D2_0;

          ----------------------------------------------------------------
          -- Calcula as duas diferencas de fase
          ----------------------------------------------------------------
          when S_D2_0 =>
            if mem_full = '1' then
              dtheta_now_s <= theta_new - theta_n_k;
              dtheta_old_s <= theta_n_r - theta_n_r_k;
            else
              dtheta_now_s <= (others => '0');
              dtheta_old_s <= (others => '0');
            end if;

            st <= S_D2_1;

          ----------------------------------------------------------------
          -- Segunda diferenca da fase
          ----------------------------------------------------------------
          when S_D2_1 =>
            if mem_full = '1' then
              d2theta_s <= dtheta_now_s - dtheta_old_s;
            else
              d2theta_s <= (others => '0');
            end if;

            st <= S_SCALE;

          ----------------------------------------------------------------
          -- Escala a segunda diferenca para melhorar resolucao
          ----------------------------------------------------------------
          when S_SCALE =>
            if mem_full = '1' then
              d2theta_scaled_s <= shift_left(resize(d2theta_s, 48), G_D2_SCALE_SH);
            else
              d2theta_scaled_s <= (others => '0');
            end if;

            st <= S_FILTER;
          ----------------------------------------------------------------
          -- Filtro saída
          ----------------------------------------------------------------			
		  when S_FILTER =>
		    if mem_full = '1' then
		  	-- IIR: y = y + (x - y)/2^N
		  	d2theta_filt_s <= d2theta_filt_r +
		  					  shift_right(d2theta_scaled_s - d2theta_filt_r, 3);
		    else
		  	d2theta_filt_s <= (others => '0');
		    end if;
		     
		    st <= S_OUT;

          ----------------------------------------------------------------
          -- Atualiza saidas
          ----------------------------------------------------------------
		  when S_OUT =>
		     
		    -- saída de debug (fase)
		    dphi_r <= dphi_s;
		     
		    if mem_full = '1' then		     
		  	-- sinal bruto
		  	d2theta_r        <= d2theta_s;		     
		  	-- sinal escalado (sem filtro)
		  	d2theta_scaled_r <= d2theta_scaled_s;		     
		  	-- sinal filtrado
		  	d2theta_filt_r   <= d2theta_filt_s;	     
		    else	     
		  	d2theta_r        <= (others => '0');
		  	d2theta_scaled_r <= (others => '0');
		  	d2theta_filt_r   <= (others => '0');		     
		    end if;
		     
		    -- pulso de validade
		    ovalid_r <= '1';
		     
		    -- volta para recepção
		    st <= S_RX;

          when others =>
            st <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

end architecture;