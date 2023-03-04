import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles


@cocotb.test()
async def test_reset(dut):
    dut._log.info("start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    dut._log.info("reset")
    dut.rst.value = 1
    dut.data_in.value = 1
    await ClockCycles(dut.clk, 2)
    dut.rst.value = 0
    dut.data_in.value = 0

    # Emulate a program with instruction memory all set to 0 (NOP)
    for i in range(1, 512):
        new_pc = i % 256

        # Debug values and execute status should all be 0
        for j in range(6):
            await ClockCycles(dut.clk, 1)
            assert int(dut.data_out.value) == 0

        # 7th cycle gives new PC
        await ClockCycles(dut.clk, 1)
        assert int(dut.data_out.value) == new_pc

        # OUT are all 0.
        for j in range(3):
            await ClockCycles(dut.clk, 1)
            assert int(dut.data_out.value) == 0

    # Should be able to reset instruction read at any point
    new_pc = 0
    for i in range(1, 10):
        await ClockCycles(dut.clk, i)

        # Remember if we got as far as incrementing PC.
        if i >= 6: new_pc += 1

        # Just reset the instruction address counter, not the whole thing
        dut.rst.value = 1
        dut.data_in.value = 2
        await ClockCycles(dut.clk, 1)
        dut.rst.value = 0
        dut.data_in.value = 0

        await ClockCycles(dut.clk, 7)
        assert int(dut.data_out.value) == new_pc
        await ClockCycles(dut.clk, 3)
        new_pc += 1

