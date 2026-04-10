library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity boolean_logic_64in_lut8 is
  port (
    i_clk         : in  std_logic;
    i_rst         : in  std_logic;

    -- 64 sinais disponíveis no sistema
    i_all_signals : in  std_logic_vector(63 downto 0);

    -- Seleção de quais sinais entram como S0..S7
    i_sel_s0      : in  std_logic_vector(5 downto 0);
    i_sel_s1      : in  std_logic_vector(5 downto 0);
    i_sel_s2      : in  std_logic_vector(5 downto 0);
    i_sel_s3      : in  std_logic_vector(5 downto 0);
    i_sel_s4      : in  std_logic_vector(5 downto 0);
    i_sel_s5      : in  std_logic_vector(5 downto 0);
    i_sel_s6      : in  std_logic_vector(5 downto 0);
    i_sel_s7      : in  std_logic_vector(5 downto 0);

    -- LUT programável
    i_lut_cfg     : in  std_logic_vector(255 downto 0);

    -- Sinais selecionados para debug
    o_selected_s  : out std_logic_vector(7 downto 0);

    -- Saída lógica final
    o_trip        : out std_logic
  );
end entity;

architecture rtl of boolean_logic_64in_lut8 is

  component signal_select_64_to_8 is
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
  end component;

  component trip_logic_lut8 is
    port (
      i_clk      : in  std_logic;
      i_rst      : in  std_logic;
      i_signals  : in  std_logic_vector(7 downto 0);
      i_lut_cfg  : in  std_logic_vector(255 downto 0);
      o_trip     : out std_logic
    );
  end component;

  signal s_selected : std_logic_vector(7 downto 0);

begin

  u_select : signal_select_64_to_8
    port map (
      i_all_signals => i_all_signals,
      i_sel_s0      => i_sel_s0,
      i_sel_s1      => i_sel_s1,
      i_sel_s2      => i_sel_s2,
      i_sel_s3      => i_sel_s3,
      i_sel_s4      => i_sel_s4,
      i_sel_s5      => i_sel_s5,
      i_sel_s6      => i_sel_s6,
      i_sel_s7      => i_sel_s7,
      o_signals     => s_selected
    );

  u_lut : trip_logic_lut8
    port map (
      i_clk      => i_clk,
      i_rst      => i_rst,
      i_signals  => s_selected,
      i_lut_cfg  => i_lut_cfg,
      o_trip     => o_trip
    );

  o_selected_s <= s_selected;

end architecture;