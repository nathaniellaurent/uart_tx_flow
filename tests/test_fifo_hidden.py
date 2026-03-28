from __future__ import annotations

import os
import random
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from cocotb_tools.runner import get_runner

LANGUAGE = os.getenv("HDL_TOPLEVEL_LANG", "verilog").lower().strip()

DATA_WIDTH = 8
DEPTH = 8


async def reset_dut(dut):
    """Assert reset for two clock cycles."""
    dut.i_rst_n.value = 0
    dut.i_wr_en.value = 0
    dut.i_rd_en.value = 0
    dut.i_wr_data.value = 0
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)


@cocotb.test(timeout_time=50, timeout_unit="ms")
async def fifo_write_then_read(dut):
    """Test 1: Fill the FIFO completely, then drain it and verify order."""
    clock = Clock(dut.i_clk, 10, unit="ns")
    clock.start(start_high=False)
    await reset_dut(dut)

    test_data = [random.randint(0, (1 << DATA_WIDTH) - 1) for _ in range(DEPTH)]

    # Write all entries
    for val in test_data:
        dut.i_wr_data.value = val
        dut.i_wr_en.value = 1
        await RisingEdge(dut.i_clk)
    dut.i_wr_en.value = 0
    await RisingEdge(dut.i_clk)

    # FIFO should be full
    assert dut.o_full.value == 1, "FIFO should be full after writing DEPTH entries"

    # Read all entries
    for i, expected in enumerate(test_data):
        dut.i_rd_en.value = 1
        await RisingEdge(dut.i_clk)
        got = int(dut.o_rd_data.value)
        assert got == expected, f"Read mismatch at index {i}: expected {expected:#x}, got {got:#x}"
    dut.i_rd_en.value = 0
    await RisingEdge(dut.i_clk)

    # FIFO should be empty
    assert dut.o_empty.value == 1, "FIFO should be empty after reading all entries"


@cocotb.test(timeout_time=50, timeout_unit="ms")
async def fifo_write_read_interleaved(dut):
    """Test 2: Write one entry then read one entry, interleaved."""
    clock = Clock(dut.i_clk, 10, unit="ns")
    clock.start(start_high=False)
    await reset_dut(dut)

    test_data = [random.randint(0, (1 << DATA_WIDTH) - 1) for _ in range(DEPTH)]

    for i, val in enumerate(test_data):
        # Write
        dut.i_wr_data.value = val
        dut.i_wr_en.value = 1
        await RisingEdge(dut.i_clk)
        dut.i_wr_en.value = 0
        await RisingEdge(dut.i_clk)

        # Read
        dut.i_rd_en.value = 1
        await RisingEdge(dut.i_clk)
        got = int(dut.o_rd_data.value)
        assert got == val, f"Interleaved mismatch at index {i}: expected {val:#x}, got {got:#x}"
        dut.i_rd_en.value = 0
        await RisingEdge(dut.i_clk)


@cocotb.test(timeout_time=50, timeout_unit="ms")
async def fifo_simultaneous_write_read(dut):
    """Test 3: Simultaneous write and read (pipeline style)."""
    clock = Clock(dut.i_clk, 10, unit="ns")
    clock.start(start_high=False)
    await reset_dut(dut)

    test_data = [random.randint(0, (1 << DATA_WIDTH) - 1) for _ in range(DEPTH)]

    # Write first value
    dut.i_wr_data.value = test_data[0]
    dut.i_wr_en.value = 1
    await RisingEdge(dut.i_clk)

    # Simultaneous write next + read previous
    for i in range(1, DEPTH):
        dut.i_wr_data.value = test_data[i]
        dut.i_wr_en.value = 1
        dut.i_rd_en.value = 1
        await RisingEdge(dut.i_clk)
        got = int(dut.o_rd_data.value)
        assert got == test_data[i - 1], (
            f"Pipeline mismatch at index {i - 1}: expected {test_data[i - 1]:#x}, got {got:#x}"
        )

    # Read last value
    dut.i_wr_en.value = 0
    dut.i_rd_en.value = 1
    await RisingEdge(dut.i_clk)
    dut.i_rd_en.value = 0


@cocotb.test(timeout_time=50, timeout_unit="ms")
async def fifo_reset_clears_state(dut):
    """Test 4: Reset clears the FIFO to empty."""
    clock = Clock(dut.i_clk, 10, unit="ns")
    clock.start(start_high=False)
    await reset_dut(dut)

    # Write some data
    for i in range(4):
        dut.i_wr_data.value = i
        dut.i_wr_en.value = 1
        await RisingEdge(dut.i_clk)
    dut.i_wr_en.value = 0
    await RisingEdge(dut.i_clk)

    assert dut.o_empty.value == 0, "FIFO should not be empty after writes"

    # Reset
    await reset_dut(dut)
    assert dut.o_empty.value == 1, "FIFO should be empty after reset"
    assert dut.o_full.value == 0, "FIFO should not be full after reset"


def test_fifo_hidden_runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent

    sources = [
        proj_path / "golden" / "fifo.sv",
        proj_path / "golden" / "fifo_ctrl.sv",
        proj_path / "golden" / "fifo_mem.sv",
    ]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="fifo",
        always=True,
    )
    runner.test(hdl_toplevel="fifo", test_module="test_fifo_hidden")
