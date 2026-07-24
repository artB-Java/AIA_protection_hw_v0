library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity signal_stabilizer is
    generic (
        DATA_WIDTH : integer := 12  -- Sinal de 12 bits (0 a 4095)
    );
    port (
        clk             : in  std_logic;
        reset           : in  std_logic;
        sample_en       : in  std_logic; -- Pulso de alto quando uma nova amostra chega
        data_in         : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        
        -- Saídas simultâneas de 12 bits para comparação
        out_media_movel : out std_logic_vector(DATA_WIDTH-1 downto 0);
        out_mediana     : out std_logic_vector(DATA_WIDTH-1 downto 0);
        out_exponencial : out std_logic_vector(DATA_WIDTH-1 downto 0);
        
        -- Sinalização de que os dados filtrados estão válidos
        valid_out       : out std_logic
    );
end entity signal_stabilizer;

architecture rtl of signal_stabilizer is

    -- ==========================================================
    -- 1. SINAIS PARA O FILTRO DE MÉDIA MÓVEL (8 AMOSTRAS)
    -- ==========================================================
    type shift_reg_type is array (0 to 7) of unsigned(DATA_WIDTH-1 downto 0);
    signal fir_reg : shift_reg_type := (others => (others => '0'));
    -- Acumulador extra de 3 bits (12 + 3 = 15 bits) para evitar overflow ao somar 8 valores
    signal fir_sum : unsigned(DATA_WIDTH+2 downto 0) := (others => '0');

    -- ==========================================================
    -- 2. SINAIS PARA O FILTRO DA MEDIANA (3 AMOSTRAS)
    -- ==========================================================
    signal med_0, med_1, med_2 : unsigned(DATA_WIDTH-1 downto 0) := (others => '0');
    signal med_result          : unsigned(DATA_WIDTH-1 downto 0) := (others => '0');

    -- ==========================================================
    -- 3. SINAIS PARA O FILTRO EXPONENCIAL IIR (ALFA = 1/4)
    -- ==========================================================
    -- Registrador interno com resolução extra de 2 bits para precisão fracionária
    signal iir_acc : signed(DATA_WIDTH+1 downto 0) := (others => '0');

begin

    -- ==========================================================
    -- PROCESSO PRINCIPAL - ATUALIZAÇÃO DOS FILTROS EM PARALELO
    -- ==========================================================
    process(clk)
        variable v_sum   : unsigned(DATA_WIDTH+2 downto 0);
        variable v_diff  : signed(DATA_WIDTH+1 downto 0);
        variable v_in_s  : signed(DATA_WIDTH+1 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                for i in 0 to 7 loop
                    fir_reg(i) <= (others => '0');
                end loop;
                fir_sum     <= (others => '0');
                med_0       <= (others => '0');
                med_1       <= (others => '0');
                med_2       <= (others => '0');
                iir_acc     <= (others => '0');
                valid_out   <= '0';
            elsif sample_en = '1' then
                
                -- --------------------------------------------------
                -- 1. ATUALIZAÇÃO: MÉDIA MÓVEL (FIR 8)
                -- --------------------------------------------------
                for i in 7 downto 1 loop
                    fir_reg(i) <= fir_reg(i-1);
                end loop;
                fir_reg(0) <= unsigned(data_in);
                
                v_sum := (others => '0');
                v_sum := v_sum + unsigned(data_in);
                for i in 0 to 6 loop
                    v_sum := v_sum + fir_reg(i);
                end loop;
                fir_sum <= v_sum;

                -- --------------------------------------------------
                -- 2. ATUALIZAÇÃO: FILTRO DA MEDIANA (JANELA 3)
                -- --------------------------------------------------
                med_2 <= med_1;
                med_1 <= med_0;
                med_0 <= unsigned(data_in);

                -- --------------------------------------------------
                -- 3. ATUALIZAÇÃO: MÉDIA EXPONENCIAL (IIR ALFA = 1/4)
                -- --------------------------------------------------
                -- Expande a entrada em 2 bits para casar com o acumulador fracionário
                v_in_s := signed(resize(unsigned(data_in) & "00", DATA_WIDTH+2));
                v_diff := v_in_s - iir_acc;
                -- Desloca 2 bits para a direita (= divisão por 4) e acumula
                iir_acc <= iir_acc + shift_right(v_diff, 2);

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
    out_media_movel <= std_logic_vector(resize(shift_right(fir_sum, 3), DATA_WIDTH));

    -- Saída 2: Mediana -> Algoritmo de ordenação paralela para 3 amostras
    process(med_0, med_1, med_2)
    begin
        if (med_0 <= med_1 and med_0 >= med_2) or (med_0 >= med_1 and med_0 <= med_2) then
            med_result <= med_0;
        elsif (med_1 <= med_0 and med_1 >= med_2) or (med_1 >= med_0 and med_1 <= med_2) then
            med_result <= med_1;
        else
            med_result <= med_2;
        end if;
    end process;
    out_mediana <= std_logic_vector(med_result);

    -- Saída 3: Exponencial -> Descarta os 2 bits fracionários inferiores
    out_exponencial <= std_logic_vector(unsigned(resize(shift_right(iir_acc, 2), DATA_WIDTH)));

end architecture rtl;
