`timescale 1ns/1ps
//-----------------------------------------------------------------------------
// Module : async_fifo
// Brief  : Asynchronous (dual-clock) FIFO using Gray-coded pointers and
//          two-flop synchronizers. Follows the approach described in
//          Clifford E. Cummings, "Simulation and Synthesis Techniques for
//          Asynchronous FIFO Design" (SNUG 2002).
//
// Parameters:
//   DATA_WIDTH : width of each FIFO word            (default 8)
//   ADDR_WIDTH : log2(depth); depth = 2**ADDR_WIDTH (default 4 -> 16 words)
//
// Notes:
//   * Write side: wclk / wrst_n / winc / wdata / wfull
//   * Read  side: rclk / rrst_n / rinc / rdata / rempty
//   * rdata is already valid while rempty is low (data is on rdata BEFORE
//     rinc is asserted; rinc simply advances to the next word).
//   * Both resets are active-low and asynchronous. Assert both together.
//-----------------------------------------------------------------------------
module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
) (
    // Write domain
    input  wire                  wclk,
    input  wire                  wrst_n,
    input  wire                  winc,
    input  wire [DATA_WIDTH-1:0] wdata,
    output wire                  wfull,

    // Read domain
    input  wire                  rclk,
    input  wire                  rrst_n,
    input  wire                  rinc,
    output wire [DATA_WIDTH-1:0] rdata,
    output wire                  rempty
);
    wire [ADDR_WIDTH-1:0] waddr, raddr;
    wire [ADDR_WIDTH:0]   wptr, rptr, wq2_rptr, rq2_wptr;

    // Read pointer -> write clock domain
    sync_2ff #(.WIDTH(ADDR_WIDTH+1)) u_sync_r2w (
        .clk  (wclk),
        .rst_n(wrst_n),
        .d    (rptr),
        .q    (wq2_rptr)
    );

    // Write pointer -> read clock domain
    sync_2ff #(.WIDTH(ADDR_WIDTH+1)) u_sync_w2r (
        .clk  (rclk),
        .rst_n(rrst_n),
        .d    (wptr),
        .q    (rq2_wptr)
    );

    fifo_mem #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) u_mem (
        .wclk (wclk),
        .winc (winc),
        .wfull(wfull),
        .waddr(waddr),
        .wdata(wdata),
        .raddr(raddr),
        .rdata(rdata)
    );

    wptr_full #(.ADDR_WIDTH(ADDR_WIDTH)) u_wptr_full (
        .wclk    (wclk),
        .wrst_n  (wrst_n),
        .winc    (winc),
        .wq2_rptr(wq2_rptr),
        .wfull   (wfull),
        .waddr   (waddr),
        .wptr    (wptr)
    );

    rptr_empty #(.ADDR_WIDTH(ADDR_WIDTH)) u_rptr_empty (
        .rclk    (rclk),
        .rrst_n  (rrst_n),
        .rinc    (rinc),
        .rq2_wptr(rq2_wptr),
        .rempty  (rempty),
        .raddr   (raddr),
        .rptr    (rptr)
    );
endmodule
