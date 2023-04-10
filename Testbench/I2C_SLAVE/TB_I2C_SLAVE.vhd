-- Library declaration
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity TB_I2C_SLAVE is
    generic (
        CLK_FREQ        :   integer := 100_000_000;
        I2C_BAUDRATE    :   integer := 100_000
    );
end entity TB_I2C_SLAVE;

architecture rtl of TB_I2C_SLAVE is

    -- component prototype
    component I2C_MASTER is
        generic (
            CLK_FREQ        :   integer := 100_000_000;
            I2C_BAUDRATE    :   integer := 100_000
        );
        port (
            -- Input ports
            CLK                 :   in  std_logic;
            RESET               :   in  std_logic;
            MASTER_EN           :   in  std_logic;
            MASTER_ADDRESS_BYTE :   in  std_logic_vector (7 downto 0);
            MASTER_IN_BYTE      :   in  std_logic_vector (7 downto 0);
            -- Output ports
            MASTER_READY        :   out  std_logic;
            MASTER_OUT_BYTE     :   out  std_logic_vector (7 downto 0);
            -- Inout ports
            SDA                 :   inout std_logic;
            SCL                 :   inout std_logic
        );
    end component;

    component I2C_SLAVE is
        generic (
            CLK_FREQ        :   integer := 100_000_000;
            I2C_BAUDRATE    :   integer := 100_000
        );
        port (
            -- Input ports
            CLK                 :   in  std_logic;
            RESET               :   in  std_logic;
            SLAVE_IN_BYTE       :   in  std_logic_vector (7 downto 0);
            -- Output ports
            SLAVE_OUT_BYTE      :   out  std_logic_vector (7 downto 0);
            -- Inout ports
            SDA                 :   inout std_logic;
            SCL                 :   inout std_logic
        );
    end component I2C_SLAVE;

    -- Signal declarations
    signal CLK                 :   std_logic    := '0';
    signal RESET               :   std_logic    := '0';
    signal MASTER_EN           :   std_logic    := '0';
    signal MASTER_ADDRESS_BYTE :   std_logic_vector (7 downto 0)    := (others => '0');
    signal MASTER_IN_BYTE      :   std_logic_vector (7 downto 0)    := (others => '0');
    signal SLAVE_IN_BYTE       :   std_logic_vector (7 downto 0)    := (others => '0');
    signal MASTER_READY        :   std_logic    := '0';
    signal MASTER_OUT_BYTE     :   std_logic_vector (7 downto 0)    := (others => '0');
    signal SLAVE_OUT_BYTE      :   std_logic_vector (7 downto 0)    := (others => '0');
    signal SDA                 :   std_logic    := 'Z';
    signal SCL                 :   std_logic    := 'Z';

    -- CLK period
    signal CLK_PERIOD          :    time        := 10 ns; 
    signal I2C_PERIOD          :    time        := 10_000 ns; 
    signal I2C_BYTE_PERIOD     :    time        := 80_000 ns; 

begin

    -- Component instantiation
    INST_I2C_MASTER: I2C_MASTER
        generic map (
            CLK_FREQ        =>   CLK_FREQ    ,
            I2C_BAUDRATE    =>   I2C_BAUDRATE 
        )
        port map (
            -- Input ports
            CLK                 =>   CLK                ,
            RESET               =>   RESET              ,
            MASTER_EN           =>   MASTER_EN          ,
            MASTER_ADDRESS_BYTE =>   MASTER_ADDRESS_BYTE,
            MASTER_IN_BYTE      =>   MASTER_IN_BYTE     ,
            MASTER_READY        =>   MASTER_READY       ,
            MASTER_OUT_BYTE     =>   MASTER_OUT_BYTE    ,
            SDA                 =>   SDA                ,
            SCL                 =>   SCL                 
        );

    INST_I2C_SLAVE : I2C_SLAVE
        generic map (
            CLK_FREQ        =>   CLK_FREQ     ,
            I2C_BAUDRATE    =>   I2C_BAUDRATE 
        )
        port map (
            CLK                 =>   CLK           , 
            RESET               =>   RESET         , 
            SLAVE_IN_BYTE       =>   SLAVE_IN_BYTE ,
            SLAVE_OUT_BYTE      =>   SLAVE_OUT_BYTE,
            SDA                 =>   SDA           ,
            SCL                 =>   SCL           
        );    

    -- Generate simulation clock
    GEN_CLK:    process
    begin
        CLK <= '0';
        wait for (CLK_PERIOD / 2);
        CLK <= '1';
        wait for (CLK_PERIOD / 2);
    end process;
    
    -- Generate the stimuli
    process
        variable pass_count     :   integer := 0;
        variable fail_count     :   integer := 0;
        variable test_count     :   integer := 0;
        variable index          :   std_logic_vector (3 downto 0)   := (others => '0');
        variable random_command :   std_logic   := '0';
    begin
        wait for (I2C_PERIOD);

        -- First stimuli for the Master transmit & Slave receive function
        MASTER_ADDRESS_BYTE <= "00001110";
        MASTER_IN_BYTE      <= x"AC";
        wait for (I2C_PERIOD);
        MASTER_EN           <= '1';
        -- Sending the address byte
        wait for ((I2C_BYTE_PERIOD * 2) + (I2C_PERIOD * 2) + ((I2C_PERIOD / 4) * 2));
        -- Ending the stimuli
        MASTER_EN  <= '0';
        if (MASTER_READY /= '1') then
            wait until (MASTER_READY = '1');
        end if;

        -- Comparison
        if (MASTER_IN_BYTE = SLAVE_OUT_BYTE) then 
            assert true
                report "[PASS] MASTER_IN_BYTE = SLAVE_OUT_BYTE!  MASTER_IN_BYTE = " & to_hstring(MASTER_IN_BYTE) & " and SLAVE_OUT_BYTE = " & to_hstring(SLAVE_OUT_BYTE)
                severity WARNING;
            report "[PASS] MASTER_IN_BYTE = SLAVE_OUT_BYTE!  MASTER_IN_BYTE = " & to_hstring(MASTER_IN_BYTE) & " and SLAVE_OUT_BYTE = " & to_hstring(SLAVE_OUT_BYTE);
            pass_count := pass_count + 1;
        else
            assert false
                report "[FAIL] MASTER_IN_BYTE = SLAVE_OUT_BYTE!  MASTER_IN_BYTE = " & to_hstring(MASTER_IN_BYTE) & " and SLAVE_OUT_BYTE = " & to_hstring(SLAVE_OUT_BYTE)
                severity WARNING;
        fail_count := fail_count + 1;
        end if;
        test_count := test_count + 1;

        -- Delay
        wait for (I2C_PERIOD * 2);

        -- Second stimuli for the Master receive & Slave transmit function
        MASTER_ADDRESS_BYTE <= "00001111";
        SLAVE_IN_BYTE <= x"BD";
        wait for (I2C_PERIOD);
        MASTER_EN           <= '1';
        -- Sending the address byte
        wait for ((I2C_BYTE_PERIOD * 2) + (I2C_PERIOD * 2) + ((I2C_PERIOD / 4) * 2));
        -- Ending the stimuli
        MASTER_EN  <= '0';
        if (MASTER_READY /= '1') then
            wait until (MASTER_READY = '1');
        end if;

        -- Comparison
        if (SLAVE_IN_BYTE = MASTER_OUT_BYTE) then 
            assert true
                report "[PASS] SLAVE_IN_BYTE = MASTER_OUT_BYTE!  SLAVE_IN_BYTE = " & to_hstring(SLAVE_IN_BYTE) & " and MASTER_OUT_BYTE = " & to_hstring(MASTER_OUT_BYTE)
                severity WARNING;
            report "[PASS] SLAVE_IN_BYTE = MASTER_OUT_BYTE!  SLAVE_IN_BYTE = " & to_hstring(SLAVE_IN_BYTE) & " and MASTER_OUT_BYTE = " & to_hstring(MASTER_OUT_BYTE);
            pass_count := pass_count + 1;
        else
            assert false
                report "[FAIL] SLAVE_IN_BYTE = MASTER_OUT_BYTE!  SLAVE_IN_BYTE = " & to_hstring(SLAVE_IN_BYTE) & " and MASTER_OUT_BYTE = " & to_hstring(MASTER_OUT_BYTE)
                severity WARNING;
        fail_count := fail_count + 1;
        end if;
        test_count := test_count + 1;

        wait for (I2C_PERIOD);

        -- Stimuli for the reset condition
        MASTER_ADDRESS_BYTE <= "00001111";
        SLAVE_IN_BYTE <= x"23";
        wait for (I2C_PERIOD);
        MASTER_EN           <= '1';
        -- Sending the address byte
        wait for ((I2C_BYTE_PERIOD * 2) + (I2C_PERIOD));
        -- Applying the reset
        RESET <= '1';
        wait for (I2C_BYTE_PERIOD);
        RESET <= '0';
        -- Ending the stimuli
        MASTER_EN  <= '0';
        wait for (I2C_PERIOD);
        report "[RESET] SLAVE_IN_BYTE = " & to_hstring(SLAVE_IN_BYTE) & " and MASTER_OUT_BYTE = " & to_hstring(MASTER_OUT_BYTE);
        if (MASTER_READY /= '1') then
            wait until (MASTER_READY = '1');
        end if;

        wait for (I2C_PERIOD);

        -- Some stimuli for the transmit function
        for i in 10 downto 0 loop
            index := std_logic_vector(to_unsigned(i, index'length));
            random_command := not (random_command);
            MASTER_ADDRESS_BYTE <= "0000111" & random_command;
            MASTER_IN_BYTE      <= index & index;
            SLAVE_IN_BYTE       <= index & index;
            
            wait for (I2C_PERIOD);
            MASTER_EN           <= '1';
            -- Sending the address byte
            wait for ((I2C_BYTE_PERIOD * 2) + (I2C_PERIOD * 2) + ((I2C_PERIOD / 4) * 2));
            -- Ending the stimuli
            MASTER_EN  <= '0';
            if (MASTER_READY /= '1') then
                wait until (MASTER_READY = '1');
            end if;

            -- Comparison
            if (random_command = '0') then
                if (MASTER_IN_BYTE = SLAVE_OUT_BYTE) then 
                    assert true
                        report "[PASS] MASTER_IN_BYTE = SLAVE_OUT_BYTE!  MASTER_IN_BYTE = " & to_hstring(MASTER_IN_BYTE) & " and SLAVE_OUT_BYTE = " & to_hstring(SLAVE_OUT_BYTE)
                        severity WARNING;
                    report "[PASS] MASTER_IN_BYTE = SLAVE_OUT_BYTE!  MASTER_IN_BYTE = " & to_hstring(MASTER_IN_BYTE) & " and SLAVE_OUT_BYTE = " & to_hstring(SLAVE_OUT_BYTE);
                    pass_count := pass_count + 1;
                else
                    assert false
                        report "[FAIL] MASTER_IN_BYTE = SLAVE_OUT_BYTE!  MASTER_IN_BYTE = " & to_hstring(MASTER_IN_BYTE) & " and SLAVE_OUT_BYTE = " & to_hstring(SLAVE_OUT_BYTE)
                        severity WARNING;
                fail_count := fail_count + 1;
                end if;
                test_count := test_count + 1;
            elsif (random_command = '1') then
                if (SLAVE_IN_BYTE = MASTER_OUT_BYTE) then 
                    assert true
                        report "[PASS] SLAVE_IN_BYTE = MASTER_OUT_BYTE!  SLAVE_IN_BYTE = " & to_hstring(SLAVE_IN_BYTE) & " and MASTER_OUT_BYTE = " & to_hstring(MASTER_OUT_BYTE)
                        severity WARNING;
                    report "[PASS] SLAVE_IN_BYTE = MASTER_OUT_BYTE!  SLAVE_IN_BYTE = " & to_hstring(SLAVE_IN_BYTE) & " and MASTER_OUT_BYTE = " & to_hstring(MASTER_OUT_BYTE);
                    pass_count := pass_count + 1;
                else
                    assert false
                        report "[FAIL] SLAVE_IN_BYTE = MASTER_OUT_BYTE!  SLAVE_IN_BYTE = " & to_hstring(SLAVE_IN_BYTE) & " and MASTER_OUT_BYTE = " & to_hstring(MASTER_OUT_BYTE)
                        severity WARNING;
                fail_count := fail_count + 1;
                end if;
                test_count := test_count + 1;
            end if;     

            -- Delay
            wait for (I2C_PERIOD * 2);
        end loop;


        report "SIMULATION RESULTS";
        report "---------------------------------------------------";
        if (pass_count = test_count) then
            report "TESTS ARE PASSED!";
            report "TEST count = " & integer'image(test_count);
            report "PASS count = " & integer'image(pass_count);
        else
            report "TESTS ARE FAILED!";
            report "TEST count = " & integer'image(test_count);
            report "FAIL count = " & integer'image(fail_count);
        end if;
        report "---------------------------------------------------";

        assert false
            report "END OF THE SIMULATION"
            severity FAILURE;
        
    end process;

end architecture;