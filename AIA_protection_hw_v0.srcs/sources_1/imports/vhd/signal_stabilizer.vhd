library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity signal_stabilizer is
    generic (
        DATA_WIDTH : integer := 12;  -- Sinal de 12 bits (0 a 4095)
        FIR_WINDOW : integer := 3;
        IIR_WEIGHT : integer  := 3
    );
    port (
        clk             : in  std_logic;
        reset           : in  std_logic;
        sample_en       : in  std_logic; -- Pulso de alto quando uma nova amostra chega
        data_in         : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        
        -- Saídas simultâneas de 12 bits para comparação
        out_media_movel : out std_logic_vector(DATA_WIDTH-1 downto 0);
        out_exponencial : out std_logic_vector(DATA_WIDTH-1 downto 0);
        
        -- Sinalização de que os dados filtrados estão válidos
        valid_out       : out std_logic
    );
end entity signal_stabilizer;

architecture rtl of signal_stabilizer is

    -- ==========================================================
    -- 1. SINAIS PARA O FILTRO DE MÉDIA MÓVEL (8 AMOSTRAS)
    -- ==========================================================
    constant c_window_size : integer := 2**FIR_WINDOW-1;
    
    type shift_reg_type is array (0 to c_window_size) of unsigned(DATA_WIDTH-1 downto 0);
    signal fir_reg : shift_reg_type := (others => (others => '0'));
    -- Acumulador extra de 3 bits (12 + 3 = 15 bits) para evitar overflow ao somar 8 valores
    signal fir_sum : unsigned(DATA_WIDTH + FIR_WINDOW downto 0) := (others => '0');


    -- ==========================================================
    -- 3. SINAIS PARA O FILTRO EXPONENCIAL IIR (ALFA = 1/4)
    -- ==========================================================
    -- Registrador interno com resolução extra de 2 bits para precisão fracionária
    signal iir_acc : signed(DATA_WIDTH+IIR_WEIGHT-1 downto 0) := (others => '0');

begin

    -- ==========================================================
    -- PROCESSO PRINCIPAL - ATUALIZAÇÃO DOS FILTROS EM PARALELO
    -- ==========================================================
    process(clk)
        variable v_sum   : unsigned(DATA_WIDTH+FIR_WINDOW downto 0);
        variable v_diff  : signed(DATA_WIDTH+IIR_WEIGHT-1 downto 0);
        variable v_in_s  : signed(DATA_WIDTH+IIR_WEIGHT-1 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                for i in 0 to c_window_size loop
                    fir_reg(i) <= (others => '0');
                end loop;
                fir_sum     <= (others => '0');
                iir_acc     <= (others => '0');
                valid_out   <= '0';
            elsif sample_en = '1' then
                
                -- --------------------------------------------------
                -- 1. ATUALIZAÇÃO: MÉDIA MÓVEL (FIR 8)
                -- --------------------------------------------------
                for i in c_window_size downto 1 loop
                    fir_reg(i) <= fir_reg(i-1);
                end loop;
                fir_reg(0) <= unsigned(data_in);
                
                v_sum := (others => '0');
                v_sum := v_sum + unsigned(data_in);
                for i in 1 to c_window_size loop
                    v_sum := v_sum + fir_reg(i);
                end loop;
                fir_sum <= v_sum;

                

                -- --------------------------------------------------
                -- 3. ATUALIZAÇÃO: MÉDIA EXPONENCIAL (IIR ALFA = 1/4)
                -- --------------------------------------------------
                -- Expande a entrada em 2 bits para casar com o acumulador fracionário
                --v_in_s := signed(resize(unsigned(data_in) & "00", DATA_WIDTH+2));
                v_in_s := shift_left(signed(resize(unsigned(data_in), DATA_WIDTH + IIR_WEIGHT)), IIR_WEIGHT);
                v_diff := v_in_s - iir_acc;
                -- Desloca 2 bits para a direita (= divisão por 4) e acumula
                iir_acc <= iir_acc + shift_right(v_diff, IIR_WEIGHT);

                valid_out <= '1';
            else
                valid_out <= '0';
            end if;
        end if;
    end process;

    -- ==========================================================
    -- LOGICA COMBINACIONAL - CÁLCULO DAS SAÍDAS
    -- ==========================================================
    
    -- Saída 1: Média Móvel -> Divide a soma por 8 através de shift right de 3 bits
    out_media_movel <= std_logic_vector(resize(shift_right(fir_sum, FIR_WINDOW), DATA_WIDTH));

    -- Saída 3: Exponencial -> Descarta os 2 bits fracionários inferiores
    out_exponencial <= std_logic_vector(unsigned(resize(shift_right(iir_acc, IIR_WEIGHT), DATA_WIDTH)));

end architecture rtl;
