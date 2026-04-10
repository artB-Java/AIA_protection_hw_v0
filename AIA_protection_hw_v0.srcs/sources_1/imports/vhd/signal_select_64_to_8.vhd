library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity signal_select_64_to_8 is
  port (
    i_all_signals : in  std_logic_vector(63 downto 0);

    i_sel_s0      : in  std_logic_vector(5 downto 0);
    i_sel_s1      : in  std_logic_vector(5 downto 0);
    i_sel_s2      : in  std_logic_vector(5 downto 0);
    i_sel_s3      : in  std_logic_vector(5 downto 0);
    i_sel_s4      : in  std_logic_vector(5 downto 0);
    i_sel_s5      : in  std_logic_vector(5 downto 0);
    i_sel_s6      : in  std_logic_vector(5 downto 0);
    i_sel_s7      : in  std_logic_vector(5 downto 0);

    o_signals     : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of signal_select_64_to_8 is
begin

  o_signals(0) <= i_all_signals(to_integer(unsigned(i_sel_s0)));
  o_signals(1) <= i_all_signals(to_integer(unsigned(i_sel_s1)));
  o_signals(2) <= i_all_signals(to_integer(unsigned(i_sel_s2)));
  o_signals(3) <= i_all_signals(to_integer(unsigned(i_sel_s3)));
  o_signals(4) <= i_all_signals(to_integer(unsigned(i_sel_s4)));
  o_signals(5) <= i_all_signals(to_integer(unsigned(i_sel_s5)));
  o_signals(6) <= i_all_signals(to_integer(unsigned(i_sel_s6)));
  o_signals(7) <= i_all_signals(to_integer(unsigned(i_sel_s7)));

end architecture;