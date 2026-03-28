// FIFO Controller module
`timescale 1ns / 1ps
module fifo_ctrl #(
  parameter  DataWidth   = 8,
  parameter  Depth       = 8,
  localparam PtrWidth    = $clog2(Depth)
)(
  input  logic                i_clk,
  input  logic                i_rst_n,
  input  logic                i_wr_en,
  input  logic                i_rd_en,
  output logic [PtrWidth-1:0] o_wr_addr,
  output logic [PtrWidth-1:0] o_rd_addr,
  output logic                o_full,
  output logic                o_empty
);

  // TODO: Implement FIFO controller
  //
  // Requirements:
  //   - Maintain read and write pointers (PtrWidth+1 bits wide for wrap-around detection)
  //   - Increment write pointer on i_wr_en, increment read pointer on i_rd_en
  //   - Reset both pointers to 0 on !i_rst_n
  //   - o_wr_addr and o_rd_addr are the lower PtrWidth bits of the respective pointers
  //   - o_full: MSBs differ but lower bits match (write pointer has lapped read pointer)
  //   - o_empty: both pointers are identical (same MSB and lower bits)

endmodule
