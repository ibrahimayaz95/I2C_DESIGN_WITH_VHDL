---------------------------------------------------------------------------------------
-- Engineer: IBRAHIM AYAZ                                                            --
-- Create Date: 10.04.2023 14:00:00                                                  --
-- Design Name: I2C_SLAVE.vhd                                                        --
--                                                                                   --
-- Description: I2C Slave component design for the I2C communication protocol.       --
---------------------------------------------------------------------------------------

-- Library declaration
library IEEE;
use IEEE.std_logic_1164.all;

-- Entity declaration
entity I2C_SLAVE is
    generic (
        CLK_FREQ        :   integer := 100_000_000;                     --! Clock frequency
        I2C_BAUDRATE    :   integer := 100_000                          --! I2C baudrate
    );
    port (
        -- Input ports
        CLK                 :   in  std_logic;                          --! Clock port
        RESET               :   in  std_logic;                          --! Reset port
        SLAVE_IN_BYTE       :   in  std_logic_vector (7 downto 0);      --! Parallel data input port
        -- Output ports
        SLAVE_OUT_BYTE      :   out  std_logic_vector (7 downto 0);     --! Parallel data output port
        -- Inout ports
        SDA                 :   inout std_logic;                        --! Serial Data Line
        SCL                 :   inout std_logic                         --! Serial Clock Line
    );
end entity I2C_SLAVE;

architecture rtl of I2C_SLAVE is

    -- State type definition
    type state_type is (S_IDLE, S_ADDRESS, S_TRANSMIT, S_RECEIVE, S_WAIT, S_STOP);              --! Type for the states
    -- State signals
    signal PS, NS      :   state_type   := S_IDLE;                                              --! Present and Next State signal's declaration 

    -- Counter limit signals
    signal I2C_FULL_PERIOD          :   integer := (CLK_FREQ / I2C_BAUDRATE);                   --! One full period of SCL
    signal I2C_HALF_PERIOD          :   integer := (CLK_FREQ / I2C_BAUDRATE) / 2;               --! One half period of SCL
    signal I2C_QUARTER_PERIOD       :   integer := (CLK_FREQ / I2C_BAUDRATE) / 4;               --! One quarter period of SCL

    -- Register signals
    signal SLAVE_ADDRESS            :   std_logic_vector (6 downto 0) := ("0000111");           --! Register for the address of this particular Slave
    signal TEMP_SLAVE_IN_REG        :   std_logic_vector (7 downto 0) := (others => '0');       --! Register for the input data
    signal MAIN_SLAVE_IN_REG        :   std_logic_vector (7 downto 0) := (others => '0');       --! Shift register for the internal operations
    signal SDA_PREV                 :   std_logic := 'Z';                                       --! One clock cycle previous value of the SDA
    signal SDA_CURRENT              :   std_logic := 'Z';                                       --! Current value of the SDA
    signal SCL_CURRENT              :   std_logic := 'Z';                                       --! Current value of the SCL
    signal SCL_PREV                 :   std_logic := 'Z';                                       --! One clock cycle previous value of the SCL
    signal SDA_REG                  :   std_logic := 'Z';                                       --! Register for the Serial Data Line
    signal SCL_REG                  :   std_logic := 'Z';                                       --! Register for the Serial Clock Line
    signal COMMAND                  :   std_logic := '0';                                       --! Register for the command that is either transmit or receive
    signal SLAVE_BUSY               :   std_logic := '0';                                       --! Register for busy signal of the Slave
    signal TEMP_SLAVE_OUT_REG       :   std_logic_vector (7 downto 0) := (others => '0');       --! Register for the output data

    -- Counter signals                      
    signal SCL_COUNTER              :    integer     := 0;                                      --! Counter signal for the SCL                           
    signal DATA_COUNTER             :    integer     := 0;                                      --! Counter signal for controlling the transmit and receive states
    signal BUSY_COUNTER             :    integer     := 0;                                      --! Counter signal for the busy condition of the Slave
    signal SML_COUNTER              :    integer     := 0;                                      --! Counter signal for checking on the condition of wheter the stop state of the Master occured
    signal END_COUNTER              :    integer     := 0;                                      --! Counter signal for helping the SML counter on either ending or continuing the transaction
    signal SCL_DONE                 :    std_logic   := '0';                                    --! Done signal for the SCL counter
    signal SCL_EN                   :    std_logic   := '0';                                    --! Enable signal for the SCL counter
    signal SML_DONE                 :    std_logic   := '0';                                    --! Done signal for the SML counter
    signal SML_EN                   :    std_logic   := '0';                                    --! Enable signal for the SML counter

begin

    -- Input assignments
    TEMP_SLAVE_IN_REG    <= SLAVE_IN_BYTE;

    -- Assigning current and previous values of SDA and SCL at every clock cycle
    PREV_AND_CURRENT  :   process (CLK)
    begin
        SDA_CURRENT <= SDA;
        SDA_PREV    <= SDA_CURRENT;

        SCL_CURRENT <= SCL;
        SCL_PREV    <= SCL_CURRENT;
    end process;

    -- Counter process for checking on the condition of wheter the stop state of the Master occured
    SMALL_COUNTER:  process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (SML_EN = '1') then
                if (SML_COUNTER = 10) then
                    SML_DONE <= '1';
                    SML_COUNTER <= 0;
                else
                    SML_DONE <= '0';
                    SML_COUNTER <= SML_COUNTER + 1;
                end if;
            else
                SML_DONE <= '0';
                SML_COUNTER <= 0;
            end if;
        end if;
    end process;

    -- I2C clock generator
    SCL_CNT:    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (SCL_EN = '1') then
                if (SCL_COUNTER = I2C_QUARTER_PERIOD - 1) then
                    SCL_DONE <= '1';
                    SCL_COUNTER <= 0;
                else
                    SCL_DONE <= '0';
                    SCL_COUNTER <= SCL_COUNTER + 1;
                end if;
            else
                SCL_DONE <= '0';
                SCL_COUNTER <= 0;
            end if;
        end if;
    end process;

    -- Synchronises the states of the Main process
    FSM_SYNC:   process (CLK, RESET)
    begin
        if (RESET = '1') then
            PS <= S_IDLE;
        elsif(rising_edge(CLK)) then
            PS <= NS;
        end if;
    end process;

    -- I2C data control logic
    MAIN_P:     process (PS, SCL, RESET, SCL_DONE, SDA_PREV, SCL_PREV, SCL_CURRENT, SML_DONE, SCL_COUNTER)
    begin
        case (PS) is
            when (S_IDLE) =>

                if (SCL_PREV = 'Z' and SCL_CURRENT = '0') then
                    NS           <= S_ADDRESS;
                else
                    SCL_EN       <= '0';
                    SML_EN       <= '0';
                    SDA_REG      <= 'Z';
                    SCL_REG      <= 'Z';
                    DATA_COUNTER <= 0;
                    BUSY_COUNTER <= 0;
                    END_COUNTER  <= 0;
                    MAIN_SLAVE_IN_REG <= (others => '0');
                end if;

            when (S_ADDRESS) =>

                if (DATA_COUNTER = 8) then
                    if (falling_edge(SCL)) then
                        SCL_EN <= '1';
                        MAIN_SLAVE_IN_REG <= MAIN_SLAVE_IN_REG (6 downto 0) & MAIN_SLAVE_IN_REG (7);
                        if (BUSY_COUNTER = 8) then
                            SLAVE_BUSY <= '0';
                        else
                            SLAVE_BUSY <= '1';
                        end if;
                    elsif (SCL_DONE = '1') then
                        SCL_EN       <= '0';
                        DATA_COUNTER <= 0;
                        BUSY_COUNTER <= 0;
                        if ((MAIN_SLAVE_IN_REG (7 downto 1) = SLAVE_ADDRESS) and (SLAVE_BUSY = '0')) then
                            NS       <= S_WAIT;
                            COMMAND  <= MAIN_SLAVE_IN_REG (0);
                            SDA_REG  <= '0';
                        else
                            NS           <= S_IDLE;
                            SDA_REG      <= 'Z';
                        end if;
                    end if;
                elsif (DATA_COUNTER = 0) then
                    if (rising_edge(SCL)) then 
                        SCL_EN       <= '1';
                    elsif (SCL_DONE = '1') then
                        SCL_EN       <= '0';
                        MAIN_SLAVE_IN_REG (7) <= SDA;
                        DATA_COUNTER <= DATA_COUNTER + 1;
                        BUSY_COUNTER <= BUSY_COUNTER + 1;
                    end if;
                else
                    if (falling_edge(SCL)) then
                        MAIN_SLAVE_IN_REG <= MAIN_SLAVE_IN_REG (6 downto 0) & MAIN_SLAVE_IN_REG (7);
                    elsif (rising_edge(SCL)) then
                        SCL_EN       <= '1';
                    elsif (SCL_DONE = '1') then
                        SCL_EN       <= '0';
                        MAIN_SLAVE_IN_REG (7) <= SDA;
                        DATA_COUNTER <= DATA_COUNTER + 1;
                        BUSY_COUNTER <= BUSY_COUNTER + 1;
                    end if;
                end if;

            when (S_TRANSMIT) =>

                if (DATA_COUNTER = 9) then
                    SDA_REG <= 'Z';
                    if (rising_edge(SCL)) then
                        SCL_EN <= '1';
                    elsif (SCL_DONE = '1') then
                        SCL_EN       <= '0';
                        DATA_COUNTER <= 0;
                        if (SDA = '0') then 
                            NS <= S_WAIT;
                        else
                            NS <= S_IDLE;
                        end if;
                    end if;
                elsif (DATA_COUNTER = 0) then
                    SCL_EN       <= '1';
                    if (SML_DONE = '1') then
                        SML_EN       <= '0';
                        END_COUNTER  <= END_COUNTER + 1;
                        if (SCL = 'Z') then
                            NS           <= S_IDLE;
                        end if;
                    elsif (SDA = 'Z' and SCL = 'Z') then
                        if (END_COUNTER = 0) then
                            SML_EN       <= '1';
                        end if;
                    elsif (SCL_DONE = '1') then
                        SCL_EN       <= '0';
                        SDA_REG      <= MAIN_SLAVE_IN_REG (7);
                        DATA_COUNTER <= DATA_COUNTER + 1;
                    end if;
                else
                    SDA_REG <= MAIN_SLAVE_IN_REG (7);
                    if (falling_edge(SCL)) then
                        SCL_EN       <= '1'; 
                    elsif (SCL_DONE = '1') then
                        SCL_EN       <= '0';
                        MAIN_SLAVE_IN_REG <= MAIN_SLAVE_IN_REG (6 downto 0) & MAIN_SLAVE_IN_REG (7);
                        DATA_COUNTER <= DATA_COUNTER + 1;
                    end if;
                end if;

            when (S_RECEIVE) =>
                
                if (DATA_COUNTER = 8) then
                    if (falling_edge(SCL)) then
                        SCL_EN <= '1';
                        MAIN_SLAVE_IN_REG <= MAIN_SLAVE_IN_REG (6 downto 0) & MAIN_SLAVE_IN_REG (7);
                        if (BUSY_COUNTER = 8) then
                            SLAVE_BUSY <= '0';
                        else
                            SLAVE_BUSY <= '1';
                        end if;
                    elsif (SCL_DONE = '1') then
                        SCL_EN       <= '0';
                        DATA_COUNTER <= 0;
                        BUSY_COUNTER <= 0;
                        if (SLAVE_BUSY = '1') then 
                            NS           <= S_IDLE;
                            SDA_REG      <= 'Z';
                        else
                            NS                 <= S_WAIT;
                            SDA_REG            <= '0';
                            TEMP_SLAVE_OUT_REG <= MAIN_SLAVE_IN_REG;
                        end if;
                    end if;
                elsif (DATA_COUNTER = 0) then
                    if (SML_DONE = '1') then
                        SML_EN       <= '0';
                        END_COUNTER  <= END_COUNTER + 1;
                        if (SCL = 'Z') then
                            NS           <= S_IDLE;
                        end if;
                    elsif (SDA = 'Z' and SCL = 'Z') then
                        if (END_COUNTER = 0) then
                            SML_EN       <= '1';
                        end if;
                    elsif (rising_edge(SCL)) then 
                        SCL_EN       <= '1';
                    elsif (SCL_DONE = '1' and SCL /= 'Z') then
                        SCL_EN       <= '0';
                        MAIN_SLAVE_IN_REG (7) <= SDA;
                        DATA_COUNTER <= DATA_COUNTER + 1;
                        BUSY_COUNTER <= BUSY_COUNTER + 1;
                    end if;
                else
                    if (falling_edge(SCL)) then
                        MAIN_SLAVE_IN_REG <= MAIN_SLAVE_IN_REG (6 downto 0) & MAIN_SLAVE_IN_REG (7);
                    elsif (rising_edge(SCL)) then
                        SCL_EN       <= '1';
                    elsif (SCL_DONE = '1') then
                        SCL_EN       <= '0';
                        MAIN_SLAVE_IN_REG (7) <= SDA;
                        DATA_COUNTER <= DATA_COUNTER + 1;
                        BUSY_COUNTER <= BUSY_COUNTER + 1;
                    end if;
                end if;          

            when (S_WAIT) =>

                if (SDA_CURRENT = 'Z' and SDA_PREV = 'Z' and SCL_CURRENT = 'Z' and SCL_PREV = 'Z') then
                    NS <= S_IDLE;
                elsif (falling_edge(SCL)) then
                    SCL_EN <= '1';
                elsif (SCL_DONE = '1') then
                    SCL_EN      <= '0';
                    SDA_REG     <= 'Z';
                    END_COUNTER <= 0;
                    if (SLAVE_BUSY = '1') then
                        SCL_EN   <= '1';
                        SCL_REG  <= '0';
                    else
                        SCL_REG  <= 'Z';
                        if (COMMAND = '1') then
                            NS <= S_TRANSMIT;
                            MAIN_SLAVE_IN_REG <= TEMP_SLAVE_IN_REG;
                        elsif (COMMAND = '0') then
                            NS <= S_RECEIVE;
                            MAIN_SLAVE_IN_REG <= (others => '0');
                        end if;
                    end if;
                else
                    NS <= S_WAIT;
                end if;

            when others =>
                NS           <= S_IDLE;
                SCL_EN       <= '0'; 
                SDA_REG      <= 'Z';
                SCL_REG      <= 'Z';
                DATA_COUNTER <= 0;
                BUSY_COUNTER <= 0;
                END_COUNTER  <= 0;
                MAIN_SLAVE_IN_REG <= (others => '0');
        end case;
    end process;


    -- Output assignments
    SDA <= (SDA_REG) when (RESET = '0') else
           ('Z');
    SCL <= (SCL_REG) when (RESET = '0') else
           ('Z');

    SLAVE_OUT_BYTE <= TEMP_SLAVE_OUT_REG;

end architecture;
