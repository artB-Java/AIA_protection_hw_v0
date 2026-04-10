
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity GenSineWave is
    Port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        ivalid   : in  std_logic;
        sine_out : out std_logic_vector(11 downto 0);
		ovalid	 : out std_logic
    );
end GenSineWave;




architecture Behavioral of GenSineWave is
    -- Tipo de ROM: 64 posicoes de signed(11 downto 0)
    type rom_type is array (0 to 63) of signed(11 downto 0);
    constant sine_rom : rom_type := (
        --  0 .. 10
        to_signed(    0,12), to_signed(  201,12), to_signed(  399,12), to_signed(  594,12),
        to_signed(  783,12), to_signed(  965,12), to_signed( 1137,12), to_signed( 1299,12),
        to_signed( 1447,12), to_signed( 1582,12), to_signed( 1702,12),
        -- 11 .. 21
        to_signed( 1805,12), to_signed( 1891,12), to_signed( 1959,12), to_signed( 2008,12),
        to_signed( 2037,12), to_signed( 2047,12), to_signed( 2037,12), to_signed( 2008,12),
        to_signed( 1959,12), to_signed( 1891,12), to_signed( 1805,12),
        -- 22 .. 32
        to_signed( 1702,12), to_signed( 1582,12), to_signed( 1447,12), to_signed( 1299,12),
        to_signed( 1137,12), to_signed(  965,12), to_signed(  783,12), to_signed(  594,12),
        to_signed(  399,12), to_signed(  201,12), to_signed(    0,12),
        -- 33 .. 43
        to_signed( -201,12), to_signed( -399,12), to_signed( -594,12), to_signed( -783,12),
        to_signed( -965,12), to_signed(-1137,12), to_signed(-1299,12), to_signed(-1447,12),
        to_signed(-1582,12), to_signed(-1702,12), to_signed(-1805,12),
        -- 44 .. 54
        to_signed(-1891,12), to_signed(-1959,12), to_signed(-2008,12), to_signed(-2037,12),
        to_signed(-2047,12), to_signed(-2037,12), to_signed(-2008,12), to_signed(-1959,12),
        to_signed(-1891,12), to_signed(-1805,12), to_signed(-1702,12),
        -- 55 .. 63
        to_signed(-1582,12), to_signed(-1447,12), to_signed(-1299,12), to_signed(-1137,12),
        to_signed( -965,12), to_signed( -783,12), to_signed( -594,12), to_signed( -399,12),
        to_signed( -201,12)
    );

    signal addr : unsigned(5 downto 0) := (others => '0');
    signal dout : signed(11 downto 0);
	 
	 
	 -------------------------
	 -- Componente LPM const
	 ------------------------
--	 Component Lpm_const IS
--	PORT
--	(
--		result		: OUT STD_LOGIC_VECTOR (10 DOWNTO 0)
--	);
--	END Component;
	signal s_lpm		  : STD_LOGIC_VECTOR (10 DOWNTO 0):="10000000000";
	signal s_multi_by_lpm : STD_LOGIC_VECTOR (22 DOWNTO 0); --(12 bits + 11 bits)

    
	 
	 
	signal s_valid: std_logic;
	 
	 
	 
	 
begin

--	-- Instancia LPM constant
--	LPM_CONSTANT_component : Lpm_const
--	PORT MAP (
--		result => s_lpm
--	);




    process(clk, rst)
    begin
        if rst = '1' then
            addr 			<= (others => '0');
            dout 			<= (others => '0');
			s_valid			<= '0';
			ovalid			<= '0';
			s_multi_by_lpm 	<= (others => '0');
        elsif rising_edge(clk) then
        
            if ivalid = '1' then
                dout <= sine_rom(to_integer(addr));
                ovalid			<= '1';
                addr <= addr + 1;
                --Mult the sin values for 0 até 1 -- 0 to 1024
                s_multi_by_lpm <= std_logic_vector(resize(dout*to_integer(unsigned(s_lpm)),23));
            else
                ovalid			<= '0';
            end if;
					
        end if;		
		
    end process;
	-- descarta 10 bits menos significativos para dividir resultado anterior por 1024
    sine_out <= std_logic_vector(s_multi_by_lpm(21 downto 10));

end Behavioral;
