/**
 * Minimal module for testing PS/2 on hardware.
 * Displays the last two received raw bytes on LEDs.
 */
module top_ps2_test (
    input  logic        clk,      // 100MHz clock (default from Basys3)
    input  logic        btnC,     // Reset
    inout  wire         PS2Clk,
    inout  wire         PS2Data,
    output logic [15:0] led
);

  logic [7:0] rx_data;
  logic       read_data;
  logic       err;

  Ps2Interface ps2_inst (
      .ps2_clk(PS2Clk),
      .ps2_data(PS2Data),
      .clk(clk),
      .rst(btnC),
      .tx_data(8'h00),
      .write_data(1'b0),
      .rx_data(rx_data),
      .read_data(read_data),
      .busy(),
      .err(err)
  );

  logic [15:0] history = 0;

  always_ff @(posedge clk) begin
    if (btnC) begin
      history <= 16'h0000;
    end else if (read_data) begin
      history <= {history[7:0], rx_data};
    end
  end

  assign led = history;

endmodule
