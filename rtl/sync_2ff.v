`timescale 1ns/1ps
//-----------------------------------------------------------------------------
// Module : sync_2ff
// Brief  : Two-flop synchronizer for moving a multi-bit GRAY-CODED value
//          into another clock domain. Only ever use this on signals that
//          change by one bit at a time (Gray pointers).
//-----------------------------------------------------------------------------
module sync_2ff #(
    parameter WIDTH = 5
) (
    input  wire             clk,    // destination clock
    input  wire             rst_n,  // active-low async reset
    input  wire [WIDTH-1:0] d,      // input from the other clock domain
    output reg  [WIDTH-1:0] q       // synchronized output
);
    reg [WIDTH-1:0] q1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q1 <= {WIDTH{1'b0}};
            q  <= {WIDTH{1'b0}};
        end else begin
            q1 <= d;   // may go metastable
            q  <= q1;  // resolved value
        end
    end
endmodule
