`timescale 1ns / 1ps

module stopwatch_control_unit (
    input      clk,
    input      reset,
    input      sw_1,
    input      i_mode,
    input      i_run_stop,
    input      i_clear,
    input      i_rs_key,
    input      i_cl_key,
    output     o_mode,
    output reg o_run_stop,
    output reg o_clear
);

    localparam STOP = 2'b00, RUN = 2'b01, CLEAR = 2'b10;

    reg [1:0] current_st, next_st;


    //State Register
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_st <= STOP;
        end else begin
            current_st <= next_st;
        end
    end

    assign o_mode = i_mode;

    //Next State, OUTPUT CL
    always @(*) begin
        next_st    = current_st;
        o_run_stop = 1'b0;  //Init
        o_clear    = 1'b0;
        case (current_st)
            STOP: begin
                o_run_stop = 1'b0;
                o_clear = 1'b0;
                if ((sw_1 == 1) && (i_run_stop || i_rs_key)) begin
                    next_st = RUN;
                end else if (i_clear || i_cl_key) begin
                    next_st = CLEAR;
                end
            end
            RUN: begin
                o_run_stop = 1'b1;
                o_clear = 1'b0;
                if (i_run_stop || i_rs_key) begin
                    next_st = STOP;
                end
            end
            CLEAR: begin
                o_run_stop = 1'b0;
                o_clear = 1'b1;
                if ((sw_1 == 1) && (i_run_stop || i_rs_key)) begin
                    next_st = RUN;
                end
            end
        endcase
    end



endmodule

module watch_control_unit (
    input      clk,
    input      reset,
    input      sw_1,
    input      i_up,
    input      i_down,
    input      i_up_key,
    input      i_dw_key,
    output reg o_up,
    output reg o_down
);

    localparam [1:0] NORMAL = 2'b00, UP = 2'b01, DOWN = 2'b10;

    reg [1:0] current_st, next_st;

    //State Register
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_st <= NORMAL;
        end else begin
            current_st <= next_st;
        end
    end

    //Next State, Output CL
    always @(*) begin
        next_st = current_st;
        o_up = 1'b0;
        o_down = 1'b0;

        case (current_st)
            NORMAL: begin
                o_up   = 1'b0;
                o_down = 1'b0;
                if (sw_1 == 0) begin
                    if (i_up == 1 || i_up_key) begin
                        next_st = UP;
                    end else if (i_down == 1 || i_dw_key) begin
                        next_st = DOWN;
                    end
                end
            end
            UP: begin
                o_up   = 1'b1;
                o_down = 1'b0;
                if (sw_1 == 0) begin
                    if (i_up == 0 || i_up_key) begin  //up ���� �� ���� ��� normal
                        next_st = NORMAL;
                    end
                end
            end
            DOWN: begin
                o_up   = 1'b0;
                o_down = 1'b1;
                if (sw_1 == 0) begin
                    if (i_down == 0 || i_dw_key) begin
                        next_st = NORMAL;
                    end
                end
            end
        endcase
    end

endmodule

module watch_modify_sel (  //�¿��ư 1:hour/sec, 0: min/msec
    input      clk,
    input      reset,
    input      i_btn_l,
    input      i_btn_r,
    input      i_l_key,
    input      i_r_key,
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
                if (i_btn_l || i_l_key) begin
                    next_st = LEFT;
                end else if (i_btn_r || i_r_key) begin
                    next_st = RIGHT;
                end
            end
            RIGHT: begin
                sel_mod_btn = 1'b0;
                if (i_btn_l || i_l_key) begin
                    next_st = LEFT;
                end else if (i_btn_r || i_r_key) begin
                    next_st = RIGHT;
                end
            end
        endcase
    end


endmodule
