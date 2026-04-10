-- ============================================================================
--  Block       : siggen_dc_h3_lut
--  Author      : André A. dos Anjos
--  Description :
--    Gerador de amostras por LUT fixa: DC + fundamental (60 Hz) + 3a harmônica.
--    A cada pulso i_valid='1', emite uma amostra e incrementa o índice da LUT.
--
--    LUT gerada para N=64 amostras/ciclo (fs=3840 Hz para f0=60 Hz):
--      f0   = 60
--      A1   = 1024
--      A3   = 128
--      phi3 = pi/5
--      DC   = 1024
--      x[n] = floor(DC + A1*sin(2*pi*n/N) + A3*sin(2*pi*3*n/N + phi3))
--
--  Ports:
--    i_clk    : clock
--    i_rst    : reset síncrono (ativo em '1')
--    i_valid  : pulso 1 ciclo solicitando próxima amostra
--    o_valid  : pulso 1 ciclo indicando o_sample válido
--    o_sample : amostra (unsigned, 12 bits)
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity siggen_dc_h3_lut is
  generic (
    G_W : integer := 12;   -- largura de saída (bits)
    G_N : integer := 64    -- tamanho da LUT (fixo em 64 nesta versão)
  );
  port (
    i_clk    : in  std_logic;
    i_rst    : in  std_logic;
    i_valid  : in  std_logic;

    o_valid  : out std_logic;
    o_sample : out std_logic_vector(G_W-1 downto 0)
  );
end entity;

architecture rtl of siggen_dc_h3_lut is

  type t_lut is array (0 to G_N-1) of integer;

  -- LUT fixa (N=64)
 -- constant C_LUT : t_lut := (
 --     0 => 1099,  1 => 1226,  2 => 1343,  3 => 1449,
 --     4 => 1540,  5 => 1617,  6 => 1679,  7 => 1729,
 --     8 => 1768,  9 => 1798, 10 => 1821, 11 => 1842,
 --    12 => 1860, 13 => 1880, 14 => 1900, 15 => 1922,
 --    16 => 1944, 17 => 1965, 18 => 1984, 19 => 1996,
 --    20 => 1999, 21 => 1991, 22 => 1969, 23 => 1930,
 --    24 => 1874, 25 => 1800, 26 => 1709, 27 => 1602,
 --    28 => 1482, 29 => 1353, 30 => 1218, 31 => 1082,
 --    32 =>  948, 33 =>  821, 34 =>  704, 35 =>  598,
 --    36 =>  507, 37 =>  430, 38 =>  368, 39 =>  318,
 --    40 =>  279, 41 =>  249, 42 =>  226, 43 =>  205,
 --    44 =>  187, 45 =>  167, 46 =>  147, 47 =>  125,
 --    48 =>  103, 49 =>   82, 50 =>   63, 51 =>   51,
 --    52 =>   48, 53 =>   56, 54 =>   78, 55 =>  117,
 --    56 =>  173, 57 =>  247, 58 =>  338, 59 =>  445,
 --    60 =>  565, 61 =>  694, 62 =>  829, 63 =>  965
 -- );
 
   constant C_LUT : t_lut := (
      0 => 2123,  1 => 2250,  2 => 2367,  3 => 2473,
      4 => 2564,  5 => 2641,  6 => 2703,  7 => 2753,
      8 => 2792,  9 => 2822, 10 => 2845, 11 => 2866,
     12 => 2884, 13 => 2904, 14 => 2924, 15 => 2946,
     16 => 2968, 17 => 2989, 18 => 3008, 19 => 3020,
     20 => 3023, 21 => 3015, 22 => 2993, 23 => 2954,
     24 => 2898, 25 => 2824, 26 => 2733, 27 => 2626,
     28 => 2506, 29 => 2377, 30 => 2242, 31 => 2106,
     32 => 1972, 33 => 1845, 34 => 1728, 35 => 1622,
     36 => 1531, 37 => 1454, 38 => 1392, 39 => 1342,
     40 => 1303, 41 => 1273, 42 => 1250, 43 => 1229,
     44 => 1211, 45 => 1191, 46 => 1171, 47 => 1149,
     48 => 1127, 49 => 1106, 50 => 1087, 51 => 1075,
     52 => 1072, 53 => 1080, 54 => 1102, 55 => 1141,
     56 => 1197, 57 => 1271, 58 => 1362, 59 => 1469,
     60 => 1589, 61 => 1718, 62 => 1853, 63 => 1989
  );


  signal r_idx    : integer range 0 to G_N-1 := 0;
  signal r_valid  : std_logic := '0';
  signal r_sample : unsigned(G_W-1 downto 0) := (others => '0');

begin

  o_valid  <= r_valid;
  o_sample <= std_logic_vector(r_sample);

  process(i_clk)
    variable v_next_idx : integer;
    variable v_samp_int : integer;
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        r_idx    <= 0;
        r_valid  <= '0';
        r_sample <= (others => '0');
      else
        r_valid <= '0';

        if i_valid = '1' then
          v_samp_int := C_LUT(r_idx);

          -- Saturação simples para caber em G_W (opcional, mas seguro)
          if v_samp_int < 0 then
            v_samp_int := 0;
          elsif v_samp_int > (2**G_W - 1) then
            v_samp_int := (2**G_W - 1);
          end if;

          r_sample <= to_unsigned(v_samp_int, G_W);
          r_valid  <= '1';

          if r_idx = G_N-1 then
            v_next_idx := 0;
          else
            v_next_idx := r_idx + 1;
          end if;
          r_idx <= v_next_idx;
        end if;
      end if;
    end if;
  end process;

end architecture;
