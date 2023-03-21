# Copyright (C) 2023 Michael Bell
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles

class HovaTest:
    def __init__(self, dut):
        self.dut = dut
        self.in1 = 0
        self.in2 = 0
        self.pc = 0
        self.out1 = 0
        self.out2 = 0
        self.dbg = [0]*5
        self.rosc_enabled = False

    async def start_and_reset(self):
        self.dut._log.info("start")
        self.clock = Clock(self.dut.clk, 10, units="us")
        cocotb.start_soon(self.clock.start())

        self.dut._log.info("reset")
        self.dut.rst.value = 1
        self.dut.data_in.value = 1
        await ClockCycles(self.dut.clk, 10)
        self.dut.rst.value = 0
        self.dut.data_in.value = 0

    async def execute_instr(self, instr):
        rising = True
        for i in range(5):
            self.dut.data_in.value = instr & 0x3F
            await ClockCycles(self.dut.clk, 1, rising)
            rising = not rising
            self.dbg[i] = self.dut.data_out.value
            instr >>= 6
        
        if (self.dut.data_out.value & 0x1) != 0: self.in1 = 0
        if (self.dut.data_out.value & 0x2) != 0: self.in2 = 0
        out1_valid = (self.dut.data_out.value & 0x4) != 0
        out2_valid = (self.dut.data_out.value & 0x8) != 0

        self.dut.data_in.value = instr & 0x3
        await FallingEdge(self.dut.clk)
        
        self.dut.data_in.value = self.in1 & 0x3F
        await RisingEdge(self.dut.clk)
        
        self.dut.data_in.value = (self.in1 >> 6) & 0x3F
        await FallingEdge(self.dut.clk)

        self.dut.data_in.value = self.in2 & 0x3F
        await RisingEdge(self.dut.clk)
        self.pc = self.dut.data_out.value

        self.dut.data_in.value = (self.in2 >> 6) & 0x3F
        await FallingEdge(self.dut.clk)

        self.dut.data_in.value = 0
        await RisingEdge(self.dut.clk)
        new_out = self.dut.data_out.value

        await ClockCycles(self.dut.clk, 1)
        new_out = new_out | ((self.dut.data_out.value & 0xF) << 8)
        new_out = (new_out ^ 0x800) - 0x800 # Sign extend

        self.dut.rst.value = 1
        self.dut.data_in.value = 6 if self.rosc_enabled else 2
        await ClockCycles(self.dut.clk, 1)
        self.dut.rst.value = 0
        self.dut.data_in.value = (self.in2 >> 6) & 0x3F

        if out1_valid:
            self.out1 = new_out
        elif out2_valid:
            self.out2 = new_out

    async def load_val_to_a(self, val):
        self.dut._log.debug("A <= {}".format(val))

        self.in1 = val

        #await self.execute_instr(0o10203040506)

        #                          ALU- A- B- C- D W- F- PC O I X K----- L-----
        await self.execute_instr(0b0000_00_00_00_0_00_00_00_0_0_0_000000_000000)
        await self.execute_instr(0b0000_11_00_00_0_00_00_00_0_0_0_000000_000000)

    async def load_val_to_b(self, val):
        self.dut._log.debug("B <= {}".format(val))

        #                          ALU- A- B- C- D W- F- PC O I X K----- L-----
        await self.execute_instr(0b0000_00_11_00_0_00_00_00_0_0_1_000000_000000 + val)

    async def load_val_to_c(self, val):
        self.dut._log.debug("C <= {}".format(val))

        await self.load_val_to_b(val)

        #                          ALU- A- B- C- D W- F- PC O I X K----- L-----
        await self.execute_instr(0b0010_00_00_01_0_00_00_00_0_0_0_000000_000000)

    async def enable_rosc(self, enabled=True):
        self.rosc_enabled = enabled
        self.dut.rst.value = 1
        self.dut.data_in.value = 6 if enabled else 2
        await ClockCycles(self.dut.clk, 1)
        self.dut.rst.value = 0
        self.dut.data_in.value = 0

@cocotb.test()
async def test_reset(dut):
    hov = HovaTest(dut)
    await hov.start_and_reset()

    # Emulate a program with instruction memory all set to 0 (NOP)
    dut._log.info("check PC")
    for i in range(1, 512):
        new_pc = i % 256

        # OUT low bits are all 0.
        await ClockCycles(dut.clk, 1)
        assert int(dut.data_out.value) == 0

        # OUT high bits should be 0
        await ClockCycles(dut.clk, 1)
        assert int(dut.data_out.value) == 0

        # Execute status should be 0
        await ClockCycles(dut.clk, 1)
        assert int(dut.data_out.value) == 0

        # OUT 7 seg should be a zero
        await ClockCycles(dut.clk, 1)
        assert int(dut.data_out.value) == 0b00111111

        # 5th cycle gives new PC
        await ClockCycles(dut.clk, 1)
        assert int(dut.data_out.value) == new_pc

    # Should be able to reset instruction read at any point
    dut._log.info("check addr reset")
    new_pc = 0
    for i in range(1, 5):
        await ClockCycles(dut.clk, i)

        # Remember if we got as far as incrementing PC.
        if i >= 3: new_pc += 1

        # Just reset the instruction address counter, not the whole thing
        dut.rst.value = 1
        dut.data_in.value = 2
        await ClockCycles(dut.clk, 1)
        dut.rst.value = 0
        dut.data_in.value = 0

        await ClockCycles(dut.clk, 5)
        assert int(dut.data_out.value) == new_pc
        new_pc += 1

@cocotb.test()
async def test_alu(dut):
    hov = HovaTest(dut)
    await hov.start_and_reset()

    async def test_alu_op(hov, alu_op, a, b, expected_result):
        await hov.load_val_to_a(a)
        await hov.load_val_to_b(b)
        #                         ALU- A- B- C- D W- F- PC O I X K----- L-----
        await hov.execute_instr(0b0000_00_00_00_0_01_10_00_0_0_0_000000_000000 + (alu_op << 28))  # W=ALU
        await hov.execute_instr(0b0000_00_00_00_0_00_00_00_1_0_0_000000_000000)  # OUT1=W
        assert hov.out1 == expected_result

    await test_alu_op(hov, 0b0000, 7, 35, 0)   # Zero
    await test_alu_op(hov, 0b0001, 7, 35, -7)  # -A
    await test_alu_op(hov, 0b0010, 7, 35, 35)  # B

    #                         ALU- A- B- C- D W- F- PC O I X K----- L-----
    await hov.execute_instr(0b0010_00_00_10_0_00_00_00_0_0_0_000000_000000)  # DEC
    await test_alu_op(hov, 0b0011, 7, 35, -1)  # C

    await hov.load_val_to_c(23)
    await test_alu_op(hov, 0b0011, 7, 35, 23)  # C

    await test_alu_op(hov, 0b0100, 7, 35, 3)   # A>>1
    await test_alu_op(hov, 0b0101, 7, 35, 42)  # A+B
    await test_alu_op(hov, 0b0110, 7, 35, 28)  # B-A
    await test_alu_op(hov, 0b0111, 7, 35, 42)  # A+B+F
    await test_alu_op(hov, 0b1000, 7, 35, 28)  # B-A-F

    await test_alu_op(hov, 0b0110, 35, 7, -28)  # B-A
    await test_alu_op(hov, 0b0111, 7, 35, 43)  # A+B+F
    await test_alu_op(hov, 0b0110, 35, 7, -28)  # B-A
    await test_alu_op(hov, 0b1000, 7, 35, 27)  # B-A-F

    await test_alu_op(hov, 0b1001, 7, 35, 7|35)  # A|B
    await test_alu_op(hov, 0b1010, 7, 35, 7&35)  # A&B
    await test_alu_op(hov, 0b1011, 7, 35, 7^35)  # A^B
    await test_alu_op(hov, 0b1100, 7, 35, ~7)  # ~A
    await test_alu_op(hov, 0b1101, 7, 35, 7)  # A
    await test_alu_op(hov, 0b1110, 8, 35, 0)  # Random number - disabled
    await test_alu_op(hov, 0b1111, 9, 42, 1)  # 1

    await hov.enable_rosc()

    # Test random number fetch, but don't assert
    await hov.execute_instr(0b1110_00_00_00_0_01_00_00_0_0_0_000000_000000)  # W=RND
    await hov.execute_instr(0b1110_00_00_00_0_01_00_00_1_0_0_000000_000000)  # OUT1=W, W=RND
    await hov.execute_instr(0b1110_00_00_00_0_00_00_00_1_1_0_000000_000000)  # OUT2=W
    assert hov.out1 != hov.out2 # Because random numbers are actually deterministic in test, this is OK
    print("Random numbers: ", hov.out1, hov.out2)

    await hov.execute_instr(0b1110_00_00_00_0_01_00_00_0_0_0_000000_000000)  # W=RND
    await hov.execute_instr(0b1110_00_00_00_0_01_00_00_1_0_0_000000_000000)  # OUT1=W, W=RND
    await hov.execute_instr(0b1110_00_00_00_0_00_00_00_1_1_0_000000_000000)  # OUT2=W
    assert hov.out1 != hov.out2 # Because random numbers are actually deterministic in test, this is OK
    print("Random numbers: ", hov.out1, hov.out2)

    # Check things are still working normally.
    await test_alu_op(hov, 0b0110, 35, 7, -28)  # B-A
    await test_alu_op(hov, 0b0111, 7, 35, 43)  # A+B+F
    await test_alu_op(hov, 0b0110, 35, 7, -28)  # B-A
    await test_alu_op(hov, 0b1000, 7, 35, 27)  # B-A-F

    await test_alu_op(hov, 0b1001, 7, 35, 7|35)  # A|B
    await test_alu_op(hov, 0b1010, 7, 35, 7&35)  # A&B
    await test_alu_op(hov, 0b1011, 7, 35, 7^35)  # A^B

@cocotb.test()
async def test_branch(dut):
    hov = HovaTest(dut)
    await hov.start_and_reset()

    # Unconditional branch
    #                         ALU- A- B- C- D W- F- PC O I X K----- L-----    
    await hov.execute_instr(0b0000_00_00_00_0_00_00_01_0_0_0_000000_001000)  # JMP 8
    assert hov.pc.value == 8
    await hov.execute_instr(0b0000_00_00_00_0_00_00_01_0_0_1_000011_111111)  # JMP 255
    assert hov.pc.value == 255
    await hov.execute_instr(0b0000_00_00_00_0_00_00_00_0_0_0_000000_000000)  # NOP
    assert hov.pc.value == 0

    # Decrement C and take a conditional branch using JMPT
    await hov.load_val_to_c(4)
    pc_start = hov.pc.value

    # Executes 5 times without branching because C must decrement to 0 (4 loops), 
    # then F is set true the next time
    for i in range(1, 6):
        #                         ALU- A- B- C- D W- F- PC O I X K----- L-----
        await hov.execute_instr(0b0011_00_00_10_0_00_01_10_0_0_0_000000_000000)  # DEC,F=ZERO(C),JMPT 0
        assert hov.pc.value == pc_start + i

    # Finaly the JMP is taken on the 6th time
    await hov.execute_instr(0b0011_00_00_10_0_00_01_10_0_0_0_000000_000000)  # DEC,F=ZERO(C),JMPT 0
    assert hov.pc.value == 0

    # Decrement C and take a conditional branch using DECNZ
    await hov.load_val_to_c(4)

    # Loops 3 times, then increments PC
    # then F is set true the next time
    for i in range(3):
        #                         ALU- A- B- C- D W- F- PC O I X K----- L-----
        await hov.execute_instr(0b0000_00_00_11_0_00_00_00_0_0_0_000000_010000)  # DECNZ 16
        assert hov.pc.value == 16

    # The DECNZ exits on the 4th time, so PC increments normally
    #                         ALU- A- B- C- D W- F- PC O I X K----- L-----
    await hov.execute_instr(0b0000_00_00_11_0_00_00_00_0_0_0_000000_010000)  # DECNZ 16
    assert hov.pc.value == 17

    await hov.load_val_to_c(1)
    # The DECNZ will not take the branch, but the JMP will
    #                         ALU- A- B- C- D W- F- PC O I X K----- L-----
    await hov.execute_instr(0b0000_00_00_11_0_00_10_01_0_0_0_000000_010000)  # DECNZ,JMP 16
    assert hov.pc.value == 16

    await hov.load_val_to_c(2)
    # The DECNZ will take the branch, the JMPT won't matter
    #                         ALU- A- B- C- D W- F- PC O I X K----- L-----
    await hov.execute_instr(0b0000_00_00_00_0_00_10_00_0_0_0_000000_000000)  # F=NEG(0)
    await hov.execute_instr(0b0000_00_00_11_0_00_00_10_0_0_0_000000_010000)  # DECNZ,JMPT 16
    assert hov.pc.value == 16

    # Set FLAG and don't JMPF
    await hov.execute_instr(0b0000_00_00_00_0_00_01_00_0_0_0_000000_000000)  # F=ZERO(0)
    await hov.execute_instr(0b0000_00_00_00_0_00_00_11_0_0_0_000000_000000)  # JMPF 0
    assert hov.pc.value == 18
    # Do jump true
    await hov.execute_instr(0b0000_00_00_00_0_00_00_10_0_0_0_000000_000000)  # JMPT 0
    assert hov.pc.value == 0

@cocotb.test()
async def test_io(dut):
    hov = HovaTest(dut)
    await hov.start_and_reset()

    # NOP to prime the inputs
    hov.in1 = 23
    hov.in2 = 42
    await hov.execute_instr(0)

    # Load IN1
    #                         ALU- A- B- C- D W- F- PC O I X K----- L-----
    await hov.execute_instr(0b0000_11_00_00_0_00_00_00_0_0_0_000000_000000)

    # D=A, A=IN2, W=-5
    await hov.execute_instr(0b0000_11_00_00_1_11_00_00_0_1_0_111011_000000)
    assert hov.out1 == 0
    assert hov.out2 == 0

    # W=A, OUT1=W, A=D
    await hov.execute_instr(0b0000_10_00_00_0_10_00_00_1_0_0_000000_000000)
    assert hov.out1 == -5
    assert hov.out2 == 0

    # W=A, OUT2=W
    #                         ALU- A- B- C- D W- F- PC O I X K----- L-----
    await hov.execute_instr(0b0000_00_00_00_0_10_00_00_1_1_0_000000_000000)
    assert hov.out2 == 42
    assert hov.out1 == -5

    # OUT1=W,W=-A
    #                         ALU- A- B- C- D W- F- PC O I X K----- L-----
    await hov.execute_instr(0b0001_00_00_00_0_01_00_00_1_0_0_000000_000000)
    assert hov.out2 == 42
    assert hov.out1 == 23

    # OUT2=W
    #                         ALU- A- B- C- D W- F- PC O I X K----- L-----
    await hov.execute_instr(0b0000_00_00_00_0_00_00_00_1_1_0_000000_000000)
    assert hov.out2 == -23
    assert hov.out1 == 23

class HovaRunProgram:
    def __init__(self, dut, prog, in1, in2=None):
        self.dut = dut
        self.prog = prog
        self.in1 = in1.copy()
        self.in2 = in2.copy() if in2 is not None else []
        self.pc = 0
        self.out1 = []
        self.out2 = [] if in2 is not None else self.in2
        self.dbg = [0]*5

    async def start_and_reset(self):
        self.dut._log.info("start")
        self.clock = Clock(self.dut.clk, 10, units="us")
        cocotb.start_soon(self.clock.start())

        self.dut._log.info("reset")
        self.dut.rst.value = 1
        self.dut.data_in.value = 1
        await ClockCycles(self.dut.clk, 2)
        self.dut.rst.value = 0
        self.dut.data_in.value = 0

    async def execute_one(self):
        instr = self.prog[self.pc]
        await self.execute_instr(instr)

    async def execute_instr(self, instr):
        for i in range(5):
            self.dut.data_in.value = instr & 0x3F
            await ClockCycles(self.dut.clk, 1)
            self.dbg[i] = self.dut.data_out.value
            instr >>= 6

        self.dut.data_in.value = instr & 0x3
        await ClockCycles(self.dut.clk, 1)
        if (self.dut.data_out.value & 0x1) != 0: self.in1.pop(0)
        if (self.dut.data_out.value & 0x2) != 0: self.in2.pop(0)
        out1_valid = (self.dut.data_out.value & 0x4) != 0
        out2_valid = (self.dut.data_out.value & 0x8) != 0

        in1 = 0 if len(self.in1) == 0 else self.in1[0]
        in2 = 0 if len(self.in2) == 0 else self.in2[0]
        self.dut.data_in.value = in1 & 0x3F
        await ClockCycles(self.dut.clk, 1)
        self.pc = self.dut.data_out.value

        self.dut.data_in.value = (in1 >> 6) & 0x3F
        await ClockCycles(self.dut.clk, 1)
        new_out = self.dut.data_out.value

        self.dut.data_in.value = in2 & 0x3F
        await ClockCycles(self.dut.clk, 1)
        new_out = new_out | ((self.dut.data_out.value & 0xF) << 8)
        new_out = (new_out ^ 0x800) - 0x800 # Sign extend

        self.dut.data_in.value = (in2 >> 6) & 0x3F
        await ClockCycles(self.dut.clk, 1)

        if out1_valid:
            self.out1.append(new_out)
        elif out2_valid:
            self.out2.append(new_out)

    async def execute_until_out1_len(self, expected_len):

        # JMP 0 to prime the inputs
        await self.execute_instr(0b0000_00_00_00_0_00_00_01_0_0_0_000000_000000)

        while len(self.out1) < expected_len:
            await self.execute_one()

#@cocotb.test()
async def test_example_loop1(dut):
    #     ALU- A- B- C- D W- F- PC O I X K----- L-----
    prog = [
        0b0000_11_00_00_0_00_00_00_0_0_0_000000_000000,  # A=IN1
        0b0000_00_10_00_0_00_00_00_0_0_0_000000_000000,  # B=A
        0b0101_01_01_00_0_00_00_00_0_0_0_000000_000000,  # A=B=A+B
        0b0101_01_01_00_0_00_00_00_0_0_0_000000_000000,  # A=B=A+B
        0b0101_00_00_00_0_01_00_00_0_0_0_000000_000000,  # W=A+B
        0b0000_00_00_00_0_00_00_00_1_0_0_000000_000000,  # OUT1=W
        0b0000_00_00_00_0_00_00_01_0_0_0_000000_000000,  # JMP 0
    ]

    NUM_VALUES = 10
    in1 = [random.randint(-2048 // 8,2047 // 8) for x in range(NUM_VALUES)]

    hov = HovaRunProgram(dut, prog, in1)
    await hov.start_and_reset()

    await hov.execute_until_out1_len(NUM_VALUES)

    for i in range(NUM_VALUES):
        assert hov.out1[i] == in1[i] * 8

#@cocotb.test()
async def test_example_loop5(dut):
    #     ALU- A- B- C- D W- F- PC O I X K----- L-----
    prog = [
        0b0000_11_00_00_0_00_00_00_0_0_0_000000_000000,  # A=IN1
        0b0000_00_10_00_0_00_00_00_0_0_0_000000_000000,  # B=A
        0b0101_01_01_00_0_00_00_00_0_0_0_000000_000000,  # A=B=A+B
        0b0101_01_01_00_0_00_00_00_0_0_0_000000_000000,  # A=B=A+B
        0b0101_11_00_00_0_01_00_00_0_0_0_000000_000000,  # W=A+B,A=IN1
        0b0000_00_10_00_0_00_00_01_1_0_0_000000_000010,  # OUT1=W,B=A,JMP 2
    ]

    NUM_VALUES = 10
    in1 = [random.randint(-2048 // 8,2047 // 8) for x in range(NUM_VALUES)]
    in1.append(0)

    hov = HovaRunProgram(dut, prog, in1)
    await hov.start_and_reset()

    await hov.execute_until_out1_len(NUM_VALUES)

    for i in range(NUM_VALUES):
        assert hov.out1[i] == in1[i] * 8

#@cocotb.test()
async def test_aoc2020_1_1(dut):
    prog = [
        0x0f0017e4,
        0x6d001000,
        0x60127000,
        0x0c001000,
        0x10031011,
        0x60137007,
        0x0c009004,
        0x0c003000,
        0x0c003000,
        0x030017e4,
        0x6d183000,
        0x60127000,
        0x0c013011,
        0x10021000,
        0x6c137009,
        0x10031011,
        0x0000900e,
        0x270057e4,
        0x60081000,
        0x00005000,
    ]

    in1 = [
        2000, 50, 1984, 1648, 32, 1612, 1992, 1671, 1955, 1658, 1592, 1596, 1888, 1540, 239, 1677, 1602, 1877, 1481, 2004, 1985, 1829, 1980, 1500, 1120, 1849, 1941, 1403, 1515, 1915, 1862, 2002, 1952, 1893, 1494, 1610, 1432, 1547, 1488, 1642, 1982, 1666, 1856, 1889, 1691, 1976, 1962, 2005, 1611, 1665, 1816, 1880, 1896, 1552, 1809, 1844, 1553, 1841, 1785, 1968, 1491, 1498, 1995, 1748, 1533, 1988, 2001, 1917, 0
    ]

    hov = HovaRunProgram(dut, prog, in1)
    await hov.start_and_reset()

    await hov.execute_until_out1_len(2)
    assert hov.out1[0] + hov.out1[1] == 2020

#@cocotb.test()
async def test_aoc2020_5_2(dut):
    prog = [
        0x0c001000,
        0x1c921000,
        0x0001f001,
        0x0c003000,
        0x1e123000,
        0x6007100c,
        0x00011008,
        0x0000f004,
        0x10121000,
        0x0001100f,
        0x20887000,
        0x0c00f004,
        0x30041000,
        0x00417004,
        0x0000f012,
        0x20081000,
        0x301c7000,
        0x0c417004,
        0x0e003000,
        0x67201fff,
        0x68021000,
        0x50091012,
        0x00005000,
    ]

    # The program outputs the one missing value from a range of values
    NUM_VALUES = 7
    offset = random.randint(1,1000)
    removed_idx = random.randint(1, NUM_VALUES - 1)
    in1 = [x + offset for x in range(NUM_VALUES + 1)]
    removed_value = in1[removed_idx]
    del in1[removed_idx]
    random.shuffle(in1)
    in1.append(0)
    in1.append(0)

    hov = HovaRunProgram(dut, prog, in1)
    await hov.start_and_reset()

    await hov.execute_until_out1_len(1)

    assert hov.out1[0] == removed_value