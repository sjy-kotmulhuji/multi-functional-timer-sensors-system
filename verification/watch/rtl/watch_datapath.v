module watch_datapath (
    input        clk,
    input        reset,
    input        left,
    input        right,
    input        up,
    input        down,
    input        sw_2,
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
        .sw_2        (sw_2),
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
        .sw_2        (sw_2),
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
        .sw_2        (sw_2),
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
        .sw_2        (sw_2),
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
    input                      sw_2,
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
                if ((i_sel_modify == sel_mod_btn) && (sw_hm_sm == sw_2)) begin  
                    counter_reg <= (counter_reg == (TIMES-1)) ? 0 : counter_reg + 1;
                end
            end else if (down) begin
                if ((i_sel_modify == sel_mod_btn) && (sw_hm_sm == sw_2)) begin
                    counter_reg <= (counter_reg == 0) ? (TIMES-1) : counter_reg - 1;
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

endmodule

module watch_modify_sel (  //좌우버튼 1:hour/sec, 0: min/msec
    input      clk,
    input      reset,
    input      i_btn_l,
    input      i_btn_r,
    output reg sel_mod_btn
);
    parameter LEFT = 1'b1, RIGHT = 1'b0;

    reg current_st, next_st;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_st <= LEFT;
        end else begin
            current_st <= next_st;
        end
    end

    always @(*) begin
        next_st = current_st;
        sel_mod_btn = 1;
        case (current_st)
            LEFT: begin
                sel_mod_btn = 1'b1;
                if (i_btn_l) begin
                    next_st = LEFT;
                end else if (i_btn_r) begin
                    next_st = RIGHT;
                end
            end
            RIGHT: begin
                sel_mod_btn = 1'b0;
                if (i_btn_l) begin
                    next_st = LEFT;
                end else if (i_btn_r) begin
                    next_st = RIGHT;
                end
            end
        endcase
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