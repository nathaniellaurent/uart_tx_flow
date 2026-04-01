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

  // Internal signals
  logic [PtrWidth-1:0] wr_addr, rd_addr;
  logic [DataWidth-1:0] rd_data_mem;
  
  // FIFO controller instance
  fifo_ctrl #(
    .DataWidth(DataWidth),
    .Depth(Depth)
  ) u_fifo_ctrl (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_wr_en(i_wr_en),
    .i_rd_en(i_rd_en),
    .o_wr_addr(wr_addr),
    .o_rd_addr(rd_addr),
    .o_full(o_full),
    .o_empty(o_empty)
  );
  
  // FIFO memory instance
  fifo_mem #(
    .DataWidth(DataWidth),
    .Depth(Depth)
  ) u_fifo_mem (
    .i_clk(i_clk),
    .i_wr_en(i_wr_en && !o_full),
    .i_wr_addr(wr_addr),
    .i_wr_data(i_wr_data),
    .i_rd_addr(rd_addr),
    .o_rd_data(rd_data_mem)
  );
  
  // Output data logic based on FWFT parameter
  generate
    if (FWFT == 1) begin : gen_fwft
      // First-Word Fall-Through: data is always available
      assign o_rd_data = rd_data_mem;
    end else begin : gen_normal
      // Normal mode: gate output with read enable
      assign o_rd_data = i_rd_en ? rd_data_mem : '0;
    end
  endgenerate

endmodule

