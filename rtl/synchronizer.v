`timescale 1ns / 1ps

module synchronizer (
    input      clk,
    input      d,
    output reg q
);

    reg ff1;
    always @(posedge clk) begin
        ff1 <= d;
        q   <= ff1;
    end
endmodule
