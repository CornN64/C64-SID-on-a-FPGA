--------------------------------------------------------------------------------
-- Company:
-- Engineer: Walter Puccio (C)2016
--
-- Create Date:    2016/1/4
-- Design Name:    
-- Module Name:    Two integrator loop biquad filter (SVF)
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity filter is

generic (isize :integer := 26;  --integrator bit size
         dpoint:integer := 13;  --Decimal point
         maxco :integer := 1;   --2Max freq cut off (higher number reduce cut off)
         maxres :integer := 4;  --Max resonance (higher number increase resonance)
         smooth :integer := 5); --FC smoothing filter

    Port ( clk      : in std_logic;                         --clk
           reset    : in std_logic;                         --reset, active high                          
 		   RES      : in std_logic_vector(3 downto 0);      --Filter resonance control
 		   FC       : in std_logic_vector(10 downto 0);     --frequency cut off
 		   fltin    : in std_logic_vector(13 downto 0);     --Input data 2-comp
           LPo      : out std_logic_vector(14 downto 0);    --filter out 2-comp
           BPo      : out std_logic_vector(14 downto 0);    --filter out 2-comp
           HPo      : out std_logic_vector(14 downto 0));   --filter out 2-comp
end filter;

architecture Behavioral of filter is

Constant offset	: std_logic_vector(4 downto 0)	:= b"0_0011";   --sets maximum level of Q for the filter
Constant LPC	: integer	:= 10;   --8LP clip bit and output gain
Constant BPC	: integer	:= 10;   --9BP clip bit and output gain
Constant HPC	: integer	:= 11;   --HP clip bit and output gain

Signal HPnD    : std_logic_vector(HPo'high downto 0);

Signal int1    : std_logic_vector(isize downto 0);
Signal int2    : std_logic_vector(isize downto 0);
Signal LP      : std_logic_vector(isize+FC'length+1 downto 0);
Signal BP      : std_logic_vector(isize+FC'length+1 downto 0);
Signal HP      : std_logic_vector(isize downto 0);
Signal Q       : std_logic_vector(BP'high+offset'high-dpoint+1 downto 0);
Signal FCs     : std_logic_vector(11 downto 0);
Signal FCo     : std_logic_vector(10 downto 0);
Signal fsum    : std_logic_vector(10+10 downto 0);
Signal rsum    : std_logic_vector(3+3 downto 0);

--
begin
Process(clk, reset)
begin
    if reset = '1' then 
        fsum  <= (others => '0');
        rsum  <= (others => '0');
    elsif rising_edge(clk) then 
        fsum <= fsum - fsum(fsum'high downto fsum'high-10) + FC;
        rsum <= rsum - rsum(rsum'high downto rsum'high-3) + RES;
	end if;
end process;

FCs <= ('0' & fsum(fsum'high downto fsum'high-FC'high)) + x"2C";   --low cutoff offset 0x28
FCo <= FCs(FCs'high-1 downto 0) when FCs(FCs'high)='0' else (others => '1');
LP <= signed(int2) * unsigned(FCo);
BP <= signed(int1) * unsigned(FCo);
Q  <= signed(BP(BP'high-1 downto dpoint)) * unsigned(NOT rsum(rsum'high downto rsum'high-RES'high) + offset);
HP <= SXT(fltin, HP'length) + SXT(Q(Q'high downto maxres), HP'length) - SXT(LP(LP'high downto dpoint+maxco), HP'length);

Process(clk, reset)
begin
    if reset = '1' then 
        int1 <= (others => '0');
        int2 <= (others => '0');
        LPo  <= (others => '0');
        BPo  <= (others => '0');
        HPnd <= (others => '0');
        HPo  <= (others => '0');

    elsif rising_edge(clk) then 
        int1 <= int1 - HP;
        int2 <= int2 - SXT(BP(BP'high downto dpoint+maxco), int2'length);

        --Filter output with hard clipping the signal at min/max
        if LP(LP'high-LPC+1)='1' AND LP(LP'high-LPC)='0' then
            LPo <= ('1', others => '0');
        elsif LP(LP'high-LPC+1)='0' AND LP(LP'high-LPC)='1' then
            LPo <= ('0', others => '1');
        else
            LPo <= LP(LP'high-LPC downto LP'high-LPo'high-LPC);
        end if;

        if BP(BP'high-BPC+1)='1' AND BP(BP'high-BPC)='0' then
            BPo <= ('1', others => '0');
        elsif BP(LP'high-BPC+1)='0' AND BP(BP'high-BPC)='1' then
            BPo <= ('0', others => '1');
        else
            BPo <= BP(BP'high-BPC downto BP'high-BPo'high-BPC);
        end if;

        if HP(HP'high-HPC+1)='1' AND HP(HP'high-HPC)='0' then
            HPnd <= ('1', others => '0');
        elsif HP(HP'high-HPC+1)='0' AND HP(HP'high-HPC)='1' then
            HPnd <= ('0', others => '1');
        else
            HPnd <= HP(HP'high-HPC downto HP'high-HPo'high-HPC);
        end if;
        HPo <= HPnd;    --delay HP one clock to match LP & BP

	end if;
end process;


end Behavioral;