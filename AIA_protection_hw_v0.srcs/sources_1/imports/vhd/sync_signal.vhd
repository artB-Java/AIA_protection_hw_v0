library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sync_signal is
    generic (
        DATA_WIDTH : integer := 12  -- Sinal de 12 bits (0 a 4095)
    );
    port (
        i_clk             : in  std_logic;
        i_rst             : in  std_logic;
        i_valid           : in  std_logic; -- Pulso de alto quando uma nova amostra chega
        i_data            : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        o_data            : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity;

architecture rtl of sync_signal is

begin
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                o_data    <= (others => '0');
            elsif i_valid = '1' then
               o_data <= i_data; 
            end if;
        end if;
    end process;
end architecture rtl;
