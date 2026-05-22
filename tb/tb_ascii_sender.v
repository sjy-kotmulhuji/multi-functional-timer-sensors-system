`timescale 1ns / 1ps

module tb_ascii_sender ();

    reg clk, rst, i_send, tx_fifo_full;
    reg [23:0] in_data;
    wire tx_start;
    wire o_ascii;



    ascii_sender_top dut (
        .clk         (clk),
        .rst         (rst),
        .i_send      (),
        .in_data     (),
        .tx_fifo_full(),
        .tx_start    (),
        .o_ascii     ()
    );

endmodule
