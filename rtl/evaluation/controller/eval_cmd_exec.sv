/**
 * Copyright (C) 2026  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Wieclawski & Sebastian Zon
 *
 * Description:
 * Command Parser & Execution Engine module.
 * Parses CLI slash commands, controls UI popups & progress, manages 128x128 PRNG dynamic bitmap streaming,
 * executes Ping message formatting, runs Baudrate sweep test, and streams formatted text to the console buffer.
 */

import string_pkg::*;
import ui_pkg::*;
import protocol_pkg::*;
import eval_cmd_pkg::*;

module eval_cmd_exec #(
    parameter int CLI_BUF_LEN      = 64,
    parameter int SWEEP_STEP_TICKS = 5_000_000
) (
    input  logic        clk,
    input  logic        rst_n,

    // Command packet input from eval_cli_input
    input  logic        cmd_valid,
    input  logic [7:0]  cmd_buf [0:CLI_BUF_LEN-1],
    input  logic [10:0] cmd_len,

    // UI button triggers from toolbar / popup
    input  logic        btn_trigger,
    input  logic [3:0]  ui_selected_item,

    // CLI text echo stream from eval_cli_input
    input  logic        echo_req,
    output logic        echo_ack,

    // Console print stream output to eval_console_buffer
    output logic        print_valid,
    output logic [7:0]  print_char,
    output logic        print_last,
    input  logic        print_ready,

    // Clear console control to eval_console_buffer
    output logic        clear_console_req,
    input  logic        clear_console_ack,

    // Dynamic Bitmap RAM interface
    output logic [13:0] bmp_addr,
    output logic        bmp_we,
    output logic [11:0] bmp_din,

    // UI Popups & Progress
    output logic        show_popup,
    output logic        show_progress,
    output logic [ 7:0] progress_val,
    output logic [ 1:0] popup_mode,

    // Link manager control & telemetry
    output logic        set_speed_req,
    output logic [ 3:0] req_baud_rate,
    output logic [ 3:0] req_oversampling,
    input  logic [ 3:0] active_baud_rate,
    input  logic [ 3:0] active_oversampling,
    output logic        failover_en,
    input  logic        failover_triggered,
    output logic        sweep_active,
    input  logic [ 1:0] link_status,
    input  logic        rx_carrier,

    // OptiBolt packet TX interface
    output logic        proto_tx_valid,
    output logic [ 2:0] proto_tx_type,
    output logic [ 7:0] proto_tx_data,
    input  logic        proto_tx_full,
    input  logic        proto_tx_empty,

    // Power Negotiation Configuration
    output logic [ 1:0] cfg_role,
    output logic [ 3:0] cfg_in_amps[4],
    output logic [ 3:0] cfg_out_amps[4],
    output logic        cfg_ready,
    output logic        cfg_clear,
    input  logic [ 2:0] pwr_status_code,
    input  logic        contract_active,
    input  logic [ 1:0] active_voltage_id,
    input  logic [ 3:0] active_amps,
    input  logic        active_is_source,
    input  logic        contract_event_pulse,

    // OptiBolt packet RX interface
    input  logic        proto_rx_valid,
    input  logic [ 2:0] proto_rx_type,
    input  logic [ 7:0] proto_rx_data,
    input  logic        proto_eval_parity_error,
    input  logic        proto_eval_manchester_code_error,
    input  logic        proto_eval_preamble_error,

    // Bitmap RX Done Telemetry from evaluation_controller
    input  logic        bmp_rx_done_pulse,
    input  logic [31:0] bmp_rx_cycles
);

  exec_state_t state;
  msg_src_t    msg_src;

  logic [10:0] msg_idx;
  logic [10:0] msg_len;
  logic [ 7:0] current_msg_char;
  logic        pending_cmd;

  // Normal Chat TX
  logic [10:0] tx_chat_idx;

  // Dynamic Bitmap Streaming
  logic [14:0] tx_pixel_cnt;
  logic        tx_pixel_phase;
  logic [ 5:0] tx_gap_cnt;
  logic [13:0] clear_bmp_idx;
  logic [11:0] prng_pixel_rgb;
  logic [ 7:0] prng_pixel_byte;
  logic [11:0] latched_pixel_rgb;
  logic [31:0] bmp_tx_timer;
  logic        bmp_pending_rx;
  logic [31:0] bmp_pending_rx_cycles;

  pixel_prng u_pixel_prng (
      .clk        (clk),
      .rst_n      (rst_n),
      .next_pixel (1'b1),
      .pixel_rgb  (prng_pixel_rgb),
      .pixel_byte (prng_pixel_byte)
  );

  // Ping test registers
  logic        ping_active;
  logic [31:0] ping_timer;
  logic [31:0] ping_rtt_cycles;
  logic        ping_is_loopback;
  logic [ 7:0] ping_msg_buf [0:63];

  // Bitmap report buffer
  logic [ 7:0] bmp_msg_buf  [0:63];

  // BCD conversion registers (Double-Dabble)
  logic [31:0] bcd_reg;
  logic [31:0] bin_reg;
  logic [ 5:0] bcd_cnt;
  logic [ 3:0] bcd_d [0:7];
  logic        fmt_is_bitmap;
  logic        fmt_report_is_rx;

  // Sequential Formatter registers
  logic [ 5:0] fmt_ptr;
  logic [ 2:0] fmt_phase;
  logic [ 3:0] fmt_digit_idx;
  logic [ 4:0] fmt_text_idx;
  logic        fmt_lead_zero;

  // Sweep registers
  logic [ 4:0] sweep_step;
  logic [ 4:0] sweep_print_step;
  logic [31:0] sweep_timer;
  logic [31:0] sweep_pkt_gap;
  logic [ 4:0] sweep_tx_count;
  logic [ 4:0] sweep_rx_count;
  logic        sweep_had_error;

  // Combinational Power Status Message Character Generator (Zero Register Overhead)
  function automatic logic [7:0] get_pwr_char(
      input logic [10:0] idx,
      input logic [ 3:0] in_a[4],
      input logic [ 3:0] out_a[4],
      input logic        is_active,
      input logic        is_src,
      input logic [ 1:0] v_id,
      input logic [ 3:0] a_val
  );
    if (idx < 11'd31) begin
      // "In : 5V=XA 9V=XA 12V=XA 20V=XA\n"
      case (idx)
        11'd0: return "I"; 11'd1: return "n"; 11'd2: return " "; 11'd3: return ":"; 11'd4: return " ";
        11'd5: return "5"; 11'd6: return "V"; 11'd7: return "="; 11'd8: return 8'h30 + {4'h0, in_a[0]}; 11'd9: return "A"; 11'd10: return " ";
        11'd11: return "9"; 11'd12: return "V"; 11'd13: return "="; 11'd14: return 8'h30 + {4'h0, in_a[1]}; 11'd15: return "A"; 11'd16: return " ";
        11'd17: return "1"; 11'd18: return "2"; 11'd19: return "V"; 11'd20: return "="; 11'd21: return 8'h30 + {4'h0, in_a[2]}; 11'd22: return "A"; 11'd23: return " ";
        11'd24: return "2"; 11'd25: return "0"; 11'd26: return "V"; 11'd27: return "="; 11'd28: return 8'h30 + {4'h0, in_a[3]}; 11'd29: return "A";
        default: return 8'h0A;
      endcase
    end else if (idx < 11'd62) begin
      // "Out: 5V=XA 9V=XA 12V=XA 20V=XA\n"
      case (idx - 11'd31)
        11'd0: return "O"; 11'd1: return "u"; 11'd2: return "t"; 11'd3: return ":"; 11'd4: return " ";
        11'd5: return "5"; 11'd6: return "V"; 11'd7: return "="; 11'd8: return 8'h30 + {4'h0, out_a[0]}; 11'd9: return "A"; 11'd10: return " ";
        11'd11: return "9"; 11'd12: return "V"; 11'd13: return "="; 11'd14: return 8'h30 + {4'h0, out_a[1]}; 11'd15: return "A"; 11'd16: return " ";
        11'd17: return "1"; 11'd18: return "2"; 11'd19: return "V"; 11'd20: return "="; 11'd21: return 8'h30 + {4'h0, out_a[2]}; 11'd22: return "A"; 11'd23: return " ";
        11'd24: return "2"; 11'd25: return "0"; 11'd26: return "V"; 11'd27: return "="; 11'd28: return 8'h30 + {4'h0, out_a[3]}; 11'd29: return "A";
        default: return 8'h0A;
      endcase
    end else begin
      // Line 3: Active Contract
      if (!is_active) begin
        // "Active: NONE\n"
        case (idx - 11'd62)
          11'd0: return "A"; 11'd1: return "c"; 11'd2: return "t"; 11'd3: return "i"; 11'd4: return "v"; 11'd5: return "e"; 11'd6: return ":"; 11'd7: return " ";
          11'd8: return "N"; 11'd9: return "O"; 11'd10: return "N"; 11'd11: return "E";
          default: return 8'h0A;
        endcase
      end else if (is_src) begin
        // "Active: SOURCE <V>V @ <A>A\n"
        case (idx - 11'd62)
          11'd0: return "A"; 11'd1: return "c"; 11'd2: return "t"; 11'd3: return "i"; 11'd4: return "v"; 11'd5: return "e"; 11'd6: return ":"; 11'd7: return " ";
          11'd8: return "S"; 11'd9: return "O"; 11'd10: return "U"; 11'd11: return "R"; 11'd12: return "C"; 11'd13: return "E"; 11'd14: return " ";
          11'd15: return (v_id == 2'd3) ? "2" : (v_id == 2'd2) ? "1" : " ";
          11'd16: return (v_id == 2'd3) ? "0" : (v_id == 2'd2) ? "2" : (v_id == 2'd1) ? "9" : "5";
          11'd17: return "V"; 11'd18: return " "; 11'd19: return "@"; 11'd20: return " ";
          11'd21: return 8'h30 + {4'h0, a_val}; 11'd22: return "A";
          default: return 8'h0A;
        endcase
      end else begin
        // "Active: RECEIVER <V>V @ <A>A\n"
        case (idx - 11'd62)
          11'd0: return "A"; 11'd1: return "c"; 11'd2: return "t"; 11'd3: return "i"; 11'd4: return "v"; 11'd5: return "e"; 11'd6: return ":"; 11'd7: return " ";
          11'd8: return "R"; 11'd9: return "E"; 11'd10: return "C"; 11'd11: return "E"; 11'd12: return "I"; 11'd13: return "V"; 11'd14: return "E"; 11'd15: return "R"; 11'd16: return " ";
          11'd17: return (v_id == 2'd3) ? "2" : (v_id == 2'd2) ? "1" : " ";
          11'd18: return (v_id == 2'd3) ? "0" : (v_id == 2'd2) ? "2" : (v_id == 2'd1) ? "9" : "5";
          11'd19: return "V"; 11'd20: return " "; 11'd21: return "@"; 11'd22: return " ";
          11'd23: return 8'h30 + {4'h0, a_val}; 11'd24: return "A";
          default: return 8'h0A;
        endcase
      end
    end
  endfunction

  // Message multiplexer
  always_comb begin
    case (msg_src)
      SRC_ECHO:               current_msg_char = (msg_idx == msg_len - 11'd1) ? 8'h0A : cmd_buf[msg_idx];
      SRC_HELP:               current_msg_char = HELP_BYTES[msg_idx];
      SRC_BAUD_SET:           current_msg_char = BAUD_SET_BYTES[msg_idx];
      SRC_FAILOVER_ON:        current_msg_char = FAILOVER_ON_BYTES[msg_idx];
      SRC_FAILOVER_OFF:       current_msg_char = FAILOVER_OFF_BYTES[msg_idx];
      SRC_FAILOVER_ALERT:     current_msg_char = FAILOVER_ALERT_BYTES[msg_idx];
      SRC_UNKNOWN:            current_msg_char = UNKNOWN_CMD_BYTES[msg_idx];
      SRC_ERR_DISCONN:        current_msg_char = ERR_DISCONN_BYTES[msg_idx];
      SRC_ERR_OS_UNSUPPORTED: current_msg_char = ERR_OS_UNSUPPORTED_BYTES[msg_idx];
      SRC_PING_START:         current_msg_char = PING_START_BYTES[msg_idx];
      SRC_PING_MSG:           current_msg_char = ping_msg_buf[msg_idx];
      SRC_BMP_TX_MSG:         current_msg_char = bmp_msg_buf[msg_idx];
      SRC_BMP_RX_MSG:         current_msg_char = bmp_msg_buf[msg_idx];
      SRC_SWEEP_START:        current_msg_char = SWEEP_START_BYTES[msg_idx];
      SRC_SWEEP_PASS:         current_msg_char = SWEEP_PASS_STR[sweep_print_step][msg_idx];
      SRC_SWEEP_FAIL:         current_msg_char = SWEEP_FAIL_STR[sweep_print_step][msg_idx];
      SRC_SWEEP_DONE:         current_msg_char = SWEEP_DONE_BYTES[msg_idx];
      SRC_PWR_ROLE_SET:       current_msg_char = PWR_ROLE_SET_BYTES[msg_idx];
      SRC_PWR_IN_SET:         current_msg_char = PWR_IN_SET_BYTES[msg_idx];
      SRC_PWR_OUT_SET:        current_msg_char = PWR_OUT_SET_BYTES[msg_idx];
      SRC_PWR_CLEARED:        current_msg_char = PWR_CLEARED_BYTES[msg_idx];
      SRC_PWR_READY:          current_msg_char = PWR_READY_BYTES[msg_idx];
      SRC_PWR_OFF:            current_msg_char = PWR_OFF_BYTES[msg_idx];
      SRC_PWR_STATUS:         current_msg_char = get_pwr_char(msg_idx, cfg_in_amps, cfg_out_amps, contract_active, active_is_source, active_voltage_id, active_amps);
      default:                current_msg_char = 8'h00;
    endcase
  end

  // Command Execution State Machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state                 <= E_IDLE;
      msg_src               <= SRC_NONE;
      msg_idx               <= '0;
      msg_len               <= '0;
      pending_cmd           <= 1'b0;
      print_valid           <= 1'b0;
      print_char            <= 8'h00;
      print_last            <= 1'b0;
      echo_ack              <= 1'b0;
      clear_console_req     <= 1'b0;
      show_popup            <= 1'b0;
      show_progress         <= 1'b0;
      progress_val          <= '0;
      popup_mode            <= POPUP_NONE;
      set_speed_req         <= 1'b0;
      req_baud_rate         <= 4'd1;
      req_oversampling      <= 4'd0;
      failover_en           <= 1'b1; // Failover enabled by default
      proto_tx_valid        <= 1'b0;
      proto_tx_type         <= 3'b000;
      proto_tx_data         <= 8'h00;
      bmp_addr              <= '0;
      bmp_we                <= 1'b0;
      bmp_din               <= '0;
      tx_pixel_cnt          <= '0;
      tx_pixel_phase        <= 1'b0;
      tx_gap_cnt            <= '0;
      clear_bmp_idx         <= '0;
      latched_pixel_rgb     <= '0;
      bmp_tx_timer          <= '0;
      bmp_pending_rx        <= 1'b0;
      bmp_pending_rx_cycles <= '0;
      ping_active           <= 1'b0;
      ping_timer            <= '0;
      ping_rtt_cycles       <= '0;
      ping_is_loopback      <= 1'b0;
      bcd_reg               <= '0;
      bin_reg               <= '0;
      bcd_cnt               <= '0;
      fmt_is_bitmap         <= 1'b0;
      fmt_report_is_rx      <= 1'b0;
      fmt_ptr               <= '0;
      fmt_phase             <= '0;
      fmt_digit_idx         <= '0;
      fmt_text_idx          <= '0;
      fmt_lead_zero         <= 1'b1;
      sweep_step            <= '0;
      sweep_print_step      <= '0;
      sweep_timer           <= '0;
      sweep_pkt_gap         <= '0;
      sweep_active          <= 1'b0;
      sweep_tx_count        <= '0;
      sweep_rx_count        <= '0;
      sweep_had_error       <= 1'b0;
      cfg_role              <= 2'd0;
      cfg_ready             <= 1'b0;
      cfg_clear             <= 1'b0;
      for (int i = 0; i < 4; i++) begin
        cfg_in_amps[i]  <= 4'd0;
        cfg_out_amps[i] <= 4'd0;
      end
      for (int i = 0; i < 8; i++) bcd_d[i] <= 4'd0;
      for (int i = 0; i < 64; i++) begin
        ping_msg_buf[i] <= 8'h00;
        bmp_msg_buf[i]  <= 8'h00;
      end
    end else begin
      set_speed_req     <= 1'b0;
      clear_console_req <= 1'b0;
      echo_ack          <= 1'b0;
      bmp_we            <= 1'b0;
      proto_tx_valid    <= 1'b0;
      cfg_clear         <= 1'b0;

      // Global incoming Ping Request responder (for dual-device and loopback):
      if (proto_rx_valid && proto_rx_type == MSG_REQUEST && proto_rx_data == CMD_PING_REQ) begin
        proto_tx_valid <= 1'b1;
        proto_tx_type  <= MSG_REQUEST;
        proto_tx_data  <= CMD_PING_RESP;
      end

      // Remote Sweep notification listeners
      if (proto_rx_valid && proto_rx_type == MSG_REQUEST && proto_rx_data == CMD_SWEEP_START) begin
        sweep_active <= 1'b1;
      end else if (proto_rx_valid && proto_rx_type == MSG_REQUEST && proto_rx_data == CMD_SWEEP_END) begin
        sweep_active <= 1'b0;
      end

      // Remote Sweep Test Packet Echo (dual-device mode):
      if (link_status == 2'b01 && proto_rx_valid && proto_rx_type == MSG_SWEEP && state == E_IDLE) begin
        proto_tx_valid <= 1'b1;
        proto_tx_type  <= MSG_SWEEP;
        proto_tx_data  <= proto_rx_data;
      end

      // Latch incoming bitmap reception completion pulse from evaluation_controller
      if (bmp_rx_done_pulse) begin
        bmp_pending_rx        <= 1'b1;
        bmp_pending_rx_cycles <= bmp_rx_cycles;
      end

      // Ping timer & timeout monitor
      if (ping_active) begin
        ping_timer <= ping_timer + 32'd1;
        if (proto_rx_valid && proto_rx_type == MSG_REQUEST && proto_rx_data == CMD_PING_RESP) begin
          ping_active      <= 1'b0;
          ping_rtt_cycles  <= ping_timer;
          ping_is_loopback <= (link_status == 2'b10);
          bin_reg          <= ping_timer;
          bcd_reg          <= '0;
          bcd_cnt          <= 6'd32;
          fmt_is_bitmap    <= 1'b0;
          state            <= E_CONVERT_BCD;
        end else if (ping_timer >= 32'd10_000_000) begin // 100ms timeout
          ping_active      <= 1'b0;
          ping_rtt_cycles  <= 32'd0;
          ping_is_loopback <= 1'b0;
          bin_reg          <= 32'd0;
          bcd_reg          <= '0;
          bcd_cnt          <= 6'd32;
          fmt_is_bitmap    <= 1'b0;
          state            <= E_CONVERT_BCD;
        end
      end

      // Automatic failover alert notification (only when failover enabled and not during sweep)
      if (failover_triggered && state == E_IDLE && failover_en && !sweep_active && !print_valid) begin
        msg_src <= SRC_FAILOVER_ALERT;
        msg_idx <= '0;
        msg_len <= 11'd47;
        state   <= E_STREAM_MSG;
      end

      case (state)
        // -------------------------------------------------------------------
        // Idle: check CLI echo requests, parsed commands, and telemetry pulses
        // -------------------------------------------------------------------
        E_IDLE: begin
          if (echo_req) begin
            msg_src     <= SRC_ECHO;
            msg_idx     <= (cmd_buf[2] == "/") ? 11'd2 : 11'd0;
            msg_len     <= cmd_len + 11'd1; // Include trailing '\n'
            echo_ack    <= 1'b1;
            pending_cmd <= cmd_valid;
            state       <= E_STREAM_MSG;
          end else if (cmd_valid || pending_cmd) begin
            pending_cmd <= 1'b0;
            state       <= E_PARSE_CMD;
          end else if (bmp_pending_rx) begin
            bmp_pending_rx   <= 1'b0;
            bin_reg          <= bmp_pending_rx_cycles;
            bcd_reg          <= '0;
            bcd_cnt          <= 6'd32;
            fmt_is_bitmap    <= 1'b1;
            fmt_report_is_rx <= 1'b1;
            state            <= E_CONVERT_BCD;
          end else if (btn_trigger) begin
            case (ui_selected_item)
              ITEM_HELP_BTN: begin
                msg_src <= SRC_HELP; msg_len <= 11'(HELP_LEN); msg_idx <= '0; state <= E_STREAM_MSG;
              end
              ITEM_PING_BTN: begin
                if (link_status == 2'b00) begin
                  msg_src <= SRC_ERR_DISCONN; msg_len <= 11'd25; msg_idx <= '0; state <= E_STREAM_MSG;
                end else begin
                  ping_active <= 1'b1; ping_timer <= '0;
                  proto_tx_valid <= 1'b1; proto_tx_type <= MSG_REQUEST; proto_tx_data <= CMD_PING_REQ;
                  msg_src <= SRC_PING_START; msg_len <= 11'd16; msg_idx <= '0; state <= E_STREAM_MSG;
                end
              end
              ITEM_SWEEP_BTN: begin
                sweep_step        <= 5'd0;
                sweep_print_step  <= 5'd0;
                sweep_timer       <= '0;
                sweep_pkt_gap     <= '0;
                sweep_active      <= 1'b1;
                sweep_tx_count    <= 4'd0;
                sweep_rx_count    <= 4'd0;
                sweep_had_error   <= 1'b0;
                popup_mode        <= POPUP_PROGRESS;
                progress_val      <= 8'd0;
                if (link_status == 2'b01) begin
                  proto_tx_valid <= 1'b1;
                  proto_tx_type  <= MSG_REQUEST;
                  proto_tx_data  <= CMD_SWEEP_START;
                end
                msg_src <= SRC_SWEEP_START; msg_len <= 11'd27; msg_idx <= '0; state <= E_STREAM_MSG;
              end
              ITEM_SNDBMP_BTN: begin
                if (link_status == 2'b00) begin
                  msg_src <= SRC_ERR_DISCONN; msg_len <= 11'd25; msg_idx <= '0; state <= E_STREAM_MSG;
                end else begin
                  show_popup     <= 1'b1;
                  show_progress  <= 1'b1;
                  popup_mode     <= POPUP_PROGRESS;
                  progress_val   <= 8'd0;
                  tx_pixel_cnt   <= '0;
                  tx_pixel_phase <= 1'b0;
                  bmp_tx_timer   <= '0;
                  state          <= E_BITMAP_SEND;
                end
              end
              ITEM_CLRBMP_BTN: begin
                clear_bmp_idx <= 14'd0;
                state         <= E_CLEAR_BITMAP;
              end
              ITEM_CLRCON_BTN: begin
                clear_console_req <= 1'b1;
              end
              ITEM_ABOUT_BTN: begin
                show_popup    <= 1'b1;
                show_progress <= 1'b0;
              end
              ITEM_POPUP_BTN: begin
                show_popup    <= 1'b0;
                show_progress <= 1'b0;
                popup_mode    <= POPUP_NONE;
              end
              default: ;
            endcase
          end
        end

        // -------------------------------------------------------------------
        // Parse and Execute Command
        // -------------------------------------------------------------------
        E_PARSE_CMD: begin
          msg_idx <= '0; // Always reset msg_idx to 0!

          if (cmd_buf[2] != "/") begin
            // Normal chat message: stream payload over OptiBolt protocol as MSG_TEXT
            if (link_status != 2'b00) begin
              tx_chat_idx <= 11'd2; // Start from first character after "> "
              state       <= E_TX_CHAT;
            end else begin
              msg_src <= SRC_ERR_DISCONN; msg_len <= 11'd25; state <= E_STREAM_MSG;
            end
          end else begin
            // Local slash commands
            logic [3:0] target_rate, target_os;
            logic valid_rate;
            target_rate = 4'd1; target_os = 4'd0;
            valid_rate = 1'b0;

            if (cmd_len >= 5 && cmd_buf[3]=="h" && cmd_buf[4]=="e") begin
              msg_src <= SRC_HELP; msg_len <= 11'(HELP_LEN); state <= E_STREAM_MSG;
            end else if (cmd_len >= 7 && cmd_buf[3]=="c" && cmd_buf[4]=="l" && cmd_buf[5]=="e" && cmd_buf[6]=="a") begin
              clear_console_req <= 1'b1;
              state <= E_IDLE;
            end else if (cmd_len >= 6 && cmd_buf[3]=="p" && cmd_buf[4]=="i" && cmd_buf[5]=="n") begin
              if (link_status == 2'b00) begin
                msg_src <= SRC_ERR_DISCONN; msg_len <= 11'd25; state <= E_STREAM_MSG;
              end else begin
                ping_active <= 1'b1; ping_timer <= '0;
                proto_tx_valid <= 1'b1; proto_tx_type <= MSG_REQUEST; proto_tx_data <= CMD_PING_REQ;
                msg_src <= SRC_PING_START; msg_len <= 11'd16; state <= E_STREAM_MSG;
              end
            end else if (cmd_len >= 6 && cmd_buf[3]=="b" && cmd_buf[4]=="a" && cmd_buf[5]=="u") begin
              valid_rate = 1'b1;

              if (cmd_buf[8]=="1" && cmd_buf[9]=="0" && cmd_buf[10]=="0")      target_rate = 4'd0; // 100k
              else if (cmd_buf[8]=="1" && cmd_buf[9]=="." && cmd_buf[10]=="2") target_rate = 4'd2; // 1.25m
              else if (cmd_buf[8]=="1" && (cmd_buf[9]=="m" || cmd_buf[9]=="M" || cmd_len==9)) target_rate = 4'd1; // 1m
              else if (cmd_buf[8]=="2" && cmd_buf[9]=="." && cmd_buf[10]=="5") target_rate = 4'd3; // 2.5m
              else if (cmd_buf[8]=="3" && cmd_buf[9]=="." && cmd_buf[10]=="1") target_rate = 4'd4; // 3.125m
              else if (cmd_buf[8]=="5" && (cmd_buf[9]=="m" || cmd_buf[9]=="M" || cmd_len==9)) target_rate = 4'd5; // 5m
              else if (cmd_buf[8]=="6" && cmd_buf[9]=="." && cmd_buf[10]=="2") target_rate = 4'd6; // 6.25m
              else if (cmd_buf[8]=="8" && cmd_buf[9]=="." && cmd_buf[10]=="3") target_rate = 4'd7; // 8.33m
              else if (cmd_buf[8]=="1" && cmd_buf[9]=="2")                     target_rate = 4'd8; // 12.5m
              else if (cmd_buf[8]=="2" && cmd_buf[9]=="5")                     target_rate = 4'd9; // 25m
              else valid_rate = 1'b0;

              // Keep current oversampling if supported, otherwise force 8x
              target_os = active_oversampling;
              if (target_os == 4'd1 && (target_rate == 4'd1 || target_rate == 4'd5 || target_rate == 4'd7 || target_rate == 4'd9)) begin
                target_os = 4'd0;
              end

              if (valid_rate) begin
                req_baud_rate    <= target_rate;
                req_oversampling <= target_os;
                set_speed_req    <= 1'b1;
                msg_src <= SRC_BAUD_SET; msg_len <= 11'd16;
              end else begin
                msg_src <= SRC_UNKNOWN; msg_len <= 11'd16;
              end
              state <= E_STREAM_MSG;
            end else if (cmd_len >= 5 && cmd_buf[3]=="o" && cmd_buf[4]=="s") begin
              if (cmd_len >= 7 && cmd_buf[5] == " ") begin
                if (cmd_buf[6] == "8" && (cmd_len == 7 || cmd_buf[7] == "x" || cmd_buf[7] == "X")) begin
                  req_baud_rate    <= active_baud_rate; // PRESERVE active baud rate!
                  req_oversampling <= 4'd0;             // 8x
                  set_speed_req    <= 1'b1;
                  msg_src <= SRC_BAUD_SET; msg_len <= 11'd16;
                end else if (cmd_buf[6] == "1" && cmd_buf[7] == "6" && (cmd_len == 8 || cmd_buf[8] == "x" || cmd_buf[8] == "X")) begin
                  // 16x is supported on 100k (0), 1.25m (2), 2.5m (3), 3.125m (4), 6.25m (6), 12.5m (8)
                  if (active_baud_rate == 4'd0 || active_baud_rate == 4'd2 || active_baud_rate == 4'd3 ||
                      active_baud_rate == 4'd4 || active_baud_rate == 4'd6 || active_baud_rate == 4'd8) begin
                    req_baud_rate    <= active_baud_rate; // PRESERVE active baud rate!
                    req_oversampling <= 4'd1;             // 16x
                    set_speed_req    <= 1'b1;
                    msg_src <= SRC_BAUD_SET; msg_len <= 11'd16;
                  end else begin
                    // Clear error message when active baud rate does not support 16x
                    msg_src <= SRC_ERR_OS_UNSUPPORTED; msg_len <= 11'd45;
                  end
                end else begin
                  msg_src <= SRC_UNKNOWN; msg_len <= 11'd16;
                end
              end else begin
                msg_src <= SRC_UNKNOWN; msg_len <= 11'd16;
              end
              state <= E_STREAM_MSG;
            end else if (cmd_len >= 10 && cmd_buf[3]=="f" && cmd_buf[4]=="a" && cmd_buf[5]=="i" && cmd_buf[6]=="l") begin
              if (cmd_len >= 14 && cmd_buf[12]=="o" && cmd_buf[13]=="f" && cmd_buf[14]=="f") begin
                failover_en <= 1'b0;
                msg_src <= SRC_FAILOVER_OFF; msg_len <= 11'd19;
              end else begin
                failover_en <= 1'b1;
                msg_src <= SRC_FAILOVER_ON; msg_len <= 11'd19;
              end
              state <= E_STREAM_MSG;
            end else if (cmd_len >= 14 && cmd_buf[3]=="b" && cmd_buf[4]=="i" && cmd_buf[5]=="t" && cmd_buf[10]=="s" && cmd_buf[11]=="e") begin
              if (link_status == 2'b00) begin
                msg_src <= SRC_ERR_DISCONN; msg_len <= 11'd25; state <= E_STREAM_MSG;
              end else begin
                show_popup     <= 1'b1;
                show_progress  <= 1'b1;
                popup_mode     <= POPUP_PROGRESS;
                progress_val   <= 8'd0;
                tx_pixel_cnt   <= '0;
                tx_pixel_phase <= 1'b0;
                tx_gap_cnt     <= '0;
                bmp_tx_timer   <= '0;
                state          <= E_BITMAP_SEND;
              end
            end else if (cmd_len >= 15 && cmd_buf[3]=="b" && cmd_buf[4]=="i" && cmd_buf[5]=="t" && cmd_buf[10]=="c" && cmd_buf[11]=="l") begin
              clear_bmp_idx <= 14'd0;
              state         <= E_CLEAR_BITMAP;
            end else if (cmd_len >= 6 && cmd_buf[3]=="s" && cmd_buf[4]=="w" && cmd_buf[5]=="e") begin
              sweep_step        <= 5'd0;
              sweep_print_step  <= 5'd0;
              sweep_timer       <= '0;
              sweep_pkt_gap     <= '0;
              sweep_active      <= 1'b1;
              sweep_tx_count    <= 4'd0;
              sweep_rx_count    <= 4'd0;
              sweep_had_error   <= 1'b0;
              show_progress     <= 1'b1;
              popup_mode        <= POPUP_PROGRESS;
              progress_val      <= 8'd0;
              if (link_status == 2'b01) begin
                proto_tx_valid <= 1'b1;
                proto_tx_type  <= MSG_REQUEST;
                proto_tx_data  <= CMD_SWEEP_START;
              end
              msg_src <= SRC_SWEEP_START; msg_len <= 11'd27; state <= E_STREAM_MSG;
            end else if (cmd_len >= 8 && cmd_buf[3]=="p" && cmd_buf[4]=="o" && cmd_buf[5]=="w" && cmd_buf[6]=="e" && cmd_buf[7]=="r") begin
              if (cmd_len >= 14 && cmd_buf[9]=="r" && cmd_buf[10]=="o" && cmd_buf[11]=="l" && cmd_buf[12]=="e" && cmd_buf[13]==" ") begin
                if (cmd_len == 18 && (cmd_buf[14] == "w" || cmd_buf[14] == "W") && (cmd_buf[15] == "a" || cmd_buf[15] == "A") &&
                    (cmd_buf[16] == "l" || cmd_buf[16] == "L") && (cmd_buf[17] == "l" || cmd_buf[17] == "L")) begin
                  cfg_role <= 2'd1; // WALL
                  msg_src <= SRC_PWR_ROLE_SET; msg_len <= 11'd19; state <= E_STREAM_MSG;
                end else if (cmd_len == 21 && (cmd_buf[14] == "b" || cmd_buf[14] == "B") && (cmd_buf[15] == "a" || cmd_buf[15] == "A") &&
                    (cmd_buf[16] == "t" || cmd_buf[16] == "T") && (cmd_buf[17] == "t" || cmd_buf[17] == "T") &&
                    (cmd_buf[18] == "e" || cmd_buf[18] == "E") && (cmd_buf[19] == "r" || cmd_buf[19] == "R") &&
                    (cmd_buf[20] == "y" || cmd_buf[20] == "Y")) begin
                  cfg_role <= 2'd2; // BATTERY
                  msg_src <= SRC_PWR_ROLE_SET; msg_len <= 11'd19; state <= E_STREAM_MSG;
                end else if (cmd_len == 18 && (cmd_buf[14] == "s" || cmd_buf[14] == "S") && (cmd_buf[15] == "i" || cmd_buf[15] == "I") &&
                    (cmd_buf[16] == "n" || cmd_buf[16] == "N") && (cmd_buf[17] == "k" || cmd_buf[17] == "K")) begin
                  cfg_role <= 2'd3; // SINK
                  msg_src <= SRC_PWR_ROLE_SET; msg_len <= 11'd19; state <= E_STREAM_MSG;
                end else begin
                  msg_src <= SRC_UNKNOWN; msg_len <= 11'd16; state <= E_STREAM_MSG;
                end
              end else if (cmd_len >= 12 && cmd_buf[9]=="i" && cmd_buf[10]=="n" && cmd_buf[11]==" ") begin
                // /power in <5|9|12|20> <0..9>
                logic valid_pwr_in;
                valid_pwr_in = 1'b0;
                if (cmd_len == 15 && cmd_buf[12] == "5" && cmd_buf[13] == " " && cmd_buf[14] >= "0" && cmd_buf[14] <= "9") begin
                  cfg_in_amps[0] <= cmd_buf[14][3:0];
                  valid_pwr_in = 1'b1;
                end else if (cmd_len == 15 && cmd_buf[12] == "9" && cmd_buf[13] == " " && cmd_buf[14] >= "0" && cmd_buf[14] <= "9") begin
                  cfg_in_amps[1] <= cmd_buf[14][3:0];
                  valid_pwr_in = 1'b1;
                end else if (cmd_len == 16 && cmd_buf[12] == "1" && cmd_buf[13] == "2" && cmd_buf[14] == " " && cmd_buf[15] >= "0" && cmd_buf[15] <= "9") begin
                  cfg_in_amps[2] <= cmd_buf[15][3:0];
                  valid_pwr_in = 1'b1;
                end else if (cmd_len == 16 && cmd_buf[12] == "2" && cmd_buf[13] == "0" && cmd_buf[14] == " " && cmd_buf[15] >= "0" && cmd_buf[15] <= "9") begin
                  cfg_in_amps[3] <= cmd_buf[15][3:0];
                  valid_pwr_in = 1'b1;
                end

                if (valid_pwr_in) begin
                  msg_src <= SRC_PWR_IN_SET; msg_len <= 11'd24; state <= E_STREAM_MSG;
                end else begin
                  msg_src <= SRC_UNKNOWN; msg_len <= 11'd16; state <= E_STREAM_MSG;
                end
              end else if (cmd_len >= 13 && cmd_buf[9]=="o" && cmd_buf[10]=="u" && cmd_buf[11]=="t" && cmd_buf[12]==" ") begin
                // /power out <5|9|12|20> <0..9>
                logic valid_pwr_out;
                valid_pwr_out = 1'b0;
                if (cmd_len == 16 && cmd_buf[13] == "5" && cmd_buf[14] == " " && cmd_buf[15] >= "0" && cmd_buf[15] <= "9") begin
                  cfg_out_amps[0] <= cmd_buf[15][3:0];
                  valid_pwr_out = 1'b1;
                end else if (cmd_len == 16 && cmd_buf[13] == "9" && cmd_buf[14] == " " && cmd_buf[15] >= "0" && cmd_buf[15] <= "9") begin
                  cfg_out_amps[1] <= cmd_buf[15][3:0];
                  valid_pwr_out = 1'b1;
                end else if (cmd_len == 17 && cmd_buf[13] == "1" && cmd_buf[14] == "2" && cmd_buf[15] == " " && cmd_buf[16] >= "0" && cmd_buf[16] <= "9") begin
                  cfg_out_amps[2] <= cmd_buf[16][3:0];
                  valid_pwr_out = 1'b1;
                end else if (cmd_len == 17 && cmd_buf[13] == "2" && cmd_buf[14] == "0" && cmd_buf[15] == " " && cmd_buf[16] >= "0" && cmd_buf[16] <= "9") begin
                  cfg_out_amps[3] <= cmd_buf[16][3:0];
                  valid_pwr_out = 1'b1;
                end

                if (valid_pwr_out) begin
                  msg_src <= SRC_PWR_OUT_SET; msg_len <= 11'd24; state <= E_STREAM_MSG;
                end else begin
                  msg_src <= SRC_UNKNOWN; msg_len <= 11'd16; state <= E_STREAM_MSG;
                end
              end else if (cmd_len >= 14 && cmd_buf[9]=="c" && cmd_buf[10]=="l" && cmd_buf[11]=="e") begin
                cfg_role  <= 2'd0;
                cfg_ready <= 1'b0;
                cfg_clear <= 1'b1;
                for (int i = 0; i < 4; i++) begin
                  cfg_in_amps[i]  <= 4'd0;
                  cfg_out_amps[i] <= 4'd0;
                end
                msg_src <= SRC_PWR_CLEARED; msg_len <= 11'd21; state <= E_STREAM_MSG;
              end else if (cmd_len >= 14 && cmd_buf[9]=="r" && cmd_buf[10]=="e" && cmd_buf[11]=="a") begin
                cfg_ready <= 1'b1;
                msg_src   <= SRC_PWR_READY; msg_len <= 11'd25; state <= E_STREAM_MSG;
              end else if (cmd_len >= 12 && cmd_buf[9]=="o" && cmd_buf[10]=="f" && cmd_buf[11]=="f") begin
                cfg_ready      <= 1'b0;
                cfg_clear      <= 1'b1;
                proto_tx_valid <= 1'b1;
                proto_tx_type  <= MSG_POWER;
                proto_tx_data  <= 8'hFE;
                msg_src <= SRC_PWR_OFF; msg_len <= 11'd22; state <= E_STREAM_MSG;
              end else if (cmd_len >= 15 && cmd_buf[9]=="s" && cmd_buf[10]=="t" && cmd_buf[11]=="a") begin
                // /power status : Show full power table
                if (!contract_active) msg_len <= 11'd75;
                else if (active_is_source) msg_len <= 11'd86;
                else msg_len <= 11'd88;
                msg_src <= SRC_PWR_STATUS;
                state   <= E_STREAM_MSG;
              end else begin
                msg_src <= SRC_UNKNOWN; msg_len <= 11'd16; state <= E_STREAM_MSG;
              end
            end else begin
              msg_src <= SRC_UNKNOWN; msg_len <= 11'd16; state <= E_STREAM_MSG;
            end
          end
        end

        // -------------------------------------------------------------------
        // Stream Message Bytes to eval_console_buffer
        // -------------------------------------------------------------------
        E_STREAM_MSG: begin
          if (!print_valid) begin
            print_char  <= current_msg_char;
            print_last  <= (msg_idx == msg_len - 11'd1);
            print_valid <= 1'b1;
          end else if (print_ready) begin
            print_valid <= 1'b0;
            if (msg_idx == msg_len - 11'd1) begin
              if (sweep_active) state <= E_SWEEP_STEP;
              else if (pending_cmd) begin
                pending_cmd <= 1'b0;
                state       <= E_PARSE_CMD;
              end else begin
                state <= E_IDLE;
              end
            end else begin
              msg_idx <= msg_idx + 11'd1;
            end
          end
        end

        // -------------------------------------------------------------------
        // Sequential Double-Dabble BCD Converter (32-bit Binary -> 8 BCD Digits)
        // -------------------------------------------------------------------
        E_CONVERT_BCD: begin
          if (bcd_cnt > 0) begin
            logic [31:0] bcd_next;
            bcd_next = bcd_reg;
            for (int i = 0; i < 8; i++) begin
              if (bcd_next[i*4 +: 4] >= 4'd5) bcd_next[i*4 +: 4] = bcd_next[i*4 +: 4] + 4'd3;
            end
            bcd_reg <= {bcd_next[30:0], bin_reg[31]};
            bin_reg <= {bin_reg[30:0], 1'b0};
            bcd_cnt <= bcd_cnt - 6'd1;
          end else begin
            for (int i = 0; i < 8; i++) bcd_d[i] <= bcd_reg[i*4 +: 4];
            fmt_ptr       <= 6'd0;
            fmt_phase     <= 3'd0;
            fmt_digit_idx <= 4'd7;
            fmt_text_idx  <= 5'd0;
            fmt_lead_zero <= 1'b1;
            if (fmt_is_bitmap) state <= E_BMP_FMT_STEP;
            else state <= E_PING_FMT_STEP;
          end
        end

        // -------------------------------------------------------------------
        // Sequential Ping Result Formatter: "Ping: X cycles (Y.YY us)\n"
        // -------------------------------------------------------------------
        E_PING_FMT_STEP: begin
          case (fmt_phase)
            3'd0: begin // "Ping: "
              case (fmt_text_idx)
                5'd0: ping_msg_buf[fmt_ptr] <= "P";
                5'd1: ping_msg_buf[fmt_ptr] <= "i";
                5'd2: ping_msg_buf[fmt_ptr] <= "n";
                5'd3: ping_msg_buf[fmt_ptr] <= "g";
                5'd4: ping_msg_buf[fmt_ptr] <= ":";
                5'd5: ping_msg_buf[fmt_ptr] <= " ";
              endcase
              fmt_ptr <= fmt_ptr + 6'd1;
              if (fmt_text_idx == 5'd5) begin
                if (ping_rtt_cycles == 32'd0) begin
                  fmt_phase    <= 3'd6; // Timeout
                  fmt_text_idx <= 5'd0;
                end else begin
                  fmt_phase     <= 3'd1; // Digits
                  fmt_digit_idx <= 4'd7;
                  fmt_lead_zero <= 1'b1;
                  fmt_text_idx  <= 5'd0;
                end
              end else fmt_text_idx <= fmt_text_idx + 5'd1;
            end

            3'd1: begin // Decimal digits for clock cycles
              if (bcd_d[fmt_digit_idx] != 4'd0 || !fmt_lead_zero || fmt_digit_idx == 4'd0) begin
                ping_msg_buf[fmt_ptr] <= 8'h30 + {4'd0, bcd_d[fmt_digit_idx]};
                fmt_ptr <= fmt_ptr + 6'd1;
                fmt_lead_zero <= 1'b0;
              end
              if (fmt_digit_idx == 4'd0) begin
                fmt_phase    <= 3'd2; // " cycles ("
                fmt_text_idx <= 5'd0;
              end else fmt_digit_idx <= fmt_digit_idx - 4'd1;
            end

            3'd2: begin // " cycles ("
              case (fmt_text_idx)
                5'd0: ping_msg_buf[fmt_ptr] <= " ";
                5'd1: ping_msg_buf[fmt_ptr] <= "c";
                5'd2: ping_msg_buf[fmt_ptr] <= "y";
                5'd3: ping_msg_buf[fmt_ptr] <= "c";
                5'd4: ping_msg_buf[fmt_ptr] <= "l";
                5'd5: ping_msg_buf[fmt_ptr] <= "e";
                5'd6: ping_msg_buf[fmt_ptr] <= "s";
                5'd7: ping_msg_buf[fmt_ptr] <= " ";
                5'd8: ping_msg_buf[fmt_ptr] <= "(";
              endcase
              fmt_ptr <= fmt_ptr + 6'd1;
              if (fmt_text_idx == 5'd8) begin
                fmt_phase     <= 3'd3; // Microseconds integer digits
                fmt_digit_idx <= 4'd7;
                fmt_lead_zero <= 1'b1;
                fmt_text_idx  <= 5'd0;
              end else fmt_text_idx <= fmt_text_idx + 5'd1;
            end

            3'd3: begin // Microseconds integer digits (bcd_d[7:2])
              if (bcd_d[fmt_digit_idx] != 4'd0 || !fmt_lead_zero || fmt_digit_idx == 4'd2) begin
                ping_msg_buf[fmt_ptr] <= 8'h30 + {4'd0, bcd_d[fmt_digit_idx]};
                fmt_ptr <= fmt_ptr + 6'd1;
                fmt_lead_zero <= 1'b0;
              end
              if (fmt_digit_idx == 4'd2) begin
                fmt_phase    <= 3'd4; // Decimal point + fractions
                fmt_text_idx <= 5'd0;
              end else fmt_digit_idx <= fmt_digit_idx - 4'd1;
            end

            3'd4: begin // "." then bcd_d[1], bcd_d[0]
              case (fmt_text_idx)
                5'd0: ping_msg_buf[fmt_ptr] <= ".";
                5'd1: ping_msg_buf[fmt_ptr] <= 8'h30 + {4'd0, bcd_d[1]};
                5'd2: ping_msg_buf[fmt_ptr] <= 8'h30 + {4'd0, bcd_d[0]};
              endcase
              fmt_ptr <= fmt_ptr + 6'd1;
              if (fmt_text_idx == 5'd2) begin
                fmt_phase    <= 3'd5; // " us)\n"
                fmt_text_idx <= 5'd0;
              end else fmt_text_idx <= fmt_text_idx + 5'd1;
            end

            3'd5: begin // " us)\n"
              case (fmt_text_idx)
                5'd0: ping_msg_buf[fmt_ptr] <= " ";
                5'd1: ping_msg_buf[fmt_ptr] <= "u";
                5'd2: ping_msg_buf[fmt_ptr] <= "s";
                5'd3: ping_msg_buf[fmt_ptr] <= ")";
                5'd4: ping_msg_buf[fmt_ptr] <= "\n";
              endcase
              if (fmt_text_idx == 5'd4) begin
                msg_src <= SRC_PING_MSG;
                msg_idx <= '0;
                msg_len <= 11'(fmt_ptr + 1);
                state   <= E_STREAM_MSG;
              end else begin
                fmt_ptr      <= fmt_ptr + 6'd1;
                fmt_text_idx <= fmt_text_idx + 5'd1;
              end
            end

            3'd6: begin // "timeout\n"
              case (fmt_text_idx)
                5'd0: ping_msg_buf[fmt_ptr] <= "t";
                5'd1: ping_msg_buf[fmt_ptr] <= "i";
                5'd2: ping_msg_buf[fmt_ptr] <= "m";
                5'd3: ping_msg_buf[fmt_ptr] <= "e";
                5'd4: ping_msg_buf[fmt_ptr] <= "o";
                5'd5: ping_msg_buf[fmt_ptr] <= "u";
                5'd6: ping_msg_buf[fmt_ptr] <= "t";
                5'd7: ping_msg_buf[fmt_ptr] <= "\n";
              endcase
              if (fmt_text_idx == 5'd7) begin
                msg_src <= SRC_PING_MSG;
                msg_idx <= '0;
                msg_len <= 11'(fmt_ptr + 1);
                state   <= E_STREAM_MSG;
              end else begin
                fmt_ptr      <= fmt_ptr + 6'd1;
                fmt_text_idx <= fmt_text_idx + 5'd1;
              end
            end
            default: state <= E_IDLE;
          endcase
        end

        // -------------------------------------------------------------------
        // Sequential Bitmap Timing Formatter: "Bitmap TX/RX: X cycles (Y.YY ms)\n"
        // -------------------------------------------------------------------
        E_BMP_FMT_STEP: begin
          case (fmt_phase)
            3'd0: begin // "Bitmap TX: " or "Bitmap RX: " (11 chars)
              case (fmt_text_idx)
                5'd0:  bmp_msg_buf[fmt_ptr] <= "B";
                5'd1:  bmp_msg_buf[fmt_ptr] <= "i";
                5'd2:  bmp_msg_buf[fmt_ptr] <= "t";
                5'd3:  bmp_msg_buf[fmt_ptr] <= "m";
                5'd4:  bmp_msg_buf[fmt_ptr] <= "a";
                5'd5:  bmp_msg_buf[fmt_ptr] <= "p";
                5'd6:  bmp_msg_buf[fmt_ptr] <= " ";
                5'd7:  bmp_msg_buf[fmt_ptr] <= fmt_report_is_rx ? "R" : "T";
                5'd8:  bmp_msg_buf[fmt_ptr] <= "X";
                5'd9:  bmp_msg_buf[fmt_ptr] <= ":";
                5'd10: bmp_msg_buf[fmt_ptr] <= " ";
              endcase
              fmt_ptr <= fmt_ptr + 6'd1;
              if (fmt_text_idx == 5'd10) begin
                fmt_phase     <= 3'd1; // Cycle digits
                fmt_digit_idx <= 4'd7;
                fmt_lead_zero <= 1'b1;
                fmt_text_idx  <= 5'd0;
              end else fmt_text_idx <= fmt_text_idx + 5'd1;
            end

            3'd1: begin // Decimal digits for clock cycles (bcd_d[7:0])
              if (bcd_d[fmt_digit_idx] != 4'd0 || !fmt_lead_zero || fmt_digit_idx == 4'd0) begin
                bmp_msg_buf[fmt_ptr] <= 8'h30 + {4'd0, bcd_d[fmt_digit_idx]};
                fmt_ptr <= fmt_ptr + 6'd1;
                fmt_lead_zero <= 1'b0;
              end
              if (fmt_digit_idx == 4'd0) begin
                fmt_phase    <= 3'd2; // " cycles ("
                fmt_text_idx <= 5'd0;
              end else fmt_digit_idx <= fmt_digit_idx - 4'd1;
            end

            3'd2: begin // " cycles (" (9 chars)
              case (fmt_text_idx)
                5'd0: bmp_msg_buf[fmt_ptr] <= " ";
                5'd1: bmp_msg_buf[fmt_ptr] <= "c";
                5'd2: bmp_msg_buf[fmt_ptr] <= "y";
                5'd3: bmp_msg_buf[fmt_ptr] <= "c";
                5'd4: bmp_msg_buf[fmt_ptr] <= "l";
                5'd5: bmp_msg_buf[fmt_ptr] <= "e";
                5'd6: bmp_msg_buf[fmt_ptr] <= "s";
                5'd7: bmp_msg_buf[fmt_ptr] <= " ";
                5'd8: bmp_msg_buf[fmt_ptr] <= "(";
              endcase
              fmt_ptr <= fmt_ptr + 6'd1;
              if (fmt_text_idx == 5'd8) begin
                fmt_phase     <= 3'd3; // Milliseconds integer digits (bcd_d[7:5])
                fmt_digit_idx <= 4'd7;
                fmt_lead_zero <= 1'b1;
                fmt_text_idx  <= 5'd0;
              end else fmt_text_idx <= fmt_text_idx + 5'd1;
            end

            3'd3: begin // Milliseconds integer digits (10^5 cycles = 1 ms -> bcd_d[7:5])
              if (bcd_d[7] == 4'd0 && bcd_d[6] == 4'd0 && bcd_d[5] == 4'd0) begin
                bmp_msg_buf[fmt_ptr] <= "0";
                fmt_ptr      <= fmt_ptr + 6'd1;
                fmt_phase    <= 3'd4; // Fraction
                fmt_text_idx <= 5'd0;
              end else begin
                if (bcd_d[fmt_digit_idx] != 4'd0 || !fmt_lead_zero || fmt_digit_idx == 4'd5) begin
                  bmp_msg_buf[fmt_ptr] <= 8'h30 + {4'd0, bcd_d[fmt_digit_idx]};
                  fmt_ptr <= fmt_ptr + 6'd1;
                  fmt_lead_zero <= 1'b0;
                end
                if (fmt_digit_idx == 4'd5) begin
                  fmt_phase    <= 3'd4; // Fraction
                  fmt_text_idx <= 5'd0;
                end else fmt_digit_idx <= fmt_digit_idx - 4'd1;
              end
            end

            3'd4: begin // "." then bcd_d[4], bcd_d[3] (0.01 ms resolution)
              case (fmt_text_idx)
                5'd0: bmp_msg_buf[fmt_ptr] <= ".";
                5'd1: bmp_msg_buf[fmt_ptr] <= 8'h30 + {4'd0, bcd_d[4]};
                5'd2: bmp_msg_buf[fmt_ptr] <= 8'h30 + {4'd0, bcd_d[3]};
              endcase
              fmt_ptr <= fmt_ptr + 6'd1;
              if (fmt_text_idx == 5'd2) begin
                fmt_phase    <= 3'd5; // " ms)\n"
                fmt_text_idx <= 5'd0;
              end else fmt_text_idx <= fmt_text_idx + 5'd1;
            end

            3'd5: begin // " ms)\n" (5 chars)
              case (fmt_text_idx)
                5'd0: bmp_msg_buf[fmt_ptr] <= " ";
                5'd1: bmp_msg_buf[fmt_ptr] <= "m";
                5'd2: bmp_msg_buf[fmt_ptr] <= "s";
                5'd3: bmp_msg_buf[fmt_ptr] <= ")";
                5'd4: bmp_msg_buf[fmt_ptr] <= "\n";
              endcase
              if (fmt_text_idx == 5'd4) begin
                msg_src <= fmt_report_is_rx ? SRC_BMP_RX_MSG : SRC_BMP_TX_MSG;
                msg_idx <= '0;
                msg_len <= 11'(fmt_ptr + 1);
                state   <= E_STREAM_MSG;
              end else begin
                fmt_ptr      <= fmt_ptr + 6'd1;
                fmt_text_idx <= fmt_text_idx + 5'd1;
              end
            end
            default: state <= E_IDLE;
          endcase
        end

        // -------------------------------------------------------------------
        // Baudrate Sweep Step Sequence
        // -------------------------------------------------------------------
        E_SWEEP_STEP: begin
          if (sweep_step < 5'd16) begin
            req_baud_rate    <= SWEEP_BAUD[sweep_step];
            req_oversampling <= SWEEP_OS[sweep_step];
            set_speed_req    <= 1'b1;
            sweep_timer      <= '0;
            sweep_pkt_gap    <= '0;
            sweep_tx_count   <= 4'd0;
            sweep_rx_count   <= 4'd0;
            sweep_had_error  <= 1'b0;
            progress_val     <= 8'((255 * (sweep_step + 1)) / 16);
            state            <= E_SWEEP_WAIT;
          end else begin
            // Sweep complete: notify remote peer at default speed 1.0 Mbps 8x
            if (link_status == 2'b01) begin
              proto_tx_valid <= 1'b1;
              proto_tx_type  <= MSG_REQUEST;
              proto_tx_data  <= CMD_SWEEP_END;
            end
            req_baud_rate    <= 4'd1;
            req_oversampling <= 4'd0;
            set_speed_req    <= 1'b1;
            sweep_active     <= 1'b0;
            show_popup       <= 1'b0;
            show_progress    <= 1'b0;
            popup_mode       <= POPUP_NONE;
            msg_src          <= SRC_SWEEP_DONE;
            msg_len          <= 11'd21;
            msg_idx          <= '0;
            state            <= E_STREAM_MSG;
          end
        end

        E_SWEEP_WAIT: begin
          sweep_timer <= sweep_timer + 32'd1;

          /* Settle guard window (1/8th of step duration): ignore switching transients */
          if (sweep_timer < (SWEEP_STEP_TICKS >> 3)) begin
            sweep_had_error <= 1'b0;
            sweep_pkt_gap   <= '0;
          end else begin
            /* Latch protocol errors during active measurement window */
            if (proto_eval_parity_error || proto_eval_manchester_code_error || proto_eval_preamble_error) begin
              sweep_had_error <= 1'b1;
            end

            /* Pace packet transmissions across active test window */
            sweep_pkt_gap <= sweep_pkt_gap + 32'd1;
            if (sweep_pkt_gap >= (SWEEP_STEP_TICKS >> 5) && sweep_tx_count < 5'd16) begin
              if (!proto_tx_full) begin
                proto_tx_valid <= 1'b1;
                proto_tx_type  <= MSG_SWEEP;
                proto_tx_data  <= {sweep_step[3:0], sweep_tx_count[3:0]};
                sweep_tx_count <= sweep_tx_count + 5'd1;
                sweep_pkt_gap  <= '0;
              end
            end else if (proto_tx_valid && !proto_tx_full) begin
              proto_tx_valid <= 1'b0;
            end
          end

          /* Count received test packets tagged specifically for this sweep step */
          if (proto_rx_valid && proto_rx_type == MSG_SWEEP && proto_rx_data[7:4] == sweep_step[3:0]) begin
            sweep_rx_count <= sweep_rx_count + 5'd1;
          end

          /* Evaluate link performance at end of dwell window */
          if (sweep_timer >= SWEEP_STEP_TICKS) begin
            proto_tx_valid   <= 1'b0;
            sweep_print_step <= sweep_step;
            sweep_step       <= sweep_step + 5'd1;
            if (sweep_rx_count == 5'd16 && !sweep_had_error && rx_carrier && link_status != 2'b00) begin
              msg_src <= SRC_SWEEP_PASS;
              msg_len <= 11'd21;
            end else begin
              msg_src <= SRC_SWEEP_FAIL;
              msg_len <= 11'd24;
            end
            // Always return to default speed (1.0 Mbps 8x) locally so next step can negotiate cleanly
            req_baud_rate    <= 4'd1;
            req_oversampling <= 4'd0;
            set_speed_req    <= 1'b1;
            sweep_timer      <= '0;
            state            <= E_SWEEP_RESTORE;
          end
        end

        E_SWEEP_RESTORE: begin
          sweep_timer <= sweep_timer + 32'd1;
          if (sweep_timer >= (SWEEP_STEP_TICKS >> 3)) begin
            msg_idx <= '0;
            state   <= E_STREAM_MSG;
          end
        end

        // -------------------------------------------------------------------
        // Dynamic Bitmap Streaming (2 bytes per pixel with continuous PRNG)
        // -------------------------------------------------------------------
        E_BITMAP_SEND: begin
          bmp_tx_timer <= bmp_tx_timer + 32'd1;

          if (proto_tx_valid && proto_tx_full) begin
            // Hold current byte valid until FIFO accepts it
            proto_tx_valid <= 1'b1;
          end else if (proto_tx_valid) begin
            // Byte was consumed by FIFO: enter 200ns recovery gap
            proto_tx_valid <= 1'b0;
            tx_gap_cnt     <= 6'd0;
          end else if (tx_gap_cnt < 6'd20) begin
            // 20 cycles @ 100MHz = 200ns recovery gap between bytes
            tx_gap_cnt <= tx_gap_cnt + 6'd1;
          end else begin
            // Recovery gap elapsed (or first byte starting)
            if (tx_pixel_cnt < 15'd16384) begin
              proto_tx_valid <= 1'b1;
              proto_tx_type  <= MSG_BITMAP;
              if (!tx_pixel_phase) begin
                // Latch RGB sample from free-running PRNG for Byte 0
                latched_pixel_rgb <= prng_pixel_rgb;
                // Byte 0: {1'b0, R[3:0], G[3:1]}
                proto_tx_data     <= {1'b0, prng_pixel_rgb[11:8], prng_pixel_rgb[7:5]};
                tx_pixel_phase    <= 1'b1;
              end else begin
                // Byte 1 uses matching lower bits of latched pixel RGB
                // Byte 1: {1'b1, G[0], B[3:0], 2'b00}
                proto_tx_data   <= {1'b1, latched_pixel_rgb[4], latched_pixel_rgb[3:0], 2'b00};
                tx_pixel_cnt    <= tx_pixel_cnt + 15'd1;
                tx_pixel_phase  <= 1'b0;
                progress_val    <= 8'(tx_pixel_cnt[13:6]);
              end
            end else begin
              // Transmission complete: hide progress popup and format console timer report
              proto_tx_valid   <= 1'b0;
              show_popup       <= 1'b0;
              show_progress    <= 1'b0;
              popup_mode       <= POPUP_NONE;
              bin_reg          <= bmp_tx_timer;
              bcd_reg          <= '0;
              bcd_cnt          <= 6'd32;
              fmt_is_bitmap    <= 1'b1;
              fmt_report_is_rx <= 1'b0;
              state            <= E_CONVERT_BCD;
            end
          end
        end

        E_CLEAR_BITMAP: begin
          bmp_addr <= clear_bmp_idx;
          bmp_din  <= 12'h000;
          bmp_we   <= 1'b1;
          if (clear_bmp_idx == 14'd16383) begin
            state <= E_IDLE;
          end else begin
            clear_bmp_idx <= clear_bmp_idx + 14'd1;
          end
        end

        // -------------------------------------------------------------------
        // Normal Chat Message TX
        // -------------------------------------------------------------------
        E_TX_CHAT: begin
          if (proto_tx_valid && proto_tx_full) begin
            proto_tx_valid <= 1'b1;
          end else begin
            if (tx_chat_idx < cmd_len) begin
              proto_tx_valid <= 1'b1;
              proto_tx_type  <= MSG_TEXT;
              proto_tx_data  <= cmd_buf[tx_chat_idx];
              tx_chat_idx    <= tx_chat_idx + 11'd1;
            end else if (tx_chat_idx == cmd_len) begin
              proto_tx_valid <= 1'b1;
              proto_tx_type  <= MSG_TEXT;
              proto_tx_data  <= 8'h0A; // Trailing newline
              tx_chat_idx    <= tx_chat_idx + 11'd1;
            end else begin
              proto_tx_valid <= 1'b0;
              state          <= E_IDLE;
            end
          end
        end

        default: state <= E_IDLE;
      endcase
    end
  end

endmodule
