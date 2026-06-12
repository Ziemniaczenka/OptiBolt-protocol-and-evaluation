/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Top module connecting Evaluation and OptiBolt
 */

module top (
    // Common
    input logic clk74p25,
    input logic clk100,
    input logic clk400,
    input logic rst_n,

    // Evaluation
    output logic       vs,
    output logic       hs,
    output logic [3:0] r,
    output logic [3:0] g,
    output logic [3:0] b,
    inout  wire        ps2_clk,
    inout  wire        ps2_data,

    //OptiBolt
    input  logic OptiBolt_rx,
    output logic OptiBolt_tx,

    //hardware
    input  logic [5:0]  sw,
    output logic [15:0] led
);

  /**
    * Local variables and signals
    */

    logic [3:0] oversampling = 4'b0000;
    logic [3:0] bit_rate;

    //rx
    logic rx_enable, rx_empty, rx_full;
    logic [7:0] data_out;
    logic [2:0] msg_type_out;
    logic parity_error, manchester_code_error, preamble_error;

    //tx
    logic tx_enable, tx_empty, tx_full;
    logic [2:0] tx_msg_type;
    logic [7:0] tx_data;

    logic [31:0] tx_timer;
    logic rx_enable_dly;
    logic [24:0] err_stretch_man;
    logic [24:0] err_stretch_pre;
    logic [24:0] err_stretch_par;


    always_comb begin
      if      (sw[5]) begin bit_rate = 4'b0110; led[5:0] = 6'b100000; end // 50M
      else if (sw[4]) begin bit_rate = 4'b0101; led[5:0] = 6'b010000; end // 25M
      else if (sw[3]) begin bit_rate = 4'b0100; led[5:0] = 6'b001000; end // 10M
      else if (sw[2]) begin bit_rate = 4'b0010; led[5:0] = 6'b000100; end // 2M
      else if (sw[1]) begin bit_rate = 4'b0001; led[5:0] = 6'b000010; end // 1M
      else            begin bit_rate = 4'b0000; led[5:0] = 6'b000001; end // 100k
    end

    always_ff @(posedge clk400 or negedge rst_n) begin
      if (!rst_n) begin
          tx_timer <= '0;
          tx_data <= '0;
          tx_msg_type <= 3'b100; // MSG_TEXT
          tx_enable <= 1'b0;
      end else begin
          tx_enable <= 1'b0; 
          if (tx_timer == 400_000_000 - 1) begin
              tx_timer <= '0;
              if (!tx_full) begin
                  tx_enable <= 1'b1;
                  tx_data <= tx_data + 1'b1; 
              end
          end else begin
              tx_timer <= tx_timer + 1'b1;
          end
      end
  end


  // 2. Odbiornik i Rozciągacze impulsów LED (50 ms błysku dla każdego błędu)
  always_ff @(posedge clk400 or negedge rst_n) begin
    if (!rst_n) begin
        rx_enable <= 1'b0;
        rx_enable_dly <= 1'b0;
        led[12:6] <= '0;
        err_stretch_man <= '0;
        err_stretch_pre <= '0;
        err_stretch_par <= '0;
    end else begin
        // Obsługa RX FIFO
        if (!rx_empty && !rx_enable) rx_enable <= 1'b1;
        else                         rx_enable <= 1'b0;

        rx_enable_dly <= rx_enable;

        // Zapis odebranych danych (tylko dolne 7 bitów, by starczyło diod)
        if (rx_enable_dly) begin
            led[12:6] <= data_out[6:0]; 
        end

        // Niezależne wydłużanie impulsów dla poszczególnych błędów
        // Zegar 400MHz -> 20_000_000 cykli = 50 milisekund
        if (manchester_code_error) err_stretch_man <= 20_000_000;
        else if (err_stretch_man > 0) err_stretch_man <= err_stretch_man - 1'b1;

        if (preamble_error) err_stretch_pre <= 20_000_000;
        else if (err_stretch_pre > 0) err_stretch_pre <= err_stretch_pre - 1'b1;

        if (parity_error) err_stretch_par <= 20_000_000;
        else if (err_stretch_par > 0) err_stretch_par <= err_stretch_par - 1'b1;
    end
end

// Przypisanie 3 najwyższych diod do rozciągaczy impulsów
assign led[15] = (err_stretch_man != 0);
assign led[14] = (err_stretch_pre != 0);
assign led[13] = (err_stretch_par != 0);


optibolt_controller u_optibolt_controller (
  .clk400,
  .rst_n,
  .oversampling,
  .bit_rate,
  .rx_manchester(OptiBolt_rx),
  .tx_manchester(OptiBolt_tx),
  .rx_enable,
  .rx_empty,
  .rx_full,
  .data_out,
  .msg_type_out,
  .parity_error,
  .manchester_code_error,
  .preamble_error,
  .tx_enable,
  .tx_msg_type,
  .tx_data,
  .tx_empty,
  .tx_full
);

endmodule
