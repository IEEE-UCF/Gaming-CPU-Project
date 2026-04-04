**I2C - Module Brief V 0.1**

**By Nicholas McNeill**

Purpose & Role:  
the Inter-Intergrated Circuit (I2C) is a multi-master, multi-slave, 2-wire synchronous bidirectional serial communication bus used for synchronous, bidirectional serial communication bus used for short-distance communication between low-speed peripherals and processors. It uses only two signals and supports multiple devices on the same bus through unique addressing.

Parameters (Registers) & Signals:

The I2C module typically resides on the AXI-Lite interconnect bus for register access and configuration by the CPU.

| Name | Addr. | Default Val | Purpose |
| --- | --- | --- | --- |
| I2CDR (data register) | 000 | R/W 0x00 | Holds the data for transmission or recently received data bytes. |
| I2CCR (Control Register) | 001 | R/W 0x00 | Enables I2C, sets Master/Slave mode, and handles Start/Stop generation. |
| I2CSR (Status Register) | 010 | R/W 0x00 | Indicates Bus Busy, Arbitration Lost, Address Match, and RX/TX Status |
| I2CBR (Baud Rate) | 011 | R/W 0x02 | Sets the clock frequency for the SCL line based on the system clock. |
| Signal | Dir | Size | Description |
| scl_io | In/Out | 1b  | Serial Clock: Synchronizes data transfer; driven by the active master. |
| Sda_io | In/Out | 1b  | Serial data: Bidrectional line for data and address transmission. |
| Axi_lite | M&lt;-&gt;S | Var | Standard AXI-Lite signals for CPU-to-register communication |
| Irq_o | Out | 1b  | Interrupt Request sent to CPU for events (Transfer Complete, NACK, Error). |

Configurations:  
Clock Modes: Supports standard mode, 100kbps, fast-mode, 400kbps, and sometimes a high-speed mode (3.4 Mbps). For addressing it supports a standard 7-bit addressing or extended 10-bit addressing mode for identifying slaves. Multi-Master; includes built in collision detection and arbitration logic of two masters attempt to control the bus simultaneously. Pull-yps; an open-drain protocol the physical lines (SDA/SCL) require external pull-up resigstors to function.

Behavior & Timing:  
Timing is governmed by the SCL signal. Data on the SDA line must be stable while SCL is high. Transitions on SDA while SCL is high are reserved for Start and Stop conditions.

Errors & Dependencies:  
Errors: Managed via irq_o. Common errors are; arbitatrion lost, NACK (No acknowledge from slave) And bus overrun.

Proper operation depends on a stable system clock for the baud rate generator and software driver to handle the I2C state machine.

Performance Targets:  
Standard: 100kHz, Fast: 400kHz