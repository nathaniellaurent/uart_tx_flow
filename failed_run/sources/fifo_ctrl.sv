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

  // Pointer registers (one extra bit for wrap-around detection)
  logic [PtrWidth:0] wr_ptr, rd_ptr;
  logic [PtrWidth:0] wr_ptr_next, rd_ptr_next;
  
  // Next pointer values (for combinational logic)
  assign wr_ptr_next = wr_ptr + 1'b1;
  assign rd_ptr_next = rd_ptr + 1'b1;
  
  // Address outputs - use current pointer values (before any updates)
  assign o_wr_addr = wr_ptr[PtrWidth-1:0];
  assign o_rd_addr = rd_ptr[PtrWidth-1:0];
  
  // Status flags
  assign o_empty = (wr_ptr == rd_ptr);
  assign o_full  = (wr_ptr[PtrWidth] != rd_ptr[PtrWidth]) && (wr_ptr[PtrWidth-1:0] == rd_ptr[PtrWidth-1:0]);
  
  // Delayed signals for pointer updates
  logic wr_en_d, rd_en_d;
  logic was_full_d, was_empty_d;
  
  // Register the enable signals to delay pointer updates
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      wr_en_d <= 1'b0;
      rd_en_d <= 1'b0;
      was_full_d <= 1'b0;
      was_empty_d <= 1'b1;
    end else begin
      wr_en_d <= i_wr_en;
      rd_en_d <= i_rd_en;
      was_full_d <= o_full;
      was_empty_d <= o_empty;
    end
  end
  
  // Pointer update logic - use delayed signals so updates happen after memory operation
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      wr_ptr <= '0;
      rd_ptr <= '0;
    end else begin
      // Write pointer updates one cycle after successful write
      if (wr_en_d && !was_full_d) begin
        wr_ptr <= wr_ptr + 1'b1;
      end
      // Read pointer updates one cycle after successful read  
      if (rd_en_d && !was_empty_d) begin
        rd_ptr <= rd_ptr + 1'b1;
      end
    end
  end

endmodule







