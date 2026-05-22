`timescale 1ns / 1ps

module btn_debounce (
    input  clk,
    input  reset,
    input  i_btn,
    output o_btn
);

    //Clock divider for debounce Shift register
    //100MHz -> 100KHz: 10us, 10^-6
    //counter 1000번 
    parameter F_COUNT = 1000;
    reg [$clog2(F_COUNT) -1 : 0] counter_reg;
    reg clk_100khz_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            clk_100khz_reg <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            clk_100khz_reg <= 1'b0;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                clk_100khz_reg <= 1'b1;
            end else begin
                clk_100khz_reg <= 1'b0;
            end
        end
    end

    //Series 8 tap F/F
    reg [7:0] q_reg, q_next;
    wire debounce;

    //Sequential Logic
    always @(posedge clk_100khz_reg, posedge reset) begin
        if (reset) begin
            q_reg <= 0;
        end else begin
            q_reg <= q_next;
        end
    end

    //Next CL
    always @(*) begin
        q_next = {i_btn, q_reg[7:1]};       //80us 이상 지속 #80_000
    end

    //debounce, 8 input AND
    assign debounce = &q_reg;  //q_reg의 8bit가 모두 1이어야 1이 됨.

    reg edge_reg;

    //edge detection
    //o_btn tick 길이를 10ns로 끊기 위해 엣지 사용
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            edge_reg <= 1'b0;
        end else begin
            edge_reg <= debounce;       //debounce 신호를 1clk 차이로 따라감
        end
    end

    assign o_btn = debounce & (~edge_reg);  //debounce == 1, edge_reg == 0일 때 1

    //입력값 1이 8clk 이상 나와야 하나의 tick 발생 #80_000

endmodule
