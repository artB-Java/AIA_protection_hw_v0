library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity trip_logic_lut8 is
  port (
    i_clk      : in  std_logic;
    i_rst      : in  std_logic;

    -- S0..S7
    i_signals  : in  std_logic_vector(7 downto 0);

    -- LUT: endereço = i_signals
    i_lut_cfg  : in  std_logic_vector(255 downto 0);

    o_trip     : out std_logic
  );
end entity;

architecture rtl of trip_logic_lut8 is
begin

  process(i_clk)
begin
  if rising_edge(i_clk) then
    o_trip <= i_lut_cfg(to_integer(unsigned(i_signals)));
  end if;
end process;

end architecture;