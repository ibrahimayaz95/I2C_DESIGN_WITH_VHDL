# Entity: I2C_MASTER 

- **File**: I2C_MASTER.vhd
## Diagram

![Diagram](I2C_MASTER.svg "Diagram")
## Generics

| Generic name | Type    | Value       | Description     |
| ------------ | ------- | ----------- | --------------- |
| CLK_FREQ     | integer | 100_000_000 | Clock frequency |
| I2C_BAUDRATE | integer | 100_000     | I2C baudrate    |
## Ports

| Port name           | Direction | Type                          | Description                                      |
| ------------------- | --------- | ----------------------------- | ------------------------------------------------ |
| CLK                 | in        | std_logic                     | Clock port                                       |
| RESET               | in        | std_logic                     | Reset port                                       |
| MASTER_EN           | in        | std_logic                     | Master enable port.                              |
| MASTER_ADDRESS_BYTE | in        | std_logic_vector (7 downto 0) | Address byte that Master transmits to the Slave. |
| MASTER_IN_BYTE      | in        | std_logic_vector (7 downto 0) | Parallel data input port                         |
| MASTER_READY        | out       | std_logic                     | Master ready port                                |
| MASTER_OUT_BYTE     | out       | std_logic_vector (7 downto 0) | Parallel data output port                        |
| SDA                 | inout     | std_logic                     | Serial Data Line                                 |
| SCL                 | inout     | std_logic                     | Serial Clock Line                                |
## Signals

| Name                  | Type                          | Description                                                    |
| --------------------- | ----------------------------- | -------------------------------------------------------------- |
| PS                    | state_type                    | Present and Next State signal's declaration                    |
| NS                    | state_type                    | Present and Next State signal's declaration                    |
| I2C_FULL_PERIOD       | integer                       | One full period of SCL                                         |
| I2C_HALF_PERIOD       | integer                       | One half period of SCL                                         |
| I2C_QUARTER_PERIOD    | integer                       | One quarter period of SCL                                      |
| TEMP_MASTER_IN_REG    | std_logic_vector (7 downto 0) | Register for the input data                                    |
| MAIN_MASTER_IN_REG    | std_logic_vector (7 downto 0) | Shift register for the internal operations                     |
| ADDRESS_MASTER_IN_REG | std_logic_vector (7 downto 0) | Register for the address data                                  |
| SDA_REG               | std_logic                     | Register for the Serial Data Line                              |
| SCL_REG               | std_logic                     | Register for the Serial Clock Line                             |
| TEMP_MASTER_OUT_REG   | std_logic_vector (7 downto 0) | Register for the output data                                   |
| SCL_COUNTER           | integer                       | Counter signal for the SCL                                     |
| DATA_COUNTER          | integer                       | Counter signal for controlling the transmit and receive states |
| STOP_COUNTER          | integer                       | Counter signal for the stop state                              |
| SCL_EN                | std_logic                     | Enable signal for the SCL counter                              |
| SCL_LOW               | std_logic                     | Done signal for the SCL counter at the mid-lows of the SCL     |
| SCL_HIGH              | std_logic                     | Done signal for the SCL counter at the mid-highs of the SCL    |
| STOP_EN               | std_logic                     | Enable signal for the stop counter                             |
| STOP_DONE             | std_logic                     | Done signal for the stop counter                               |
## Types

| Name       | Type                                                                                                                                                                                            | Description         |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- |
| state_type | (S_IDLE,<br><span style="padding-left:20px"> S_TRANSMIT,<br><span style="padding-left:20px"> S_RECEIVE,<br><span style="padding-left:20px"> S_WAIT,<br><span style="padding-left:20px"> S_STOP) | Type for the states |
## Processes
- SCL_GEN: ( CLK )
- STOP_CNT: ( CLK )
- FSM_SYNC: ( CLK, RESET )
- MAIN_P: ( PS, MASTER_EN, SCL, SCL_HIGH, SCL_LOW, STOP_DONE, RESET, SCL_COUNTER, STOP_COUNTER )
