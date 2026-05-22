`timescale 1ns / 1ps

module top_control_unit (  //top_stopwatch_watch
    input clk,
    input reset,
    input [3:0] sw,  //3: (s.ms/humid), (h.m/temp)  2: watch/sensor, 1: (watch/sw), (sr04/dht11) select, 0: sw mode(up/down)
    input btn_r,  //run_stop
    input btn_l,  //clear
    input btn_u,  //watch up
    input btn_d,  //watch down
    input uart_rx,
    input i_echo_sig,
    output uart_tx,
    output o_trig_sig,
    output dht11_valid,
    output [3:0] fnd_digit,
    output [7:0] fnd_data,

    inout io_dhtio
);

    wire w_mode, w_run_stop, w_clear, w_up, w_down;
    wire o_btn_run_stop, o_btn_clear, o_btn_up, o_btn_down;
    wire r_key, l_key, u_key, d_key;
    wire [23:0] w_stopwatch_time, w_watch_time;
    wire [31:0] w_distance;
    wire [31:0] w_humid_temp_data;
    wire [31:0] w_mux_w_sw_sel;

    humi_temp_datapath U_DHT11 (
        .clk         (clk),
        .rst         (reset),
        .i_ctrl_start(o_btn_run_stop),     //btn right
        .o_data      (w_humid_temp_data),
        .dht11_done  (),
        .dht11_valid (dht11_valid),
        .debug       (),
        .checksum    (),
        .io_dhtio    (io_dhtio)
    );

    sr04_controller U_SR04 (
        .clk        (clk),
        .rst        (reset),
        .i_start_btn(o_btn_down),
        .i_echo_sig (i_echo_sig),
        .o_trig_sig (o_trig_sig),
        .o_distance (w_distance)
    );

    uart_top U_UART_TOP (
        .clk    (clk),
        .rst    (reset),
        .sw     (sw[2:1]),
        .in_data(w_mux_w_sw_sel),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .o_r    (r_key),
        .o_l    (l_key),
        .o_u    (u_key),
        .o_d    (d_key)
    );

    btn_debounce U_BD_UP (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_u),
        .o_btn(o_btn_up)
    );

    btn_debounce U_BD_DOWN (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_d),
        .o_btn(o_btn_down)
    );

    watch_control_unit U_W_CONTROL_UNIT (
        .clk     (clk),
        .reset   (reset),
        .sw_1    (sw[1]),
        .i_up    (o_btn_up),
        .i_down  (o_btn_down),
        .i_up_key(u_key),
        .i_dw_key(d_key),
        .o_up    (w_up),
        .o_down  (w_down)
    );

    watch_datapath U_WATCH_PATH (
        .clk    (clk),
        .reset  (reset),
        .left   (o_btn_clear),
        .right  (o_btn_run_stop),
        .up     (w_up),
        .down   (w_down),
        .sw_3   (sw[3]),
        .i_l_key(l_key),
        .i_r_key(r_key),
        .msec   (w_watch_time[6:0]),
        .sec    (w_watch_time[12:7]),
        .min    (w_watch_time[18:13]),
        .hour   (w_watch_time[23:19])
    );

    btn_debounce U_BD_RUNSTOP (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_r),
        .o_btn(o_btn_run_stop)
    );

    btn_debounce U_BD_CLEAR (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn_l),
        .o_btn(o_btn_clear)
    );

    stopwatch_control_unit U_SW_CONTROL_UNIT (
        .clk       (clk),
        .reset     (reset),
        .sw_1      (sw[1]),
        .i_mode    (sw[0]),
        .i_run_stop(o_btn_run_stop),
        .i_clear   (o_btn_clear),
        .i_rs_key  (r_key),
        .i_cl_key  (l_key),
        .o_mode    (w_mode),
        .o_run_stop(w_run_stop),
        .o_clear   (w_clear)
    );

    stopwatch_datapath U_STOPWATCH_PATH (
        .clk     (clk),
        .reset   (reset),
        .mode    (w_mode),
        .clear   (w_clear),
        .run_stop(w_run_stop),
        .msec    (w_stopwatch_time[6:0]),
        .sec     (w_stopwatch_time[12:7]),
        .min     (w_stopwatch_time[18:13]),
        .hour    (w_stopwatch_time[23:19])
    );


    mux_2x1_w_sw_sel U_Mux_W_SW_SEL (       //스탑워치, 워치, 거리, 온습도 중 출력할 값 스위치로 결정
        .stopwatch_time({8'b0, w_stopwatch_time}),
        .watch_time    ({8'b0, w_watch_time}),
        .dist_sr04     ({w_distance}),
        .dht11_data    (w_humid_temp_data),
        .sel           (sw[2:1]),
        .o_data        (w_mux_w_sw_sel)
    );  //00: watch, 01: stopwatch, 10: sr04, 11: DH

    fnd_controller U_FND_CNTL (
        .clk        (clk),
        .reset      (reset),
        .sel_display(sw[3:1]),
        .fnd_in_data(w_mux_w_sw_sel),
        .fnd_digit  (fnd_digit),
        .fnd_data   (fnd_data)
    );

endmodule

module mux_2x1_w_sw_sel (
    input      [31:0] stopwatch_time,
    input      [31:0] watch_time,
    input      [31:0] dist_sr04,
    input      [31:0] dht11_data,
    input      [ 1:0] sel,
    output reg [31:0] o_data
);

    always @(*) begin
        case (sel)
            2'b00: o_data = watch_time;
            2'b01: o_data = stopwatch_time;
            2'b10: o_data = dist_sr04;
            2'b11: o_data = dht11_data;
        endcase
    end

endmodule

module watch_datapath (
    input        clk,
    input        reset,
    input        left,
    input        right,
    input        up,
    input        down,
    input        sw_3,
    input        i_l_key,
    input        i_r_key,
    output [6:0] msec,
    output [5:0] sec,
    output [5:0] min,
    output [4:0] hour

);
    wire w_tick_100hz, w_tick_sec, w_tick_min, w_tick_hour, w_sel_mod_btn;

    watch_tick_counter #(  //시계 시간 조정
        .BIT_WIDTH(5),
        .TIMES   (24)
    ) hour_counter (  //tick counter(msec, sec, min, hour) 
        .clk         (clk),
        .reset       (reset),
        .i_tick      (w_tick_hour),
        .hour_rst    (1'b1),
        .sel_mod_btn (w_sel_mod_btn),
        .i_sel_modify(1'b1),
        .sw_3        (sw_3),
        .sw_hm_sm    (1'b1),
        .up          (up),
        .down        (down),
        .o_count     (hour),
        .o_tick      ()
    );

    watch_tick_counter #(  //시계 시간 조정
        .BIT_WIDTH(6),
        .TIMES    (60)
    ) min_counter (  //tick counter(msec, sec, min, hour) 
        .clk         (clk),
        .reset       (reset),
        .i_tick      (w_tick_min),
        .hour_rst    (1'b0),
        .sel_mod_btn (w_sel_mod_btn),
        .i_sel_modify(1'b0),
        .sw_3        (sw_3),
        .sw_hm_sm    (1'b1),
        .up          (up),
        .down        (down),
        .o_count     (min),
        .o_tick      (w_tick_hour)
    );

    watch_tick_counter #(  //시계 시간 조정
        .BIT_WIDTH(6),
        .TIMES    (60)
    ) sec_counter (  //tick counter(msec, sec, min, hour) 
        .clk         (clk),
        .reset       (reset),
        .i_tick      (w_tick_sec),
        .hour_rst    (1'b0),
        .sel_mod_btn (w_sel_mod_btn),
        .i_sel_modify(1'b1),
        .sw_3        (sw_3),
        .sw_hm_sm    (1'b0),
        .up          (up),
        .down        (down),
        .o_count     (sec),
        .o_tick      (w_tick_min)
    );

    watch_tick_counter #(  //시계 시간 조정
        .BIT_WIDTH(7),
        .TIMES    (100)
    ) msec_counter (  //tick counter(msec, sec, min, hour) 
        .clk         (clk),
        .reset       (reset),
        .i_tick      (w_tick_100hz),
        .hour_rst    (1'b0),
        .sel_mod_btn (w_sel_mod_btn),
        .i_sel_modify(1'b0),
        .sw_3        (sw_3),
        .sw_hm_sm    (1'b0),
        .up          (up),
        .down        (down),
        .o_count     (msec),
        .o_tick      (w_tick_sec)
    );

    watch_modify_sel U_WATCH_MODIFY (  //좌우버튼 1:hour/sec, 0: min/msec
        .clk        (clk),
        .reset      (reset),
        .i_btn_l    (left),
        .i_btn_r    (right),
        .i_l_key    (i_l_key),
        .i_r_key    (i_r_key),
        .sel_mod_btn(w_sel_mod_btn)
    );

    tick_gen_100hz U_TICK_GEN (
        .clk         (clk),
        .reset       (reset),
        .run_stop_sw (1'b1),
        .o_tick_100hz(w_tick_100hz)
    );

endmodule


module watch_tick_counter #(  //시계 시간 조정
    parameter BIT_WIDTH = 7,
    TIMES = 100
) (  //tick counter(msec, sec, min, hour) 
    input                      clk,
    input                      reset,
    input                      i_tick,
    input                      hour_rst,
    input                      sel_mod_btn,
    input                      i_sel_modify,
    input                      sw_3,
    input                      sw_hm_sm,
    input                      up,
    input                      down,
    output     [BIT_WIDTH-1:0] o_count,
    output reg                 o_tick
);
    reg [BIT_WIDTH-1:0] counter_reg, counter_next;

    assign o_count = counter_reg;

    //State reg SL
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= (hour_rst) ? 12 : 0;
        end else begin
            if (up) begin
                if ((i_sel_modify == sel_mod_btn) && (sw_hm_sm == sw_3)) begin
                    counter_reg <= (counter_next == (TIMES-1)) ? 0 : counter_next + 1;
                end
            end else if (down) begin
                if ((i_sel_modify == sel_mod_btn) && (sw_hm_sm == sw_3)) begin
                    counter_reg <= (counter_next == 0) ? (TIMES-1) : counter_next - 1;
                end
            end else begin
                counter_reg <= counter_next;
            end
        end
    end

    always @(*) begin
        counter_next = counter_reg;
        o_tick       = 1'b0;
        if (i_tick) begin
            if (counter_reg == (TIMES - 1)) begin
                o_tick       = 1'b1;
                counter_next = 0;
            end else begin
                o_tick       = 1'b0;
                counter_next = counter_reg + 1;
            end
        end
    end

    /*  always @(*) begin
        if(up) begin
            up_down_reg = 1;
        end else if(down) begin
            up_down_reg = 
        end
    end
 */
    //Output CL
    /*      always @(*) begin  //up: +1, down: -1
        o_count = counter_reg;
        if (up) begin
            o_count = counter_reg + 1'b1;
        end else if (down) begin
            o_count = counter_reg - 1'b1;
        end
    end
    */
endmodule

module stopwatch_datapath (
    input        clk,
    input        reset,
    input        mode,
    input        clear,
    input        run_stop,
    output [6:0] msec,
    output [5:0] sec,
    output [5:0] min,
    output [4:0] hour

);
    wire w_tick_100hz, w_sec_tick, w_min_tick, w_hour_tick;

    sw_tick_counter #(
        .BIT_WIDTH(5),
        .TIMES    (24)
    ) hour_counter (
        .clk     (clk),
        .reset   (reset),
        .i_tick  (w_hour_tick),
        .mode    (mode),
        .clear   (clear),
        .run_stop(run_stop),
        .o_count (hour),         //wire로 선언 후 
        .o_tick  ()
    );

    sw_tick_counter #(
        .BIT_WIDTH(6),
        .TIMES    (60)
    ) min_counter (
        .clk     (clk),
        .reset   (reset),
        .i_tick  (w_min_tick),
        .mode    (mode),
        .clear   (clear),
        .run_stop(run_stop),
        .o_count (min),
        .o_tick  (w_hour_tick)
    );

    sw_tick_counter #(
        .BIT_WIDTH(6),
        .TIMES    (60)
    ) sec_counter (
        .clk     (clk),
        .reset   (reset),
        .i_tick  (w_sec_tick),
        .mode    (mode),
        .clear   (clear),
        .run_stop(run_stop),
        .o_count (sec),
        .o_tick  (w_min_tick)
    );

    sw_tick_counter #(
        .BIT_WIDTH(7),
        .TIMES    (100)
    ) msec_counter (
        .clk     (clk),
        .reset   (reset),
        .i_tick  (w_tick_100hz),
        .mode    (mode),
        .clear   (clear),
        .run_stop(run_stop),
        .o_count (msec),
        .o_tick  (w_sec_tick)
    );

    tick_gen_100hz U_TICK_GEN (
        .clk         (clk),
        .reset       (reset),
        .run_stop_sw (run_stop),
        .o_tick_100hz(w_tick_100hz)
    );

endmodule

module sw_tick_counter #(  //시간 조정
    parameter BIT_WIDTH = 7,
    TIMES = 100
) (  //tick counter(msec, sec, min, hour) 
    input                      clk,
    input                      reset,
    input                      i_tick,
    input                      mode,
    input                      clear,
    input                      run_stop,
    output     [BIT_WIDTH-1:0] o_count,
    output reg                 o_tick
);
    //Counter reg
    reg [BIT_WIDTH-1:0] counter_reg, counter_next;

    assign o_count = counter_reg;  //시간값

    //State reg SL
    always @(posedge clk, posedge reset) begin
        if (reset | clear) begin
            counter_reg <= 0;
        end else begin
            counter_reg <= counter_next;
        end
    end

    always @(*) begin
        counter_next = counter_reg;
        o_tick = 1'b0;
        if(i_tick && run_stop) begin                //o_tick은 reg이므로 latch 방지 위해 기본값.
            if (mode == 1'b1) begin  //down mode
                if (counter_reg == 0) begin
                    o_tick       = 1'b1;
                    counter_next = TIMES - 1;  //0 -> 99로 돌아감
                end else begin
                    counter_next = counter_reg - 1;
                    o_tick       = 1'b0;
                end
            end else begin  //up mode
                if (counter_reg == (TIMES - 1)) begin
                    o_tick       = 1'b1;
                    counter_next = 0;
                end else begin
                    counter_next = counter_reg + 1;
                    o_tick       = 1'b0;
                end
            end
        end
    end

endmodule

module tick_gen_100hz (  //10ms
    input      clk,
    input      reset,
    input      run_stop_sw,
    output reg o_tick_100hz
);
    parameter F_COUNT = 100_000_000 / 100;  //
    reg [$clog2(F_COUNT)-1:0] r_counter;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_counter    <= 0;
            o_tick_100hz <= 0;
        end else begin
            if (run_stop_sw) begin
                r_counter <= r_counter + 1;

                if (r_counter == (F_COUNT - 1)) begin
                    r_counter    <= 0;
                    o_tick_100hz <= 1;
                end else begin
                    o_tick_100hz <= 0;
                end
            end else begin
                o_tick_100hz <= 0;
            end
        end
    end

endmodule
