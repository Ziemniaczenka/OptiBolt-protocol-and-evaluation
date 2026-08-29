/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Wieclawski & Sebastian Zon
 *
 * Description:
 * Top module for evaluation logic.
 */

import string_pkg::*;
import ui_pkg::*;
import protocol_pkg::*;

module evaluation_controller #(
    parameter int SWEEP_STEP_TICKS = 5_000_000,
    parameter int PWR_RETRY_TICKS  = 10_000_000
) (
    input logic clk,
    input logic rst_n,

    // Keyboard Inputs
    input logic cmd_up,
    input logic cmd_down,
    input logic cmd_left,
    input logic cmd_right,
    input logic cmd_enter,
    input logic cmd_esc,

    // Text Inputs
    input logic       char_valid,
    input logic [7:0] char_ascii,
    input logic       cmd_backspace,

    // --- RAM Interfaces ---
    output logic [$clog2(string_pkg::CONSOLE_MAX_LEN)-1:0] console_addr,
    output logic                                           console_we,
    output logic [                                    7:0] console_din,
    input  logic [                                    7:0] console_dout,

    output logic [$clog2(string_pkg::INPUT_MAX_LEN)-1:0] input_addr,
    output logic                                         input_we,
    output logic [                                  7:0] input_din,

    output logic [13:0] bmp_addr,
    output logic        bmp_we,
    output logic [11:0] bmp_din,

    input  logic [3:0] ui_selected_item,
    output logic       mode_text,
    output logic       show_popup,
    output logic       show_progress,
    output logic [7:0] progress_val,
    output logic [1:0] popup_mode,

    // --- Diagnostics & Error Metrics Outputs ---
    output logic [15:0] err_man_cnt,
    output logic [15:0] err_pre_cnt,
    output logic [15:0] err_par_cnt,
    output logic [ 7:0] prog_man,
    output logic [ 7:0] prog_pre,
    output logic [ 7:0] prog_par,
    output logic [ 7:0] prog_hlt,
    output logic [11:0] color_man,
    output logic [11:0] color_pre,
    output logic [11:0] color_par,
    output logic [11:0] color_hlt,

    // --- Handshake Interface ---
    input  logic       hs_tx_req,
    input  logic [2:0] hs_tx_type,
    input  logic [7:0] hs_tx_data,
    output logic       hs_tx_ack,
    input  logic [1:0] link_status,

    // --- OptiBolt Protocol Control & Telemetry Interface ---
    output logic [3:0] eval_proto_baud_rate,
    output logic [3:0] eval_proto_oversampling,
    output logic       eval_proto_loopback_en,
    output logic       eval_failover_en,
    output logic       speed_updated_pulse,

    // TX Interface
    output logic       eval_proto_tx_valid,
    output logic [2:0] eval_proto_tx_type,
    output logic [7:0] eval_proto_tx_data,
    input  logic       proto_eval_tx_full,
    input  logic       proto_eval_tx_empty,

    // RX Interface
    input logic       proto_eval_rx_valid,
    input logic [2:0] proto_eval_rx_type,
    input logic [7:0] proto_eval_rx_data,
    input logic       proto_eval_parity_error,
    input logic       proto_eval_manchester_code_error,
    input logic       proto_eval_preamble_error,
    input logic       proto_eval_rx_carrier,

    // Telemetry / Status
    input logic        proto_eval_link_status,
    input logic [31:0] proto_eval_ber_count,
    input logic [15:0] proto_eval_err_count,

    // Power Negotiation Outputs to UI
    output logic [2:0] pwr_status_code,
    output logic [1:0] active_voltage_id,
    output logic [3:0] active_amps,
    output logic       contract_active
);

  localparam int CLI_BUF_LEN = 128;
  localparam logic [2:0] MSG_BITMAP = 3'b101;

  // Inter-module signals
  logic        cli_cmd_valid;
  logic [ 7:0] cli_cmd_buf          [0:CLI_BUF_LEN-1];
  logic [10:0] cli_cmd_len;
  logic        btn_trigger;

  logic        echo_req;
  logic [ 7:0] echo_buf             [0:CLI_BUF_LEN-1];
  logic [10:0] echo_len;
  logic        echo_ack;

  logic        print_valid;
  logic [ 7:0] print_char;
  logic        print_last;
  logic        print_ready;

  logic        clear_console_req;
  logic        clear_console_ack;

  // Link manager & speed control signals
  logic        set_speed_req;
  logic [ 3:0] req_baud_rate;
  logic [ 3:0] req_oversampling;
  logic        failover_en;
  logic        failover_triggered;

  logic        nego_tx_valid;
  logic [ 2:0] nego_tx_type;
  logic [ 7:0] nego_tx_data;

  // Cmd exec TX packet interface
  logic        cmd_tx_valid;
  logic [ 2:0] cmd_tx_type;
  logic [ 7:0] cmd_tx_data;
  logic        sweep_active;

  // Power Negotiation Signals
  logic [ 1:0] cfg_role;
  logic [ 3:0] cfg_in_amps          [              4];
  logic [ 3:0] cfg_out_amps         [              4];
  logic        cfg_ready;
  logic        cfg_clear;
  logic        contract_error;
  logic        active_is_source;
  logic        contract_event_pulse;

  logic        pwr_tx_valid;
  logic [ 2:0] pwr_tx_type;
  logic [ 7:0] pwr_tx_data;
  logic        pwr_tx_ready;

  // Bitmap RAM control multiplexing (Cmd Exec TX vs Protocol RX)
  logic [13:0] cmd_bmp_addr;
  logic        cmd_bmp_we;
  logic [11:0] cmd_bmp_din;
  logic [13:0] rx_pixel_ptr;
  logic        rx_bmp_has_b0;
  logic [ 7:0] rx_pixel_rg;
  logic [27:0] rx_bmp_idle_cnt;

  always_comb begin
    if (proto_eval_rx_valid && proto_eval_rx_type == MSG_BITMAP &&
        proto_eval_rx_data[7] == 1'b1 && rx_bmp_has_b0) begin
      bmp_addr = rx_pixel_ptr;
      // Reconstruct 12-bit RGB:
      // Byte 0: {1'b0, R[3:0], G[3:1]}
      // Byte 1: {1'b1, G[0], B[3:0], 2'b00}
      bmp_din = {
        rx_pixel_rg[6:3], rx_pixel_rg[2:0], proto_eval_rx_data[6], proto_eval_rx_data[5:2]
      };
      bmp_we = 1'b1;
    end else begin
      bmp_addr = cmd_bmp_addr;
      bmp_din  = cmd_bmp_din;
      bmp_we   = cmd_bmp_we;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_pixel_ptr    <= 14'd0;
      rx_bmp_has_b0   <= 1'b0;
      rx_pixel_rg     <= 8'h00;
      rx_bmp_idle_cnt <= '0;
    end else begin
      if (proto_eval_rx_valid && proto_eval_rx_type == MSG_BITMAP) begin
        rx_bmp_idle_cnt <= '0;
        if (proto_eval_rx_data[7] == 1'b0) begin
          // Guaranteed Byte 0
          rx_pixel_rg   <= proto_eval_rx_data;
          rx_bmp_has_b0 <= 1'b1;
        end else if (proto_eval_rx_data[7] == 1'b1 && rx_bmp_has_b0) begin
          // Guaranteed Byte 1 matching Byte 0
          rx_bmp_has_b0 <= 1'b0;
          if (rx_pixel_ptr == 14'd16383) rx_pixel_ptr <= 14'd0;
          else rx_pixel_ptr <= rx_pixel_ptr + 14'd1;
        end
      end else begin
        // Reset pixel pointer if link idle for > 2.0s (200,000,000 cycles at 100MHz)
        if (rx_bmp_idle_cnt < 28'd200_000_000) begin
          rx_bmp_idle_cnt <= rx_bmp_idle_cnt + 28'd1;
        end else begin
          rx_pixel_ptr  <= 14'd0;
          rx_bmp_has_b0 <= 1'b0;
        end
      end
    end
  end

  // =========================================================================
  // 1. Dedicated Diagnostics & Error Metrics Submodule
  // =========================================================================
  eval_diagnostics u_eval_diagnostics (
      .clk                             (clk),
      .rst_n                           (rst_n),
      .proto_eval_manchester_code_error(proto_eval_manchester_code_error),
      .proto_eval_preamble_error       (proto_eval_preamble_error),
      .proto_eval_parity_error         (proto_eval_parity_error),
      .link_status                     (link_status),
      .err_man_cnt                     (err_man_cnt),
      .err_pre_cnt                     (err_pre_cnt),
      .err_par_cnt                     (err_par_cnt),
      .prog_man                        (prog_man),
      .prog_pre                        (prog_pre),
      .prog_par                        (prog_par),
      .prog_hlt                        (prog_hlt),
      .color_man                       (color_man),
      .color_pre                       (color_pre),
      .color_par                       (color_par),
      .color_hlt                       (color_hlt)
  );

  // =========================================================================
  // 2. Dedicated CLI Text Input & MRU History Submodule
  // =========================================================================
  eval_cli_input #(
      .CLI_BUF_LEN(CLI_BUF_LEN)
  ) u_eval_cli_input (
      .clk             (clk),
      .rst_n           (rst_n),
      .cmd_up          (cmd_up),
      .cmd_down        (cmd_down),
      .cmd_left        (cmd_left),
      .cmd_right       (cmd_right),
      .cmd_enter       (cmd_enter),
      .cmd_esc         (cmd_esc),
      .char_valid      (char_valid),
      .char_ascii      (char_ascii),
      .cmd_backspace   (cmd_backspace),
      .ui_selected_item(ui_selected_item),
      .mode_text       (mode_text),
      .btn_trigger     (btn_trigger),
      .input_addr      (input_addr),
      .input_we        (input_we),
      .input_din       (input_din),
      .cmd_valid       (cli_cmd_valid),
      .cmd_buf         (cli_cmd_buf),
      .cmd_len         (cli_cmd_len),
      .echo_req        (echo_req),
      .echo_buf        (echo_buf),
      .echo_len        (echo_len),
      .echo_ack        (echo_ack)
  );

  /* 3. Dedicated Console BRAM Buffer & Line-by-Line Scroller Submodule */
  logic       rx_console_char_ready;
  logic       rx_bol;
  logic       rx_data_char_valid;
  logic [7:0] rx_data_char_byte;

  /* Incoming RX Text FIFO Buffer (prevents dropped characters during prefix '< ' injection and scrolling) */
  logic       rx_text_fifo_empty;
  logic       rx_text_fifo_full;
  logic [7:0] rx_text_fifo_dout;
  logic       rx_text_fifo_pop;

  fwft_fifo #(
      .WORD_WIDTH(8),
      .DEPTH     (64)
  ) u_rx_text_fifo (
      .clk  (clk),
      .rst_n(rst_n),
      .flush(1'b0),
      .push (proto_eval_rx_valid && proto_eval_rx_type == MSG_TEXT),
      .pop  (rx_text_fifo_pop),
      .din  (proto_eval_rx_data),
      .dout (rx_text_fifo_dout),
      .empty(rx_text_fifo_empty),
      .full (rx_text_fifo_full),
      .count()
  );

  typedef enum logic [2:0] {
    RX_TEXT_IDLE,
    RX_TEXT_PREFIX_LT,
    RX_TEXT_PREFIX_SP,
    RX_TEXT_WRITE,
    RX_TEXT_POP_WAIT
  } rx_text_state_t;

  rx_text_state_t rx_text_state;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_bol             <= 1'b1;
      rx_text_state      <= RX_TEXT_IDLE;
      rx_data_char_valid <= 1'b0;
      rx_data_char_byte  <= 8'h00;
      rx_text_fifo_pop   <= 1'b0;
    end else begin
      rx_text_fifo_pop <= 1'b0;

      case (rx_text_state)
        RX_TEXT_IDLE: begin
          if (!rx_text_fifo_empty) begin
            if (rx_bol && rx_text_fifo_dout != 8'h0A) begin
              /* Start of line: output '<' */
              rx_data_char_byte  <= 8'h3C;  // '<'
              rx_data_char_valid <= 1'b1;
              rx_text_state      <= RX_TEXT_PREFIX_LT;
            end else begin
              /* Normal character or bare newline: present character */
              rx_data_char_byte  <= rx_text_fifo_dout;
              rx_data_char_valid <= 1'b1;
              rx_text_state      <= RX_TEXT_WRITE;
            end
          end else begin
            rx_data_char_valid <= 1'b0;
          end
        end

        RX_TEXT_PREFIX_LT: begin
          if (rx_console_char_ready) begin
            /* '<' accepted: output ' ' */
            rx_data_char_byte  <= 8'h20;  // ' '
            rx_data_char_valid <= 1'b1;
            rx_text_state      <= RX_TEXT_PREFIX_SP;
          end else begin
            rx_data_char_valid <= 1'b1;
          end
        end

        RX_TEXT_PREFIX_SP: begin
          if (rx_console_char_ready) begin
            /* ' ' accepted: output first payload character */
            rx_data_char_byte  <= rx_text_fifo_dout;
            rx_data_char_valid <= 1'b1;
            rx_bol             <= 1'b0;
            rx_text_state      <= RX_TEXT_WRITE;
          end else begin
            rx_data_char_valid <= 1'b1;
          end
        end

        RX_TEXT_WRITE: begin
          if (rx_console_char_ready) begin
            /* Character accepted by console buffer: pop from FIFO */
            rx_text_fifo_pop   <= 1'b1;
            rx_data_char_valid <= 1'b0;
            if (rx_data_char_byte == 8'h0A) rx_bol <= 1'b1;
            else rx_bol <= 1'b0;
            rx_text_state <= RX_TEXT_POP_WAIT;
          end else begin
            rx_data_char_valid <= 1'b1;
          end
        end

        RX_TEXT_POP_WAIT: begin
          /* 1-cycle pause for FWFT FIFO to update pointers and empty flag */
          rx_data_char_valid <= 1'b0;
          rx_text_state      <= RX_TEXT_IDLE;
        end

        default: rx_text_state <= RX_TEXT_IDLE;
      endcase
    end
  end

  eval_console_buffer #(
      .MAX_LINES(40),
      .LINE_WRAP_COLS(95)
  ) u_eval_console_buffer (
      .clk          (clk),
      .rst_n        (rst_n),
      .console_addr (console_addr),
      .console_we   (console_we),
      .console_din  (console_din),
      .console_dout (console_dout),
      .print_valid  (print_valid),
      .print_char   (print_char),
      .print_last   (print_last),
      .print_ready  (print_ready),
      .rx_char_valid(rx_data_char_valid),
      .rx_char_data (rx_data_char_byte),
      .rx_char_ready(rx_console_char_ready),
      .clear_req    (clear_console_req),
      .clear_ack    (clear_console_ack),
      .line_count   (),
      .console_busy ()
  );

  // =========================================================================
  // 4. OptiBolt Protocol Link Manager & Speed Failover Submodule (Layer 2)
  // =========================================================================
  assign eval_failover_en = failover_en;

  optibolt_link_manager #(
      .DEFAULT_BAUD_RATE   (4'd1),  // 1.0 Mbps
      .DEFAULT_OVERSAMPLING(4'd0)   // 16x OS
  ) u_optibolt_link_manager (
      .clk                             (clk),
      .rst_n                           (rst_n),
      .link_status                     (link_status),
      .rx_carrier                      (proto_eval_rx_carrier),
      .proto_eval_parity_error         (proto_eval_parity_error),
      .proto_eval_manchester_code_error(proto_eval_manchester_code_error),
      .proto_eval_preamble_error       (proto_eval_preamble_error),
      .failover_en                     (failover_en),
      .sweep_active                    (sweep_active),
      .set_speed_req                   (set_speed_req),
      .req_baud_rate                   (req_baud_rate),
      .req_oversampling                (req_oversampling),
      .set_loopback_req                (1'b0),
      .req_loopback_en                 (1'b0),
      .proto_rx_valid                  (proto_eval_rx_valid),
      .proto_rx_type                   (proto_eval_rx_type),
      .proto_rx_data                   (proto_eval_rx_data),
      .nego_tx_valid                   (nego_tx_valid),
      .nego_tx_type                    (nego_tx_type),
      .nego_tx_data                    (nego_tx_data),
      .active_baud_rate                (eval_proto_baud_rate),
      .active_oversampling             (eval_proto_oversampling),
      .active_loopback_en              (eval_proto_loopback_en),
      .failover_triggered              (failover_triggered),
      .speed_nego_in_progress          (),
      .speed_updated_pulse             (speed_updated_pulse),
      .proto_eval_tx_empty             (proto_eval_tx_empty)
  );

  // =========================================================================
  // 5. Dedicated Command Parser & Execution Engine Submodule
  // =========================================================================
  eval_cmd_exec #(
      .CLI_BUF_LEN     (CLI_BUF_LEN),
      .SWEEP_STEP_TICKS(SWEEP_STEP_TICKS)
  ) u_eval_cmd_exec (
      .clk                             (clk),
      .rst_n                           (rst_n),
      .cmd_valid                       (cli_cmd_valid),
      .cmd_buf                         (cli_cmd_buf),
      .cmd_len                         (cli_cmd_len),
      .btn_trigger                     (btn_trigger),
      .ui_selected_item                (ui_selected_item),
      .echo_req                        (echo_req),
      .echo_buf                        (echo_buf),
      .echo_len                        (echo_len),
      .echo_ack                        (echo_ack),
      .print_valid                     (print_valid),
      .print_char                      (print_char),
      .print_last                      (print_last),
      .print_ready                     (print_ready),
      .clear_console_req               (clear_console_req),
      .clear_console_ack               (clear_console_ack),
      .bmp_addr                        (cmd_bmp_addr),
      .bmp_we                          (cmd_bmp_we),
      .bmp_din                         (cmd_bmp_din),
      .show_popup                      (show_popup),
      .show_progress                   (show_progress),
      .progress_val                    (progress_val),
      .popup_mode                      (popup_mode),
      .set_speed_req                   (set_speed_req),
      .req_baud_rate                   (req_baud_rate),
      .req_oversampling                (req_oversampling),
      .failover_en                     (failover_en),
      .sweep_active                    (sweep_active),
      .failover_triggered              (failover_triggered),
      .link_status                     (link_status),
      .rx_carrier                      (proto_eval_rx_carrier),
      .proto_tx_valid                  (cmd_tx_valid),
      .proto_tx_type                   (cmd_tx_type),
      .proto_tx_data                   (cmd_tx_data),
      .proto_tx_full                   (proto_eval_tx_full),
      .proto_rx_valid                  (proto_eval_rx_valid),
      .proto_rx_type                   (proto_eval_rx_type),
      .proto_rx_data                   (proto_eval_rx_data),
      .proto_eval_parity_error         (proto_eval_parity_error),
      .proto_eval_manchester_code_error(proto_eval_manchester_code_error),
      .proto_eval_preamble_error       (proto_eval_preamble_error),
      .cfg_role                        (cfg_role),
      .cfg_in_amps                     (cfg_in_amps),
      .cfg_out_amps                    (cfg_out_amps),
      .cfg_ready                       (cfg_ready),
      .cfg_clear                       (cfg_clear),
      .pwr_status_code                 (pwr_status_code),
      .contract_active                 (contract_active),
      .active_voltage_id               (active_voltage_id),
      .active_amps                     (active_amps),
      .active_is_source                (active_is_source),
      .contract_event_pulse            (contract_event_pulse)
  );

  power_negotiator #(
      .RETRY_TICKS(PWR_RETRY_TICKS)
  ) u_pwr_nego (
      .clk                 (clk),
      .rst_n               (rst_n),
      .link_status         (link_status),
      .cfg_role            (cfg_role),
      .cfg_in_amps         (cfg_in_amps),
      .cfg_out_amps        (cfg_out_amps),
      .cfg_ready           (cfg_ready),
      .cfg_clear           (cfg_clear),
      .pwr_status_code     (pwr_status_code),
      .contract_active     (contract_active),
      .contract_error      (contract_error),
      .active_voltage_id   (active_voltage_id),
      .active_amps         (active_amps),
      .active_is_source    (active_is_source),
      .contract_event_pulse(contract_event_pulse),
      .pwr_tx_valid        (pwr_tx_valid),
      .pwr_tx_type         (pwr_tx_type),
      .pwr_tx_data         (pwr_tx_data),
      .pwr_tx_ready        (pwr_tx_ready),
      .proto_rx_valid      (proto_eval_rx_valid),
      .proto_rx_type       (proto_eval_rx_type),
      .proto_rx_data       (proto_eval_rx_data)
  );

  // =========================================================================
  // Protocol TX Multiplexer (Cmd Exec > Speed Nego > Handshake)
  // =========================================================================
  always_comb begin
    if (cmd_tx_valid) begin
      eval_proto_tx_valid = 1'b1;
      eval_proto_tx_type  = cmd_tx_type;
      eval_proto_tx_data  = cmd_tx_data;
      hs_tx_ack           = 1'b0;
      pwr_tx_ready        = 1'b0;
    end else if (nego_tx_valid) begin
      eval_proto_tx_valid = 1'b1;
      eval_proto_tx_type  = nego_tx_type;
      eval_proto_tx_data  = nego_tx_data;
      hs_tx_ack           = 1'b0;
      pwr_tx_ready        = 1'b0;
    end else if (pwr_tx_valid) begin
      eval_proto_tx_valid = 1'b1;
      eval_proto_tx_type  = pwr_tx_type;
      eval_proto_tx_data  = pwr_tx_data;
      hs_tx_ack           = 1'b0;
      pwr_tx_ready        = !proto_eval_tx_full;
    end else if (hs_tx_req) begin
      eval_proto_tx_valid = 1'b1;
      eval_proto_tx_type  = hs_tx_type;
      eval_proto_tx_data  = hs_tx_data;
      hs_tx_ack           = !proto_eval_tx_full;
      pwr_tx_ready        = 1'b0;
    end else begin
      eval_proto_tx_valid = 1'b0;
      eval_proto_tx_type  = 3'b000;
      eval_proto_tx_data  = 8'h00;
      hs_tx_ack           = 1'b0;
      pwr_tx_ready        = 1'b0;
    end
  end

endmodule
