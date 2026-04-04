import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

@cocotb.test()

async def reset_dut(rst_n, duration_ns):
    rst_n.value = 0
    await Timer(duration_ns, unit="ns")
    rst_n.value = 1
    cocotb.log.debug("Reset complete")

async def icache_test(dut):
    rst_n = dut.rst_ni
    clk = dut.clk_i

    cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())

    await reset_dut(rst_n,500)

