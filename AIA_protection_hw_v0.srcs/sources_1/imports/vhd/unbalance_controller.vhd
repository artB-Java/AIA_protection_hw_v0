----------------------------------------------------------------------------------
-- Module Name:    unbalance_controller
-- Description:
--   Controlador para injetar falhas e desbalanços em sinais trifásicos.
--   Recebe os sinais do gerador de ROM e aplica:
--     1) Inversão de sequência (ABC para ACB)
--     2) Queda de magnitude (Afundamentos/Sag ou Perda total) por fase
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity unbalance_controller is
  generic (
    G_WIDTH : integer := 12
  );
  port (
    i_clk           : in  std_logic;
    i_rst           : in  std_logic;

    -- Entradas: Sinais vindos do gerador stim_3ph_rom_64pts
    i_phase_A       : in  signed(G_WIDTH-1 downto 0);
    i_valid_A       : in  std_logic;
    i_phase_B       : in  signed(G_WIDTH-1 downto 0);
    i_valid_B       : in  std_logic;
    i_phase_C       : in  signed(G_WIDTH-1 downto 0);
    i_valid_C       : in  std_logic;

    -- Controles de Distúrbio
    i_seq_neg       : in  std_logic; -- '0' = ABC (Positiva), '1' = ACB (Negativa)
    
    -- Seletores de Magnitude: 
    -- "00" = 100% (Normal)
    -- "01" = 75%  (Queda leve)
    -- "10" = 50%  (Queda severa)
    -- "11" = 0%   (Perda de fase/Curto)
    i_mag_sel_A     : in  std_logic_vector(1 downto 0);
    i_mag_sel_B     : in  std_logic_vector(1 downto 0);
    i_mag_sel_C     : in  std_logic_vector(1 downto 0);

    -- Saídas: Sinais finais com desbalanço aplicado
    o_phase_A       : out signed(G_WIDTH-1 downto 0);
    o_valid_A       : out std_logic;
    o_phase_B       : out signed(G_WIDTH-1 downto 0);
    o_valid_B       : out std_logic;
    o_phase_C       : out signed(G_WIDTH-1 downto 0);
    o_valid_C       : out std_logic
  );
end entity;

architecture rtl of unbalance_controller is

    -- Sinais intermediários para o roteamento da sequência
    signal seq_A, seq_B, seq_C             : signed(G_WIDTH-1 downto 0);
    signal seq_vld_A, seq_vld_B, seq_vld_C : std_logic;

    -- Função puramente combinacional para aplicar o ganho
    function apply_magnitude(val : signed; sel : std_logic_vector(1 downto 0)) return signed is
        variable v_val : signed(val'range);
    begin
        case sel is
            when "00" => 
                v_val := val;                           -- 100%
            when "01" => 
                v_val := val - shift_right(val, 2);     -- 75%  (Valor original menos 1/4)
            when "10" => 
                v_val := shift_right(val, 1);           -- 50%  (Metade do valor)
            when "11" => 
                v_val := (others => '0');               -- 0%   (Zero)
            when others =>
                v_val := val;
        end case;
        return v_val;
    end function;

begin

    -- =========================================================
    -- 1. Roteamento de Sequência (Positiva ABC vs Negativa ACB)
    -- =========================================================
    -- A fase A permanece intacta como referência.
    -- Se i_seq_neg = '1', cruzamos os dados e os valids de B e C.
    
    seq_A     <= i_phase_A;
    seq_vld_A <= i_valid_A;

    seq_B     <= i_phase_C when i_seq_neg = '1' else i_phase_B;
    seq_vld_B <= i_valid_C when i_seq_neg = '1' else i_valid_B;

    seq_C     <= i_phase_B when i_seq_neg = '1' else i_phase_C;
    seq_vld_C <= i_valid_B when i_seq_neg = '1' else i_valid_C;


    -- =========================================================
    -- 2. Aplicação de Magnitude (Registrado para melhor timing)
    -- =========================================================
    process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            o_phase_A <= (others => '0');
            o_phase_B <= (others => '0');
            o_phase_C <= (others => '0');
            o_valid_A <= '0';
            o_valid_B <= '0';
            o_valid_C <= '0';
            
        elsif rising_edge(i_clk) then
            -- Aplica a redução e registra as saídas para não criar caminho crítico longo
            o_phase_A <= apply_magnitude(seq_A, i_mag_sel_A);
            o_valid_A <= seq_vld_A;

            o_phase_B <= apply_magnitude(seq_B, i_mag_sel_B);
            o_valid_B <= seq_vld_B;

            o_phase_C <= apply_magnitude(seq_C, i_mag_sel_C);
            o_valid_C <= seq_vld_C;
        end if;
    end process;

end architecture;