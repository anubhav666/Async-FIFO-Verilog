`timescale 1ns/1ps
//-----------------------------------------------------------------------------
// Module : fifo_mem
// Brief  : Dual-port FIFO storage. Synchronous write (wclk), asynchronous
//          (combinational) read. Write is gated by the full flag.
//-----------------------------------------------------------------------------
module fifo_mem #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
) (
    input  wire                  wclk,
    input  wire                  winc,
    input  wire                  wfull,
    input  wire [ADDR_WIDTH-1:0] waddr,
    input  wire [DATA_WIDTH-1:0] wdata,
    input  wire [ADDR_WIDTH-1:0] raddr,
    output wire [DATA_WIDTH-1:0] rdata
);
    localparam DEPTH = 1 << ADDR_WIDTH;

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    assign rdata = mem[raddr];

    always @(posedge wclk) begin
        if (winc && !wfull)
            mem[waddr] <= wdata;
    end
endmodule
