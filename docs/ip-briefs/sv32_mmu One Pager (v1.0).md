sv32\_mmu — Module Brief (v1.0) RTL: rtl/cpu/mmu/sv32\_mmu.sv



#### **Purpose \& Role**

Sv32 virtual memory translation unit. Handles TLB management, page-table walks (delegated to an external Page Table Walker module), and access-permission enforcement for S-mode and U-mode memory accesses. Sits between the CPU memory stage and the memory subsystem, translating virtual addresses into physical addresses. Uses a Translation Lookaside Buffer (TLB) for cached translations and issues page-table walk requests to an external PTW module on TLB miss. Enforces R/W/X and U/S permissions according to the Sv32 specification, propagating page-faults to core trap logic. Ensures isolation between privilege levels and maintains correct virtual memory operation across the CPU pipeline.



**Parameters**
**Name	      	Default	       	Description**
---

  TLB\_ENTRIES		  16		Number of cached page table entries.

  PAGE\_SIZE		  4 KB		Base page size per SV32 specification.

  PTW\_TIMEOUT\_CYCLES	  256		Maximum cycles to wait for external PTW.

  ADDR\_WIDTH		  32		Virtual address width (fixed for RV32).

  PADDR\_WIDTH	 	  34		Physical address width to memory subsystem.



#### **Interfaces (Ports)**

##### **Signal	Dir 	Width 	Description**

  clk\_i			  In		1	Clock input.

  rst\_ni		  In		1	Active-low reset.

  va\_i			  In 		32 	Virtual address input.

  pa\_o 			  Out 		34 	Physical address output.

  valid\_i		  In		1	Request valid.

  ready\_o		  Out		1	Ready for next request.

  ptw\_req\_valid\_o         Out 		1	Request external PTW initiation.

  ptw\_req\_addr\_o	  Out		32	Base address of PTE to read from SATP.

  ptw\_rsp\_valid\_i	  In		1	External PTW response valid.

  ptw\_rsp\_data\_i	  In		64	Returned PTE data from external PTW.

  satp\_i 		  In 		32 	SATP register value.

  priv\_i		  In		2	Current privilege level (U/S/M).



#### **Protocols**

* CPU side: uses in-order valid/ready.
* PTW side: sv32\_mmu issues requests, PTW handles memory access and returns results according to valid/ready exchange.

 

#### **Behavior \& Timing**

* TLB hit  ---> 1-cycle translation.
* TLB miss ---> sv32\_mmu issues a PTW request via ptw\_req\_ to the external PTW.
* PTW performs the actual AXI/DRAM access and returns PTE data through ptw\_rsp\_\* signals.
* Permission check for R/W/X and U/S enforcement.
* Order based request handling. One translation in flight.
* SV32 two level walk: Root PPN from SATP -> VPN\[1] -> VPN \[0].
* Single clock domain (clk\_i). No CDC. One pipeline stage for TLB lookup. Stalls on misses.



#### **Programming Model**

Controlled by CSRs: SATP (enable/ASID/root PPN), SFENCE.VMA (invalidate), and SUM/MXR/UXN bits from mstatus/sstatus. Refer to csr\_spec.yaml. No memory mapped registers.



#### **Errors \& IRQs**

#####   **Condition	Description	    Handling**

  Page fault  	       Bad PTW or                      CPU exception

                       permission violation.           (load/store/instr).

  PTW timeout	       No response from external       Sets error flag,

                       PTW in timeout window.          Retry or exception.

  Misaligned PTE       Invalid alignment from PTW.     Treated as page fault.

There are no stand alone IRQ outputs. Exceptions spread to core trap logic.



#### **Performance Targets**

#####   **Metric	  Target 		Notes**

  TLB hit latency       1 cycle 			  No stall translation.

  TLB miss latency      less than or equal to 40 cycles   Two level walk average.

  Throughput            1 translation/cycle 	          When not PTW stalled.

  Clock frequency	500 MHz			          CPU domain minimal default.



#### **Dependencies**

* Modules: tlb (lookup + insertion), ptw (external page table walker module).
* Clocks/Resets: clk\_i, rest\_ni (is shared with CPU).
* Software: SATP must be configured before enable; SFENCE.VMA after context switch.
* PTW performs AXI4-Lite/AXI memory reads; MMU only provides address and receives PTE data.
* MMU receives privilege and CSR configuration from csr\_file.



#### **Verification Links**

Unit tests: verification/mmu/test\_sv32\_mmu.py

Integration: verification/core/system\_paging.sv

Coverage: cov/mmu\_cov.html

Known limitations: No superpage support (>4 MiB). PTW timeout error path unverified.



#### **Definitions \& Acronyms**



AXI4-Lite:

Advanced eXtensible Interface, lightweight subset of the ARM AXI4 protocol used for memory-mapped control and status register accesses.



A/D bits:

Accessed and Dirty bits within a page-table entry (PTE). The MMU sets these when a page is read or written for the first time.



ASID:

Address Space Identifier; field in the SATP register distinguishing virtual-memory contexts.



CDC:

Clock-Domain Crossing; logic used to safely transfer signals between different clock domains.



CPU:

Central Processing Unit.



CSR:

Control and Status Register; RISC-V architectural registers that configure privilege behavior, MMU mode, and interrupts.



MMU:

Memory Management Unit; hardware responsible for translating virtual addresses to physical addresses and enforcing protection.



OS:

Operating System.



PA:

PADDR\_WIDTH — Physical Address; bit-width of the physical address output from the MMU.



PTE:

Page Table Entry; 32-bit or 64-bit descriptor in memory describing one virtual-to-physical mapping and its permissions.



PTW:

Page Table Walker; sub-module that fetches PTEs from memory on a TLB miss.



RAM:

Random-Access Memory; main system memory where program data and page tables reside.



R/W/X:

Read, Write, and Execute permission bits inside a PTE.



RV32 / RV32I: 32-bit RISC-V base integer instruction set architecture.



SATP:

Supervisor Address Translation and Protection register; enables paging and provides root page-table pointer and ASID.



SFENCE.VMA:

Supervisor Fence for Virtual-Memory Area; RISC-V instruction that invalidates TLB entries.



S-mode / U-mode / M-mode: Supervisor, User, and Machine privilege levels defined by the RISC-V privilege specification.



SoC:

System-on-Chip, integrated design including CPU, MMU, caches, interconnect, and peripherals.



SV32:

RISC-V 32-bit virtual-memory scheme using two-level page tables with 4 KB pages.



TLB:

Translation Lookaside Buffer; cache storing recently used PTEs to accelerate address translation.



VPN:

Virtual Page Number; upper bits of a virtual address that index the page table.



CSR\_FILE:

Hardware block managing RISC-V control/status registers used by the CPU and MMU.



AXI Crossbar:

On-chip interconnect fabric (rtl/bus/axi/axi\_crossbar.sv) that routes AXI transactions between masters (CPU, PTW) and slaves (memory, peripherals).



BootROM:

Read-only memory code executed on reset to initialize hardware and enable the MMU/OS.



IRQ:

Interrupt Request; hardware signal used to notify the processor of asynchronous events.

