tlb — Module Brief (v1.0) RTL: rtl/cpu/mmu/tlb.sv



#### **Purpose \& Role**

The TLB, Translation Lookaside Buffer, provides cached virtual to physical mappings for the Sv32 MMU. It takes recently used page table entries and stores them to accelerate address translation and minimize page table walks. It supports separate instruction (I) and data (D) lookup paths with shared shootdown domain. Implemented as an associative cache that uses a content addressable memory (CAM) structure with the least recently used (LRU) or pseudo least recently used replacement policy. During misses, the requests are sent to the MMU, which forwards them to an external Page Table Walker (PTW) for page-table fetch. When address spaces change, global invalidations through SFENCE.VMA and SATP writes ensure these outdated translations are removed.



**Parameters**
**Name	     Default	     Description**
---

  ENTRIES		  16		Number of cached TLB entries per instance.

  PAGE\_SIZE		  4 KB		Base page size per Sv32 specification.

  ASSOCIATIVE   	  FULL		Fully associative lookup organization.

  REPL\_POLICY		  LRU		Replacement policy: LRU or pseudo-LRU select.

  ADDR\_WIDTH		  32		Virtual address width for tag comparison.

  PADDR\_WIDTH	 	  34		Physical address width for stored entries.



#### **Interfaces (Ports)**

##### **Signal	Dir 	Width 	Description**

  clk\_i			  In		1	Clock input.

  rst\_ni		  In		1	Active-low reset.

  lookup\_va\_i		  In 		32 	Virtual address to translate.

  lookup\_hit\_o 		  Out 		1 	Indicates translation hit.

  lookup\_pa\_o		  Out		34	Physical address result if hit.

  lookup\_valid\_i	  In		1	Lookup request valid.

  lookup\_ready\_o          Out 		1	Ready for next lookup.

  insert\_valid\_i	  In		1	Request insert entry (from sv32\_mmu).

  insert\_vpn\_i  	  In		20	Virtual page number to cache.

  insert\_ppn\_i  	  In		22	Physical page number to cache.

  insert\_perm\_i 	  In 		8 	Permission bits (R/W/X/U/S/A/D).

  flush\_i		  In		1	Global flush signal (SFENCE.VMA/SATP).

  miss\_o		  Out		1	When lookup misses existing entries.



#### **Protocols**

* Lookup interface uses sequential valid/ready handshake with MMU pipeline.
* Insert interface triggered by MMU/PTW completion. Must not overlap with active flush.
* Flush is synchronous and clears all entries within one cycle after assertion.

 

#### **Behavior \& Timing**

* CAM based associative lookup performs tag comparison in one cycle.
* On hit ---> return cached physical address. No pipeline stall.
* On miss --> raise miss\_o prompting MMU to initiate PTW fetch.
* LRU or pseudo LRU replacement selects victim entry for new insertions.
* Supports optional shared shootdown across I/D TLBs when enabled.
* Single clock domain (clk\_i). No clock domain crossings.



#### **Programming Model**

Indirectly controlled through MMU CSRs and instructions:

* SFENCE.VMA: Flush all or ASID specific entries.
* SATP writes: trigger global flush and context switch.
* Privilege level (w/ CSR) determines permission bits cached with each entry.
* Refer to csr\_spec.yaml for CSR definitions.





#### **Errors \& IRQs**

#####   **Condition	Description	    Handling**

  Parity error 		CAM parity or ECC error.        Entry invalidated,

                       			                Reloaded on next access.

  Invalid insert        Insertion without valid PTE.    Ignored, triggers MMU retry.



There are no stand alone IRQ outputs. Exceptions spread to core trap logic.



#### **Performance Targets**

#####   **Metric	  Target 	Notes**

  Lookup latency        1 cycle 		No stall on hit.

  Insert latency        1 cycle			Tag and data write.

  Flush latency         1-2 cycles		Depends on entry count.

  Throughput 		1 lookup/cycle		Continuous pipeline operation.



#### **Dependencies**

* Connected to: sv32\_mmu for lookups, misses, and entry insertions.
* Page-table misses resolved indirectly through external PTW (handled by sv32\_mmu).
* Receives: SFENCE.VMA and SATP write flush controls through CSR subsystem.
* Clocks/Resets: clk\_i, rst\_ni (is shared with MMU).
* Integration: Shares shootdown domain across instruction/data TLB instances.



#### **Verification Links**

Unit tests: verification/mmu/test\_tlb.py

Integration: verification/mmu/test\_sv32\_mmu.sv

Coverage: cov/tlb\_cov.html

Known limitations: No superpage support (>4 MiB) entries. pseudo LRU accuracy is not verified under concurrent insertions.



#### **Definitions \& Acronyms**



TLB: Translation Lookaside Buffer. Cache storing recently used page-table entries.

CAM: Content Addressable Memory. Memory allowing associative lookup based on tag comparison.

LRU: Least Recently Used. Replacement policy that evicts the entry unused for the longest time.

PTW: Page Table Walker. Internal MMU logic that fetches page-table entries on TLB misses.

MMU: Memory Management Unit. Performs address translation and permission checks.

PTE: Page Table Entry. Descriptor defining a mapping between virtual and physical pages.

SFENCE.VMA: Supervisor Fence Virtual Memory Area. Instruction used to flush TLB entries.

SATP: Supervisor Address Translation and Protection register. Defines root page table and ASID.

ASID: Address Space Identifier. Distinguishes virtual-memory address spaces.

CSR: Control and Status Register. Holds configuration and privilege control data.

AXI4-Lite: Simplified version of ARM AXI4 bus protocol used for memory access.

SoC: System-on-Chip. Integrated CPU, MMU, cache, and peripheral components.

