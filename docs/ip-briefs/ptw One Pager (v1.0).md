ptw — Module Brief (v1.0) RTL: rtl/cpu/mmu/ptw.sv



#### **Purpose \& Role**

The Page Table Walker (PTW) performs a hardware page-table traversal for the SV32 Virtual memory. When the TLB and sv32\_mmu detects a miss, the PTW takes the page table entries (PTEs) from memory using AXI4-Lite read requests. It implements the 2 level SV32 walk (VPN\[1]->VPN\[0]) and returns either a valid PTE or a page fault condition.



The PTW is a lone external module. It does not manage TLBs directly.

sv32\_mmu requests page walks -> ptw gets PTEs -> sv32\_mmu interprets results and completes permission checks -> sv32\_mmu handles TLB insertion after walk completes.



**Parameters
Name	     Default	       	Description**
---

  TIMEOUT\_CYCLES	  256		Max cycles allowed mem response before timeout

  ADDR\_WIDTH		  32		Width of virtual \& PTE address generated.

  DATA\_WIDTH		  32		Width of PTE fetch data.

  PPN\_WIDTH		  22		Physical page # width for next level base @.



#### **Interfaces (Ports)**

##### **Signal		Dir 	Width 	Description**

  clk\_i			  In		1	Clock input.

  rst\_ni		  In		1	Active-low reset.

&#x20; flush\_i		  In		1	Flush input from MMU / SFENCE.VMA; clears in-flight walk state.

  walk\_req\_valid\_i	  In 		1 	Request start page walk (from sv32).
  walk\_req\_ready\_o	  Out 		1 	PTW ready to accept new walk request.

&#x20; walk\_req\_addr\_i	  In 		32 	Root page-table base address for the level-1 walk.

  walk\_req\_vpn\_i	  In		20	VPN\[19:0] split into VPN\[1]/\[0].

  walk\_rsp\_valid\_o	  Out		1	PTW response valid.

  walk\_rsp\_pte\_o	  Out		32	Returned PTE data (valid or faulty).

  walk\_rsp\_error\_o	  Out		1	PTW error indication (timeout / invalid walk / access fault).

  axi\_ar\_valid\_o	  Out		1	AXI4-Lite read address valid.

  axi\_ar\_addr\_o 	  Out 		32 	AXI4-Lite read address for PTE fetch.

  axi\_ar\_ready\_i 	  In 		1 	AXI4-Lite address channel ready.

  axi\_r\_valid\_i		  In		1	AXI4-Lite read data valid.

  axi\_r\_data\_i		  In		32	PTE data returned from memory.

  axi\_r\_resp\_i		  In		2	AXI read response code for access-fault detection.





#### **Protocols**

* Walk interface: single outstanding request. Valid/ready managed between sv32\_mmu and PTW.
* AXI4-Lite: address request uses axi\_ar\_valid\_o / axi\_ar\_ready\_i, read data returns through axi\_r\_valid\_i / axi\_r\_data\_i / axi\_r\_resp\_i.
* MMU sequencing: PTW only begins a walk when a valid request is accepted, and no interleaved walks are supported.

 

#### **Behavior \& Timing**

* Performs a two-level Sv32 lookup, fetches the level-1 PTE using the root page-table base plus VPN\[1].
* If the entry is a pointer, fetches the level-2 PTE using the next-level base plus VPN\[0].
* Detects and reports invalid PTEs, misaligned PTE conditions, access faults, and timeout conditions.
* Walk latency depends on memory response timing with typical latency 8–20 cycles, with maximum latency bounded by TIMEOUT\_CYCLES.
* One translation may be in flight at a time.
* PTW does not modify A/D bits (sv32\_mmu handles that if required).
* flush\_i clears PTW state and cancels any in-flight walk.



#### **Programming Model**

The PTW is not software-visible. It is indirectly controlled through sv32\_mmu and CSRs:

* SATP.PPN provides root page-table pointer.
* SFENCE.VMA causes PTW state flush through the MMU.
* No memory mapped registers.
* No CSR interface inside PTW.



#### **Errors \& IRQs**

#####   **Condition	Description	    Handling**

  Timeout  	       Memory read response exceeds    walk\_rsp\_error\_o asserted.

 		       TIMEOUT\_CYCLES.

  Invalid PTE	       PTE has illegal or reserved     Error returned to sv32\_mmu.

 		       values.

  Misaligned PTE       Invalid alignment from PTE.     Treated as page fault.

  Access fault	       AXI bus returns error.	       Error raised to sv32\_mmu.



PTW does not generate standalone interrupts; all exceptions are handled by sv32\_mmu and core trap logic.



#### **Performance Targets**

#####   **Metric	Target 		Notes**

  Walk latency	     <= 40 cycles typical  2 level walk under average memory timing.

  Throughput	     1 walk at a time	   Back pressure via walk\_req\_valid\_i.

  Frequency	     500 MHz		   Same as MMU domain.



#### **Dependencies**

* sv32\_mmu (requests + responses), AXI4-Lite interconnect (memory PTE fetches).
* Clocks: clk\_i / rst\_ni shared with MMU.
* Inputs: SATP root pointer (via mmu).
* Must be coordinated with TLB insertions performed by sv32\_mmu.



#### **Verification Links**

Unit tests: verification/mmu/test\_ptw.py

Integration: verification/core/system\_paging.sv

Coverage: cov/cov/ptw\_cov.html

Known limitations:

* Superpage support behavior depends on final Sv32 alignment policy implemented in RTL.
* No multi-walk concurrency.
* Timeout behavior not cycle-accurate with all DRAM models.



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

Page Table Entry; 32-bit descriptor in memory describing one virtual-to-physical mapping and its permissions.



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

