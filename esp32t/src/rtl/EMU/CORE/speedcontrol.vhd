library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity speedcontrol is
   port
   (
      clk_sys     : in  std_logic;  -- System clock
      pause       : in  std_logic;  -- Pause signal
      speedup     : in  std_logic;  -- Manual speedup (unused in this case)
      cart_act    : in  std_logic;  -- Cartridge activity (if relevant)
      DMA_on      : in  std_logic;  -- DMA active (for memory protection)
      button_a    : in  std_logic;  -- Button A input
      button_b    : in  std_logic;  -- Button B input
      button_start: in  std_logic;  -- Start button input
      ce          : out std_logic := '0';  -- Normal clock enable
      ce_2x       : buffer std_logic := '0';  -- 2x clock enable (buffer)
      refresh     : out std_logic := '0';  -- Refresh signal
      ff_on       : out std_logic := '0'  -- Fast-forward active signal
   );
end entity;

architecture arch of speedcontrol is
   signal clkdiv           : unsigned(1 downto 0) := (others => '0'); 
   signal cart_act_1       : std_logic := '0';
   signal combo_pressed    : std_logic := '0';  -- Combo signal for Start + A + B
   signal fastforward_cnt  : integer range 0 to 15 := 0;    
   signal state            : tstate := NORMAL;

   type tstate is (
      NORMAL,
      PAUSED,
      FASTFORWARDSTART,
      FASTFORWARD,
      FASTFORWARDEND,
      RAMACCESS
   );

begin

   -- Process for handling clock cycles and states
   process(clk_sys)
   begin
      if falling_edge(clk_sys) then
         ce <= '0';
         ce_2x <= '0';
         refresh <= '0';
         cart_act_1 <= cart_act;

         -- Detect button combo: Start + A + B
         combo_pressed <= button_start and button_a and button_b;

         case (state) is
            -- Normal operation state
            when NORMAL =>
               if (pause = '1' and clkdiv = "11" and cart_act = '0') then
                  state <= PAUSED;
               elsif (combo_pressed = '1' and pause = '0' and DMA_on = '0' and clkdiv = "00") then
                  state <= FASTFORWARDSTART;
                  fastforward_cnt <= 0;
               else
                  clkdiv <= clkdiv + 1;
                  if (clkdiv = "00") then
                     ce <= '1';  -- Enable normal clock pulse
                  end if;
                  if (clkdiv(0) = '0') then
                     ce_2x <= '1';  -- Enable 2x clock pulse
                  end if;
               end if;

            -- Paused state
            when PAUSED =>
               if (pause = '0') then
                  state <= NORMAL;
               end if;

            -- Start fast-forward
            when FASTFORWARDSTART =>
               if (fastforward_cnt = 15) then
                  state <= FASTFORWARD;
                  ff_on <= '1';  -- Fast-forward active
               else
                  fastforward_cnt <= fastforward_cnt + 1;
               end if;

            -- Fast-forward mode (4x speed)
            when FASTFORWARD =>
               if (pause = '1' or combo_pressed = '0' or DMA_on = '1') then
                  state <= FASTFORWARDEND;
                  fastforward_cnt <= 0;
               else
                  clkdiv <= clkdiv + 1;
                  if clkdiv = "11" then  -- 4 cycles per frame (4x speed)
                     ce <= '1';  -- Enable clock pulse at 4x speed
                     clkdiv <= "00";  -- Reset after 4 cycles
                  end if;
                  ce_2x <= '1';
               end if;

            -- End fast-forward
            when FASTFORWARDEND =>
               state <= NORMAL;
               ff_on <= '0';  -- Disable fast-forward signal

            -- RAM access state (optional)
            when RAMACCESS =>
               state <= FASTFORWARD;
         end case;

      end if;
   end process;

end architecture;