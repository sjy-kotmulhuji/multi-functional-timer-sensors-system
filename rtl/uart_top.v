`timescale 1ns / 1ps

module uart_top (
    input        clk,
    input        rst,
    input  [1:0] sw,
    input [31:0] in_data,
    input        uart_rx,
    output       uart_tx,
    output       o_r,
    output       o_l,
    output       o_u,
    output       o_d
);

    wire w_b_tick, w_rx_done, w_tx_start;
    wire [7:0] w_rx_data, w_rx_fifo_pop_data, w_tx_fifo_pop_data, w_o_ascii;
    wire w_tx_fifo_full, w_tx_fifo_empty, w_rx_fifo_empty, w_tx_busy;

    fifo U_FIFO_TX (
        .clk(clk),
        .rst(rst),
        .push(w_tx_start),  //sender에서 받아와야 하는데..
        .pop(~w_tx_busy),
        .push_data(w_o_ascii),  //sender 출력 데이터
        .pop_data(w_tx_fifo_pop_data),
        .full(w_tx_fifo_full),     //sender로 들어가야 함. 근데 무슨 용도로?
        .empty(w_tx_fifo_empty)
    );

    fifo U_FIFO_RX (
        .clk(clk),
        .rst(rst),
        .push(w_rx_done),
        .pop(1'b1),  //decoder에서 받아와야 하는데..딱히 조건이 없는데 그냥 1 줘도 되지 않을까?
        .push_data(w_rx_data),
        .pop_data(w_rx_fifo_pop_data),  //decoder 입력 데이터
        .full(),
        .empty(w_rx_fifo_empty)         //decoder로 들어가야 함. 근데 tick이 아닌데,,,
    );

    uart_tx U_UART_TX (
        .clk     (clk),
        .rst     (rst),
        .tx_start(~w_tx_fifo_empty),
        .b_tick  (w_b_tick),
        .tx_data (w_tx_fifo_pop_data),
        .tx_busy (w_tx_busy),
        .tx_done (),
        .uart_tx (uart_tx)
    );

    uart_rx U_UART_RX (
        .clk    (clk),
        .rst    (rst),
        .rx     (uart_rx),
        .b_tick (w_b_tick),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

    ascii_decoder U_ASCii_DEC (
        .clk    (clk),
        .rst    (rst),
        .i_ascii(w_rx_fifo_pop_data),
        .rx_done(~w_rx_fifo_empty),
        .o_r    (o_r),
        .o_l    (o_l),
        .o_u    (o_u),
        .o_d    (o_d),
        .o_s    (o_s)
    );

    ascii_sender U_ASCii_SENDER (
        .clk         (clk),
        .rst         (rst),
        .i_send      (o_s),
        .i_sw        (sw),
        .in_data     (in_data),
        .tx_fifo_full(w_tx_fifo_full),
        .tx_start    (w_tx_start),
        .o_ascii     (w_o_ascii)
    );

    baud_tick U_BAUD_TICK (
        .clk   (clk),
        .rst   (rst),
        .b_tick(w_b_tick)
    );

endmodule

module uart_rx (
    input        clk,
    input        rst,
    input        rx,
    input        b_tick,
    output [7:0] rx_data,
    output       rx_done
);

    localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;

    reg [1:0] c_state, n_state;
    reg [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    reg done_reg, done_next;
    reg [7:0] buf_reg, buf_next;

    assign rx_data = buf_reg;
    assign rx_done = done_reg;

    //State Register SL
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state        <= 2'd0;
            b_tick_cnt_reg <= 5'd0;
            bit_cnt_reg    <= 3'd0;
            done_reg       <= 1'b0;
            buf_reg        <= 8'd0;
        end else begin
            c_state        <= n_state;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            done_reg       <= done_next;
            buf_reg        <= buf_next;
        end
    end

    //Next, Output CL
    always @(*) begin
        n_state         = c_state;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        done_next       = done_reg;
        buf_next        = buf_reg;

        case (c_state)
            IDLE: begin
                bit_cnt_next    = 3'd0;
                done_next       = 1'b0;
                b_tick_cnt_next = 5'b0;

                if (b_tick & !rx) begin  //b_tick == 1 && rx == 0
                    buf_next = 8'd0;
                    n_state  = START;
                end
            end
            START: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 7) begin
                        b_tick_cnt_next = 5'd0;
                        // bit_cnt_next = bit_cnt_reg + 1;    
                        buf_next[7]     = rx;
                        n_state         = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 4'd15) begin
                        b_tick_cnt_next = 5'd0;
                        buf_next        = {rx, buf_reg[7:1]};
                        if (bit_cnt_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        n_state   = IDLE;
                        done_next = 1'b1;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end


        endcase

    end

endmodule

module uart_tx (
    input        clk,
    input        rst,
    input        tx_start,
    input        b_tick,
    input  [7:0] tx_data,
    output       tx_busy,
    output       tx_done,
    output       uart_tx
);

    localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;

    reg [3:0] c_state, n_state;
    reg tx_reg, tx_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    reg busy_reg, busy_next;
    reg done_reg, done_next;
    reg [7:0] data_in_buf_reg, data_in_buf_next;
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;

    assign uart_tx = tx_reg;
    assign tx_busy = busy_reg;
    assign tx_done = done_reg;

    //State Register SL
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state         <= IDLE;
            tx_reg          <= 1'b1;
            bit_cnt_reg     <= 0;
            busy_reg        <= 0;
            done_reg        <= 0;
            data_in_buf_reg <= 8'h00;
            b_tick_cnt_reg  <= 0;
        end else begin
            c_state         <= n_state;
            tx_reg          <= tx_next;
            bit_cnt_reg     <= bit_cnt_next;
            busy_reg        <= busy_next;
            done_reg        <= done_next;
            data_in_buf_reg <= data_in_buf_next;
            b_tick_cnt_reg  <= b_tick_cnt_next;
        end
    end

    //Next state, Output CL
    always @(*) begin
        n_state = c_state;
        tx_next = tx_reg;
        bit_cnt_next = bit_cnt_reg;
        busy_next = busy_reg;
        done_next = done_reg;
        data_in_buf_next = data_in_buf_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        case (c_state)
            IDLE: begin
                tx_next         = 1;
                bit_cnt_next    = 0;
                b_tick_cnt_next = 0;
                busy_next       = 0;
                done_next       = 0;
                if (tx_start) begin
                    n_state = START;
                    busy_next = 1;
                    data_in_buf_next = tx_data;
                end
            end
            START: begin
                tx_next = 0;  //to start uart frame of start bit
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        n_state = DATA;
                        b_tick_cnt_next = 4'h0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                tx_next = data_in_buf_reg[0];  //Shift Register
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        if (bit_cnt_reg == 7) begin
                            b_tick_cnt_next = 4'h0;
                            n_state         = STOP;
                        end else begin
                            b_tick_cnt_next  = 4'h0;
                            bit_cnt_next     = bit_cnt_reg + 1;
                            data_in_buf_next = {1'b0, data_in_buf_reg[7:1]};
                            n_state          = DATA;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                tx_next = 1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 4'h0;
                        n_state         = IDLE;
                        busy_next       = 0;
                        done_next       = 1;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule

module baud_tick (  //tick_cnt 0~15
    input      clk,
    input      rst,
    output reg b_tick
);
    parameter BAUD_RATE = 9600 * 16;
    parameter F_COUNT = 100_000_000 / BAUD_RATE;

    reg [$clog2(F_COUNT)-1 : 0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick      <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;

            if (counter_reg == F_COUNT - 1) begin
                b_tick      <= 1'b1;
                counter_reg <= 0;
            end else begin
                b_tick <= 1'b0;
            end
        end
    end

endmodule
