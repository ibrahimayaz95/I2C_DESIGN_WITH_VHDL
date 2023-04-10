-- Library declaration
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity TB_I2C_MASTER is
    generic (
        CLK_FREQ        :   integer := 100_000_000;
        I2C_BAUDRATE    :   integer := 100_000
    );
end entity TB_I2C_MASTER;

architecture rtl of TB_I2C_MASTER is

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

    -- Signal declarations
    signal CLK                 :   std_logic    := '0';
    signal RESET               :   std_logic    := '0';
    signal MASTER_EN           :   std_logic    := '0';
    signal MASTER_ADDRESS_BYTE :   std_logic_vector (7 downto 0)    := (others => '0');
    signal MASTER_IN_BYTE      :   std_logic_vector (7 downto 0)    := (others => '0');
    signal MASTER_READY        :   std_logic    := '0';
    signal MASTER_OUT_BYTE     :   std_logic_vector (7 downto 0)    := (others => '0');
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
        variable SLAVE_DATA     :   std_logic_vector (7 downto 0)   := (others => '0');
        variable MASTER_DATA    :   std_logic_vector (7 downto 0)   := (others => '0');
        variable pass_count     :   integer := 0;
        variable fail_count     :   integer := 0;
        variable test_count     :   integer := 0;
        variable index          :   std_logic_vector (3 downto 0)   := (others => '0');
        variable random_ack     :   std_logic   := '0';  
    begin
        wait for (I2C_PERIOD);

        -- First stimuli for the transmit function
        MASTER_ADDRESS_BYTE <= x"B0";
        MASTER_IN_BYTE      <= x"AC";
        wait for (I2C_PERIOD);
        MASTER_EN           <= '1';
        -- Sending the address byte
        wait for (I2C_BYTE_PERIOD);
        wait for (I2C_PERIOD / 4);
        SDA <= '0';
        wait for (I2C_PERIOD);
        SDA <= 'Z';
        SCL <= '0';
        wait for (I2C_PERIOD);
        -- Sending the first data byte
        SCL <= 'Z';
        for i in 7 downto 0 loop
            wait for (I2C_PERIOD);
            MASTER_DATA (i) := SDA;
        end loop;
        wait for (I2C_PERIOD / 4);
        SDA <= '0';
        wait for (I2C_PERIOD);
        SDA <= 'Z';
        SCL <= '0';
        wait for (I2C_PERIOD * 2);
        -- Ending the stimuli
        MASTER_EN  <= '0';
        SCL        <= 'Z';
        if (MASTER_READY /= '1') then
            wait until (MASTER_READY = '1');
        end if;

        -- Comparison
        if (MASTER_IN_BYTE = MASTER_DATA) then 
            assert true
                report "[PASS] MASTER_IN_BYTE = MASTER_DATA!  MASTER_IN_BYTE = " & to_hstring(MASTER_IN_BYTE) & " and MASTER_DATA = " & to_hstring(MASTER_DATA)
                severity WARNING;
            report "[PASS] MASTER_IN_BYTE = MASTER_DATA!  MASTER_IN_BYTE = " & to_hstring(MASTER_IN_BYTE) & " and MASTER_DATA = " & to_hstring(MASTER_DATA);
            pass_count := pass_count + 1;
        else
            assert false
                report "[FAIL] MASTER_IN_BYTE = MASTER_DATA!  MASTER_IN_BYTE = " & to_hstring(MASTER_IN_BYTE) & " and MASTER_DATA = " & to_hstring(MASTER_DATA)
                severity WARNING;
        fail_count := fail_count + 1;
        end if;
        test_count := test_count + 1;

        -- Delay
        wait for (I2C_PERIOD * 2);

        -- First stimuli for the receive function
        MASTER_ADDRESS_BYTE <= x"C1";
        SLAVE_DATA          := x"55";
        wait for (I2C_PERIOD);
        MASTER_EN           <= '1';
        -- Sending the address byte
        wait for (I2C_BYTE_PERIOD);
        wait for (I2C_PERIOD / 4);
        SDA <= '0';
        wait for (I2C_PERIOD);
        SDA <= 'Z';
        SCL <= '0';
        wait for (I2C_PERIOD);
        -- Receiving the first data byte
        SCL <= 'Z';
        wait for (I2C_PERIOD / 4);
        for i in 7 downto 0 loop
            SDA <= SLAVE_DATA (i);
            wait for (I2C_PERIOD);
        end loop;
        SDA <= 'Z';
        wait for (I2C_PERIOD / 2);
        if (SDA = '0') then
            wait for (I2C_PERIOD / 2);
            SCL <= '0';
            wait for (I2C_PERIOD);
            MASTER_EN <= '0';
            SCL       <= 'Z';
        else
            wait for (I2C_PERIOD / 2);
            MASTER_EN <= '0';
            SCL       <= 'Z';
        end if;
        if (MASTER_READY /= '1') then
            wait until (MASTER_READY = '1');
        end if;

        -- Comparison
        if (MASTER_OUT_BYTE = SLAVE_DATA) then 
            assert true
                report "[PASS] MASTER_OUT_BYTE = SLAVE_DATA!  MASTER_OUT_BYTE = " & to_hstring(MASTER_OUT_BYTE) & " and SLAVE_DATA = " & to_hstring(SLAVE_DATA)
                severity WARNING;
            report "[PASS] MASTER_OUT_BYTE = SLAVE_DATA!  MASTER_OUT_BYTE = " & to_hstring(MASTER_OUT_BYTE) & " and SLAVE_DATA = " & to_hstring(SLAVE_DATA);
            pass_count := pass_count + 1;
        else
            assert false
                report "[FAIL] MASTER_OUT_BYTE = SLAVE_DATA!  MASTER_OUT_BYTE = " & to_hstring(MASTER_OUT_BYTE) & " and SLAVE_DATA = " & to_hstring(SLAVE_DATA)
                severity WARNING;
        fail_count := fail_count + 1;
        end if;
        test_count := test_count + 1;

        wait for (I2C_PERIOD * 2);

        -- Stimuli for the reset function
        MASTER_ADDRESS_BYTE <= x"A1";
        SLAVE_DATA          := x"34";
        wait for (I2C_PERIOD);
        MASTER_EN           <= '1';
        -- Sending the address byte
        wait for (I2C_BYTE_PERIOD);
        wait for (I2C_PERIOD / 4);
        SDA <= '0';
        wait for (I2C_PERIOD);
        SDA <= 'Z';
        SCL <= '0';
        wait for (I2C_PERIOD);
        -- Receiving the first data byte
        SCL <= 'Z';
        wait for (I2C_PERIOD / 4);
        for i in 4 downto 0 loop
            SDA <= SLAVE_DATA (i);
            wait for (I2C_PERIOD);
        end loop;
        RESET <= '1';
        SDA   <= 'Z';
        MASTER_EN  <= '0';
        wait for (I2C_PERIOD * 2);
        RESET <= '0';
        if (MASTER_READY /= '1') then
            wait until (MASTER_READY = '1');
        end if;

        wait for (I2C_PERIOD * 2);


        -- Some stimuli for the transmit function
        for i in 10 downto 7 loop
            index := std_logic_vector(to_unsigned(i, index'length));
            MASTER_ADDRESS_BYTE <= index & "1010";
            MASTER_IN_BYTE      <= index & index;
            wait for (I2C_PERIOD);
            MASTER_EN           <= '1';
            -- Sending the address byte
            wait for (I2C_BYTE_PERIOD);
            wait for (I2C_PERIOD / 4);
            SDA <= '0';
            wait for (I2C_PERIOD);
            SDA <= 'Z';
            SCL <= '0';
            wait for (I2C_PERIOD);
            -- Sending the first data byte
            SCL <= 'Z';
            for i in 7 downto 0 loop
                wait for (I2C_PERIOD);
                MASTER_DATA (i) := SDA;
            end loop;
            wait for (I2C_PERIOD / 4);
            SDA <= random_ack;
            wait for (I2C_PERIOD);
            if (random_ack = '0') then
                SDA <= 'Z';
                SCL <= '0';
            else
                wait for (I2C_PERIOD);
                SDA <= 'Z';
                SCL <= 'Z';
            end if;
            random_ack := not (random_ack);
            wait for (I2C_PERIOD * 2);
            -- Ending the stimuli
            MASTER_EN  <= '0';
            SCL        <= 'Z';
            if (MASTER_READY /= '1') then
                wait until (MASTER_READY = '1');
            end if;

            -- Comparison
            if (MASTER_IN_BYTE = MASTER_DATA) then 
                assert true
                    report "[PASS] MASTER_IN_BYTE = MASTER_DATA!  MASTER_IN_BYTE = " & to_hstring(MASTER_IN_BYTE) & " and MASTER_DATA = " & to_hstring(MASTER_DATA)
                    severity WARNING;
                report "[PASS] MASTER_IN_BYTE = MASTER_DATA!  MASTER_IN_BYTE = " & to_hstring(MASTER_IN_BYTE) & " and MASTER_DATA = " & to_hstring(MASTER_DATA);
                pass_count := pass_count + 1;
            else
                assert false
                    report "[FAIL] MASTER_IN_BYTE = MASTER_DATA!  MASTER_IN_BYTE = " & to_hstring(MASTER_IN_BYTE) & " and MASTER_DATA = " & to_hstring(MASTER_DATA)
                    severity WARNING;
            fail_count := fail_count + 1;
            end if;
            test_count := test_count + 1;

            -- Delay
            wait for (I2C_PERIOD * 2);
        end loop;

        -- Some stimuli for the receive function
        for i in 5 downto 2 loop
            index := std_logic_vector(to_unsigned(i, index'length));
            MASTER_ADDRESS_BYTE <= index & "1001";
            SLAVE_DATA          := index & index;
            wait for (I2C_PERIOD);
            MASTER_EN           <= '1';
            -- Sending the address byte
            wait for (I2C_BYTE_PERIOD);
            wait for (I2C_PERIOD / 4);
            SDA <= '0';
            wait for (I2C_PERIOD);
            SDA <= 'Z';
            SCL <= '0';
            wait for (I2C_PERIOD);
            -- Receiving the first data byte
            SCL <= 'Z';
            wait for (I2C_PERIOD / 4);
            for i in 7 downto 0 loop
                SDA <= SLAVE_DATA (i);
                wait for (I2C_PERIOD);
            end loop;
            SDA <= 'Z';
            wait for (I2C_PERIOD / 2);
            if (SDA = '0') then
                wait for (I2C_PERIOD / 2);
                SCL <= '0';
                wait for (I2C_PERIOD);
                MASTER_EN <= '0';
                SCL       <= 'Z';
            else
                wait for (I2C_PERIOD / 2);
                MASTER_EN <= '0';
                SCL       <= 'Z';
            end if;
            if (MASTER_READY /= '1') then
                wait until (MASTER_READY = '1');
            end if;

            -- Comparison
            if (MASTER_OUT_BYTE = SLAVE_DATA) then 
                assert true
                    report "[PASS] MASTER_OUT_BYTE = SLAVE_DATA!  MASTER_OUT_BYTE = " & to_hstring(MASTER_OUT_BYTE) & " and SLAVE_DATA = " & to_hstring(SLAVE_DATA)
                    severity WARNING;
                report "[PASS] MASTER_OUT_BYTE = SLAVE_DATA!  MASTER_OUT_BYTE = " & to_hstring(MASTER_OUT_BYTE) & " and SLAVE_DATA = " & to_hstring(SLAVE_DATA);
                pass_count := pass_count + 1;
            else
                assert false
                    report "[FAIL] MASTER_OUT_BYTE = SLAVE_DATA!  MASTER_OUT_BYTE = " & to_hstring(MASTER_OUT_BYTE) & " and SLAVE_DATA = " & to_hstring(SLAVE_DATA)
                    severity WARNING;
            fail_count := fail_count + 1;
            end if;
            test_count := test_count + 1;

            wait for (I2C_PERIOD * 2);
        end loop;


        wait for (I2C_PERIOD);

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