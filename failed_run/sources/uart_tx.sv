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
  input  logic                  i_rst_n,
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

  // FSM States
  typedef enum logic [2:0] {
    WAIT  = 3'b000,
    START = 3'b001,
    DATA  = 3'b010,
    STOP  = 3'b011,
    DONE  = 3'b100
  } state_t;
  
  state_t current_state, next_state;
  
  // Internal registers
  logic [ClkCounterWidth-1:0] clk_counter;
  logic [BitCounterWidth-1:0] bit_counter;
  logic [DataLength-1:0] tx_shift_reg;
  logic tx_out;
  
  // Clock counter for bit timing
  logic bit_done;
  assign bit_done = (clk_counter == CyclesPerBit - 1);
  
  // Flow control condition
  logic can_transmit;
  assign can_transmit = FlowControl ? (!i_tx_fifo_empty && i_cts) : !i_tx_fifo_empty;
  
  // State machine
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      current_state <= WAIT;
    end else begin
      current_state <= next_state;
    end
  end
  
  // Next state logic
  always_comb begin
    next_state = current_state;
    case (current_state)
      WAIT: begin
        if (can_transmit) begin
          next_state = START;
        end
      end
      START: begin
        if (bit_done) begin
          next_state = DATA;
        end
      end
      DATA: begin
        if (bit_done && (bit_counter == DataLength - 1)) begin
          next_state = STOP;
        end
      end
      STOP: begin
        if (bit_done) begin
          next_state = DONE;
        end
      end
      DONE: begin
        next_state = WAIT;
      end
      default: next_state = WAIT;
    endcase
  end
  
  // Clock counter
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      clk_counter <= '0;
    end else begin
      if (current_state == WAIT || current_state == DONE || bit_done) begin
        clk_counter <= '0;
      end else begin
        clk_counter <= clk_counter + 1'b1;
      end
    end
  end
  
  // Bit counter (for DATA state)
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      bit_counter <= '0;
    end else begin
      if (current_state == DATA && bit_done) begin
        bit_counter <= bit_counter + 1'b1;
      end else if (current_state != DATA) begin
        bit_counter <= '0;
      end
    end
  end
  
  // Shift register (load on WAIT->START transition)
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      tx_shift_reg <= '0;
    end else begin
      if (current_state == WAIT && next_state == START) begin
        // Load data from FIFO
        tx_shift_reg <= i_tx_fifo_data;
      end else if (current_state == DATA && bit_done) begin
        // Shift right to send LSB first
        tx_shift_reg <= tx_shift_reg >> 1;
      end
    end
  end
  
  // TX output logic
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      tx_out <= 1'b1; // Idle high
    end else begin
      case (current_state)
        WAIT, DONE: tx_out <= 1'b1;        // Idle high
        START:      tx_out <= 1'b0;        // Start bit (low)
        DATA:       tx_out <= tx_shift_reg[0]; // Data bits LSB first
        STOP:       tx_out <= 1'b1;        // Stop bit (high)
        default:    tx_out <= 1'b1;
      endcase
    end
  end
  
  // FIFO read enable (pulse in DONE state)
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      o_tx_fifo_read_en <= 1'b0;
    end else begin
      o_tx_fifo_read_en <= (current_state == DONE);
    end
  end
  
  // Output assignment
  assign o_tx = tx_out;

endmodule

