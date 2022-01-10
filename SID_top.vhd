-------------------------------------------------------------------------------
-- Company:  N/A
-- Engineer: Walter Puccio
--
-- Create Date:   01/10/2016
-- Design Name:   
-- Description: Top module   
-- 
-- Notes: 
-- 
-------------------------------------------------------------------------------
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;

entity SID is
	port (
		RESET							: in  std_logic;	-- active low reset
		OSC 							: in  std_logic;	-- main clock 40Mhz
		Aout 							: out std_logic;	-- audio out from SD DAC
		RX	 							: in  std_logic;	-- RS232 data to FPGA
		TX  							: out std_logic		-- RS232 data from FPGA
		);
    end SID;

architecture Behavioral of SID is

	signal div  					    : std_logic_vector(2 downto 0) := (others => '0');
	signal clk1						    : std_logic := '0';	--  1 Mhz
	signal clk2						    : std_logic := '0';	--  2 Mhz
	signal clk4						    : std_logic := '0';	--  4 Mhz

	signal ADR						    : std_logic_vector(7 downto 0) := (others => '0');
	signal D_in			    		    : std_logic_vector(7 downto 0) := (others => '0');
	signal D_out			    		: std_logic_vector(7 downto 0) := (others => '0');
	signal EN			    		    : std_logic := '0';
	signal RW			    		    : std_logic := '0';

	signal WE		                	: std_logic := '0';

	signal rst							: std_logic := '0';
	signal audio_pwm			    	: std_logic := '0';

begin

  -----------------------------------------------------------------------------
  -- Signal mapping
  -----------------------------------------------------------------------------
	rst		<= NOT RESET;				    -- create active high
    WE      <= EN AND RW;

  -----------------------------------------------------------------------------
  -- CLOCKs
  -----------------------------------------------------------------------------
    Process(OSC, rst)
    begin
        if rst = '1' then 
            div <= (others => '0');
            clk4 <= '0';
            clk2 <= '0';
            clk1 <= '0';

        elsif rising_edge(OSC) then 
            if div=0 then
                clk4 <= NOT clk4;
                div <= std_logic_vector(to_unsigned(9-5, div'length));
                if clk4='0' then
                    clk2 <= NOT clk2;
                    if clk2='0' then
                        clk1 <= NOT clk1;
                    end if;
                end if;
            else
                div <= div + 1;
            end if;
        end if;
    end process;

  -----------------------------------------------------------------------------
  -- UART RS232
  -----------------------------------------------------------------------------
  	RxTx : entity work.RS232v2 
	port map (
		clk				=> OSC,
		sysclk			=> clk1,
		reset   		=> rst,
		RX				=> RX,
		TX				=> TX,
		RW				=> RW,			--Read(0)/Write(1)		
		EN				=> EN,          --Enable, active high 
		D_in		    => D_in,
		D_out		    => D_out,
		Adr				=> ADR
	);

  -----------------------------------------------------------------------------
  -- SID 6581/8580
  -----------------------------------------------------------------------------
    audio : entity work.sid6581
    port map (
			clk_1mhz		    => clk1,			-- main SID clock
			clk_DAC		    	=> clk4,			-- DAC clock signal, must be as high as possible for the best results
			reset				=> rst,				-- high active reset signal (reset when reset = '1')
			cs					=> '1',				-- "chip select", when this signal is '1' this model can be accessed
			we					=> WE,		        -- when '1' this model can be written to, otherwise access is considered as read
			addr				=> ADR(4 downto 0),	-- address lines (5 bits)
			di					=> D_out,		    -- data in (to chip, 8 bits)
			do					=> D_in,	        -- data out	(from chip, 8 bits)
			--pot_x				=> open,		    -- paddle input-X
			--pot_y				=> open,		    -- paddle input-Y
			audio_out		    => Aout	            -- this line outputs the PWM audio-signal
		);

end Behavioral;