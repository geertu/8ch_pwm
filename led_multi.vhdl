--
-- © Copyright 2014 by Geert Uytterhoeven <geert@linux-m68k.org>
--
-- This file is subject to the terms and conditions of the GNU General Public
-- License.
--
-- 8-channel PWM dimmer
--   - "nselect" selects a channel to control,
--   - "nchange" controls (brightness, on/off) the selected channel,
--   - channel 9 enables demo mode.
--
-- Pin mapping on Terasic DE0-Nano:
--
--     Signal     FPGA    I/O Standard      Function
--     ------     ----    ------------      --------
--     clk        R8      3.3V LVTTL        CLOCK_50
--     nselect    E1      2.5V (default)    KEY1 (Schmitt Trigger Debounced)
--     nchange    J15     2.5V (default)    KEY0 (Schmitt Trigger Debounced)
--     leds[0]    A15     3.3V LVTTL        LED0
--     leds[1]    A13     3.3V LVTTL        LED1
--     leds[2]    B13     3.3V LVTTL        LED2
--     leds[3]    A11     3.3V LVTTL        LED3
--     leds[4]    D1      3.3V LVTTL        LED4
--     leds[5]    F3      3.3V LVTTL        LED5
--     leds[6]    B1      3.3V LVTTL        LED6
--     leds[7]    L3      3.3V LVTTL        LED7
--     ext[0]     E9      3.3V LVTTL        GPIO_023 (JP1 pin 14)
--     ext[1]     F8      3.3V LVTTL        GPIO_021 (JP1 pin 16)
--     ext[2]     D8      3.3V LVTTL        GPIO_019 (JP1 pin 18)
--     ext[3]     E6      3.3V LVTTL        GPIO_017 (JP1 pin 20)
--     ext[4]     C6      3.3V LVTTL        GPIO_015 (JP1 pin 22)
--     ext[5]     D6      3.3V LVTTL        GPIO_013 (JP1 pin 24)
--     ext[6]     A6      3.3V LVTTL        GPIO_011 (JP1 pin 26)
--     ext[7]     D5      3.3V LVTTL        GPIO_09  (JP1 pin 28)


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity clk_div is
	generic (
		ORDER : natural
	);
	port (
		clk_in : in std_logic;
		clk_out : out std_logic
	);
end clk_div;

architecture behavioral of clk_div is
	signal cntr : std_logic_vector(ORDER downto 0);
begin
	process (clk_in)
	begin
		if (rising_edge(clk_in)) then
			cntr <= cntr + 1;
		end if;
	end process;

	clk_out <= cntr(ORDER);
end behavioral;

-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity up_down_counter is
	generic (
		MAXVAL : natural
	);
	port (
		clk : in std_logic;
		run : in std_logic;
		level : buffer natural range 0 to MAXVAL
	);
end up_down_counter;

architecture behavioral of up_down_counter is
	signal up : boolean;
	signal run0 : std_logic;
begin
	process (clk)
	begin
		if (rising_edge(clk)) then
			if (run = '1') then
				if (up) then
					if (level = MAXVAL) then
						up <= false;
					else
						level <= level + 1;
					end if;
				else
					if (level) = 0 then
						up <= true;
					else
						level <= level - 1;
					end if;
				end if;
			elsif (run0 = '1') then
				up <= not up;
			end if;
			run0 <= run;
		end if;
	end process;
end behavioral;

-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity keypress is
	generic (
		DELAY : natural
	);
	port (
		clk : in std_logic;
		key : in std_logic;
		held : out std_logic;
		pressed : out std_logic
	);
end keypress;

architecture behavioral of keypress is
	signal state : natural;
begin
	process (clk)
	begin
		if (rising_edge(clk)) then
			if (key = '1') then
				pressed <= '0';
				if (state < DELAY) then
					state <= state + 1;
				end if;
			elsif (state > 0) then
				if (state < DELAY) then
					pressed <= '1';
				end if;
				state <= 0;
			else
				pressed <= '0';
			end if;
		end if;
	end process;

	held <= '1' when (state >= DELAY) else '0';
end behavioral;

-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity selector is
	generic (
		CHANNELS : natural
	);
	port (
		clk : in std_logic;
		key : in std_logic;
		q : out std_logic_vector(CHANNELS - 1 downto 0)
	);
end selector;

architecture behavioral of selector is
	signal selection : natural range 0 to CHANNELS - 1;
	signal key0 : std_logic;
begin
	process (clk)
	begin
		if (rising_edge(clk)) then
			if (key = '1' and key0 = '0') then
				selection <= (selection + 1) mod CHANNELS;
			end if;
			key0 <= key;
			for i in 0 to CHANNELS - 1 loop
				if (i = selection) then
					q(i) <= '1';
				else
					q(i) <= '0';
				end if;
			end loop;
		end if;
	end process;
end behavioral;

-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity pwm_control is
	generic (
		MAXVAL : natural
	);
	port (
		clk_in : in std_logic;
		clk_out : buffer std_logic;
		pwm_ref : buffer natural range 0 to MAXVAL
	);
end pwm_control;

architecture behavioral of pwm_control is
begin
	process (clk_in)
	begin
		if (rising_edge(clk_in)) then
			if (pwm_ref < MAXVAL) then
				pwm_ref <= pwm_ref + 1;
				clk_out <= '0';
			else
				pwm_ref <= 0;
				clk_out <= '1';
			end if;
		end if;
	end process;
end behavioral;

-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity comparator is
	generic (
		MAXVAL : natural
	);
	port (
		clk : in std_logic;
		enable : in std_logic;
		a : in natural range 0 to MAXVAL;
		b : in natural range 0 to MAXVAL;
		q : out std_logic
	);
end comparator;

architecture behavioral of comparator is
begin
	q <= '1' when (enable = '1' and a > b) else '0';
end behavioral;

-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity dimmer is
	generic (
		LEVELS : natural
	);
	port (
		ui_clk : in std_logic;
		pwm_clk : in std_logic;
		held : in std_logic;
		pressed : in std_logic;
		pwm_ref : in natural range 0 to LEVELS - 1;
		q : out std_logic
	);
end dimmer;

architecture behavioral of dimmer is
	signal enable: std_logic;
	signal level : natural range 0 to LEVELS - 1;
	component up_down_counter
		generic (
			MAXVAL : natural
		);
		port (
			clk : in std_logic;
			run : in std_logic;
			level : buffer natural range 0 to MAXVAL
		);
	end component;
	component comparator
		generic (
			MAXVAL : natural
		);
		port (
			clk : in std_logic;
			enable : in std_logic;
			a : in natural range 0 to MAXVAL;
			b : in natural range 0 to MAXVAL;
			q : out std_logic
		);
	end component;
begin
	CNTR:	up_down_counter
		generic map (MAXVAL => LEVELS - 1)
		port map (ui_clk, held, level);

	COMP:	comparator
		generic map (MAXVAL => LEVELS - 1)
		port map (pwm_clk, enable, level, pwm_ref, q);

	process (ui_clk)
	begin
		if (rising_edge(ui_clk)) then
			if (held = '1') then
				enable <= '1';
			elsif (pressed = '1') then
				enable <= not enable;
			end if;
		end if;
	end process;
end behavioral;

-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity demo is
	generic (
		CHANNELS : natural;
		BURSTLENGTH : natural
	);
	port (
		clk : in std_logic;
		enable : in std_logic;
		start : in std_logic;
		q : out std_logic_vector(CHANNELS - 1 downto 0)
	);
end demo;

architecture behavioral of demo is
	signal cntr : std_logic_vector(BURSTLENGTH + CHANNELS downto 0);
	signal started : boolean;
begin
	process (clk)
	begin
		if (rising_edge(clk)) then
			if (started) then
				cntr <= cntr + 7;
				q <= cntr(BURSTLENGTH + CHANNELS downto
					  BURSTLENGTH + 1);
			end if;
			if (enable = '0') then
				started <= false;
				q <= (CHANNELS - 1 downto 0 => '0');
			elsif (start = '1') then
				started <= true;
			end if;
		end if;
	end process;
end behavioral;

-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity led_multi is
	port (
		clk : in std_logic;
		nselect : in std_logic;
		nchange : in std_logic;
		leds : out std_logic_vector(7 downto 0);
		ext : out std_logic_vector(7 downto 0)
	);
end led_multi;

architecture behavioral of led_multi is
	constant LEVELS : natural := 64;
	constant CHANNELS : natural := 8;
	signal pwm_clk : std_logic;
	signal ui_clk : std_logic;
	signal held : std_logic;
	signal pressed : std_logic;
	signal pwm_ref : natural range 0 to LEVELS - 1;
	signal selected : std_logic_vector(CHANNELS downto 0);
	signal demos : std_logic_vector(CHANNELS - 1 downto 0);
	signal pwm_out : std_logic_vector(7 downto 0);
	component clk_div
		generic (
			ORDER : natural
		);
		port(
			clk_in : in std_logic;
			clk_out : out std_logic
		);
	end component;
	component keypress
		generic (
			DELAY : natural
		);
		port (
			clk : in std_logic;
			key : in std_logic;
			held : out std_logic;
			pressed : out std_logic
		);
	end component;
	component selector
		generic (
			CHANNELS : natural
		);
		port (
			clk : in std_logic;
			key : in std_logic;
			q : out std_logic_vector(CHANNELS - 1 downto 0)
		);
	end component;
	component pwm_control
		generic (
			MAXVAL : natural
		);
		port (
			clk_in : in std_logic;
			clk_out : buffer std_logic;
			pwm_ref : buffer natural range 0 to MAXVAL
		);
	end component;
	component dimmer
		generic (
			LEVELS : natural
		);
		port (
			ui_clk : in std_logic;
			pwm_clk : in std_logic;
			held : in std_logic;
			pressed : in std_logic;
			pwm_ref : in natural range 0 to LEVELS - 1;
			q : out std_logic
		);
	end component;
	component demo
		generic (
			CHANNELS : natural;
			BURSTLENGTH : natural
		);
		port (
			clk : in std_logic;
			enable : in std_logic;
			start : in std_logic;
			q : out std_logic_vector(CHANNELS - 1 downto 0)
		);
	end component;
begin
	-- Base clock
	CLK0:	clk_div
		generic map (ORDER => 13)
		port map (clk, pwm_clk);

	KEY0:	keypress
		generic map (DELAY => 8)
		port map (ui_clk, not nchange, held, pressed);

	KEY1:	selector
		generic map (CHANNELS + 1)
		port map (ui_clk, not nselect, selected);

	PWM0:	pwm_control
		generic map (MAXVAL => LEVELS - 1)
		port map (pwm_clk, ui_clk, pwm_ref);

	GEN_DIM:
		for i in 0 to CHANNELS - 1 generate
		DIMx:	dimmer
			generic map (LEVELS)
			port map (ui_clk, pwm_clk,
				  (held and selected(i)) or demos(i),
				  pressed and selected(i), pwm_ref,
				  pwm_out(i));
		end generate;

	DEMO0:	demo
		generic map (CHANNELS => CHANNELS, BURSTLENGTH => 5)
		port map (ui_clk, selected(CHANNELS), held, demos);

	ext <= pwm_out;
	-- leds <= pwm_out;
end behavioral;
