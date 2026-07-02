----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 22.05.2026 14:03:47
-- Design Name: 
-- Module Name: XadcDcOffsetCalibrator - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity XadcDcOffsetCalibrator is
    generic (
        -- G_ACCUM_BITS define a janela da média. 
        -- 16 significa 2^16 = 65536 amostras. 
        -- A divisão no final é feita apenas ignorando os 16 bits menos significativos (shift right).
        G_ACCUM_BITS : natural := 14 
    );
    port (
        i_clk          : in  std_logic;
        i_rst          : in  std_logic;
        
        -- Sinal BRUTO vindo direto do XADC (0 a 4095)
        i_data_raw     : in  std_logic_vector(11 downto 0); 
        i_valid        : in  std_logic;                     

        -- Saída com o Offset DC calculado (pronto para ser lido pelo Vitis)
        o_offset_avg   : out std_logic_vector(11 downto 0); 
        o_offset_valid : out std_logic                      
    );
end entity XadcDcOffsetCalibrator;

architecture rtl of XadcDcOffsetCalibrator is
    -- Acumulador: 12 bits de dados + 16 bits de acúmulo = 28 bits no total
    signal r_acc   : unsigned(11 + G_ACCUM_BITS downto 0) := (others => '0');
    -- Contador de amostras
    signal r_count : unsigned(G_ACCUM_BITS - 1 downto 0)  := (others => '0');
begin

    process(i_clk, i_rst)
        variable v_next_acc : unsigned(11 + G_ACCUM_BITS downto 0);
    begin
        if i_rst = '1' then
            r_acc          <= (others => '0');
            r_count        <= (others => '0');
            o_offset_avg   <= (others => '0');
            o_offset_valid <= '0';
            
        elsif rising_edge(i_clk) then
            -- Default para o pulso de validade
            o_offset_valid <= '0'; 

            if i_valid = '1' then
                -- Soma a amostra atual ao acumulador
                v_next_acc := r_acc + unsigned(i_data_raw);
                
                -- Se o contador atingiu o valor máximo (ex: 65535 para 16 bits)
                if r_count = (r_count'range => '1') then
                    
                    -- A DIVISÃO por 2^16 é feita simplesmente pegando os 12 bits superiores
                    o_offset_avg <= std_logic_vector(v_next_acc(11 + G_ACCUM_BITS downto G_ACCUM_BITS));
                    o_offset_valid <= '1';
                    
                    -- Zera o acumulador para a próxima janela
                    r_acc <= (others => '0');
                else
                    -- Continua acumulando
                    r_acc <= v_next_acc;
                end if;
                
                -- Incrementa o contador (rola naturalmente para 0 por overflow)
                r_count <= r_count + 1;
                
            end if;
        end if;
    end process;

end architecture rtl;
