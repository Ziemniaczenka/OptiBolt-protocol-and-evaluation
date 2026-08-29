/**
 * Top RTL Loopback Integration Testbench
 * Test link disconnect transition
 */

`timescale 1ns / 1ps

import protocol_pkg::*;
import ui_pkg::*;
import string_pkg::*;

module top_rtl_tb;

  timeunit 1ns; timeprecision 1ps;

  logic clk74p25, clk100, clk200, rst_n;
  wire vs, hs;
  wire [3:0] r, g, b;
  wire [3:0] an;
  wire [6:0] seg;
  wire dp;

  wire ps2_clk  = 1'b1;
  wire ps2_data = 1'b1;

  wire OptiBolt_tx;
  logic OptiBolt_rx;
  logic optical_connected;

  assign OptiBolt_rx = optical_connected ? OptiBolt_tx : 1'b0;

  initial begin clk74p25 = 1'b0; forever #6.734 clk74p25 = ~clk74p25; end
  initial begin clk100   = 1'b0; forever #5.000 clk100   = ~clk100;   end
  initial begin clk200   = 1'b0; forever #2.500 clk200   = ~clk200;   end

  top #(
      .CARRIER_HOLD_CYCLES(5_000)
  ) dut (
      .clk74p25(clk74p25),
      .clk100(clk100),
      .clk200(clk200),
      .rst_n(rst_n),
      .vs(vs), .hs(hs), .r(r), .g(g), .b(b),
      .ps2_clk(ps2_clk), .ps2_data(ps2_data),
      .an(an), .seg(seg), .dp(dp),
      .OptiBolt_tx(OptiBolt_tx),
      .OptiBolt_rx(OptiBolt_rx)
  );

  initial begin
    rst_n = 1'b0;
    optical_connected = 1'b1;
    #500;
    rst_n = 1'b1;

    wait(dut.u_top_evaluation.link_status == 2'b10);
    $display("[TB] Loopback link established at %0t (link_status=%b, carrier=%b)",
             $time, dut.u_top_evaluation.link_status, dut.proto_eval_rx_carrier);

    #50_000; // 50 us later, physically disconnect optical link
    $display("[TB] Disconnecting optical cable at %0t...", $time);
    optical_connected = 1'b0;

    // Observe what happens
    fork
      begin
        wait(dut.u_top_evaluation.link_status == 2'b00);
        $display("[TB-PASS] Disconnected detected at %0t! link_status=%b, carrier=%b",
                 $time, dut.u_top_evaluation.link_status, dut.proto_eval_rx_carrier);
      end
      begin
        #500_000; // 500us timeout
        $display("[TB-TIMEOUT] After 500us: link_status=%b, carrier=%b, timer=%0d",
                 dut.u_top_evaluation.link_status, dut.proto_eval_rx_carrier,
                 dut.u_optical_carrier_detector.timer);
      end
    join_any

    $finish;
  end

endmodule
