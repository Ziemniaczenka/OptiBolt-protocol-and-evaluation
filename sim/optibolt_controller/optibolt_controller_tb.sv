/**
 * Copyright (C) 2025  AGH University of Science and Technology
 * MTM UEC2
 * Author: Tomasz Więcławski & Sebastian Zoń
 *
 * Description:
 * Testbench for optibolt_controller
 */

module optibolt_controller_tb();

    logic clk200;
    logic rst_n;
    logic [3:0] oversampling;
    logic [3:0] bit_rate;

    logic rx_manchester;
    logic tx_manchester;

    logic rx_enable;
    logic rx_empty, rx_full;
    logic [7:0] data_out;
    logic [2:0] msg_type_out;
    logic parity_error, manchester_code_error, preamble_error;

    logic tx_enable;
    logic [2:0] tx_msg_type;
    logic [7:0] tx_data;
    logic tx_empty, tx_full;

    assign rx_manchester = tx_manchester;

    optibolt_controller dut (
        .clk200(clk200),
        .rst_n(rst_n),
        .oversampling(oversampling),
        .bit_rate(bit_rate),
        .rx_manchester(rx_manchester),
        .tx_manchester(tx_manchester),
        .rx_enable(rx_enable),
        .rx_empty(rx_empty),
        .rx_full(rx_full),
        .data_out(data_out),
        .msg_type_out(msg_type_out),
        .parity_error(parity_error),
        .manchester_code_error(manchester_code_error), 
        .preamble_error(preamble_error),
        .tx_enable(tx_enable),
        .tx_msg_type(tx_msg_type),
        .tx_data(tx_data),
        .tx_empty(tx_empty),
        .tx_full(tx_full)
    );

    initial begin
        clk200 = 0;
        forever #2.5 clk200 = ~clk200;
    end

    initial begin
        rst_n = 0;
        oversampling = 4'b0000;
        bit_rate = 4'b0000;
        rx_enable = 0;
        tx_enable = 0;
        tx_msg_type = 3'b000;
        tx_data = 8'h00;

        #15 rst_n = 1;
        #100;

        @(posedge clk200);
        for (int i = 0; i < 3; i++) begin
            tx_msg_type = 3'b100;
            tx_data = 8'hA0 + i; 
            tx_enable = 1;
            @(posedge clk200);
        end
        tx_enable = 0;

        for (int i = 0; i < 3; i++) begin
            while (rx_empty == 1'b1) @(posedge clk200);
            $display("loop: %h.", i);
            if (data_out !== (8'hA0 + i) || msg_type_out !== 3'b100) begin
                $error("Error: loopback data mismatch. Expected data: %h, Got: %h", (8'hA0 + i), data_out);
            end
            
            rx_enable = 1;
            @(posedge clk200);
            rx_enable = 0;
            
            @(posedge clk200); 
        end

        #1000; 
        $display("INFO: All tests completed.");
        $finish;
    end

    property reset_behavior;
        @(posedge clk200) !rst_n |-> (rx_empty == 1'b1) && (tx_empty == 1'b1) && (tx_manchester == 1'b1);
    endproperty
    assert_reset: assert property (reset_behavior) else $error("Error: reset behavior");

    property tx_fifo_write;
        @(posedge clk200) disable iff (!rst_n)
        (tx_enable && !tx_full) |=> (!tx_empty);
    endproperty
    assert_tx_write: assert property (tx_fifo_write) else $error("Error: tx_empty flag not cleared");

    property bit_valid_pulse;
        @(posedge clk200) disable iff (!rst_n)
        dut.bit_valid |=> !dut.bit_valid;
    endproperty
    assert_bit_valid_pulse: assert property (bit_valid_pulse) else $error("Error: bit_valid pulse is too long");

    property tx_start_triggers_busy;
        @(posedge clk200) disable iff (!rst_n)
        (!tx_empty && !dut.tx_busy) |=> (dut.tx_busy == 1'b1);
    endproperty
    assert_tx_start_busy: assert property (tx_start_triggers_busy) else $error("Error: transmitter did not start");

    property tx_does_not_hang;
        @(posedge clk200) disable iff (!rst_n)
        $rose(dut.tx_busy) |-> ##[1:$] $fell(dut.tx_busy);
    endproperty
    assert_tx_finish: assert property (tx_does_not_hang) else $error("Error: transmitter is stuck");

    property tick_generation_active;
        @(posedge clk200) disable iff (!rst_n)
        $rose(dut.tick) |-> ##[1:10000] $rose(dut.tick);
    endproperty
    assert_tick_active: assert property (tick_generation_active) else $error("Error: tick signal is dead");

    property valid_parity_when_not_empty;
        @(posedge clk200) disable iff (!rst_n)
        (!rx_empty) |-> (parity_error == 0);
    endproperty
    assert_valid_parity: assert property (valid_parity_when_not_empty) else $error("Error: parity error detected in received frame");

endmodule