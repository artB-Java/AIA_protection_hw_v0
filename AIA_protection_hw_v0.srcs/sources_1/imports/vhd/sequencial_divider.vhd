library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sequencial_divider is
    generic (
        W_NUM  : integer := 12; -- Largura de bits do Numerador 
        W_DEN  : integer := 12; -- Largura de bits do Denominador 
        W_FRAC : integer := 12  -- Quantos bits fracionários queremos no resultado (Ex: Q12.12)
    );
    port (
        i_clk   : in  std_logic;
        i_rst   : in  std_logic;
        
        -- Sinais de Controlo
        i_start : in  std_logic; -- Pulso de 1 ciclo para iniciar a divisão
        o_ready : out std_logic; -- Fica a '1' quando a divisão termina
        
        -- Entradas de Dados (Unsigned)
        i_num   : in  unsigned(W_NUM - 1 downto 0);
        i_den    : in  unsigned(W_DEN - 1 downto 0);
        
        -- Saída (Resultado = (V2 << W_FRAC) / V1 )
        -- A largura total da saída será a largura do Numerador + Bits Fracionários
        o_ratio : out unsigned((W_NUM + W_FRAC) - 1 downto 0) 
    );
end entity;

architecture rtl of sequencial_divider is

    type state_type is (IDLE, DIVIDIR, CONCLUIDO);
    signal state : state_type;

    -- O número total de iterações é igual ao tamanho do dividendo expandido
    constant W_ITER : integer := W_NUM + W_FRAC;

    -- Registos de deslocamento (Shift Registers) para o algoritmo
    signal dividendo_reg : unsigned(W_ITER - 1 downto 0);
    signal quociente_reg : unsigned(W_ITER - 1 downto 0);
    
    -- O resto precisa de ter 1 bit a mais que o denominador para evitar overflow na subtração
    signal resto   : unsigned(W_DEN downto 0);
    signal divisor : unsigned(W_DEN - 1 downto 0);
    
    -- Contador de ciclos
    signal contador : integer range 0 to W_ITER;

begin

    process(i_clk)
        variable temp_resto : unsigned(W_DEN downto 0);
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                state <= IDLE;
                o_ready <= '0';
                o_ratio <= (others => '0');
            else
                case state is
                    
                    when IDLE =>
                        o_ready <= '0';
                        if i_start = '1' then
                            -- Prepara o dividendo (V2) concatenando zeros à direita (W_FRAC)
                            -- Isto é o equivalente matemático a multiplicar V2 pela resolução desejada
                            dividendo_reg <= i_num & to_unsigned(0, W_FRAC);
                            divisor       <= i_den;
                            
                            quociente_reg <= (others => '0');
                            resto         <= (others => '0');
                            contador      <= W_ITER;

                            -- Prevenção básica contra divisão por zero
                            if i_den = 0 then
                                o_ratio <= (others => '1'); -- Saturação no valor máximo
                                state   <= CONCLUIDO;
                            else
                                state   <= DIVIDIR;
                            end if;
                        end if;

                    when DIVIDIR =>
                        -- 1. Desloca o bit mais significativo (MSB) do dividendo para o resto
                        temp_resto := (resto(W_DEN-1 downto 0) & dividendo_reg(W_ITER-1));

                        -- 2. Verifica se o resto temporário é maior ou igual ao divisor
                        if temp_resto >= ("0" & divisor) then
                            -- Se cabe: subtrai e insere '1' no quociente
                            resto <= temp_resto - ("0" & divisor);
                            quociente_reg <= quociente_reg(W_ITER-2 downto 0) & '1';
                        else
                            -- Se não cabe: mantém o resto e insere '0' no quociente
                            resto <= temp_resto;
                            quociente_reg <= quociente_reg(W_ITER-2 downto 0) & '0';
                        end if;

                        -- 3. Desloca o dividendo para a esquerda (prepara o próximo bit)
                        dividendo_reg <= dividendo_reg(W_ITER-2 downto 0) & '0';

                        -- 4. Controlo do laço de repetição
                        if contador = 1 then
                            state <= CONCLUIDO;
                        else
                            contador <= contador - 1;
                        end if;

                    when CONCLUIDO =>
                        -- Entrega o resultado e emite o pulso de pronto
                        o_ratio <= quociente_reg;
                        o_ready <= '1';
                        
                        -- Volta ao início imediatamente (podendo aceitar nova divisão no ciclo seguinte)
                        state <= IDLE;
                        
                end case;
            end if;
        end if;
    end process;

end architecture;
