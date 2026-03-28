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

  logic [DataLength-1:0] uart_tx_fifo_data;
  logic tx_fifo_full, tx_fifo_empty;
  logic uart_tx_fifo_read_en;

  fifo #(
    .DataWidth(DataLength),
    .Depth(FifoDepth)
  ) fifo_tx (
    .i_clk,
    .i_rst_n,
    .i_wr_data(i_tx_data),
    .i_wr_en(i_tx_req),
    .i_rd_en(uart_tx_fifo_read_en),
    .o_rd_data(uart_tx_fifo_data),
    .o_full(tx_fifo_full),
    .o_empty(tx_fifo_empty)
  );

  assign o_tx_rdy = ~tx_fifo_full;

  uart_tx #(
    .DataLength(DataLength),
    .FlowControl(FlowControl),
    .SystemClockFreq(SystemClockFreq),
    .BaudRate(BaudRate)
  ) uart_tx_inst (
    .i_clk,
    .i_rst_n,
    .o_tx,
    .i_cts,
    .i_tx_fifo_data(uart_tx_fifo_data),
    .i_tx_fifo_empty(tx_fifo_empty),
    .o_tx_fifo_read_en(uart_tx_fifo_read_en)
  );

endmodule
