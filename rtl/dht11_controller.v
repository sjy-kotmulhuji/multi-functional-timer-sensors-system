`timescale 1ns / 1ps

/*
module dht11_top (
    input        clk,
    input        rst,
    input        i_ctrl_start,
    input        sw,
    output [3:0] fnd_digit,
    output [7:0] fnd_data,
    inout        dhtio
);

    wire w_tick_10us, w_i_ctrl_start;
    wire [15:0] w_humidity, w_temperature;
    wire [2:0] w_debug;

    dht11_controller U_DHT11_CNTL (
        .clk        (clk),
        .rst        (rst),
        .i_tick_10us(w_tick_10us),
        .i_ctrl_start      (w_i_ctrl_start),
        .humidity   (w_humidity),
        .temperature(w_temperature),
        .dht11_done (),
        .dht11_valid(),
        .debug      (w_debug),
        .checksum   (),
        .dhtio      (dhtio)
    );

    btn_debounce U_BTN_DEBOUNCE (
        .clk  (clk),
        .reset(rst),
        .i_btn(i_ctrl_start),
        .o_btn(w_i_ctrl_start)
    );


    fnd_controller U_FND_CNTL (
        .clk           (clk),
        .reset         (rst),
        .sw            (sw),
        .in_humidity   (w_humidity),
        .in_temperature(w_temperature),
        .fnd_digit     (fnd_digit),
        .fnd_data      (fnd_data)
    );

    tick_gen_10us U_TICK_10us (
        .clk      (clk),
        .rst      (rst),
        .tick_10us(w_tick_10us)
    );

    //   ila_0 U_ILA0 (
    //       .clk   (clk),
    //       .probe0(dhtio),
    //       .probe1(w_debug)
    //   );

endmodule

*/


   // output [15:0] humidity,
   // output [15:0] temperature,

module humi_temp_datapath (
    input         clk,
    input         rst,
    input         i_ctrl_start,
    output [31:0] o_data,
    output        dht11_done,
    output        dht11_valid,  //checksum이 맞는지 확인하는 신호
    output [ 2:0] debug,
    output [ 7:0] checksum,
    inout         io_dhtio
);

    wire w_tick_10us;

    tick_gen_10us U_TICK_10us (
        .clk      (clk),
        .rst      (rst),
        .tick_10us(w_tick_10us)
    );


    parameter IDLE = 0, START = 1, WAIT = 2, SYNC_L = 3, SYNC_H = 4, DATA_SYNC = 5, DATA_C = 6, STOP = 7;
    reg [2:0] c_state, n_state;
    reg dhtio_reg, dhtio_next;
    reg io_sel_reg, io_sel_next;
    reg [$clog2(1900)-1:0]
        tick_cnt_reg, tick_cnt_next;  //i_ctrl_start에서 dhtio 0 신호 19ms 유지
    reg [39:0]
        data_buf_reg, data_buf_next;  //입력 데이터 40bit 저장 버퍼
    reg [$clog2(40)-1:0] bit_cnt_reg, bit_cnt_next;  //40bit count
    reg [15:0] humidity_reg, humidity_next;
    reg [15:0] temperature_reg, temperature_next;
    reg valid_reg, valid_next;
    reg done_reg, done_next;
    wire sync_dhtio;


    assign io_dhtio = (io_sel_reg) ? dhtio_reg : 1'bz;      //wire 연결 끊고 연결할 때
    assign debug = c_state;  //디버깅용
    assign o_data = {humidity_reg[15:0], temperature_reg[15:0]};    //습도 정수, 실수, 온도 정수, 실수
    assign dht11_valid = valid_reg;
    assign dht11_done = done_reg;
    assign checksum = data_buf_reg[39:32] + data_buf_reg[31:24] + data_buf_reg[23:16] + data_buf_reg[15:8];

    synchronizer U_SYNCHRONIZER (
        .clk(clk),
        .d  (io_dhtio),
        .q  (sync_dhtio)
    );

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state         <= 0;
            dhtio_reg       <= 1'b1;
            tick_cnt_reg    <= 1;
            io_sel_reg      <= 1;
            data_buf_reg    <= 0;
            bit_cnt_reg     <= 39;  //MSB First
            humidity_reg    <= 0;
            temperature_reg <= 0;
            valid_reg       <= 0;
            done_reg        <= 0;
        end else begin
            c_state         <= n_state;
            dhtio_reg       <= dhtio_next;
            tick_cnt_reg    <= tick_cnt_next;
            humidity_reg    <= humidity_next;
            temperature_reg <= temperature_next;
            io_sel_reg      <= io_sel_next;
            data_buf_reg    <= data_buf_next;
            bit_cnt_reg     <= bit_cnt_next;
            valid_reg       <= valid_next;
            done_reg        <= done_next;
        end
    end

    //Next State
    always @(*) begin
        n_state          = c_state;
        tick_cnt_next    = tick_cnt_reg;
        dhtio_next       = dhtio_reg;
        io_sel_next      = io_sel_reg;
        bit_cnt_next     = bit_cnt_reg;
        data_buf_next    = data_buf_reg;
        humidity_next    = humidity_reg;
        temperature_next = temperature_reg;
        valid_next       = valid_reg;
        done_next        = done_reg;
        case (c_state)
            IDLE: begin
                valid_next = 0;
                done_next = 0;
                data_buf_next = 0;
                if (i_ctrl_start) n_state = START;
            end
            START: begin
                dhtio_next = 0;
                if (w_tick_10us) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (tick_cnt_reg == 1900 - 1) begin
                        n_state = WAIT;
                        tick_cnt_next = 0;
                    end
                end
            end
            WAIT: begin
                dhtio_next = 1'b1;
                if (w_tick_10us) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (tick_cnt_reg == 3) begin  //io_sel 바꿈. 30us는 끌어줘야 안정적
                        tick_cnt_next = 0;
                        n_state = SYNC_L;
                        io_sel_next = 0;
                    end
                end
            end
            SYNC_L: begin
                if(w_tick_10us) begin     //기존 클락말고 10us tick 사용으로 노이즈 줄임(샘플링 주기가 길어지므로)
                    if (sync_dhtio == 1) n_state = SYNC_H;
                end
            end
            SYNC_H: begin
                if (w_tick_10us) begin
                    if (sync_dhtio == 0) n_state = DATA_SYNC;
                end
            end
            DATA_SYNC: begin
                if (w_tick_10us) begin
                    if (sync_dhtio) begin
                        n_state = DATA_C;
                    end
                end
            end
            DATA_C: begin
                if (w_tick_10us) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (sync_dhtio == 0) begin
                        if ((tick_cnt_reg >= 2) & (tick_cnt_reg <= 3)) begin
                            data_buf_next[bit_cnt_reg] = 1'b0;
                        end else if (tick_cnt_reg >= 7) begin
                            data_buf_next[bit_cnt_reg] = 1'b1;
                        end
                        tick_cnt_next = 1;
                        n_state = DATA_SYNC;
                        if (bit_cnt_reg == 0) begin
                            bit_cnt_next = 39;
                            n_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg - 1;
                        end
                    end
                end
            end
            STOP: begin
                humidity_next = data_buf_reg[39:24];
                temperature_next = data_buf_reg[23:8];
                done_next = 1;

                if (w_tick_10us) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    //checksum
                    if(data_buf_reg[7:0] == (data_buf_reg[39:32] + data_buf_reg[31:24] + data_buf_reg[23:16] + data_buf_reg[15:8])) begin
                        valid_next = 1'b1;
                    end
                    if (tick_cnt_reg == 5) begin  //output mode
                        dhtio_next  = 1;
                        io_sel_next = 1;
                        n_state     = IDLE;
                    end
                end
            end
        endcase
    end

endmodule

module tick_gen_10us (
    input      clk,
    input      rst,
    output reg tick_10us
);
    parameter F_COUNT = 100_000_000 / 100_000;
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            tick_10us   <= 0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                tick_10us   <= 1'b1;
            end else begin
                tick_10us <= 1'b0;
            end
        end
    end

endmodule
