**Author:** Trevor Cannon
**RTL:** *rtl/mem/cache/dcache.sv*

---
**Purpose & Role**
- Data Cache (D$) is a 16KB 4-way set-associative cache that services the Memory (MEM) stage of the pipeline, storing frequently used non-instruction data
- D$ has a **write-back policy** in which when data is overwritten during CPU operation, cache lines are tagged as "dirty", dirty lines will overwritten in main memory once evicted from cache
	- Also features **write-allocate policy** where in the event the CPU tries to write to a address not currently in D$, that line will be retrieved from main memory and the subsequently overwritten and tagged as dirty
---
**Parameters**
- Subject to change

| Name       | Default | Description                                                                                            |
| ---------- | ------- | ------------------------------------------------------------------------------------------------------ |
| LINE_SIZE  | 64      | Size of cache line in bytes                                                                            |
| WAYS       | 4       | Ways of associativity per set (number of lines per set)                                                |
| DMEM_SIZE  | 16384   | Total size of D$ in bytes                                                                              |
| ADDR_WIDTH | 32      | 32 bit word size                                                                                       |
| DATA_WIDTH | 32      | 32 bit word size                                                                                       |



---
**Interfaces (Ports)**
- Subject to change
	- AXI bus requirements will need to be defined by bus team for D$ port
	- D$ port will require CDC between AXI interconnect and D$, accomplished using asynchronous FIFO/buffer etc.

| Signal Name             | Direction | Width | Description                                                                                                           |
| ----------------------- | --------- | ----- | --------------------------------------------------------------------------------------------------------------------- |
|                         |           |       |                                                                                                                       |
| **Global Signals**      |           |       |                                                                                                                       |
| clk_i                   | In        | 1     | Main clock input                                                                                                      |
| rst_ni                  | In        | 1     | Active-low reset                                                                                                      |
|                         |           |       |                                                                                                                       |
| **CPU Interface**       |           |       |                                                                                                                       |
| cpu_req_valid_i         | In        | 1     | CPU request for load/store to D$                                                                                      |
| cpu_load_store_i        | In        | 1     | Load/store flag from CPU, '0' for load, '1' for store, sample once *cpu_req_valid_i* is high                          |
| cpu_addr_i              | In        | 32    | CPU virtual address for load/store                                                                                    |
| dcache_req_ready_o      | Out       | 1     | D$ ready to receive requests                                                                                          |
| dcache_resp_valid_o     | Out       | 1     | D$ returning valid data word, only on load operation                                                                  |
| dcache_resp_data_o      | Out       | 32    | Data word given to CPU on load                                                                                        |
| cpu_resp_ready_i        | In        | 1     | CPU ready to accept data                                                                                              |
| cpu_write_i             | In        | 32    | CPU data to write back to memory, sample data on valid request                                                        |
| cpu_byte_en_i           | In        | 4     | Byte enable for byte store instructions, ex. if equal to 0100, valid byte when storing word is byte #2 (bits 16 - 23) |
| dcache_flush_i          | In        | 1     | Flush D$                                                                                                              |
|                         |           |       |                                                                                                                       |
| **MMU/TLB Interface**   |           |       |                                                                                                                       |
| dcache_tlb_req_valid_o  | Out       | 1     | D$ is sending a valid virtual address to the TLB                                                                      |
| dcache_tlb_va_o         | Out       | 32    | Virtual address to be translated                                                                                      |
| tlb_req_ready_i         | In        | 1     | TLB ready for translation                                                                                             |
| tlb_resp_valid_i        | In        | 1     | TLB response is valid                                                                                                 |
| tlb_resp_pa_i           | In        | 32    | TLB's translated physical address                                                                                     |
| dcache_tlb_resp_ready_o | Out       | 1     | D$ ready to accept TLB response                                                                                       |

---
**Reset/Init**
- When performing a reset, the signal *rst_ni* becomes LOW, and every cache lines valid bit is set LOW
	- This signals an invalid line which will cause new data to be fetched from main memory on every CPU request
	- This is done to put the cache in a known starting state
---
**Behavior & Timing**
- Cache Hit:
	- Defined as a requested instruction being found successfully in D$ and returned to CPU for execution
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
	- The CPU's MEM stage must then be stalled until the correct line can be fetched from main memory (across AXI bus) using the physical address from TLB
	- The fetched line is then stored according to our replacement policy and the pipeline is resumed
- Replacement Policy:
	- When a cache miss occurs and the set is full, a line must be evicted from the cache
	- Choosing which line to evict falls onto he replacement policy
	- This can be defined later, common policies are Random or Least Recently Used (LRU)
---
**Performance Targets**
- Hit Rate:
	- Percentage of cache accesses that result in the correct data being found in cache
	- 95%+ hit rate on successfully finding instructions in D$
	- Hit rate (and miss rate) can be improved upon by choosing well-suited replacement policy when needing to store new data in cache
- Hit Latency
	- Time taken to load/store data on cache hit
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
		- D$ serves is master, main memory is slave
	- The AXI data width and burst length will be defined the AXI crossbar itself
		- Must match with project-wide specifications
- CPU (IF stage): *rtl/cpu/core/mem_stage.sv*
	- D$ receives load/store requests from CPU fetch stage, returns data word on hit, retrieves from line from main memory on miss
- MMU/TLB: *rtl/cpu/mmu/sv32_mmu.sv*
	- MMU maps virtual addresses from the kernel to physical hardware addresses
	- TLB (Translation Lookaside Buffer) stores recently used virtual-hardware address mappings to speed up memory accesses
	- I$ and D$ must must make use of address translations from MMU/TLB as CPU will always give virtual addresses that must be mapped back into physical addresses
---
**Verification Links**
- *sim/cocotb/test_dcache.py*
	- Cocotb simulation environment to verify D$
- *verification/cache/wb_wa_sequences.sv*
	- Testing write-back and write-allocate features of D$