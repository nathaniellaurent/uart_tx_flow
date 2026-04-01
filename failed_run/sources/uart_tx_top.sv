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

  // Internal signals between FIFO and UART TX
  logic [DataLength-1:0] fifo_rd_data;
  logic fifo_empty;
  logic fifo_full;
  logic fifo_rd_en;
  
  // TX FIFO instance (FWFT mode for stable data during transmission)
  fifo #(
    .DataWidth(DataLength),
    .Depth(FifoDepth),
    .FWFT(1)
  ) u_tx_fifo (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_wr_data(i_tx_data),
    .i_wr_en(i_tx_req),
    .i_rd_en(fifo_rd_en),
    .o_rd_data(fifo_rd_data),
    .o_full(fifo_full),
    .o_empty(fifo_empty)
  );
  
  // UART TX instance
  uart_tx #(
    .SystemClockFreq(SystemClockFreq),
    .BaudRate(BaudRate),
    .Parity(1'b0),
    .StopBit(1'b1),
    .DataLength(DataLength),
    .FlowControl(FlowControl)
  ) u_uart_tx (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .o_tx(o_tx),
    .i_cts(i_cts),
    .i_tx_fifo_data(fifo_rd_data),
    .i_tx_fifo_empty(fifo_empty),
    .o_tx_fifo_read_en(fifo_rd_en)
  );
  
  // TX ready signal (inverted full flag)
  assign o_tx_rdy = !fifo_full;

endmodule

