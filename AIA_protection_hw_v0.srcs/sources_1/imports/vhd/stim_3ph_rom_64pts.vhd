
----------------------------------------------------------------------------------
-- Company:        (user)
-- Engineer:       (user)
--
-- Create Date:    2025-12-13
-- Design Name:    Three-Phase ROM Stimulus (64 pts)
-- Module Name:    stim_3ph_rom_64pts
-- Project Name:   x001_Alan Sistema de Proteçao
-- Target Devices: FPGA (generic)
-- Tool Versions:  Vivado compatible
--
-- Description:
--   Gerador de sinais trifásicos para teste em FPGA, baseado em ROM.
--   Cada fase A/B/C possui:
--     - Uma ROM de 64 amostras (12 bits signed)
--     - Um ponteiro circular 0..63
--     - Atualização na borda de subida do clock quando i_valid_fase_X='1'
--   Saída o_valid_phase_X é um pulso de 1 clock quando a amostra é atualizada.
--
-- Inputs:
--   i_valid_fase_A/B/C: Pulso (1 clock) indicando quando consumir a próxima amostra
--
-- Outputs:
--   o_phase_A/B/C: Amostra senoidal (12 bits signed)
--   o_valid_phase_A/B/C: Pulso de 1 clock alinhado com a atualização da saída
--
-- Notes:
--   - Reset ASSÍNCRONO ativo em '1' (i_rst).
--   - Os vetores Va/Vb/Vc foram fornecidos pelo usuário e foram transcritos
--     fielmente para ROM_VA/ROM_VB/ROM_VC.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity stim_3ph_rom_64pts is
  generic (
    G_WIDTH : integer := 12;
    G_NPTS  : integer := 64
  );
  port (
    i_clk           : in  std_logic;
    i_rst           : in  std_logic;

    i_valid_fase_A  : in  std_logic;
    i_valid_fase_B  : in  std_logic;
    i_valid_fase_C  : in  std_logic;

    o_phase_A       : out signed(G_WIDTH-1 downto 0);
    o_valid_phase_A : out std_logic;

    o_phase_B       : out signed(G_WIDTH-1 downto 0);
    o_valid_phase_B : out std_logic;

    o_phase_C       : out signed(G_WIDTH-1 downto 0);
    o_valid_phase_C : out std_logic
  );
end entity;

architecture rtl of stim_3ph_rom_64pts is

  type rom_t is array (0 to G_NPTS-1) of signed(G_WIDTH-1 downto 0);

  -- ROMs (64 valores) exatamente como na tabela enviada (Va | Vb | Vc)
  constant ROM_VA : rom_t := (
     0  => to_signed(    0, G_WIDTH),
     1  => to_signed(  200, G_WIDTH),
     2  => to_signed(  399, G_WIDTH),
     3  => to_signed(  594, G_WIDTH),
     4  => to_signed(  783, G_WIDTH),
     5  => to_signed(  964, G_WIDTH),
     6  => to_signed( 1137, G_WIDTH),
     7  => to_signed( 1298, G_WIDTH),
     8  => to_signed( 1447, G_WIDTH),
     9  => to_signed( 1582, G_WIDTH),
     10 => to_signed( 1702, G_WIDTH),
     11 => to_signed( 1805, G_WIDTH),
     12 => to_signed( 1891, G_WIDTH),
     13 => to_signed( 1958, G_WIDTH),
     14 => to_signed( 2007, G_WIDTH),
     15 => to_signed( 2037, G_WIDTH),
     16 => to_signed( 2047, G_WIDTH),
     17 => to_signed( 2037, G_WIDTH),
     18 => to_signed( 2007, G_WIDTH),
     19 => to_signed( 1958, G_WIDTH),
     20 => to_signed( 1891, G_WIDTH),
     21 => to_signed( 1805, G_WIDTH),
     22 => to_signed( 1702, G_WIDTH),
     23 => to_signed( 1582, G_WIDTH),
     24 => to_signed( 1447, G_WIDTH),
     25 => to_signed( 1298, G_WIDTH),
     26 => to_signed( 1137, G_WIDTH),
     27 => to_signed(  964, G_WIDTH),
     28 => to_signed(  783, G_WIDTH),
     29 => to_signed(  594, G_WIDTH),
     30 => to_signed(  399, G_WIDTH),
     31 => to_signed(  200, G_WIDTH),
     32 => to_signed(   0, G_WIDTH),
     33 => to_signed( -201, G_WIDTH),
     34 => to_signed( -400, G_WIDTH),
     35 => to_signed( -595, G_WIDTH),
     36 => to_signed( -784, G_WIDTH),
     37 => to_signed( -965, G_WIDTH),
     38 => to_signed(-1138, G_WIDTH),
     39 => to_signed(-1299, G_WIDTH),
     40 => to_signed(-1448, G_WIDTH),
     41 => to_signed(-1583, G_WIDTH),
     42 => to_signed(-1703, G_WIDTH),
     43 => to_signed(-1806, G_WIDTH),
     44 => to_signed(-1892, G_WIDTH),
     45 => to_signed(-1959, G_WIDTH),
     46 => to_signed(-2008, G_WIDTH),
     47 => to_signed(-2038, G_WIDTH),
     48 => to_signed(-2047, G_WIDTH),
     49 => to_signed(-2038, G_WIDTH),
     50 => to_signed(-2008, G_WIDTH),
     51 => to_signed(-1959, G_WIDTH),
     52 => to_signed(-1892, G_WIDTH),
     53 => to_signed(-1806, G_WIDTH),
     54 => to_signed(-1703, G_WIDTH),
     55 => to_signed(-1583, G_WIDTH),
     56 => to_signed(-1448, G_WIDTH),
     57 => to_signed(-1299, G_WIDTH),
     58 => to_signed(-1138, G_WIDTH),
     59 => to_signed( -965, G_WIDTH),
     60 => to_signed( -784, G_WIDTH),
     61 => to_signed( -595, G_WIDTH),
     62 => to_signed( -400, G_WIDTH),
     63 => to_signed( -201, G_WIDTH)
  );

  constant ROM_VB : rom_t := (
     0  => to_signed(-1773, G_WIDTH),
     1  => to_signed(-1865, G_WIDTH),
     2  => to_signed(-1939, G_WIDTH),
     3  => to_signed(-1994, G_WIDTH),
     4  => to_signed(-2030, G_WIDTH),
     5  => to_signed(-2046, G_WIDTH),
     6  => to_signed(-2043, G_WIDTH),
     7  => to_signed(-2020, G_WIDTH),
     8  => to_signed(-1978, G_WIDTH),
     9  => to_signed(-1916, G_WIDTH),
     10 => to_signed(-1836, G_WIDTH),
     11 => to_signed(-1739, G_WIDTH),
     12 => to_signed(-1624, G_WIDTH),
     13 => to_signed(-1495, G_WIDTH),
     14 => to_signed(-1350, G_WIDTH),
     15 => to_signed(-1193, G_WIDTH),
     16 => to_signed(-1024, G_WIDTH),
     17 => to_signed( -845, G_WIDTH),
     18 => to_signed( -658, G_WIDTH),
     19 => to_signed( -465, G_WIDTH),
     20 => to_signed( -268, G_WIDTH),
     21 => to_signed(  -67, G_WIDTH),
     22 => to_signed(  133, G_WIDTH),
     23 => to_signed(  333, G_WIDTH),
     24 => to_signed(  529, G_WIDTH),
     25 => to_signed(  721, G_WIDTH),
     26 => to_signed(  905, G_WIDTH),
     27 => to_signed( 1080, G_WIDTH),
     28 => to_signed( 1246, G_WIDTH),
     29 => to_signed( 1399, G_WIDTH),
     30 => to_signed( 1539, G_WIDTH),
     31 => to_signed( 1663, G_WIDTH),
     32 => to_signed( 1772, G_WIDTH),
     33 => to_signed( 1864, G_WIDTH),
     34 => to_signed( 1938, G_WIDTH),
     35 => to_signed( 1993, G_WIDTH),
     36 => to_signed( 2029, G_WIDTH),
     37 => to_signed( 2045, G_WIDTH),
     38 => to_signed( 2042, G_WIDTH),
     39 => to_signed( 2019, G_WIDTH),
     40 => to_signed( 1977, G_WIDTH),
     41 => to_signed( 1915, G_WIDTH),
     42 => to_signed( 1835, G_WIDTH),
     43 => to_signed( 1738, G_WIDTH),
     44 => to_signed( 1623, G_WIDTH),
     45 => to_signed( 1494, G_WIDTH),
     46 => to_signed( 1349, G_WIDTH),
     47 => to_signed( 1192, G_WIDTH),
     48 => to_signed( 1023, G_WIDTH),
     49 => to_signed(  844, G_WIDTH),
     50 => to_signed(  657, G_WIDTH),
     51 => to_signed(  464, G_WIDTH),
     52 => to_signed(  267, G_WIDTH),
     53 => to_signed(   66, G_WIDTH),
     54 => to_signed( -134, G_WIDTH),
     55 => to_signed( -334, G_WIDTH),
     56 => to_signed( -530, G_WIDTH),
     57 => to_signed( -722, G_WIDTH),
     58 => to_signed( -906, G_WIDTH),
     59 => to_signed(-1081, G_WIDTH),
     60 => to_signed(-1247, G_WIDTH),
     61 => to_signed(-1400, G_WIDTH),
     62 => to_signed(-1540, G_WIDTH),
     63 => to_signed(-1664, G_WIDTH)
  );

  constant ROM_VC : rom_t := (
     0  => to_signed( 1772, G_WIDTH),
     1  => to_signed( 1663, G_WIDTH),
     2  => to_signed( 1539, G_WIDTH),
     3  => to_signed( 1399, G_WIDTH),
     4  => to_signed( 1246, G_WIDTH),
     5  => to_signed( 1080, G_WIDTH),
     6  => to_signed(  905, G_WIDTH),
     7  => to_signed(  721, G_WIDTH),
     8  => to_signed(  529, G_WIDTH),
     9  => to_signed(  333, G_WIDTH),
     10 => to_signed(  133, G_WIDTH),
     11 => to_signed(  -67, G_WIDTH),
     12 => to_signed( -268, G_WIDTH),
     13 => to_signed( -465, G_WIDTH),
     14 => to_signed( -658, G_WIDTH),
     15 => to_signed( -845, G_WIDTH),
     16 => to_signed(-1024, G_WIDTH),
     17 => to_signed(-1193, G_WIDTH),
     18 => to_signed(-1350, G_WIDTH),
     19 => to_signed(-1495, G_WIDTH),
     20 => to_signed(-1624, G_WIDTH),
     21 => to_signed(-1739, G_WIDTH),
     22 => to_signed(-1836, G_WIDTH),
     23 => to_signed(-1916, G_WIDTH),
     24 => to_signed(-1978, G_WIDTH),
     25 => to_signed(-2020, G_WIDTH),
     26 => to_signed(-2043, G_WIDTH),
     27 => to_signed(-2046, G_WIDTH),
     28 => to_signed(-2030, G_WIDTH),
     29 => to_signed(-1994, G_WIDTH),
     30 => to_signed(-1939, G_WIDTH),
     31 => to_signed(-1865, G_WIDTH),
     32 => to_signed(-1773, G_WIDTH),
     33 => to_signed(-1664, G_WIDTH),
     34 => to_signed(-1540, G_WIDTH),
     35 => to_signed(-1400, G_WIDTH),
     36 => to_signed(-1247, G_WIDTH),
     37 => to_signed(-1081, G_WIDTH),
     38 => to_signed( -906, G_WIDTH),
     39 => to_signed( -722, G_WIDTH),
     40 => to_signed( -530, G_WIDTH),
     41 => to_signed( -334, G_WIDTH),
     42 => to_signed( -134, G_WIDTH),
     43 => to_signed(   66, G_WIDTH),
     44 => to_signed(  267, G_WIDTH),
     45 => to_signed(  464, G_WIDTH),
     46 => to_signed(  657, G_WIDTH),
     47 => to_signed(  844, G_WIDTH),
     48 => to_signed( 1023, G_WIDTH),
     49 => to_signed( 1192, G_WIDTH),
     50 => to_signed( 1349, G_WIDTH),
     51 => to_signed( 1494, G_WIDTH),
     52 => to_signed( 1623, G_WIDTH),
     53 => to_signed( 1738, G_WIDTH),
     54 => to_signed( 1835, G_WIDTH),
     55 => to_signed( 1915, G_WIDTH),
     56 => to_signed( 1977, G_WIDTH),
     57 => to_signed( 2019, G_WIDTH),
     58 => to_signed( 2042, G_WIDTH),
     59 => to_signed( 2045, G_WIDTH),
     60 => to_signed( 2029, G_WIDTH),
     61 => to_signed( 1993, G_WIDTH),
     62 => to_signed( 1938, G_WIDTH),
     63 => to_signed( 1864, G_WIDTH)
  );

  -- ponteiros
  signal idx_a : integer range 0 to G_NPTS-1 := 0;
  signal idx_b : integer range 0 to G_NPTS-1 := 0;
  signal idx_c : integer range 0 to G_NPTS-1 := 0;

  -- regs de saída
  signal phase_a_r, phase_b_r, phase_c_r : signed(G_WIDTH-1 downto 0) := (others => '0');
  signal vld_a_r,   vld_b_r,   vld_c_r   : std_logic := '0';

begin

  o_phase_A <= phase_a_r;
  o_phase_B <= phase_b_r;
  o_phase_C <= phase_c_r;

  o_valid_phase_A <= vld_a_r;
  o_valid_phase_B <= vld_b_r;
  o_valid_phase_C <= vld_c_r;

  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      idx_a <= 0;
      idx_b <= 0;
      idx_c <= 0;

      phase_a_r <= (others => '0');
      phase_b_r <= (others => '0');
      phase_c_r <= (others => '0');

      vld_a_r <= '0';
      vld_b_r <= '0';
      vld_c_r <= '0';

    elsif rising_edge(i_clk) then
      -- default: valids em pulso
      vld_a_r <= '0';
      vld_b_r <= '0';
      vld_c_r <= '0';

      if i_valid_fase_A = '1' then
        phase_a_r <= ROM_VA(idx_a);
        vld_a_r   <= '1';
        if idx_a = G_NPTS-1 then idx_a <= 0; else idx_a <= idx_a + 1; end if;
      end if;

      if i_valid_fase_B = '1' then
        phase_b_r <= ROM_VB(idx_b);
        vld_b_r   <= '1';
        if idx_b = G_NPTS-1 then idx_b <= 0; else idx_b <= idx_b + 1; end if;
      end if;

      if i_valid_fase_C = '1' then
        phase_c_r <= ROM_VC(idx_c);
        vld_c_r   <= '1';
        if idx_c = G_NPTS-1 then idx_c <= 0; else idx_c <= idx_c + 1; end if;
      end if;

    end if;
  end process;

end architecture;
