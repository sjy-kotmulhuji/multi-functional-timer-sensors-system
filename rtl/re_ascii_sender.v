`timescale 1ns / 1ps

module ascii_sender (
    input         clk,
    input         rst,
    //i_send : pc에서 "S"를 send하면 tick으로 입력. ASCii Decoder에서 입력
    input         i_send,
    //i_sw : stopwatch, watch, sensor 모드 구분. 스위치값 입력
    input  [ 1:0] i_sw,
    //in_data : fnd로 들어가는 데이터 받아옴
    input  [31:0] in_data,
    //tx_fifo_full : fifo full 반전시킨 값이 sender->tx
    input         tx_fifo_full,
    //tx_start : fifo_tx_push 신호
    output reg  tx_start,
    //8bit 데이터 하나씩 출력 
    output reg [ 7:0] o_ascii
);
    //Input Data Digit Split
    //sw, w time data
    wire [7:0] hour_10, hour_1, min_10, min_1, sec_10, sec_1, msec_10, msec_1;
    //distance data
    wire [7:0] dist_1000, dist_100, dist_10, dist_1;
    //humid, temp data
    wire [7:0] humid_int_10, humid_int_1, humid_dec_10, temp_int_10, temp_int_1, temp_dec_10;

    //Output ASCii Data
    wire[7:0] a_hour_10, a_hour_1, a_min_10, a_min_1, a_sec_10, a_sec_1, a_msec_10, a_msec_1;
    wire [7:0] a_dist_1000, a_dist_100, a_dist_10, a_dist_1;
    wire [7:0] a_humid_int_10, a_humid_int_1, a_humid_dec_10, a_temp_int_10, a_temp_int_1, a_temp_dec_10;

    bcd_sender U_BCD_SENDER_HOUR_10 (
        .bcd_sender(hour_10),
        .send_data(a_hour_10)
    );
    bcd_sender U_BCD_SENDER_HOUR_1 (
        .bcd_sender(hour_1),
        .send_data(a_hour_1)
    );
    bcd_sender U_BCD_SENDER_MIN_10 (
        .bcd_sender(min_10),
        .send_data(a_min_10)
    );
    bcd_sender U_BCD_SENDER_MIN_1 (
        .bcd_sender(min_1),
        .send_data(a_min_1)
    );
    bcd_sender U_BCD_SENDER_SEC_10 (
        .bcd_sender(sec_10),
        .send_data(a_sec_10)
    );
    bcd_sender U_BCD_SENDER_SEC_1 (
        .bcd_sender(sec_1),
        .send_data(a_sec_1)
    );
    bcd_sender U_BCD_SENDER_MSEC_10 (
        .bcd_sender(msec_10),
        .send_data(a_msec_10)
    );
    bcd_sender U_BCD_SENDER_MSEC_1 (
        .bcd_sender(msec_1),
        .send_data(a_msec_1)
    );
    bcd_sender U_BCD_SENDER_DIST_1000 (
        .bcd_sender(dist_1000),
        .send_data(a_dist_1000)
    );
    bcd_sender U_BCD_SENDER_DIST_100 (
        .bcd_sender(dist_100),
        .send_data(a_dist_100)
    );
    bcd_sender U_BCD_SENDER_DIST_10 (
        .bcd_sender(dist_10),
        .send_data(a_dist_10)
    );
    bcd_sender U_BCD_SENDER_DIST_1 (
        .bcd_sender(dist_1),
        .send_data(a_dist_1)
    );
    bcd_sender U_BCD_SENDER_HUMID_I_10 (
        .bcd_sender(humid_int_10),
        .send_data(a_humid_int_10)
    );
    bcd_sender U_BCD_SENDER_HUMID_I_1 (
        .bcd_sender(humid_int_1),
        .send_data(a_humid_int_1)
    );
    bcd_sender U_BCD_SENDER_HUMID_D_10 (
        .bcd_sender (humid_dec_10),
        .send_data(a_humid_dec_10)
    );
    bcd_sender U_BCD_SENDER_TEMP_I_10 (
        .bcd_sender (temp_int_10),
        .send_data(a_temp_int_10)
    );
    bcd_sender U_BCD_SENDER_TEMP_I_1 (
        .bcd_sender (temp_int_1),
        .send_data(a_temp_int_1)
    );
    bcd_sender U_BCD_SENDER_TEMP_D_10 (
        .bcd_sender (temp_dec_10),
        .send_data(a_temp_dec_10)
    );

    assign hour_10 = (in_data[23:19] / 10) % 10;
    assign hour_1  = in_data[23:19] % 10;
    assign min_10  = (in_data[18:13] / 10) % 10;
    assign min_1   = in_data[18:13] % 10;
    assign sec_10  = (in_data[12:7] / 10) % 10;
    assign sec_1   = in_data[12:7] % 10;
    assign msec_10 = (in_data[6:0] / 10) % 1;
    assign msec_1  = in_data[6:0] % 10;

    assign dist_1000 = (in_data[8:0] / 1000) % 10;
    assign dist_100 = (in_data[8:0] / 100) % 10;
    assign dist_10 = (in_data[8:0] / 10) % 10;
    assign dist_1 = in_data[8:0] % 10;

    assign humid_int_10 = (in_data[31:24] / 10) % 10;
    assign humid_int_1 = in_data[31:24] % 10;
    assign humid_dec_10 = (in_data[23:16] / 10) % 10;

    assign temp_int_10 = (in_data[15:8] / 10) % 10;
    assign temp_int_1 =   in_data[15:8] % 10;
    assign temp_dec_10 = (in_data[7:0] / 10) % 10;


    parameter IDLE = 2'd0, SEND = 2'd1, WAIT = 2'd2;

    reg [1:0] c_state, n_state;
    reg [3:0] send_cnt_reg, send_cnt_next;

    //State Register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            send_cnt_reg <= 4'd0;
        end else begin
            c_state <= n_state;
            send_cnt_reg <= send_cnt_next;
        end
    end


    //Next State, Output CL
    always @(*) begin
        n_state = c_state;
        send_cnt_next = send_cnt_reg;
        tx_start = 0;
        o_ascii = 8'd0;

        case (c_state)
            IDLE: begin
                if(i_send && ~tx_fifo_full) begin   //send 키 입력 & fifo full 아닐 때 동작 시작
                    n_state = SEND;
                end
            end
            SEND: begin
                tx_start = 1;
                case (send_cnt_reg)
                    4'd0: begin
                        if (tx_fifo_full) begin
                            n_state = WAIT;
                        end else begin
                            case (i_sw)
                                2'b00: o_ascii = 8'h20;
                                2'b01: o_ascii = 8'h20;
                                2'b10: o_ascii = 8'h44;
                                2'b11: o_ascii = 8'h48;
                            endcase
                        end
                    end
                    4'd1: begin
                        if (tx_fifo_full) begin
                            n_state = WAIT;
                        end else begin
                            case (i_sw)
                                2'b00: o_ascii = 8'h20;
                                2'b01: o_ascii = 8'h53;
                                2'b10: o_ascii = 8'h49;
                                2'b11: o_ascii = 8'h2F;
                            endcase
                        end
                    end
                    4'd2: begin
                        if (tx_fifo_full) begin
                            n_state = WAIT;
                        end else begin
                            case (i_sw)
                                2'b00: o_ascii = 8'h57;
                                2'b01: o_ascii = 8'h57;
                                2'b10: o_ascii = 8'h53;
                                2'b11: o_ascii = 8'h54;
                            endcase
                        end
                    end
                    4'd3: begin
                        if (tx_fifo_full) begin
                            n_state = WAIT;
                        end else begin
                            case (i_sw)
                                2'b00: o_ascii = 8'h3D;
                                2'b01: o_ascii = 8'h3D;
                                2'b10: o_ascii = 8'h3D;
                                2'b11: o_ascii = 8'h3D;
                            endcase
                        end
                    end
                    4'd4: begin
                        if (tx_fifo_full) begin
                            n_state = WAIT;
                        end else begin
                            case (i_sw)
                                2'b00: o_ascii = a_hour_10;
                                2'b01: o_ascii = a_hour_10;
                                2'b10: o_ascii = 8'h20;
                                2'b11: o_ascii = 8'h20;
                            endcase
                        end
                    end
                    4'd5: begin
                        if (tx_fifo_full) begin
                            n_state = WAIT;
                        end else begin
                            case (i_sw)
                                2'b00: o_ascii = a_hour_1;
                                2'b01: o_ascii = a_hour_1;
                                2'b10: o_ascii = a_dist_1000;
                                2'b11: o_ascii = a_humid_int_10;
                            endcase
                        end
                    end
                    4'd6: begin
                        if (tx_fifo_full) begin
                            n_state = WAIT;
                        end else begin
                            case (i_sw)
                                2'b00: o_ascii = 8'h3A;
                                2'b01: o_ascii = 8'h3A;
                                2'b10: o_ascii = a_dist_100;
                                2'b11: o_ascii = a_humid_int_1;
                            endcase
                        end
                    end
                    4'd7: begin
                        if (tx_fifo_full) begin
                            n_state = WAIT;
                        end else begin
                            case (i_sw)
                                2'b00: o_ascii = a_min_10;
                                2'b01: o_ascii = a_min_10;
                                2'b10: o_ascii = a_dist_10;
                                2'b11: o_ascii = 8'h2E;
                            endcase
                        end
                    end
                    4'd8: begin
                        if (tx_fifo_full) begin
                            n_state = WAIT;
                        end else begin
                            case (i_sw)
                                2'b00: o_ascii = a_min_1;
                                2'b01: o_ascii = a_min_1;
                                2'b10: o_ascii = a_dist_1;
                                2'b11: o_ascii = a_humid_dec_10;
                            endcase
                        end
                    end
                    4'd9: begin
                        if (tx_fifo_full) begin
                            n_state = WAIT;
                        end else begin
                            case (i_sw)
                                2'b00: o_ascii = 8'h3A;
                                2'b01: o_ascii = 8'h3A;
                                2'b10: o_ascii = 8'h63;
                                2'b11: o_ascii = 8'h2F;
                            endcase
                        end
                    end
                    4'd10: begin
                        if (tx_fifo_full) begin
                            n_state = WAIT;
                        end else begin
                            case (i_sw)
                                2'b00: o_ascii = a_sec_10;
                                2'b01: o_ascii = a_sec_10;
                                2'b10: o_ascii = 8'h6D;
                                2'b11: o_ascii = a_temp_int_10;
                            endcase
                        end
                    end
                    4'd11: begin
                        if (tx_fifo_full) begin
                            n_state = WAIT;
                        end else begin
                            case (i_sw)
                                2'b00: o_ascii = a_sec_1;
                                2'b01: o_ascii = a_sec_1;
                                2'b10: o_ascii = 8'h20;
                                2'b11: o_ascii = a_temp_int_1;
                            endcase
                        end
                    end
                    4'd12: begin
                        if (tx_fifo_full) begin
                            n_state = WAIT;
                        end else begin
                            case (i_sw)
                                2'b00: o_ascii = 8'h3A;
                                2'b01: o_ascii = 8'h3A;
                                2'b10: o_ascii = 8'h20;
                                2'b11: o_ascii = 8'h2E;
                            endcase
                        end
                    end
                    4'd13: begin
                        if (tx_fifo_full) begin
                            n_state = WAIT;
                        end else begin
                            case (i_sw)
                                2'b00: o_ascii = a_msec_10;
                                2'b01: o_ascii = a_msec_10;
                                2'b10: o_ascii = 8'h20;
                                2'b11: o_ascii = a_temp_dec_10;
                            endcase
                        end
                    end
                    4'd14: begin
                        if (tx_fifo_full) begin
                            n_state = WAIT;
                        end else begin
                            n_state = IDLE;
                            case (i_sw)
                                2'b00: o_ascii = a_msec_1;
                                2'b01: o_ascii = a_msec_1;
                                2'b10: o_ascii = 8'h20;
                                2'b11: o_ascii = 8'h20;
                            endcase
                        end
                    end
                    4'd15: begin
                        if (tx_fifo_full) begin
                            n_state = WAIT;
                        end else begin
                            n_state = IDLE;
                            case (i_sw)
                                2'b00: o_ascii = 8'h09;
                                2'b01: o_ascii = 8'h09;
                                2'b10: o_ascii = 8'h09;
                                2'b11: o_ascii = 8'h09;
                            endcase
                        end
                    end
                    default: n_state = IDLE;
                endcase
            end
            WAIT: begin
                if (!tx_fifo_full) begin
                    if (send_cnt_reg == 15) begin
                        send_cnt_next = 0;
                        n_state = IDLE;
                    end else begin
                        n_state = SEND;
                    end
                end
            end
        endcase
    end
endmodule

module bcd_sender (
    input [3:0] bcd_sender,
    output reg [7:0] send_data
);

    always @(bcd_sender) begin
        case (bcd_sender)
            4'd0: send_data = 8'h30;
            4'd1: send_data = 8'h31;
            4'd2: send_data = 8'h32;
            4'd3: send_data = 8'h33;
            4'd4: send_data = 8'h34;
            4'd5: send_data = 8'h35;
            4'd6: send_data = 8'h36;
            4'd7: send_data = 8'h37;
            4'd8: send_data = 8'h38;
            4'd9: send_data = 8'h39;
            default: send_data = 8'h20;
        endcase
    end

endmodule
