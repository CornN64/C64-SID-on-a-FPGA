-------------------------------------------------------------------------------
--
-- Delta-Sigma DAC
--
-- Refer to Xilinx Application Note XAPP154.
--
-- This DAC requires an external RC low-pass filter:
--
--   dac_o 0---XXXXX---+---0 analog audio
--              3k3    |
--                    === 4n7
--                     |
--                    GND
--
-------------------------------------------------------------------------------
-- to do:	- uses only 10bits out of 16. Need a higher order modulator for that
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
--use std.textio.all;	--Sim only

--Implementation Digital to Analog converter
entity sdadc is
  generic (
    DSZ : integer := 15
  );
  port (
    clk    : in  std_logic;
    reset  : in  std_logic;
    data   : in  std_logic_vector(DSZ downto 0);
    dac    : out std_logic
  );
end sdadc;

architecture rtl of sdadc is
  signal sig : unsigned(9+2 downto 0) := (others => '0');
  signal dacdly : std_logic;
begin
dac <= dacdly;

  seq: process (clk, reset)
--declare output file
--file     OUTFILE  : text is out "SDdacout.txt";
--variable VEC_LINE : line;
  begin
    if reset = '1' then
      sig  <= (others => '0');
      dacdly  <= '0';
    elsif rising_edge(clk) then
      sig  <= sig + unsigned(sig(sig'high) & sig(sig'high) & NOT data(data'high) & data(data'high-1 downto data'high-9)); --conv data 2-comp -> range Walter
      dacdly  <= sig(sig'high);
    end if;
--write line to external file.
--write(VEC_LINE, to_integer(unsigned(sig(sig'high downto sig'high))));
--writeline(OUTFILE, VEC_LINE);	
  end process seq;
end rtl;
