module uart_tx #(
  parameter SystemClockFreq = 50_000_000,
  parameter BaudRate        = 115200,
  parameter Parity          = 1'b0,
  parameter StopBit         = 1'b1,
  parameter DataLength      = 8,
  parameter FlowControl     = 1'b0
)(
  /* Main Signals */
  input  logic                  i_clk,
  input  logic 	                i_rst_n,
  /* UART Signals */
  output logic                  o_tx,
  input  logic                  i_cts,
  /* FIFO Signals */
  input  logic [DataLength-1:0] i_tx_fifo_data,
  input  logic                  i_tx_fifo_empty,
  output logic                  o_tx_fifo_read_en
);

  localparam CyclesPerBit    = SystemClockFreq / BaudRate;
  localparam ClkCounterWidth = $clog2(CyclesPerBit);
  localparam BitCounterWidth = $clog2(DataLength);

  // TODO: Implement TX shift-register FSM
  //
  // States: RESET -> WAIT -> START -> DATA -> (optional PARITY) -> STOP -> DONE -> WAIT
  //
  // Requirements:
  //   - In WAIT state, begin transmission only when TX FIFO is not empty
  //     (and if FlowControl is enabled, only when i_cts is asserted)
  //   - START state: drive o_tx low for one bit period (CyclesPerBit clocks)
  //   - DATA state: shift out DataLength bits LSB-first, one bit period each
  //     The FIFO uses First-Word Fall-Through (FWFT), so i_tx_fifo_data holds
  //     the current word stable throughout transmission. You may either index it
  //     directly with a bit counter, or copy it into a local shift register on
  //     the WAIT->START transition. If using a shift register, be careful not to
  //     shift during START — only begin shifting once DATA state begins.
  //   - STOP state: drive o_tx high for one bit period
  //   - DONE state: pulse o_tx_fifo_read_en to advance the FIFO to the next word
  //   - o_tx must be registered (driven from a flip-flop, not combinational)
  //   - o_tx idles high, resets high

endmodule
