`timescale 1ns / 1ps
// UART Transmitter with TX FIFO
module uart_tx_top #(
  parameter DataLength      = 8,
  parameter BaudRate        = 115200,
  parameter FifoDepth       = 8,
  parameter SystemClockFreq = 50_000_000,
  parameter FlowControl     = 1'b0
)(
  /* Main Signals */
  input  logic        i_rst_n,    /* Async active low reset */
  input  logic        i_clk,
  /* Module Signals */
  input  logic [7:0]  i_tx_data,  /* Byte to send */
  input  logic        i_tx_req,   /* Request to send */
  output logic        o_tx_rdy,   /* TX FIFO Not Full */
  /* UART Signals */
  output logic        o_tx,
  input  logic        i_cts
);

  // TODO: Implement internal logic
  //
  // Required submodules and logic:
  //   - TX FIFO (fifo instance, FWFT mode) for transmit data buffering
  //   - uart_tx instance for serial transmission
  //   - o_tx_rdy driven from TX FIFO full flag (inverted)
  //   - Wire the FIFO's read data and empty flag to uart_tx's inputs
  //   - Wire uart_tx's o_tx_fifo_read_en back to the FIFO's read enable

endmodule
