**Author:** Trevor Cannon
**RTL:** *rtl/mem/cache/icache.sv*

---
**Purpose & Role**
- Instruction Cache (I$) is a N-way set-associative cache that loads instructions from main memory through AXI port which are then sent to the Fetch (IF) stage of CPU pipeline
	- N-way set associative: Cache is comprised of many "sets" where each set has N number of "ways" to store data. Each way in a set contains one "line" of data.
	- Set-associative means that any incoming data can be stored at any way within the set, providing flexibility of storage
	- Number of "ways" (N) can be decided on later, will likely be 2 or 4 way
---
**Parameters**
- Parameters in Verilog/SystemVerilog are similar to constants and #define directives seen in C/C++ that are reused many times across a module to avoid magic numbers and promote reusability
- Parameters are subject to change but this is a general idea:

| Name      | Default         | Description                                                                                            |
| --------- | --------------- | ------------------------------------------------------------------------------------------------------ |
| LINE_SIZE | project default | Size of cache line in bytes                                                                            |
| WAYS      | project default | Ways of associativity per set (number of lines per set)                                                |
| IMEM_SIZE | project default | Total size of I$                                                                                       |
| SETS      | project default | Number of sets in cache, defined based formula: ($\frac{Total\,Cache\,Size}{Ways\,\times Line\,Size}$) |

---
**Interfaces (Ports)**
- Any input or output signal that will be used in the operation of the I$
- AXI burst parameters must be defined later
- Subject to change

| Signal Name             | Direction | Width | Description                                                            |
| ----------------------- | --------- | ----- | ---------------------------------------------------------------------- |
|                         |           |       |                                                                        |
| **Global Signals**      |           |       |                                                                        |
| clk_i                   | In        | 1     | Main clock input                                                       |
| rst_ni                  | In        | 1     | Active-low reset                                                       |
|                         |           |       |                                                                        |
| **CPU Interface**       |           |       |                                                                        |
| cpu_req_valid_i         | In        | 1     | CPU requesting an instruction fetch                                    |
| cpu_addr_i              | In        | 32    | CPU virtual address for requested instruction                          |
| icache_req_ready_o      | Out       | 1     | I$ ready to receive fetch requests                                     |
| icache_resp_valid_o     | Out       | 1     | I$ returning a valid instruction                                       |
| icache_resp_instr_o     | Out       | 32    | Instruction located at CPU's requested virtual address                 |
| cpu_resp_ready_i        | In        | 1     | CPU ready to accept instruction                                        |
| icache_flush_i          | In        | 1     | Invalidate I$ on FENCE.I instruction                                   |
|                         |           |       |                                                                        |
| **AXI Interface**       |           |       |                                                                        |
| axi_mem_ar_o            | Out       | 32    | AXI Address Read (AR) - Physical address to be read from main memory   |
| axi_ar_valid_o          | Out       | 1     | AXI Handshake - I$ sending valid address to main memory                |
| axi_ar_ready_i          | In        | 1     | AXI Handshake - Main memory ready to accept address                    |
| axi_mem_r_i             | In        | 128   | AXI Read Data (R) - Returns data from requested address in main memory |
| axi_r_valid_i           | In        | 1     | AXI Handshake - Main memory data sent is valid                         |
| axi_r_ready_o           | Out       | 1     | AXI Handshake - I$ ready to accept data from main memory               |
|                         |           |       |                                                                        |
| **MMU/TLB Interface**   |           |       |                                                                        |
| icache_tlb_req_valid_o  | Out       | 1     | I$ is sending a valid virtual address to the TLB                       |
| icache_tlb_va_o         | Out       | 32    | Virtual address to be translated                                       |
| tlb_req_ready_i         | In        | 1     | TLB ready for translation                                              |
| tlb_resp_valid_i        | In        | 1     | TLB response is valid                                                  |
| tlb_resp_pa_i           | In        | 32    | TLB's translated physical address                                      |
| icache_tlb_resp_ready_o | Out       | 1     | I$ ready to accept TLB response                                        |

---
**Reset/Init**
- When performing a reset, the signal rst_ni becomes LOW, and every cache lines valid bit is set LOW
	- This signals an invalid line which will cause new data to be fetched from main memory on every CPU request
	- This is done to put the cache in a known starting state
---
**Behavior & Timing**
- Cache Hit:
	- Defined as a requested instruction being found successfully in I$ and returned to CPU for execution
	- Each address the CPU requests contains a Tag, Index, and Offset
		- Index is used to map to the specific set in cache
		- Tag is used to check if the data at that address is already present in cache
		- Offset is the specific byte in the line corresponding to that address
	- Since the CPU provides virtual addresses that must be converted to physical addresses, the MMU/TLB must be used to translate these addresses
	- We will implement a Virtually-Indexed, Physically Tagged system (VIPT) where only the tag of the address will need to be translated in order to confirm a match
	- This will greatly speedup operation as the cache does not need to wait on the TLB returning the full physical address and works in parallel with the TLB lookup
	- VIPT works as follows:
		- Once receiving a virtual address from the CPU, the cache will immediately send the address to the TLB to translate into a physical address
		- At the same time this occurs, the Index of the virtual address is used to select the corresponding set and read all tags and data from all lines in that set
		- When the TLB returns the physical address back to the cache, we can use the translated Tag to compare against all the tags from the set selected earlier
		- If there is a match amongst the tags, it is considered a hit
		- Data can then be sent immediately to the CPU since we have already read the entire line + offset earlier
- Cache Miss:
	- A miss will occur if after checking the tag against all lines in that set we have no matches
	- The CPU's IF stage must then be stalled until the correct line can be fetched from main memory (across AXI bus) using the physical address from TLB
	- The fetched line is then stored according to our replacement policy and the pipeline is resumed
- Replacement Policy:
	- When a cache miss occurs and the set is full, a line must be evicted from the cache
	- Choosing which line to evict falls onto he replacement policy
	- This can be defined later, common policies are Random or Least Recently Used (LRU)
---
**Performance Targets**
- Hit Rate:
	- Percentage of cache accesses that result in the correct data being found in cache
	- 95%+ hit rate on successfully finding instructions in I$
	- Hit rate (and miss rate) can be improved upon by choosing well-suited replacement policy when needing to store new data in cache
- Hit Latency
	- Time taken to return instruction to CPU on cache hit
	- Aiming for 1-2 cycles
- Miss Rate
	- Percentage of cache accesses that result in the data not being found, requiring main memory access
	- Want <5% miss rate
- Miss Penalty:
	- Additional time needed when cache miss occurs
	- Miss penalty is heavily determined by AXI/main memory speeds
	- Access time low as possible, but still could be tens to hundreds of clock cycles
	- Minimizing miss latency is the goal
---
**Dependencies**
- AXI: *rtl/bus/axi/axi_crossbar.sv*
	- AXI connection for multiple master-slave agents
		- I$ serves is master, main memory is slave
	- The AXI data width and burst length will be defined the AXI crossbar itself
		- Must match with project-wide specifications
- CPU (IF stage): *rtl/cpu/core/fetch.sv*
	- I$ receives instruction requests from CPU fetch stage, returns instructions on hit, retrieves from main memory on miss
- MMU/TLB: *rtl/cpu/mmu/sv32_mmu.sv*
	- MMU maps virtual addresses from the kernel to physical hardware addresses
	- TLB (Translation Lookaside Buffer) stores recently used virtual-hardware address mappings to speed up memory accesses
	- I$ and D$ must must make use of address translations from MMU/TLB as CPU will always give virtual addresses that must be mapped back into physical addresses
---
**Verification Links**
- *sim/cocotb/test_icache.py*
	- Cocotb simulation environment to verify instruction cache
- ~~*verification/cache/wb_wa_sequences.sv*~~
	- ~~Testing write-back and write-allocate features of D$~~
	- **I$ is read only, write policies not used**
- *verification/cache/self_mod_code_fencei.S*
	- Testing the FENCE.I instruction where I$ is considered invalid due to self-modifying code
		- FENCE.I is used when new code is written to memory that may conflict with instructions found in I$ or CPU fetch pipeline
		- Must invalidate cache and force re-fetching of instructions to prevent use of stale or incorrect instructions
	- Used by OS/kernel to flush I$ and prevent VIPT conflicts