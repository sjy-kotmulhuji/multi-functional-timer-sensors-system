`timescale 1ns / 1ps

module ascii_decoder (
    input            clk,
    input            rst,
    input      [7:0] i_ascii,
    input            rx_done,
    output reg       o_r,
    output reg       o_l,
    output reg       o_u,
    output reg       o_d,
    output reg       o_s
);

    //pc에서 보낼 땐 소문자로
    parameter R = 8'h72, L = 8'h6C, U = 8'h75, D = 8'h64, S = 8'h73;
    reg w_r, w_l, w_u, w_d;
    reg edge_reg;


    always @(posedge clk, posedge rst) begin
        if (rst) begin
            o_r <= 0;
            o_l <= 0;
            o_u <= 0;
            o_d <= 0;
        end else begin
            case (i_ascii)
                R: begin
                    o_r <= rx_done;
                end
                L: begin
                    o_l <= rx_done;
                end
                U: begin
                    o_u <= rx_done;
                end
                D: begin
                    o_d <= rx_done;
                end
                S: begin
                    o_s <= rx_done;
                end
            endcase
        end
    end

endmodule

