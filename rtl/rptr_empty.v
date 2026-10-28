`timescale 1ns/1ps
//-----------------------------------------------------------------------------
// Module : rptr_empty
// Brief  : Read-pointer and EMPTY-flag logic (read clock domain).
//          EMPTY when the next Gray read pointer equals the synchronized
//          write pointer.
//-----------------------------------------------------------------------------
module rptr_empty #(
    parameter ADDR_WIDTH = 4
) (
    input  wire                  rclk,
    input  wire                  rrst_n,
    input  wire                  rinc,
    input  wire [ADDR_WIDTH:0]   rq2_wptr,  // write ptr (Gray) synced into rclk
    output reg                   rempty,
    output wire [ADDR_WIDTH-1:0] raddr,
    output reg  [ADDR_WIDTH:0]   rptr       // Gray read pointer -> write domain
);
    reg  [ADDR_WIDTH:0] rbin;
    wire [ADDR_WIDTH:0] rbin_next;
    wire [ADDR_WIDTH:0] rgray_next;
    wire                rempty_val;

    assign raddr      = rbin[ADDR_WIDTH-1:0];
    assign rbin_next  = rbin + (rinc & ~rempty);
    assign rgray_next = (rbin_next >> 1) ^ rbin_next;   // binary -> Gray

    assign rempty_val = (rgray_next == rq2_wptr);

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin   <= {(ADDR_WIDTH+1){1'b0}};
            rptr   <= {(ADDR_WIDTH+1){1'b0}};
            rempty <= 1'b1;
        end else begin
            rbin   <= rbin_next;
            rptr   <= rgray_next;
            rempty <= rempty_val;
        end
    end
endmodule
