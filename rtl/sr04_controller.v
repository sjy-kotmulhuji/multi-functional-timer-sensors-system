`timescale 1ns / 1ps

module sr04_controller (
    input clk,
    input rst,
    input i_start_btn,  //tick으로 받아오고 내부에서 계산
    input i_echo_sig,  //high 유지 시간으로 거리 계산
    output o_trig_sig,
    output [31:0] o_distance  //최대 400cm
);

    wire tick_1us;

    tick_gen_1us U_TICK_1us (
        .clk       (clk),
        .rst       (rst),
        .o_tick_1us(tick_1us)
    );

    parameter MAX = 400 * 58;  //최대 감지 가능 거리
    parameter IDLE = 2'b00, START = 2'b01, WAIT = 2'b10, DISTANCE = 2'b11;
    reg [1:0] c_state, n_state;
    reg trig_sig_reg, trig_sig_next;
    reg [3:0]
        trig_cnt_reg,
        trig_cnt_next;  //시작 신호 10us 이상 끌기 위한 cnt
    reg [8:0] distance_reg, distance_next;  //거리. bit 수 미정
    reg [$clog2(MAX) - 1:0]
        distance_cnt_reg,
        distance_cnt_next;  //trigger와 echo 사이 구간을 재기 위해

    assign o_distance = {23'd0, distance_reg};
    assign o_trig_sig = trig_sig_reg;

    //State Register SL
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state          <= IDLE;
            trig_sig_reg     <= 0;
            trig_cnt_reg     <= 0;
            distance_reg     <= 0;
            distance_cnt_reg <= 0;
        end else begin
            c_state          <= n_state;
            trig_sig_reg     <= trig_sig_next;
            trig_cnt_reg     <= trig_cnt_next;
            distance_reg     <= distance_next;
            distance_cnt_reg <= distance_cnt_next;
        end
    end

    //Next State CL
    always @(*) begin
        n_state           = c_state;
        trig_sig_next     = trig_sig_reg;
        trig_cnt_next     = trig_cnt_reg;
        distance_next     = distance_reg;
        distance_cnt_next = distance_cnt_reg;
        case (c_state)
            IDLE: begin
                if (i_start_btn) begin  //천이 조건: start tick == 1
                    trig_sig_next = 1;
                    n_state       = START;
                end
            end
            START: begin
                distance_next     = 0;  //거리 초기화 여기서 하는 거 맞나
                distance_cnt_next = 0;
                if (tick_1us) begin
                    if(trig_cnt_reg == 11) begin      //천이 조건: start 신호 11us 이상
                        trig_cnt_next = 0;
                        n_state       = WAIT;
                        trig_sig_next = 0;  //11us 동안 start trigger 유지

                    end else begin
                        trig_cnt_next = trig_cnt_reg + 1;
                    end
                end
            end
            WAIT: begin
                if (i_echo_sig == 1) begin
                    n_state = DISTANCE;
                end
            end
            DISTANCE: begin
                if (tick_1us) begin
                    if (i_echo_sig == 1) begin
                        distance_cnt_next = distance_cnt_reg + 1;
                    end else begin
                        distance_next = distance_cnt_reg / 58;  //거리 계산
                        n_state       = IDLE;
                    end
                end
            end


        endcase
    end

endmodule

module tick_gen_1us (
    input      clk,
    input      rst,
    output reg o_tick_1us
);

    parameter F_COUNT = 100_000_000 / 100_000_0;

    reg [$clog2(F_COUNT) - 1:0] r_counter;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            r_counter  <= 0;
            o_tick_1us <= 0;
        end else begin
            r_counter <= r_counter + 1;
            if (r_counter == F_COUNT - 1) begin
                r_counter  <= 0;
                o_tick_1us <= 1;
            end else begin
                o_tick_1us <= 0;
            end
        end
    end



endmodule
