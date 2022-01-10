--------------------------------------------------------------------------------
-- Company: me
-- Engineer: (c)2022 Walter Puccio
--
-- Create Date:    2022
-- Design Name:    V3
-- Module Name:    Delta Sigma DAC - 3:rd order 16bit input
--   dac 0---/\/\/---+--------||---0 audio
--            1k5    |        10uF
--                  === 4.7nF
--                   |
--                  GND
--
-- Clock rate around 4MHz will give clean 16bit audio
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
--use std.textio.all;	--Sim only

entity SDadc is

generic (bsize :integer := 15);  --DAC input bits(-1)

    Port ( clk      : in std_logic;         --clk
           reset    : in std_logic;         --reset, active high                          
 		   data     : in std_logic_vector(bsize downto 0);     --Input data two's-comp
           dac      : out std_logic    --Delta Sigma output (one bit)
          );
end SDadc;

architecture Behavioral of SDadc is

Signal SD1     : std_logic_vector(bsize+4 downto 0);
Signal SD2     : std_logic_vector(bsize+6 downto 0);
Signal SD3     : std_logic_vector(bsize+7 downto 0);

Signal FB1     : std_logic_vector(SD1'high downto 0);
Signal FB2     : std_logic_vector(SD2'high downto 0);
Signal FB3     : std_logic_vector(SD3'high downto 0);

begin
FB1 <= 0 - conv_std_logic_vector(2*2**bsize, FB1'length) when SD3(SD3'high)='0' else
       0 + conv_std_logic_vector(2*2**bsize, FB1'length);

FB2 <= 0 - conv_std_logic_vector(11*2**bsize, FB2'length) when SD3(SD3'high)='0' else
       0 + conv_std_logic_vector(11*2**bsize, FB2'length);

FB3 <= 0 - conv_std_logic_vector(25*2**bsize, FB3'length) when SD3(SD3'high)='0' else
       0 + conv_std_logic_vector(25*2**bsize, FB3'length);

Process(clk, reset)
--declare output file Sim only
--file     OUTFILE  : text is out "SDdacout.txt";
--variable VEC_LINE : line;
begin
    if reset = '1' then
        SD1 <= (others => '0');
        SD2 <= (others => '0');
        SD3 <= (others => '0');
        dac <= '0';

    elsif rising_edge(clk) then
		SD1 <= SD1 + FB1 + SXT(data, SD1'length) - SXT(SD2(SD2'high downto 10), SD1'length);
		SD2 <= SD2 + FB2 + SXT(SD1, SD2'length);
		SD3 <= SD3 + FB3 + SXT(SD2, SD3'length);
		dac <= NOT SD3(SD3'high);
--write line to external file. Sim only
--write(VEC_LINE, conv_integer(NOT SD3(SD3'high)));
--writeline(OUTFILE, VEC_LINE);	
	end if;
end process;

end Behavioral;