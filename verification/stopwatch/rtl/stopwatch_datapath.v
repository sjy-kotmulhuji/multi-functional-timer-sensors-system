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
        .o_count (hour),
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
        .clear       (clear),
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
    input      clear,
    input      run_stop_sw,
    output reg o_tick_100hz
);
    parameter F_COUNT = 100_000_000 / 1000000;
    reg [$clog2(F_COUNT)-1:0] r_counter;

    always @(posedge clk, posedge reset) begin
        if (reset || clear) begin
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
