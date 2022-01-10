##C64 SID audio chip on a FPGA which allows to play classic SID tunes through a computers COM port.
This SID VHDL implementation is based on source from http://papilio.gadgetfactory.net/index.php?n=Playground.C64SID. <br/>
Adding a digital filter to emulate the analog one present on the real SID and the undocumented modes when several waveforms<br/>
are selected for a SID voice which some sounds rely on. A 3rd order 16bit DeltaSigma DAC was added to the audio output to give<br/>
some nice quality audio reproduction. Some minor changes was done to the noise generator as well.<br/>
The implementation basically takes writes to the SID register and allows to stream SID data directly to the SID through<br/>
a 115k2 baud RS232 interface. An ACTEL A3P1500 flash FPGA was used for testing of which about 25% was occupied by the logic.<br/>
The non pipelined multiplers used for volume and filtering uses quite a bit of logic and makes the solution "slow"<br/> 

The FPGA expects a main clock of 40MHz but can be tweaked to other rates (The real SID works at 1MHz after all)<br/>
The COM port need to run as fast as possible but 115200 baud seem to run well enough for most SIDs<br/>
The audio pin require a simple RC filter with 1k5 resistor and 4n7 capacitor to ground to smooth out the SD modulator noise.<br/> 
Below you can see the interface signals need to make this work.<br/>

NRESET	: in  std_logic;	-- active low reset<br/>
OSC 	: in  std_logic;	-- main clock 40Mhz<br/>
Aout	: out std_logic;	-- audio out<br/>
RX	    : in  std_logic;	-- RS232 data to FPGA<br/>
TX  	: out std_logic		-- RS232 data from FPGA<br/>

A three pin UART FTDI USB to TTL 3.3V cable can be used to connect the computer to the FPGA RX & TX pins<br/>

First I used siddump.exe (https://csdb.dk/release/?id=152422) to dump a SID track to something that looks like this<br/>
```
|     0 | 0000  ... ..  00 0000 000 | 0000  ... ..  00 0000 000 | 0000  ... ..  00 0000 000 | 0000 00 Off 0 |
|     1 | 0116  ... ..  .. .... ... | 0116  ... ..  .. .... ... | 0116  ... ..  .. .... ... | .... .. ... F |
|     2 | ....  ... ..  .. .... ... | ....  ... ..  .. .... ... | ....  ... ..  .. .... ... | .... .. ... . |
|     3 | 02EA  ... ..  08 076F 0A0 | ....  ... ..  .. .... ... | ....  ... ..  .. .... ... | .... .. ... . |
|     4 | 7517  A-6 D1  81 .... 140 | ....  ... ..  .. .... ... | ....  ... ..  .. .... ... | .... .. ... . |
|     5 | 0BA1 (F-3 A9) 41 .... 800 | ....  ... ..  .. .... ... | ....  ... ..  .. .... ... | .... .. ... . |
|     6 | 057E (E-2 9C) .. .... ... | ....  ... ..  .. .... ... | ....  ... ..  .. .... ... | .... .. ... . |
|     7 | 02EA (F-1 91) .. .... 220 | ....  ... ..  .. .... ... | ....  ... ..  .. .... ... | .... .. ... . |
```

Then this file is parsed, translated to SID register writes and transmitted through UART/RS232 with a matlab script (see below)<br/>
All in all a fun project to hear the good old (and new) SID tunes.<br/>
Enjoy (^.^)

```
if ~exist('s','var')
    s = serial('COM5','BaudRate',115200);
    fopen(s);
    %s = 1;	%write to screen
end

fileID = fopen('R-type.txt');	%siddump file name to parse

C = textscan(fileID,'%s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s');
fclose(fileID);

fwrite(s,'W1500');
flt = 0;
vol = '0';
upd = false;
tic;

for i=1:numel(C{1,1})
    %Volume/filter
    if C{1,26}{i}(1)~='.'	%Res/ch
		fwrite(s,['w' char(23) char(hex2dec(C{1,26}{i}))]);
    end
    
    if C{1,25}{i}(1)~='.'	%Fcut
		fwrite(s,['w' char(22) char(hex2dec(C{1,25}{i}(1:2)))]);
    end
    
    if C{1,28}{i}(1)~='.'	%volume
        upd=true;
        vol=C{1,28}{i}(1);
    end

    if C{1,27}{i}(1)~='.'	%Filter mode
        upd = true;
        switch C{1,27}{i}
            case 'Off'
                flt=0;
            case 'Low'
                flt=1;
            case 'Bnd'
                flt=2;
            case 'L+B'
                flt=3;
            case 'Hi '
                flt=4;
            case 'L+H'
                flt=5;
            case 'B+H'
                flt=6;
            case 'LBH'
                flt=7;
        end
    end

    if upd == true  %Set volume and filter mode
        upd = false;
		fwrite(s,['w' char(24) char(16*flt+hex2dec(vol))]);
    end
    
    %Voice 1
    if C{1,4}{i}(1)~='.'	%Freq
        fwrite(s,['w' char(0) char(hex2dec(C{1,4}{i}(3:4))) 'w' char(1) char(hex2dec(C{1,4}{i}(1:2)))]);
    end
    if C{1,9}{i}(1)~='.'	%PWM
        fwrite(s,['w' char(3) char(hex2dec(C{1,9}{i}(1))) 'w' char(2) char(hex2dec(C{1,9}{i}(2:3)))]);
    end
    if C{1,8}{i}(1)~='.'	%ADSR
        fwrite(s,['w' char(6) char(hex2dec(C{1,8}{i}(3:4))) 'w' char(5) char(hex2dec(C{1,8}{i}(1:2)))]);
    end
    if C{1,7}{i}(1)~='.'	%CTRL
		fwrite(s,['w' char(4) char(hex2dec(C{1,7}{i}))]);
    end
    
    %Voice 2
    if C{1,11}{i}(1)~='.'	%Freq
        fwrite(s,['w' char(7) char(hex2dec(C{1,11}{i}(3:4))) 'w' char(8) char(hex2dec(C{1,11}{i}(1:2)))]);
    end
    if C{1,16}{i}(1)~='.'	%PWM
        fwrite(s,['w' char(10) char(hex2dec(C{1,16}{i}(1))) 'w' char(9) char(hex2dec(C{1,16}{i}(2:3)))]);
    end
    if C{1,15}{i}(1)~='.'	%ADSR
        fwrite(s,['w' char(13) char(hex2dec(C{1,15}{i}(3:4))) 'w' char(12) char(hex2dec(C{1,15}{i}(1:2)))]);
    end
    if C{1,14}{i}(1)~='.'	%CTRL
		fwrite(s,['w' char(11) char(hex2dec(C{1,14}{i}))]);
    end
    
    %Voice 3
    if C{1,18}{i}(1)~='.'	%Freq
        fwrite(s,['w' char(14) char(hex2dec(C{1,18}{i}(3:4))) 'w' char(15) char(hex2dec(C{1,18}{i}(1:2)))]);
    end
    if C{1,23}{i}(1)~='.'	%PWM
        fwrite(s,['w' char(17) char(hex2dec(C{1,23}{i}(1))) 'w' char(16) char(hex2dec(C{1,23}{i}(2:3)))]);
    end
    if C{1,22}{i}(1)~='.'	%ADSR
        fwrite(s,['w' char(20) char(hex2dec(C{1,22}{i}(3:4))) 'w' char(19) char(hex2dec(C{1,22}{i}(1:2)))]);
    end
    if C{1,21}{i}(1)~='.'	%CTRL
		fwrite(s,['w' char(18) char(hex2dec(C{1,21}{i}))]);
    end
    
    %fwrite(s,sprintf('\n'));
    while toc < 0.02; end;	%wait until 20ms has passed (SID update rate PAL->20ms, NTSC->16.67ms)
    tic;
end

fwrite(s,'W0410');  fwrite(s,'W0B10');  fwrite(s,'W1210'); %WAVE/GATE
%fclose(s);
```