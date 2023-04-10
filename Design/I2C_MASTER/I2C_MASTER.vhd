---------------------------------------------------------------------------------------
-- Engineer: IBRAHIM AYAZ                                                            --
-- Create Date: 10.04.2023 14:00:00                                                  --
-- Design Name: I2C_MASTER.vhd                                                       --
--                                                                                   --
-- Description: I2C Master component design for the I2C communication protocol.      --
---------------------------------------------------------------------------------------

-- Library declaration
library IEEE;
use IEEE.std_logic_1164.all;

-- Entity declaration
entity I2C_MASTER is
    generic (
        CLK_FREQ        :   integer := 100_000_000;                         --! Clock frequency
        --! I2C baudrate
        I2C_BAUDRATE    :   integer := 100_000                              
    );
    port (
        -- Input ports
        CLK                 :   in  std_logic;                              --! Clock port
        RESET               :   in  std_logic;                              --! Reset port
        MASTER_EN           :   in  std_logic;                              --! Master enable port.
        MASTER_ADDRESS_BYTE :   in  std_logic_vector (7 downto 0);          --! Address byte that Master transmits to the Slave.
        MASTER_IN_BYTE      :   in  std_logic_vector (7 downto 0);          --! Parallel data input port
        -- Output ports
        MASTER_READY        :   out  std_logic;                             --! Master ready port
        MASTER_OUT_BYTE     :   out  std_logic_vector (7 downto 0);         --! Parallel data output port
        -- Inout ports  
        SDA                 :   inout std_logic;                            --! Serial Data Line
        SCL                 :   inout std_logic                             --! Serial Clock Line
    );
end entity I2C_MASTER;

architecture rtl of I2C_MASTER is

    -- State type definition
    type state_type is (S_IDLE, S_TRANSMIT, S_RECEIVE, S_WAIT, S_STOP);                         --! Type for the states
    -- State signals
    signal PS, NS      :   state_type   := S_IDLE;                                              --! Present and Next State signal's declaration

    -- Counter limit signals
    signal I2C_FULL_PERIOD          :   integer := (CLK_FREQ / I2C_BAUDRATE);                   --! One full period of SCL
    signal I2C_HALF_PERIOD          :   integer := (CLK_FREQ / I2C_BAUDRATE) / 2;               --! One half period of SCL
    signal I2C_QUARTER_PERIOD       :   integer := (CLK_FREQ / I2C_BAUDRATE) / 4;               --! One quarter period of SCL

    -- Register signals
    signal TEMP_MASTER_IN_REG       :   std_logic_vector (7 downto 0) := (others => '0');       --! Register for the input data
    signal MAIN_MASTER_IN_REG       :   std_logic_vector (7 downto 0) := (others => '0');       --! Shift register for the internal operations
    signal ADDRESS_MASTER_IN_REG    :   std_logic_vector (7 downto 0) := (others => '0');       --! Register for the address data
    signal SDA_REG                  :   std_logic := 'Z';                                       --! Register for the Serial Data Line
    signal SCL_REG                  :   std_logic := 'Z';                                       --! Register for the Serial Clock Line
    signal TEMP_MASTER_OUT_REG      :   std_logic_vector (7 downto 0) := (others => '0');       --! Register for the output data

    -- Counter signals
    signal SCL_COUNTER              :    integer     := 0;                                      --! Counter signal for the SCL                          
    signal DATA_COUNTER             :    integer     := 0;                                      --! Counter signal for controlling the transmit and receive states               
    signal STOP_COUNTER             :    integer     := 0;                                      --! Counter signal for the stop state      
    signal SCL_EN                   :    std_logic   := '0';                                    --! Enable signal for the SCL counter                 
    signal SCL_LOW                  :    std_logic   := '0';                                    --! Done signal for the SCL counter at the mid-lows of the SCL 
    signal SCL_HIGH                 :    std_logic   := '0';                                    --! Done signal for the SCL counter at the mid-highs of the SCL                  
    signal STOP_EN                  :    std_logic   := '0';                                    --! Enable signal for the stop counter 
    signal STOP_DONE                :    std_logic   := '0';                                    --! Done signal for the stop counter

begin

    -- Input assignments
    TEMP_MASTER_IN_REG    <= MASTER_IN_BYTE;
    ADDRESS_MASTER_IN_REG <= MASTER_ADDRESS_BYTE;

    -- I2C clock generator
    SCL_GEN:    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (SCL_EN = '1') then
                if (SCL_COUNTER = (I2C_HALF_PERIOD - 1)) then
                    SCL_REG     <= not (SCL_REG);
                    SCL_COUNTER <= 0;
                    SCL_LOW     <= '0';
                    SCL_HIGH    <= '0';
                elsif ((SCL_COUNTER = (I2C_QUARTER_PERIOD - 1)) and (SCL_REG = '0')) then
                    SCL_COUNTER <= SCL_COUNTER + 1;
                    SCL_LOW     <= '1';
                elsif ((SCL_COUNTER = (I2C_QUARTER_PERIOD - 1)) and (SCL_REG = '1')) then
                    SCL_COUNTER <= SCL_COUNTER + 1;
                    SCL_HIGH    <= '1';
                else
                    SCL_COUNTER <= SCL_COUNTER + 1;
                    SCL_LOW     <= '0';
                    SCL_HIGH    <= '0';
                end if;
            else
                SCL_REG     <= '0';
                SCL_COUNTER <= 0;
                SCL_LOW     <= '0';
                SCL_HIGH    <= '0';
            end if;
        end if;
    end process;


    -- STOP counter
    STOP_CNT:    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (STOP_EN = '1') then
                if (STOP_COUNTER = (I2C_FULL_PERIOD - 1)) then
                    STOP_COUNTER <= 0;
                    STOP_DONE    <= '1';
                else
                    STOP_COUNTER <= STOP_COUNTER + 1;
                    STOP_DONE    <= '0';
                end if;
            else
                STOP_COUNTER <= 0;
                STOP_DONE    <= '0';
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
    MAIN_P:     process (PS, MASTER_EN, SCL, SCL_HIGH, SCL_LOW, STOP_DONE, RESET, SCL_COUNTER, STOP_COUNTER)
    begin
        case (PS) is
            when (S_IDLE) =>

                if (RESET = '1') then
                    MASTER_READY <= '0';
                    SDA_REG      <= 'Z';
                    SCL_EN       <= '0';
                    DATA_COUNTER <= 0;
                    MAIN_MASTER_IN_REG <= (others => '0');
                elsif (MASTER_EN = '1') then
                    NS           <= S_TRANSMIT;
                    MASTER_READY <= '0';
                    SDA_REG      <= '0';
                    MAIN_MASTER_IN_REG <= ADDRESS_MASTER_IN_REG;
                else
                    NS           <= S_IDLE; 
                    MASTER_READY <= '1';
                    SDA_REG      <= 'Z';
                    SCL_EN       <= '0';
                    DATA_COUNTER <= 0;
                    MAIN_MASTER_IN_REG <= (others => '0');
                end if;

            when (S_TRANSMIT) =>

                if (DATA_COUNTER = 9) then
                    SDA_REG <= 'Z';
                    if (SCL_HIGH = '1') then
                        DATA_COUNTER    <= 0;
                        if ((SDA = '0') and (MASTER_EN = '1')) then
                            NS  <= S_WAIT;
                        else
                            NS <= S_STOP;
                        end if;
                    end if;
                elsif (DATA_COUNTER = 0) then
                    SCL_EN       <= '1';
                    if (SCL_LOW = '1') then
                        SDA_REG            <= MAIN_MASTER_IN_REG (7);
                        DATA_COUNTER       <= DATA_COUNTER + 1;
                    end if;
                else
                    if (SCL_LOW = '1') then
                        MAIN_MASTER_IN_REG <= MAIN_MASTER_IN_REG (6 downto 0) & MAIN_MASTER_IN_REG (7);
                        DATA_COUNTER       <= DATA_COUNTER + 1;
                    else
                        SDA_REG <= MAIN_MASTER_IN_REG (7);
                    end if;
                end if;

            when (S_RECEIVE) =>
                
                if (DATA_COUNTER = 15) then
                    if (SCL_LOW = '1') then
                        TEMP_MASTER_OUT_REG <= MAIN_MASTER_IN_REG (6 downto 0) & MAIN_MASTER_IN_REG (7);
                        MAIN_MASTER_IN_REG  <= MAIN_MASTER_IN_REG (6 downto 0) & MAIN_MASTER_IN_REG (7);
                        DATA_COUNTER        <= 0;
                        if (MASTER_EN = '1') then
                            NS      <= S_WAIT;
                            SDA_REG <= '0';
                        else
                            NS      <= S_STOP;
                            SDA_REG <= '1';
                        end if;
                    end if;
                elsif (DATA_COUNTER = 0) then
                    SCL_EN       <= '1';
                    if (SCL_HIGH = '1') then
                        MAIN_MASTER_IN_REG (7)  <= SDA;
                        DATA_COUNTER            <= DATA_COUNTER + 1;
                    end if;
                else
                    if (SCL_LOW = '1') then
                        MAIN_MASTER_IN_REG <= MAIN_MASTER_IN_REG (6 downto 0) & MAIN_MASTER_IN_REG (7);
                        DATA_COUNTER       <= DATA_COUNTER + 1;
                    elsif (SCL_HIGH = '1') then
                        MAIN_MASTER_IN_REG (7)  <= SDA;
                        DATA_COUNTER            <= DATA_COUNTER + 1;
                    end if;
                end if;

            when (S_WAIT) =>

                if ((MASTER_EN /= '1') and (MASTER_READY = '1')) then
                    NS <= S_IDLE;
                elsif (SCL_LOW = '1') then
                    SCL_EN  <= '0';
                    SDA_REG <= 'Z';
                    MASTER_READY <= '1';
                elsif ((MASTER_READY = '1') and (SCL = 'Z')) then
                    if (ADDRESS_MASTER_IN_REG (0) = '0') then
                        NS <= S_TRANSMIT;
                        MASTER_READY <= '0';
                        MAIN_MASTER_IN_REG <= TEMP_MASTER_IN_REG;
                    elsif (ADDRESS_MASTER_IN_REG (0) = '1') then
                        NS <= S_RECEIVE;
                        MASTER_READY <= '0';
                        MAIN_MASTER_IN_REG <= (others => '0');
                    else
                        NS <= S_STOP;
                    end if;
                else
                    NS <= S_WAIT;
                end if;
                
            when (S_STOP) =>
                if (SCL_LOW = '1') then
                    SCL_EN  <= '0';
                    SDA_REG <= '0';
                elsif (STOP_DONE = '1') then
                    STOP_EN <= '0';
                    NS <= S_IDLE;
                elsif (SCL = 'Z') then
                    STOP_EN <= '1';
                    SDA_REG <= '1';
                else
                    NS <= S_STOP;
                end if;

            when others =>
                NS           <= S_IDLE;
                MASTER_READY <= '1';
                SDA_REG      <= 'Z';
                SCL_EN       <= '0';
                STOP_EN      <= '0';
                DATA_COUNTER <= 0;
        end case;
    end process;


    -- Output assignments
    SDA <= (SDA_REG) when (RESET = '0') else
           ('Z');
    SCL <= (SCL_REG) when (RESET = '0' and SCL_EN = '1') else
           ('Z')     when (RESET = '0' and SCL_EN = '0') else
           ('Z');

    MASTER_OUT_BYTE <= TEMP_MASTER_OUT_REG;

end architecture;