----------------------------------------------------------------------------------
--
-- (c) 2011 Thomas 'skoe' Giesel
--
-- This software is provided 'as-is', without any express or implied
-- warranty.  In no event will the authors be held liable for any damages
-- arising from the use of this software.
--
-- Permission is granted to anyone to use this software for any purpose,
-- including commercial applications, and to alter it and redistribute it
-- freely, subject to the following restrictions:
--
-- 1. The origin of this software must not be misrepresented; you must not
--    claim that you wrote the original software. If you use this software
--    in a product, an acknowledgment in the product documentation would be
--    appreciated but is not required.
-- 2. Altered source versions must be plainly marked as such, and must not be
--    misrepresented as being the original software.
-- 3. This notice may not be removed or altered from any source distribution.
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cart_kernal is
    port (
        clk:                in  std_logic;
        n_reset:            in  std_logic;
        enable:             in  std_logic;
        phi2:               in  std_logic;
        ba:                 in  std_logic;
        n_romh:             in  std_logic;
        n_wr:               in  std_logic;
        addr_ready:         in  std_logic;
        bus_ready:          in  std_logic;
        phase_pos:          in  std_logic_vector(10 downto 0);
        cycle_start:        in  std_logic;
        set_bank:           in  std_logic;
        addr:               in  std_logic_vector(15 downto 0);
        data:               in  std_logic_vector(7 downto 0);
        button_crt_reset:   in  std_logic;
        flash_addr:         out std_logic_vector(16 downto 0);
        n_dma:              out std_logic;
        a14:                out std_logic;
        n_game:             out std_logic;
        n_exrom:            out std_logic;
        start_reset:        out std_logic;
        flash_read:         out std_logic;
        hiram:              out std_logic
    );
end cart_kernal;

architecture behav of cart_kernal is
    signal kernal_space_addressed:  boolean;
    signal kernal_space_cpu_read:   boolean;
    signal kernal_read_active:      boolean;
    signal kernal_started:          std_logic;
    signal bank:                    std_logic_vector(2 downto 0);
begin

    kernal_space_addressed <= true when addr(15 downto 13) = "111" else false;

    kernal_space_cpu_read <= true when kernal_space_addressed and
        phi2 = '1' and ba = '1' and n_wr = '1'
        else false;

    start_reset <= enable and button_crt_reset;

    ---------------------------------------------------------------------------
    -- Note: When the bank is set, the KERNAL is _not_ yet enabled
    ---------------------------------------------------------------------------
    set_kernal_bank: process(clk)
    begin
        -- todo: reset?
        if rising_edge(clk) then
            if set_bank = '1' then
                bank <= data(2 downto 0);
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    --
    -- VIC-II needs address input in this time window (times after Phi2):
    --      min: Trhl_min - Tasrin = 155 ns - 25 ns = 130 ns
    --      max: Trhl_max + Trahin = 190 ns + 0 ns  = 190 ns
    -- phase_pos(3) ends at 160..200 ns, so we can set DMA at this cycle
    --
    --
    -- DMA bei:     0   1   2   3   4   5   6   7   8
    -- 250407:      OK  OK  OK  OK  NOK ?   ?   NOK NOK
    -- 250469:      OK  OK  OK  OK  OK  ?   ?   NOK NOK
    -- Zwei Zyklen:
    -- 250407:          OK> OK>
    -- 250469:          OK> OK>
    -- nok: 7, 8
    ---------------------------------------------------------------------------
    detect_hiram: process(n_reset, phi2, clk)
    begin
        if n_reset = '0' then
            n_game  <= '1';
            n_exrom <= '1';
            a14 <= '1';
            n_dma <= '1';
            hiram <= '0';
            kernal_started <= '0';
            kernal_read_active <= false;
        elsif rising_edge(clk) then
            if enable = '1' then

                if phase_pos(2) = '1' and kernal_space_cpu_read then
                    n_dma <= '0';
                    a14 <= '0';
                    n_game  <= '0';
                    n_exrom <= '0';
                    kernal_read_active <= true;
                end if;

                if kernal_read_active then
                    if phase_pos(4) = '1' then
                        -- Release everything and check for hiram
                        a14 <= '1';
                        n_dma <= '1';
                        -- ROMH reflects HIRAM now
                        if n_romh = '1' then
                            -- ram
                            n_game  <= '1';
                            n_exrom <= '1';
                        else
                            kernal_started <= '1'; -- first access seen
                            -- rom
                            n_exrom <= '1'; -- Ultimax mode
                        end if;
                    end if;
                end if; -- kernal_read_active

                if cycle_start = '1' then
                    -- KERNAL read complete
                    n_game  <= kernal_started; -- for C128 start
                    n_exrom <= '1';
                    a14 <= '1';
                    --n_dma <= '1';
                    kernal_read_active <= false;
                end if;
            else -- enable
                n_game  <= '1';
                n_exrom <= '1';
                a14 <= '1';
                n_dma <= '1';
                hiram <= '0';
                kernal_read_active <= false;
            end if; -- enable
        end if; -- clk
    end process;


    ---------------------------------------------------------------------------
    -- We keep the machine in Ultimax mode until the KERNAL started
    -- definitely. This is the case when we get ROMH the first time.
    -- We do this to force the C128 into C64 mode when a KERNAL shall be
    -- started. Otherwise it would always go to C128 mode.
    ---------------------------------------------------------------------------

    ---------------------------------------------------------------------------
    -- Combinatorically create the next memory address.
    -- Always read from part usually used for ROML, because there we have
    -- the boot sectors which contain the KERNAL images
    ---------------------------------------------------------------------------
    create_mem_addr: process(bank, addr)
    begin
        flash_addr <= (others => '0');
        flash_addr(15 downto 0) <= bank & addr(12 downto 0);
    end process;

    ---------------------------------------------------------------------------
    -- Combinatorical logic to prepare the address to be latched to the
    -- internal address bus. Additionally the signal which enables
    -- the latches at the next CLK cycle is prepared here.
    ---------------------------------------------------------------------------
    create_mem_ctrl: process(enable, addr, phase_pos,
                             kernal_space_cpu_read)
    begin
        flash_read <= '0';

        if enable = '1' then
            if phase_pos(0) = '1' and kernal_space_cpu_read then
                -- start speculative flash read to hide its latency
                flash_read <= '1';
            end if;
        end if;
    end process;

end architecture behav;
