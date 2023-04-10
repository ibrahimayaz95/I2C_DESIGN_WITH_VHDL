# Entity: I2C_SLAVE 

- **File**: I2C_SLAVE.vhd
## Diagram

![Diagram](I2C_SLAVE.svg "Diagram")
## Generics

| Generic name | Type    | Value       | Description     |
| ------------ | ------- | ----------- | --------------- |
| CLK_FREQ     | integer | 100_000_000 | Clock frequency |
| I2C_BAUDRATE | integer | 100_000     | I2C baudrate    |
## Ports

| Port name      | Direction | Type                          | Description               |
| -------------- | --------- | ----------------------------- | ------------------------- |
| CLK            | in        | std_logic                     | Clock port                |
| RESET          | in        | std_logic                     | Reset port                |
| SLAVE_IN_BYTE  | in        | std_logic_vector (7 downto 0) | Parallel data input port  |
| SLAVE_OUT_BYTE | out       | std_logic_vector (7 downto 0) | Parallel data output port |
| SDA            | inout     | std_logic                     | Serial Data Line          |
| SCL            | inout     | std_logic                     | Serial Clock Line         |
## Signals

| Name               | Type                          | Description                                                                                 |
| ------------------ | ----------------------------- | ------------------------------------------------------------------------------------------- |
| PS                 | state_type                    | Present and Next State signal's declaration                                                 |
| NS                 | state_type                    | Present and Next State signal's declaration                                                 |
| I2C_FULL_PERIOD    | integer                       | One full period of SCL                                                                      |
| I2C_HALF_PERIOD    | integer                       | One half period of SCL                                                                      |
| I2C_QUARTER_PERIOD | integer                       | One quarter period of SCL                                                                   |
| SLAVE_ADDRESS      | std_logic_vector (6 downto 0) | Register for the address of this particular Slave                                           |
| TEMP_SLAVE_IN_REG  | std_logic_vector (7 downto 0) | Register for the input data                                                                 |
| MAIN_SLAVE_IN_REG  | std_logic_vector (7 downto 0) | Shift register for the internal operations                                                  |
| SDA_PREV           | std_logic                     | One clock cycle previous value of the SDA                                                   |
| SDA_CURRENT        | std_logic                     | Current value of the SDA                                                                    |
| SCL_CURRENT        | std_logic                     | Current value of the SCL                                                                    |
| SCL_PREV           | std_logic                     | One clock cycle previous value of the SCL                                                   |
| SDA_REG            | std_logic                     | Register for the Serial Data Line                                                           |
| SCL_REG            | std_logic                     | Register for the Serial Clock Line                                                          |
| COMMAND            | std_logic                     | Register for the command that is either transmit or receive                                 |
| SLAVE_BUSY         | std_logic                     | Register for busy signal of the Slave                                                       |
| TEMP_SLAVE_OUT_REG | std_logic_vector (7 downto 0) | Register for the output data                                                                |
| SCL_COUNTER        | integer                       | Counter signal for the SCL                                                                  |
| DATA_COUNTER       | integer                       | Counter signal for controlling the transmit and receive states                              |
| BUSY_COUNTER       | integer                       | Counter signal for the busy condition of the Slave                                          |
| SML_COUNTER        | integer                       | Counter signal for checking on the condition of wheter the stop state of the Master occured |
| END_COUNTER        | integer                       | Counter signal for helping the SML counter on either ending or continuing the transaction   |
| SCL_DONE           | std_logic                     | Done signal for the SCL counter                                                             |
| SCL_EN             | std_logic                     | Enable signal for the SCL counter                                                           |
| SML_DONE           | std_logic                     | Done signal for the SML counter                                                             |
| SML_EN             | std_logic                     | Enable signal for the SML counter                                                           |
## Types

| Name       | Type                                                                                                                                                                                                                                           | Description         |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- |
| state_type | (S_IDLE,<br><span style="padding-left:20px"> S_ADDRESS,<br><span style="padding-left:20px"> S_TRANSMIT,<br><span style="padding-left:20px"> S_RECEIVE,<br><span style="padding-left:20px"> S_WAIT,<br><span style="padding-left:20px"> S_STOP) | Type for the states |
## Processes
- PREV_AND_CURRENT: ( CLK )
- SMALL_COUNTER: ( CLK )
- SCL_CNT: ( CLK )
- FSM_SYNC: ( CLK, RESET )
- MAIN_P: ( PS, SCL, RESET, SCL_DONE, SDA_PREV, SCL_PREV, SCL_CURRENT, SML_DONE, SCL_COUNTER )
