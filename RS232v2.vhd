-- -------------------------------------------------------------
-- Company: me
-- Engineer: Walter Puccio
-- -------------------------------------------------------------
-- Module: RS232 interface 8,N,1 115200 Baud with 1MHz clk
--
-- Read  command  "RAA" <- DD
-- Write command  "WAADD"
-- AA=HEX address
-- DD=HEX data
-- Fast binary write command "wad" (lower case 'w')
-- a=8bit binary address
-- d=8bit binary data
-- -------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
--USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY rs232v2 IS

generic (clkrate :integer := 40000000;
         BMODE   :integer := 0; --(0) Normal divider, (1) NCO divider
         Baud    :integer := 115200); --Check manually the error <+-5%

   PORT( clk            :IN    std_logic;   --fast clock
         sysclk         :IN    std_logic;   --slow clock
         reset          :IN    std_logic;   --active high
         RX             :IN    std_logic;   --RX 
         TX             :OUT   std_logic;   --TX 
         RW             :OUT   std_logic;   --Read(0)/Write(1)
         EN             :OUT   std_logic;   --Enable, active high 
         D_in           :IN    std_logic_vector(7 DOWNTO 0);   --Data in
         D_out          :OUT   std_logic_vector(7 DOWNTO 0);   --Data out
         Adr            :OUT   std_logic_vector(7 DOWNTO 0)   --Address
         );

END rs232v2;

----------------------------------------------------------------
----------------------------------------------------------------
ARCHITECTURE Behavioral OF rs232v2 IS

--DEC 2 HEX
  type RomType is array (0 to 15) of std_logic_vector(7 downto 0);
  CONSTANT ROM : RomType := (x"30",x"31",x"32",x"33",x"34",x"35",x"36",x"37",
                             x"38",x"39",x"41",x"42",x"43",x"44",x"45",x"46");

  SIGNAL dec                          : std_logic_vector(3 DOWNTO 0); 

  SIGNAL bstate                       : std_logic; 
  SIGNAL bcount                       : std_logic_vector(7 DOWNTO 0); 
  SIGNAL btick                        : std_logic;  --Baud rate x8 

  SIGNAL adr_i                        : std_logic_vector(7 DOWNTO 0); 
  
  SIGNAL rstate                       : std_logic_vector(1 DOWNTO 0); 
  SIGNAL rshift_reg                   : std_logic_vector(7 DOWNTO 0); --shift register
  SIGNAL rs_cnt                       : std_logic_vector(3 DOWNTO 0); --RX sample skew
  SIGNAL rb_cnt                       : std_logic_vector(3 DOWNTO 0); --Bit count
  SIGNAL rx_rdy                       : std_logic; 

  SIGNAL tstate                       : std_logic_vector(7 DOWNTO 0); 
  SIGNAL tshift_reg                   : std_logic_vector(8 DOWNTO 0);   --include start bit 
  SIGNAL ts_cnt                       : std_logic_vector(3 DOWNTO 0); 
  SIGNAL tb_cnt                       : std_logic_vector(3 DOWNTO 0); 
  SIGNAL rw_int                       : std_logic; 
  SIGNAL en_int                       : std_logic; 

  SIGNAL pstate                       : std_logic_vector(1 DOWNTO 0); 
  SIGNAL pen_int                      : std_logic; 
  SIGNAL prw_int                      : std_logic; 
----------------------------------------------------------------
----------------------------------------------------------------
BEGIN

process(clk, reset)
begin
   	case BMODE is
        when 0 =>   --Baud generator x8, prefered Baud clock
            if reset='1' then
                bcount <= (others =>'0');
                btick <= '0';

        	elsif rising_edge(clk) then
                if bcount>((clkrate-(12*Baud))/(8*Baud)) then
                    bcount <= (others =>'0');
                    btick <= '1';
                else
                    bcount <= bcount + 1;
                    btick <= '0';
                end if;
            end if;

        when 1 =>   --Baud generator x8 can give better Baud clock but is not prefered
           	if reset='1' then
                bcount <= (others =>'0');
                bstate <= '0';
                btick <= '0';
        	elsif rising_edge(clk) then
                bcount <= bcount + ((Baud*8*128+(clkrate/2))/clkrate);  --set Baudrate
        	    case bstate is
        		    when '0' => --wait 1
                        if bcount(6)='1' then
                            btick <= '1';
                            bstate <= '1';
                        else btick <= '0';
                        end if;

        		    when '1' =>
                        btick <= '0';
                        if bcount(6)='0' then bstate <= '0';
                        end if;

        		    when  others => bstate <= '0';   -- no loose ends
        		    end case;
            end if;

        when  others => rstate <= (others =>'0');   -- no loose ends
	end case;
end process;

--HEX 2 DEC
dec <= x"0" when rshift_reg=48 else
       x"1" when rshift_reg=49 else
       x"2" when rshift_reg=50 else
       x"3" when rshift_reg=51 else
       x"4" when rshift_reg=52 else
       x"5" when rshift_reg=53 else
       x"6" when rshift_reg=54 else
       x"7" when rshift_reg=55 else
       x"8" when rshift_reg=56 else
       x"9" when rshift_reg=57 else
       x"A" when rshift_reg=65 OR rshift_reg=97 else
       x"B" when rshift_reg=66 OR rshift_reg=98 else
       x"C" when rshift_reg=67 OR rshift_reg=99 else
       x"D" when rshift_reg=68 OR rshift_reg=100 else
       x"E" when rshift_reg=69 OR rshift_reg=101 else
       x"F" when rshift_reg=70 OR rshift_reg=102 else x"0";

--RX STATEMACHINE
process(clk, reset, rstate)
begin
   	if reset='1' then
        rstate <= (others =>'0');
        rshift_reg <= (others =>'0');
        rs_cnt <= (others =>'0');
        rb_cnt <= (others =>'0');
        rx_rdy <= '0';

	elsif rising_edge(clk) then
        if btick='1' then 
		    case rstate is
			    when "00" => --Wait for start bit
                    rx_rdy <= '0';
                    rs_cnt <= x"B"; --skew bit sampling to middle
                    rb_cnt <= x"7"; --# of bits to RX(-1)
                    if RX='0' then rstate <= "01";
                    end if;

			    when "01" => -- get RX data
                    if rs_cnt=0 then
                        rs_cnt <= x"7";
                        rshift_reg <= RX & rshift_reg(7 downto 1);
                        rb_cnt <= rb_cnt - 1;
                        if rb_cnt=0 then
                            rx_rdy <= '1';
                            rstate <= "10";
                        end if;
                    else rs_cnt <= rs_cnt - 1;
                    end if;

			    when "10" => -- wait for stop bit
                    rx_rdy <= '0';
                    rs_cnt <= rs_cnt - 1;
                    if rs_cnt=0 then rstate <= "00";
                    end if;

			    when  others => rstate <= (others =>'0');   -- no loose ends
		    end case;
	    end if;
    end if;
end process;	

TX <= tshift_reg(0);
Adr(7 downto 0) <= adr_i;

--Decode & TX STATEMACHINE
process(clk, reset, tstate)
begin
   	if reset='1' then
        tstate <= (others =>'0');
        tshift_reg <= (others =>'1');
        ts_cnt <= (others =>'0');
        tb_cnt <= (others =>'0');
        rw_int <= '0';
        en_int <= '0';
        adr_i <= (others =>'0');
        D_out <= (others =>'0');

	elsif rising_edge(clk) then
        if btick='1' then 
		    case tstate is
			    when x"00" => --Wait for command
                    en_int <= '0';
                    if rx_rdy='1' then
                        if rshift_reg=82 then   --R(ead hex)?
                            rw_int <= '0';
                            tstate <= x"10";
                        elsif rshift_reg=87 then    --W(rite hex)?
                            rw_int <= '1';
                            tstate <= x"10";
                        elsif rshift_reg=119 then    --w(rite bin)?
                            rw_int <= '1';
                            tstate <= x"25";
                        end if;
                    else rw_int <= '0';
                    end if;

			    when x"10" => --Wait for (Hex) address
                    if rx_rdy='1' then
                        adr_i(7 downto 4) <= dec;
                        tstate <= x"11";
                    end if;

			    when x"11" => --Wait for (Hex) address
                    if rx_rdy='1' then
                        adr_i(3 downto 0) <= dec;
                        if rw_int='0' then
                            en_int <= '1';
                            tstate <= x"30";
                        else tstate <= x"20";
                        end if;
                    end if;
--Write(slow hex)
			    when x"20" => --Wait for (Hex) data
                    if rx_rdy='1' then
                        D_out(7 downto 4) <= dec;
                        tstate <= x"23";
                    end if;

			    when x"23" => --Wait for (Hex) data
                    if rx_rdy='1' then
                        D_out(3 downto 0) <= dec;
                        en_int <= '1';
                        tstate <= x"00";
                    end if;

--Write(fast bin)
			    when x"25" => --Wait for (bin) address
                    if rx_rdy='1' then
                        adr_i <= rshift_reg;
                        tstate <= x"26";
                    end if;

			    when x"26" => --Wait for (bin) data
                    if rx_rdy='1' then
                        D_out <= rshift_reg;
                        en_int <= '1';
                        tstate <= x"00";
                    end if;

--Read reply
			    when x"30" => --TX Data
                    en_int <= '0';
                    ts_cnt <= x"7";
                    tb_cnt <= x"A";
                    tshift_reg <= ROM(conv_integer(D_in(7 downto 4))) & '0';
                    tstate <= x"31";

			    when x"31" =>
                    if ts_cnt=0 then
                        ts_cnt <= x"7";
                        tshift_reg <= '1' & tshift_reg(8 downto 1);
                        tb_cnt <= tb_cnt - 1;
                        if tb_cnt=0 then tstate <= x"36";
                        end if;
                    else ts_cnt <= ts_cnt - 1;
                    end if;

			    when x"36" => --TX Data
                    en_int <= '0';
                    ts_cnt <= x"7";
                    tb_cnt <= x"A";
                    tshift_reg <= ROM(conv_integer(D_in(3 downto 0))) & '0';
                    tstate <= x"37";

			    when x"37" =>
                    if ts_cnt=0 then
                        ts_cnt <= x"7";
                        tshift_reg <= '1' & tshift_reg(8 downto 1);
                        tb_cnt <= tb_cnt - 1;
                        if tb_cnt=0 then tstate <= x"00";
                        end if;
                    else ts_cnt <= ts_cnt - 1;
                    end if;

			    when  others => tstate <= (others =>'X');   -- no loose ends
		    end case;
	    end if;
    end if;
end process;	

EN <= pen_int;
RW <= prw_int;

--Enable pulse
process(clk, sysclk, reset)
begin
   	if reset='1' then
        pstate <= (others =>'0');
        pen_int <= '0';
        prw_int <= '0';

	elsif rising_edge(clk) then
	    case pstate is
		    when "00" => --wait for en_int=1
                pen_int <= '0';
                prw_int <= '0';
                if en_int='1' then
                    pstate <= "01";
                end if;

		    when "01" =>
                if sysclk='0' then
                    pen_int <= '1';
                    prw_int <= rw_int;
                    pstate <= "10";
                end if;

		    when "10" =>
                if sysclk='1' then
                    pstate <= "11";
                end if;

		    when "11" => --wait for en_int=0
                if sysclk='0' AND en_int='0' then
                    pen_int <= '0';
                    pstate <= "00";
                end if;

			    when  others => pstate <= (others =>'0');   -- no loose ends
		    end case;
    end if;
end process;	
END Behavioral;