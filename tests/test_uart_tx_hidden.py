from __future__ import annotations

import os
import random
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from cocotb_tools.runner import get_runner

LANGUAGE = os.getenv("HDL_TOPLEVEL_LANG", "verilog").lower().strip()

# Parameters matching the golden design
BAUD_RATE = 115200
CLOCK_FREQ = 50_000_000
DATA_LENGTH = 8
FIFO_DEPTH = 8
NUM_TEST = 8

CLOCK_PERIOD_NS = 20  # 50 MHz -> 20 ns
CYCLES_PER_BIT = CLOCK_FREQ // BAUD_RATE  # 434
BIT_PERIOD_NS = CYCLES_PER_BIT * CLOCK_PERIOD_NS  # 8680 ns (exact integer)
HALF_BIT_NS = (CYCLES_PER_BIT // 2) * CLOCK_PERIOD_NS  # 4340 ns
MAX_WAIT_CYCLES = CYCLES_PER_BIT * 12  # Max cycles to wait for any signal


async def reset_dut(dut):
    """Assert reset for two clock cycles, then release."""
    dut.i_rst_n.value = 0
    dut.i_tx_req.value = 0
    dut.i_cts.value = 1  # Permit TX
    dut.i_tx_data.value = 0
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)


async def fifo_tx_write(dut, data):
    """Write a byte into the TX FIFO, waiting until ready."""
    for _ in range(MAX_WAIT_CYCLES):
        if dut.o_tx_rdy.value == 1:
            break
        await RisingEdge(dut.i_clk)
    else:
        assert False, "Timeout waiting for o_tx_rdy"
    dut.i_tx_req.value = 1
    dut.i_tx_data.value = data
    await RisingEdge(dut.i_clk)
    dut.i_tx_req.value = 0


async def receive_uart_stream(dut):
    """Capture one UART frame from o_tx using Timer-based timing."""
    # Wait for start bit (o_tx goes low)
    for _ in range(MAX_WAIT_CYCLES):
        if dut.o_tx.value == 0:
            break
        await RisingEdge(dut.i_clk)
    else:
        assert False, "Timeout waiting for TX start bit"

    # Wait half a bit period to align to mid-bit
    await Timer(HALF_BIT_NS, unit="ns")

    # Read 8 data bits (LSB first)
    packet = 0
    for j in range(DATA_LENGTH):
        await Timer(BIT_PERIOD_NS, unit="ns")
        if dut.o_tx.value == 1:
            packet |= (1 << j)

    # Wait for stop bit
    await Timer(BIT_PERIOD_NS, unit="ns")
    assert dut.o_tx.value == 1, "No stop bit detected on TX output"

    return packet


@cocotb.test(timeout_time=50, timeout_unit="ms")
async def uart_tx_basic(dut):
    """Test TX path: send a single byte and verify the serial frame."""
    clock = Clock(dut.i_clk, CLOCK_PERIOD_NS, unit="ns")
    clock.start(start_high=False)
    await reset_dut(dut)

    assert dut.o_tx_rdy.value == 1, "o_tx_rdy should be 1 at startup"
    assert dut.o_tx.value == 1, "o_tx should idle high"

    test_val = random.randint(0, 255)
    await fifo_tx_write(dut, test_val)
    got = await receive_uart_stream(dut)
    assert got == test_val, f"TX mismatch: sent {test_val:#04x}, received {got:#04x}"


@cocotb.test(timeout_time=100, timeout_unit="ms")
async def uart_tx_back_to_back(dut):
    """Test TX path: load FIFO with multiple bytes, verify all serial frames."""
    clock = Clock(dut.i_clk, CLOCK_PERIOD_NS, unit="ns")
    clock.start(start_high=False)
    await reset_dut(dut)

    test_vectors = [random.randint(0, 255) for _ in range(NUM_TEST)]

    async def write_all():
        for val in test_vectors:
            await fifo_tx_write(dut, val)

    async def read_all():
        for i, expected in enumerate(test_vectors):
            got = await receive_uart_stream(dut)
            assert got == expected, (
                f"TX mismatch at frame {i}: sent {expected:#04x}, received {got:#04x}"
            )

    write_task = cocotb.start_soon(write_all())
    read_task = cocotb.start_soon(read_all())
    await write_task
    await read_task


@cocotb.test(timeout_time=50, timeout_unit="ms")
async def uart_tx_idle_high(dut):
    """Test that o_tx stays high when there is nothing to transmit."""
    clock = Clock(dut.i_clk, CLOCK_PERIOD_NS, unit="ns")
    clock.start(start_high=False)
    await reset_dut(dut)

    # Wait many cycles and verify o_tx stays high
    for _ in range(100):
        await RisingEdge(dut.i_clk)
        assert dut.o_tx.value == 1, "o_tx should remain high when idle"


@cocotb.test(timeout_time=100, timeout_unit="ms")
async def uart_tx_cts_flow_control(dut):
    """Test that TX does not transmit when CTS is de-asserted."""
    clock = Clock(dut.i_clk, CLOCK_PERIOD_NS, unit="ns")
    clock.start(start_high=False)
    await reset_dut(dut)

    # De-assert CTS (prevent transmission)
    dut.i_cts.value = 0

    # Write a byte into the FIFO
    test_val = random.randint(0, 255)
    await fifo_tx_write(dut, test_val)

    # Wait several bit periods — o_tx should stay high (no transmission)
    await Timer(BIT_PERIOD_NS * 3, unit="ns")
    assert dut.o_tx.value == 1, "o_tx should remain high when CTS is de-asserted"

    # Assert CTS — transmission should begin
    dut.i_cts.value = 1
    got = await receive_uart_stream(dut)
    assert got == test_val, f"TX after CTS: sent {test_val:#04x}, received {got:#04x}"


@cocotb.test(timeout_time=50, timeout_unit="ms")
async def uart_tx_fifo_full(dut):
    """Test that o_tx_rdy goes low when FIFO is full."""
    clock = Clock(dut.i_clk, CLOCK_PERIOD_NS, unit="ns")
    clock.start(start_high=False)
    await reset_dut(dut)

    # De-assert CTS to prevent draining
    dut.i_cts.value = 0

    # Fill the FIFO
    for i in range(FIFO_DEPTH):
        dut.i_tx_req.value = 1
        dut.i_tx_data.value = i
        await RisingEdge(dut.i_clk)
    dut.i_tx_req.value = 0
    await RisingEdge(dut.i_clk)

    assert dut.o_tx_rdy.value == 0, "o_tx_rdy should be 0 when FIFO is full"

    # Re-assert CTS and drain — o_tx_rdy should go back to 1
    dut.i_cts.value = 1

    # Wait for first frame to complete (frees a FIFO slot)
    _ = await receive_uart_stream(dut)

    # Wait for TX FSM to reach DONE and pulse the FIFO read
    await Timer(BIT_PERIOD_NS, unit="ns")

    # After one frame transmitted, FIFO should have space
    assert dut.o_tx_rdy.value == 1, "o_tx_rdy should be 1 after draining one entry"


def test_uart_tx_hidden_runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent

    sources = [
        proj_path / "sources" / "uart_tx_top.sv",
        proj_path / "sources" / "uart_tx.sv",
        proj_path / "sources" / "fifo.sv",
        proj_path / "sources" / "fifo_ctrl.sv",
        proj_path / "sources" / "fifo_mem.sv",
    ]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="uart_tx_top",
        always=True,
        parameters={"FlowControl": 1},
    )
    runner.test(hdl_toplevel="uart_tx_top", test_module="test_uart_tx_hidden")
