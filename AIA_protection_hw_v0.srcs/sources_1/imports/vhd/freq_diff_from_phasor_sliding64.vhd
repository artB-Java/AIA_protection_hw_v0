-- ============================================================================
--  Autor       : Prof. Dr. Andre dos Anjos
--  Bloco       : freq_diff_from_phasor_sliding64
--  Descricao   :
--
--    Versao FSM, sem uso de variaveis. Somente sinais.
--    Calcula:
--      - dphi instantaneo (unwrap)
--      - dtheta64 (deriva em 64 amostras, janela deslizante)
--      - df em mHz (aproximado por mult + shift)
--
--    Estados:
--      S_IDLE   : aguarda primeiro dado valido (so inicializa phi_prev)
--      S_RX     : captura fase atual
--      S_DPHI   : calcula dphi e atualiza phi_prev
--      S_THETA  : calcula theta_new
--      S_READ   : le theta_old da memoria circular
--      S_WRITE  : escreve theta_new e atualiza ponteiro
--      S_DTHETA : calcula dtheta64
--      S_MUL    : multiplicacao pesada
--      S_OUT    : shift, atualiza saidas e gera o_valid
--
-- ============================================================================

--library ieee;
--use ieee.std_logic_1164.all;
--use ieee.numeric_std.all;
--
--entity freq_diff_from_phasor_sliding64 is
--  generic (
--    ANG_WIDTH : integer := 16;
--    ANG_FRAC  : integer := 13;
--    M         : integer := 64;
--    FS_HZ     : integer := 3844
--  );
--  port (
--    i_clk          : in  std_logic;
--    i_rst          : in  std_logic;
--
--    i_valid_phasor : in  std_logic;
--    i_phase_q13    : in  signed(ANG_WIDTH-1 downto 0);
--
--    o_valid        : out std_logic;
--    o_dphi_q13     : out signed(ANG_WIDTH-1 downto 0);
--    o_dtheta64_q13 : out signed(31 downto 0);
--    o_dfreq_mHz    : out signed(31 downto 0)
--  );
--end entity;
--
--architecture rtl of freq_diff_from_phasor_sliding64 is
--
--  -- Constantes Q13
--  constant PI_Q13     : integer := 25736;
--  constant TWO_PI_Q13 : integer := 51472;
--
--  -- Conversao para mHz (aproximacao)
--  constant K_MUL : integer := 2390;
--  constant K_SH  : integer := 11;
--
--  -- Memoria circular
--  type theta_mem_t is array (0 to M-1) of signed(31 downto 0);
--  signal theta_mem : theta_mem_t;
--  signal wr_ptr    : integer range 0 to M-1 := 0;
--
--  -- Registradores principais
--  signal phi_prev    : signed(ANG_WIDTH-1 downto 0) := (others => '0');
--  signal theta_unw   : signed(31 downto 0) := (others => '0');
--
--  -- Pipeline interno (somente sinais)
--  signal phase_now   : signed(ANG_WIDTH-1 downto 0) := (others => '0');
--  signal dphi_s      : signed(ANG_WIDTH-1 downto 0) := (others => '0');
--
--  signal theta_new   : signed(31 downto 0) := (others => '0');
--  signal theta_old_s : signed(31 downto 0) := (others => '0');
--
--  signal dtheta64_s  : signed(31 downto 0) := (others => '0');
--
--  signal mul_s       : signed(47 downto 0) := (others => '0');
--  signal df_mHz_s    : signed(31 downto 0) := (others => '0');
--
--  -- Saidas registradas
--  signal ovalid_r     : std_logic := '0';
--  signal dphi_r       : signed(ANG_WIDTH-1 downto 0) := (others => '0');
--  signal dtheta64_r   : signed(31 downto 0) := (others => '0');
--  signal dfreq_mHz_r  : signed(31 downto 0) := (others => '0');
--  
--  signal fill_cnt : integer range 0 to M := 0;
--  signal buf_full : std_logic := '0';
--
--  -- FSM
--  type state_t is (
--    S_IDLE,
--    S_RX,
--    S_DPHI,
--    S_THETA,
--    S_READ,
--    S_WRITE,
--    S_DTHETA,
--    S_MUL,
--	S_SHIFT,
--    S_OUT
--  );
--  signal st : state_t := S_IDLE;
--
--  -- Funcao unwrap (somente para delta pequeno)
--  function unwrap_delta_q13(din : signed(ANG_WIDTH-1 downto 0)) return signed is
--    variable d : integer;
--  begin
--    d := to_integer(din);
--
--    if d > PI_Q13 then
--      d := d - TWO_PI_Q13;
--    elsif d < -PI_Q13 then
--      d := d + TWO_PI_Q13;
--    end if;
--
--    return to_signed(d, ANG_WIDTH);
--  end function;
--
--begin
--
--  o_valid        <= ovalid_r;
--  o_dphi_q13     <= dphi_r;
--  o_dtheta64_q13 <= dtheta64_r;
--  o_dfreq_mHz    <= dfreq_mHz_r;
--
--  process(i_clk)
--  begin
--    if rising_edge(i_clk) then
--
--      if i_rst = '1' then
--        st <= S_IDLE;
--
--        wr_ptr      <= 0;
--        phi_prev    <= (others => '0');
--        theta_unw   <= (others => '0');
--
--        phase_now   <= (others => '0');
--        dphi_s      <= (others => '0');
--        theta_new   <= (others => '0');
--        theta_old_s <= (others => '0');
--        dtheta64_s  <= (others => '0');
--        mul_s       <= (others => '0');
--        df_mHz_s    <= (others => '0');
--
--        ovalid_r    <= '0';
--        dphi_r      <= (others => '0');
--        dtheta64_r  <= (others => '0');
--        dfreq_mHz_r <= (others => '0');
--	
--        buf_full <= '0';
--		fill_cnt <= 0;
--
--      else
--
--        -- pulso de saida de 1 ciclo
--        ovalid_r <= '0';
--
--        case st is
--
--          -- Aguarda primeiro valid. Aqui apenas inicializa phi_prev
--          -- para evitar um dphi inicial absurdo.
--          when S_IDLE =>
--            if i_valid_phasor = '1' then
--              phi_prev  <= i_phase_q13;
--              theta_unw <= (others => '0');
--              st <= S_RX;
--            end if;
--
--          -- Captura fase atual para processamento
--          when S_RX =>
--            if i_valid_phasor = '1' then
--              phase_now <= i_phase_q13;
--              st <= S_DPHI;
--            end if;
--
--          -- Calcula dphi e atualiza phi_prev
--          when S_DPHI =>
--            dphi_s   <= unwrap_delta_q13(phase_now - phi_prev);
--            phi_prev <= phase_now;
--            st <= S_THETA;
--
--          -- Calcula theta_new = theta_unw + dphi
--          when S_THETA =>
--            theta_new <= theta_unw + resize(dphi_s, 32);
--            st <= S_READ;
--
--          -- Le theta_old da memoria circular
--          when S_READ =>
--            theta_old_s <= theta_mem(wr_ptr);
--            st <= S_WRITE;
--
--          -- Escreve theta_new no buffer e atualiza ponteiro
--          when S_WRITE =>
--            theta_mem(wr_ptr) <= theta_new;
--
--            if wr_ptr = M-1 then
--              wr_ptr <= 0;
--            else
--              wr_ptr <= wr_ptr + 1;
--            end if;
--			
--			 -- Contador de preenchimento do buffer
--            if buf_full = '0' then
--              if fill_cnt = M then
--                fill_cnt <= M;
--                buf_full <= '1';
--              else
--                fill_cnt <= fill_cnt + 1;
--              end if;
--            end if;
--			
--			
--
--            -- Atualiza acumulador principal
--            theta_unw <= theta_new;
--
--            st <= S_DTHETA;
--
--          -- Calcula dtheta64 = theta_new - theta_old
--          when S_DTHETA =>
--            dtheta64_s <= theta_new - theta_old_s;
--            st <= S_MUL;
--
--          -- Multiplicacao pesada em ciclo dedicado
--          -- mul_s tem 48 bits porque 32 + 16 = 48
--          when S_MUL =>
--            mul_s <= resize(dtheta64_s, 32) * to_signed(K_MUL, 16);
--            st <= S_SHIFT;
--			
--		 -- SHIFT divisao
--		  when S_SHIFT =>
--            df_mHz_s <= resize(shift_right(mul_s, K_SH), 32);
--            st <= S_OUT;
--			
--          -- Saida registrada
--          when S_OUT =>         
--
--            dphi_r      <= dphi_s;
--			
--			
--			if buf_full = '1' then 
--				dtheta64_r  <= dtheta64_s;
--				dfreq_mHz_r <= df_mHz_s;
--			else
--			    dtheta64_r  <= (others => '0');
--				dfreq_mHz_r <= (others => '0');
--			end if;
--			   
--            ovalid_r    <= '1';
--
--            st <= S_RX;
--
--          when others =>
--            st <= S_IDLE;
--
--        end case;
--      end if;
--    end if;
--  end process;
--
--end architecture;

---- ============================================================================
----  Autor       : Prof. Dr. Andre dos Anjos
----  Bloco       : freq_diff_from_phasor_sliding64
----  Descricao   :
----
----    Versao FSM, sem uso de variaveis. Somente sinais.
----    Calcula:
----      - dphi instantaneo (unwrap)
----      - dtheta64 (deriva em 64 amostras, janela deslizante)
----      - df em mHz (aproximado por mult + shift)
----
----      Foi identificado que o salto na estimativa (dfreq e dtheta64) ocorre
----      no instante em que a fase wrapped salta de +pi para -pi (ou vice versa).
----      O problema raiz era overflow na subtracao em 16 bits:
----         phase_now - phi_prev pode dar aproximadamente -50000 em Q13,
----         mas 16 bits so permite -32768..+32767, causando wrap aritmetico.
----      Assim, o unwrap recebia um valor ja corrompido e injetava um erro de
----      1 amostra no acumulador theta_unw, que permanecia por 64 amostras.
----
----    Solucao:
----      - Fazer a subtracao em 32 bits (sem overflow)
----      - Fazer o unwrap em 32 bits
----      - So entao reduzir para 16 bits em dphi_s
----      - Para isso, foram criados subestados:
----          S_DPHI_RAW : calcula dphi_raw_32 (registrado)
----          S_DPHI_UNW : calcula unwrap e atualiza dphi_s e phi_prev
----
----    Estados:
----      S_IDLE      : aguarda primeiro dado valido (so inicializa phi_prev)
----      S_RX        : captura fase atual
----      S_DPHI_RAW  : calcula delta de fase bruto em 32 bits (evita overflow)
----      S_DPHI_UNW  : unwrap do delta e atualiza phi_prev e dphi_s
----      S_THETA     : calcula theta_new
----      S_READ      : le theta_old da memoria circular
----      S_WRITE     : escreve theta_new e atualiza ponteiro e fill
----      S_DTHETA    : calcula dtheta64
----      S_MUL       : multiplicacao pesada
----      S_SHIFT     : shift de divisao
----      S_OUT       : atualiza saidas e gera o_valid
----
---- ============================================================================
--
--library ieee;
--use ieee.std_logic_1164.all;
--use ieee.numeric_std.all;
--
--entity freq_diff_from_phasor_sliding64 is
--  generic (
--    ANG_WIDTH : integer := 16;
--    ANG_FRAC  : integer := 13;
--    M         : integer := 64;
--    FS_HZ     : integer := 3844
--  );
--  port (
--    i_clk          : in  std_logic;
--    i_rst          : in  std_logic;
--
--    i_valid_phasor : in  std_logic;
--    i_phase_q13    : in  signed(ANG_WIDTH-1 downto 0);
--
--    o_valid        : out std_logic;
--    o_dphi_q13     : out signed(ANG_WIDTH-1 downto 0);
--    o_dtheta64_q13 : out signed(31 downto 0);
--    o_dfreq_mHz    : out signed(31 downto 0)
--  );
--end entity;
--
--architecture rtl of freq_diff_from_phasor_sliding64 is
--
--  -- Constantes Q13
--  constant PI_Q13     : integer := 25736;
--  constant TWO_PI_Q13 : integer := 51472;
--
--  -- Constantes em 32 bits (para comparacoes no unwrap em 32 bits)
--  constant PI_Q13_32     : signed(31 downto 0) := to_signed(PI_Q13, 32);
--  constant TWO_PI_Q13_32 : signed(31 downto 0) := to_signed(TWO_PI_Q13, 32);
--
--  -- Conversao para mHz (aproximacao)
--  -- df_mHz ~= dtheta64_q13 * K_MUL / 2^K_SH
--  constant K_MUL : integer := 2390;
--  constant K_SH  : integer := 11;
--
--  -- Memoria circular
--  type theta_mem_t is array (0 to M-1) of signed(31 downto 0);
--  signal theta_mem : theta_mem_t;
--  signal wr_ptr    : integer range 0 to M-1 := 0;
--
--  -- Registradores principais
--  signal phi_prev    : signed(ANG_WIDTH-1 downto 0) := (others => '0');
--  signal theta_unw   : signed(31 downto 0) := (others => '0');
--
--  -- Pipeline interno (somente sinais)
--  signal phase_now   : signed(ANG_WIDTH-1 downto 0) := (others => '0');
--
--  -- Delta de fase em 32 bits para evitar overflow no wrap
--  signal dphi_raw_32 : signed(31 downto 0) := (others => '0');
--  signal dphi_unw_32 : signed(31 downto 0) := (others => '0');
--
--  -- Delta final em 16 bits (Q13) usado no acumulador
--  signal dphi_s      : signed(ANG_WIDTH-1 downto 0) := (others => '0');
--
--  signal theta_new   : signed(31 downto 0) := (others => '0');
--  signal theta_old_s : signed(31 downto 0) := (others => '0');
--
--  signal dtheta64_s  : signed(31 downto 0) := (others => '0');
--
--  signal mul_s       : signed(47 downto 0) := (others => '0');
--  signal df_mHz_s    : signed(31 downto 0) := (others => '0');
--
--  -- Saidas registradas
--  signal ovalid_r     : std_logic := '0';
--  signal dphi_r       : signed(ANG_WIDTH-1 downto 0) := (others => '0');
--  signal dtheta64_r   : signed(31 downto 0) := (others => '0');
--  signal dfreq_mHz_r  : signed(31 downto 0) := (others => '0');
--
--  -- Controle para manter saida em zero ate encher o buffer
--  signal fill_cnt : integer range 0 to M := 0;
--  signal buf_full : std_logic := '0';
--
--  -- FSM
--  type state_t is (
--    S_IDLE,
--    S_RX,
--    S_DPHI_RAW,
--    S_DPHI_UNW,
--	S_RESIZE,
--    S_THETA,
--    S_READ,
--    S_WRITE,
--    S_DTHETA,
--    S_MUL,
--    S_SHIFT,
--    S_OUT
--  );
--  signal st : state_t := S_IDLE;
--
--begin
--
--  o_valid        <= ovalid_r;
--  o_dphi_q13     <= dphi_r;
--  o_dtheta64_q13 <= dtheta64_r;
--  o_dfreq_mHz    <= dfreq_mHz_r;
--
--  process(i_clk)
--  begin
--    if rising_edge(i_clk) then
--
--      if i_rst = '1' then
--        st <= S_IDLE;
--
--        wr_ptr      <= 0;
--        phi_prev    <= (others => '0');
--        theta_unw   <= (others => '0');
--
--        phase_now   <= (others => '0');
--
--        dphi_raw_32 <= (others => '0');
--        dphi_unw_32 <= (others => '0');
--        dphi_s      <= (others => '0');
--
--        theta_new   <= (others => '0');
--        theta_old_s <= (others => '0');
--        dtheta64_s  <= (others => '0');
--
--        mul_s       <= (others => '0');
--        df_mHz_s    <= (others => '0');
--
--        ovalid_r    <= '0';
--        dphi_r      <= (others => '0');
--        dtheta64_r  <= (others => '0');
--        dfreq_mHz_r <= (others => '0');
--
--        buf_full <= '0';
--        fill_cnt <= 0;
--
--      else
--
--        -- pulso de saida de 1 ciclo
--        ovalid_r <= '0';
--
--        case st is
--
--          -- Aguarda primeiro valid. Aqui apenas inicializa phi_prev
--          -- para evitar um dphi inicial absurdo.
--          when S_IDLE =>
--            if i_valid_phasor = '1' then
--              phi_prev  <= i_phase_q13;
--              theta_unw <= (others => '0');
--              st <= S_RX;
--            end if;
--
--          -- Captura fase atual para processamento
--          when S_RX =>
--            if i_valid_phasor = '1' then
--              phase_now <= i_phase_q13;
--              st <= S_DPHI_RAW;
--            end if;
--
--          -- Calcula delta bruto em 32 bits (registrado)
--          -- Aqui esta a correcao principal: evita overflow na subtracao em 16 bits.
--          when S_DPHI_RAW =>
--            dphi_raw_32 <= resize(phase_now, 32) - resize(phi_prev, 32);
--            st <= S_DPHI_UNW;
--
--          -- Unwrap do delta em 32 bits e atualiza dphi_s e phi_prev
--          -- A logica de unwrap agora trabalha com um delta valido (sem overflow).
--          when S_DPHI_UNW =>
--            if dphi_raw_32 > PI_Q13_32 then
--              dphi_unw_32 <= dphi_raw_32 - TWO_PI_Q13_32;
--            elsif dphi_raw_32 < -PI_Q13_32 then
--              dphi_unw_32 <= dphi_raw_32 + TWO_PI_Q13_32;
--            else
--              dphi_unw_32 <= dphi_raw_32;
--            end if;
--			st <= S_RESIZE;
--			
--		 when S_RESIZE =>
--            -- Atualiza dphi em 16 bits e atualiza phi_prev
--            -- O resize aqui e seguro porque dphi_unw_32 ficara proximo de zero
--            -- (delta pequeno) quando a fase for coerente.
--            dphi_s   <= resize(dphi_unw_32, ANG_WIDTH);
--            phi_prev <= phase_now;
--
--            st <= S_THETA;
--
--          -- Calcula theta_new = theta_unw + dphi
--          when S_THETA =>
--            theta_new <= theta_unw + resize(dphi_s, 32);
--            st <= S_READ;
--
--          -- Le theta_old da memoria circular
--          when S_READ =>
--            theta_old_s <= theta_mem(wr_ptr);
--            st <= S_WRITE;
--
--          -- Escreve theta_new no buffer e atualiza ponteiro
--          when S_WRITE =>
--            theta_mem(wr_ptr) <= theta_new;
--
--            if wr_ptr = M-1 then
--              wr_ptr <= 0;
--            else
--              wr_ptr <= wr_ptr + 1;
--            end if;
--
--            -- Contador de preenchimento do buffer
--            -- Mantem saida em zero ate que existam M amostras validas armazenadas.
--            if buf_full = '0' then
--              if fill_cnt = M then
--                fill_cnt <= M;
--                buf_full <= '1';
--              else
--                fill_cnt <= fill_cnt + 1;
--              end if;
--            end if;
--
--            -- Atualiza acumulador principal
--            theta_unw <= theta_new;
--
--            st <= S_DTHETA;
--
--          -- Calcula dtheta64 = theta_new - theta_old
--          when S_DTHETA =>
--            dtheta64_s <= theta_new - theta_old_s;
--            st <= S_MUL;
--
--          -- Multiplicacao pesada em ciclo dedicado
--          -- mul_s tem 48 bits porque 32 + 16 = 48
--          when S_MUL =>
--            mul_s <= resize(dtheta64_s, 32) * to_signed(K_MUL, 16);
--            st <= S_SHIFT;
--
--          -- SHIFT divisao
--          when S_SHIFT =>
--            df_mHz_s <= resize(shift_right(mul_s, K_SH), 32);
--            st <= S_OUT;
--
--          -- Saida registrada
--          when S_OUT =>
--
--            -- dphi sempre sai (mesmo durante preenchimento)
--            dphi_r <= dphi_s;
--
--            -- dtheta64 e dfreq so saem validos apos buffer cheio
--            if buf_full = '1' then
--              dtheta64_r  <= dtheta64_s;
--              --dfreq_mHz_r <= df_mHz_s;
--			  dfreq_mHz_r <= df_mHz_s + to_signed(63, 32); -- correcao para referernciar em 60 Hz e não em 3044/64 (62.5 mHz)
--            else
--              dtheta64_r  <= (others => '0');
--              dfreq_mHz_r <= (others => '0');
--            end if;
--
--            ovalid_r <= '1';
--            st <= S_RX;
--
--          when others =>
--            st <= S_IDLE;
--
--        end case;
--      end if;
--    end if;
--  end process;
--
--end architecture;

-- ============================================================================
--  Autor       : Prof. Dr. Andre dos Anjos
--  Bloco       : freq_diff_from_phasor_sliding64
--  Descricao   :
--
--    Versao FSM, sem uso de variaveis. Somente sinais.
--    Calcula:
--      - dphi instantaneo (unwrap)
--      - dtheta64 (deriva em 64 amostras, janela deslizante)
--      - df em mHz (aproximado por mult + shift)
--
--      Foi identificado que o salto na estimativa (dfreq e dtheta64) ocorre
--      no instante em que a fase wrapped salta de +pi para -pi (ou vice versa).
--      O problema raiz era overflow na subtracao em 16 bits:
--         phase_now - phi_prev pode dar aproximadamente -50000 em Q13,
--         mas 16 bits so permite -32768..+32767, causando wrap aritmetico.
--      Assim, o unwrap recebia um valor ja corrompido e injetava um erro de
--      1 amostra no acumulador theta_unw, que permanecia por 64 amostras.
--
--    Solucao:
--      - Fazer a subtracao em 32 bits (sem overflow)
--      - Fazer o unwrap em 32 bits
--      - So entao reduzir para 16 bits em dphi_s
--      - Para isso, foram criados subestados:
--          S_DPHI_RAW : calcula dphi_raw_32 (registrado)
--          S_DPHI_UNW : calcula unwrap e atualiza dphi_s e phi_prev
--          S_RESIZE   : garante que o resize use o valor correto
--
--    Suavizacao:
--      - Foi adicionado um filtro IIR de primeira ordem na saida dfreq_mHz
--        para reduzir a oscilacao da estimativa.
--      - Equacao:
--          df_filt = df_filt + (df_raw_corr - df_filt)/2^IIR_SH
--      - Implementacao por shift, sem multiplicacao.
--      - Estados adicionados:
--          S_IIR0 : registra df_raw_corr (ja com correcao +63 mHz)
--          S_IIR1 : calcula df_err
--          S_OUT  : atualiza df_filt e atualiza saidas
--
--    Estados:
--      S_IDLE      : aguarda primeiro dado valido (so inicializa phi_prev)
--      S_RX        : captura fase atual
--      S_DPHI_RAW  : calcula delta de fase bruto em 32 bits (evita overflow)
--      S_DPHI_UNW  : unwrap do delta em 32 bits
--      S_RESIZE    : reduz delta para 16 bits e atualiza phi_prev
--      S_THETA     : calcula theta_new
--      S_READ      : le theta_old da memoria circular
--      S_WRITE     : escreve theta_new e atualiza ponteiro e fill
--      S_DTHETA    : calcula dtheta64
--      S_MUL       : multiplicacao pesada
--      S_SHIFT     : shift de divisao
--      S_IIR0      : registra df_raw_corr (mHz, referenciado em 60 Hz)
--      S_IIR1      : calcula erro do IIR
--      S_OUT       : atualiza saidas e gera o_valid
--
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity freq_diff_from_phasor_sliding64 is
  generic (
    ANG_WIDTH : integer := 16;
    ANG_FRAC  : integer := 13;
    M         : integer := 64;
    FS_HZ     : integer := 3844;

    -- IIR_SH controla a suavizacao
    -- 4 = pouco, 5 = medio, 6 = forte
    IIR_SH    : integer := 5
  );
  port (
    i_clk          : in  std_logic;
    i_rst          : in  std_logic;

    i_valid_phasor : in  std_logic;
    i_phase_q13    : in  signed(ANG_WIDTH-1 downto 0);

    o_valid        : out std_logic;
    o_dphi_q13     : out signed(ANG_WIDTH-1 downto 0);
    o_dtheta64_q13 : out signed(31 downto 0);
    o_dfreq_mHz    : out signed(31 downto 0)
  );
end entity;

architecture rtl of freq_diff_from_phasor_sliding64 is

  -- Constantes Q13
  constant PI_Q13     : integer := 25736;
  constant TWO_PI_Q13 : integer := 51472;

  -- Constantes em 32 bits (para comparacoes no unwrap em 32 bits)
  constant PI_Q13_32     : signed(31 downto 0) := to_signed(PI_Q13, 32);
  constant TWO_PI_Q13_32 : signed(31 downto 0) := to_signed(TWO_PI_Q13, 32);

  -- Conversao para mHz (aproximacao)
  -- df_mHz ~= dtheta64_q13 * K_MUL / 2^K_SH
  constant K_MUL : integer := 2390;
  constant K_SH  : integer := 11;

  -- Correcao para referenciar em 60 Hz e nao em FS_HZ/M
  -- FS_HZ/M = 3844/64 = 60.0625 Hz => offset = +62.5 mHz
  constant DF_OFFS_MHZ : signed(31 downto 0) := to_signed(63, 32);

  -- Memoria circular
  type theta_mem_t is array (0 to M-1) of signed(31 downto 0);
  signal theta_mem : theta_mem_t;
  signal wr_ptr    : integer range 0 to M-1 := 0;

  -- Registradores principais
  signal phi_prev    : signed(ANG_WIDTH-1 downto 0) := (others => '0');
  signal theta_unw   : signed(31 downto 0) := (others => '0');

  -- Pipeline interno (somente sinais)
  signal phase_now   : signed(ANG_WIDTH-1 downto 0) := (others => '0');

  -- Delta de fase em 32 bits para evitar overflow no wrap
  signal dphi_raw_32 : signed(31 downto 0) := (others => '0');
  signal dphi_unw_32 : signed(31 downto 0) := (others => '0');

  -- Delta final em 16 bits (Q13) usado no acumulador
  signal dphi_s      : signed(ANG_WIDTH-1 downto 0) := (others => '0');

  signal theta_new   : signed(31 downto 0) := (others => '0');
  signal theta_old_s : signed(31 downto 0) := (others => '0');

  signal dtheta64_s  : signed(31 downto 0) := (others => '0');

  signal mul_s       : signed(47 downto 0) := (others => '0');
  signal df_mHz_s    : signed(31 downto 0) := (others => '0');

  -- IIR na saida de frequencia (novo)
  signal df_raw_corr_s : signed(31 downto 0) := (others => '0');
  signal df_err_s      : signed(31 downto 0) := (others => '0');
  signal df_filt_s     : signed(31 downto 0) := (others => '0');
  signal filt_init     : std_logic := '0';

  -- Saidas registradas
  signal ovalid_r     : std_logic := '0';
  signal dphi_r       : signed(ANG_WIDTH-1 downto 0) := (others => '0');
  signal dtheta64_r   : signed(31 downto 0) := (others => '0');
  signal dfreq_mHz_r  : signed(31 downto 0) := (others => '0');

  -- Controle para manter saida em zero ate encher o buffer
  signal fill_cnt : integer range 0 to M := 0;
  signal buf_full : std_logic := '0';

  -- FSM
  type state_t is (
    S_IDLE,
    S_RX,
    S_DPHI_RAW,
    S_DPHI_UNW,
    S_RESIZE,
    S_THETA,
    S_READ,
    S_WRITE,
    S_DTHETA,
    S_MUL,
    S_SHIFT,
    S_IIR0,
    S_IIR1,
    S_OUT
  );
  signal st : state_t := S_IDLE;

begin

  o_valid        <= ovalid_r;
  o_dphi_q13     <= dphi_r;
  o_dtheta64_q13 <= dtheta64_r;
  o_dfreq_mHz    <= dfreq_mHz_r;

  process(i_clk)
  begin
    if rising_edge(i_clk) then

      if i_rst = '1' then
        st <= S_IDLE;

        wr_ptr      <= 0;
        phi_prev    <= (others => '0');
        theta_unw   <= (others => '0');

        phase_now   <= (others => '0');

        dphi_raw_32 <= (others => '0');
        dphi_unw_32 <= (others => '0');
        dphi_s      <= (others => '0');

        theta_new   <= (others => '0');
        theta_old_s <= (others => '0');
        dtheta64_s  <= (others => '0');

        mul_s       <= (others => '0');
        df_mHz_s    <= (others => '0');

        df_raw_corr_s <= (others => '0');
        df_err_s      <= (others => '0');
        df_filt_s     <= (others => '0');
        filt_init     <= '0';

        ovalid_r    <= '0';
        dphi_r      <= (others => '0');
        dtheta64_r  <= (others => '0');
        dfreq_mHz_r <= (others => '0');

        buf_full <= '0';
        fill_cnt <= 0;

      else

        -- pulso de saida de 1 ciclo
        ovalid_r <= '0';

        case st is

          -- Aguarda primeiro valid. Aqui apenas inicializa phi_prev
          -- para evitar um dphi inicial absurdo.
          when S_IDLE =>
            if i_valid_phasor = '1' then
              phi_prev  <= i_phase_q13;
              theta_unw <= (others => '0');

              -- reseta o filtro quando reinicia a captura
              df_filt_s <= (others => '0');
              filt_init <= '0';

              st <= S_RX;
            end if;

          -- Captura fase atual para processamento
          when S_RX =>
            if i_valid_phasor = '1' then
              phase_now <= i_phase_q13;
              st <= S_DPHI_RAW;
            end if;

          -- Calcula delta bruto em 32 bits (registrado)
          -- Aqui esta a correcao principal: evita overflow na subtracao em 16 bits.
          when S_DPHI_RAW =>
            dphi_raw_32 <= resize(phase_now, 32) - resize(phi_prev, 32);
            st <= S_DPHI_UNW;

          -- Unwrap do delta em 32 bits
          when S_DPHI_UNW =>
            if dphi_raw_32 > PI_Q13_32 then
              dphi_unw_32 <= dphi_raw_32 - TWO_PI_Q13_32;
            elsif dphi_raw_32 < -PI_Q13_32 then
              dphi_unw_32 <= dphi_raw_32 + TWO_PI_Q13_32;
            else
              dphi_unw_32 <= dphi_raw_32;
            end if;
            st <= S_RESIZE;

          when S_RESIZE =>
            -- Atualiza dphi em 16 bits e atualiza phi_prev
            -- O resize aqui e seguro porque dphi_unw_32 ficara proximo de zero
            -- (delta pequeno) quando a fase for coerente.
            dphi_s   <= resize(dphi_unw_32, ANG_WIDTH);
            phi_prev <= phase_now;

            st <= S_THETA;

          -- Calcula theta_new = theta_unw + dphi
          when S_THETA =>
            theta_new <= theta_unw + resize(dphi_s, 32);
            st <= S_READ;

          -- Le theta_old da memoria circular
          when S_READ =>
            theta_old_s <= theta_mem(wr_ptr);
            st <= S_WRITE;

          -- Escreve theta_new no buffer e atualiza ponteiro
          when S_WRITE =>
            theta_mem(wr_ptr) <= theta_new;

            if wr_ptr = M-1 then
              wr_ptr <= 0;
            else
              wr_ptr <= wr_ptr + 1;
            end if;

            -- Contador de preenchimento do buffer
            -- Mantem saida em zero ate que existam M amostras validas armazenadas.
            if buf_full = '0' then
              if fill_cnt = M then
                fill_cnt <= M;
                buf_full <= '1';
              else
                fill_cnt <= fill_cnt + 1;
              end if;
            end if;

            -- Atualiza acumulador principal
            theta_unw <= theta_new;

            st <= S_DTHETA;

          -- Calcula dtheta64 = theta_new - theta_old
          when S_DTHETA =>
            dtheta64_s <= theta_new - theta_old_s;
            st <= S_MUL;

          -- Multiplicacao pesada em ciclo dedicado
          -- mul_s tem 48 bits porque 32 + 16 = 48
          when S_MUL =>
            mul_s <= resize(dtheta64_s, 32) * to_signed(K_MUL, 16);
            st <= S_SHIFT;

          -- SHIFT divisao
          when S_SHIFT =>
            df_mHz_s <= resize(shift_right(mul_s, K_SH), 32);
            st <= S_IIR0;

          -- Registra df_raw_corr (ja com correcao para 60 Hz)
          when S_IIR0 =>
            df_raw_corr_s <= df_mHz_s + DF_OFFS_MHZ;
            st <= S_IIR1;

          -- Calcula erro do IIR: df_err = df_raw_corr - df_filt
          when S_IIR1 =>
            df_err_s <= df_raw_corr_s - df_filt_s;
            st <= S_OUT;

          -- Saida registrada + atualizacao do IIR
          when S_OUT =>

            -- dphi sempre sai (mesmo durante preenchimento)
            dphi_r <= dphi_s;

            -- dtheta64 e dfreq so saem validos apos buffer cheio
            if buf_full = '1' then
              dtheta64_r <= dtheta64_s;

              -- Inicializa o filtro na primeira amostra valida do buffer cheio
              -- Isso evita um transitorio longo quando comeca a filtrar.
              if filt_init = '0' then
                df_filt_s    <= df_raw_corr_s;
                dfreq_mHz_r  <= df_raw_corr_s;
                filt_init    <= '1';
              else
                -- IIR: df_filt = df_filt + (df_raw - df_filt)/2^IIR_SH
                -- Implementacao por shift (sem multiplicacao)
                df_filt_s   <= df_filt_s + shift_right(df_err_s, IIR_SH);
                dfreq_mHz_r <= df_filt_s + shift_right(df_err_s, IIR_SH);
              end if;

            else
              dtheta64_r  <= (others => '0');
              dfreq_mHz_r <= (others => '0');

              -- Mantem filtro resetado ate buffer cheio
              df_filt_s <= (others => '0');
              filt_init <= '0';
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