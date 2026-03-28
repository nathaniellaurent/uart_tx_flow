// Synchronous FIFO (First-in First-Out) buffer
`timescale 1ns / 1ps
module fifo #(
  parameter  DataWidth = 8,
  parameter  Depth     = 8,
  parameter  FWFT      = 1, // First-Word Fall-Through
  localparam PtrWidth  = $clog2(Depth)
)(
  input  logic                 i_clk,
  input  logic                 i_rst_n,
  input  logic [DataWidth-1:0] i_wr_data,
  input  logic                 i_wr_en,
  input  logic                 i_rd_en,
  output logic [DataWidth-1:0] o_rd_data,
  output logic                 o_full,
  output logic                 o_empty
);

  // TODO: Implement FIFO top-level
  //
  // Requirements:
  //   - Instantiate fifo_mem for storage (dual-port RAM, async read, sync write)
  //   - Instantiate fifo_ctrl for pointer management and flag generation
  //   - If FWFT == 1: o_rd_data always reflects the head of the FIFO (combinational read)
  //   - If FWFT == 0: o_rd_data is gated by i_rd_en (output 0 when not reading)

endmodule
