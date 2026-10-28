`timescale 1ns/1ps
//-----------------------------------------------------------------------------
// Testbench : async_fifo_tb
// Brief     : Self-checking testbench with a scoreboard.
//
// Tests:
//   1. Reset state            : empty=1, full=0
//   2. Fill to full           : full asserts, extra writes are ignored
//   3. Drain to empty         : data comes out in order, empty asserts,
//                               extra reads are ignored
//   4. Random traffic, fast write / slow read   (FIFO tends to fill)
//   5. Random traffic, slow write / fast read   (FIFO tends to empty)
//   6. Random traffic, equal-ish frequencies, odd phase relationship
//   7. Mid-run reset, then fresh traffic
//
// Run "PASS"/"FAIL" summary is printed at the end.
//-----------------------------------------------------------------------------
module async_fifo_tb;

    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;
    localparam DEPTH     = 1 << ADDR_WIDTH;

    // DUT signals
    reg                   wclk = 0, rclk = 0;
    reg                   wrst_n = 0, rrst_n = 0;
    reg                   winc = 0, rinc = 0;
    reg  [DATA_WIDTH-1:0] wdata = 0;
    wire [DATA_WIDTH-1:0] rdata;
    wire                  wfull, rempty;

    // Clock half-periods in ns (changed per test)
    real wclk_half = 5.0;     // 100 MHz
    real rclk_half = 13.5;    // ~37 MHz

    always #(wclk_half) wclk = ~wclk;
    always #(rclk_half) rclk = ~rclk;

    async_fifo #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) dut (
        .wclk(wclk), .wrst_n(wrst_n), .winc(winc), .wdata(wdata), .wfull(wfull),
        .rclk(rclk), .rrst_n(rrst_n), .rinc(rinc), .rdata(rdata), .rempty(rempty)
    );

    //-------------------------------------------------------------------------
    // Scoreboard
    //-------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] ref_mem [0:65535];
    integer wr_idx = 0;       // number of words accepted by the FIFO
    integer rd_idx = 0;       // number of words read out
    integer errors = 0;
    integer total_writes = 0;
    integer total_reads  = 0;
    integer max_occupancy = 0;
    integer occ;

    // Record every accepted write
    always @(posedge wclk) begin
        if (wrst_n && winc && !wfull) begin
            ref_mem[wr_idx[15:0]] = wdata;
            wr_idx = wr_idx + 1;
            total_writes = total_writes + 1;
            occ = wr_idx - rd_idx;
            if (occ > max_occupancy) max_occupancy = occ;
            if (occ > DEPTH) begin
                errors = errors + 1;
                $display("[%0t] ERROR: overflow, occupancy=%0d", $time, occ);
            end
        end
    end

    // Check every accepted read
    always @(posedge rclk) begin
        if (rrst_n && rinc && !rempty) begin
            if (rd_idx >= wr_idx) begin
                errors = errors + 1;
                $display("[%0t] ERROR: underflow (read with nothing written)", $time);
            end else if (rdata !== ref_mem[rd_idx[15:0]]) begin
                errors = errors + 1;
                $display("[%0t] ERROR: data mismatch idx=%0d got=%02h exp=%02h",
                         $time, rd_idx, rdata, ref_mem[rd_idx[15:0]]);
            end
            rd_idx = rd_idx + 1;
            total_reads = total_reads + 1;
        end
    end

    // Flag checks: a truly full FIFO must never report not-full, and a truly
    // empty FIFO must never report not-empty. (Flags may be pessimistic
    // because of synchronizer latency - that is expected and allowed.)
    always @(negedge wclk) begin
        if (wrst_n && (wr_idx - rd_idx) == DEPTH && !wfull) begin
            errors = errors + 1;
            $display("[%0t] ERROR: FIFO is full but wfull=0", $time);
        end
    end
    always @(negedge rclk) begin
        if (rrst_n && (wr_idx == rd_idx) && !rempty) begin
            errors = errors + 1;
            $display("[%0t] ERROR: FIFO is empty but rempty=0", $time);
        end
    end

    //-------------------------------------------------------------------------
    // Helper tasks
    //-------------------------------------------------------------------------
    integer wr_prob = 0;  // % chance of winc each wclk (random mode)
    integer rd_prob = 0;  // % chance of rinc each rclk (random mode)
    reg     rand_mode = 0;

    // Random drivers (active only when rand_mode = 1)
    always @(posedge wclk) if (rand_mode) begin
        #1;
        winc  = ({$random} % 100) < wr_prob;
        wdata = $random;
    end
    always @(posedge rclk) if (rand_mode) begin
        #1;
        rinc = ({$random} % 100) < rd_prob;
    end

    task do_reset;
        begin
            rand_mode = 0;
            winc = 0; rinc = 0;
            wrst_n = 0; rrst_n = 0;
            // Scoreboard restarts the moment reset is asserted
            wr_idx = 0; rd_idx = 0;
            repeat (4) @(posedge wclk);
            repeat (4) @(posedge rclk);
            #1;
            wrst_n = 1; rrst_n = 1;
            repeat (3) @(posedge wclk);
            repeat (3) @(posedge rclk);
        end
    endtask

    task write_one(input [DATA_WIDTH-1:0] d);
        begin
            @(posedge wclk); #1;
            winc = 1; wdata = d;
            @(posedge wclk); #1;
            winc = 0;
        end
    endtask

    task read_one;
        begin
            @(posedge rclk); #1;
            rinc = 1;
            @(posedge rclk); #1;
            rinc = 0;
        end
    endtask

    task check(input cond, input [255:0] msg);
        begin
            if (!cond) begin
                errors = errors + 1;
                $display("[%0t] CHECK FAILED: %0s", $time, msg);
            end
        end
    endtask

    task random_phase(input integer wp, input integer rp, input integer cycles,
                      input [255:0] name);
        begin
            $display("[%0t] --- %0s (wr_prob=%0d%%, rd_prob=%0d%%) ---",
                     $time, name, wp, rp);
            wr_prob = wp; rd_prob = rp; rand_mode = 1;
            repeat (cycles) @(posedge wclk);
            rand_mode = 0; #2; winc = 0;
            // let the reader drain what is left
            rand_mode = 0;
            #1;
        end
    endtask

    task drain_all;
        integer guard;
        begin
            guard = 0;
            while ((wr_idx != rd_idx) && guard < 5000) begin
                @(posedge rclk); #1;
                rinc = !rempty;
                guard = guard + 1;
            end
            @(posedge rclk); #1; rinc = 0;
            repeat (6) @(posedge rclk);
            check(wr_idx == rd_idx, "all data drained");
            check(rempty == 1'b1,   "rempty after drain");
        end
    endtask

    //-------------------------------------------------------------------------
    // Main sequence
    //-------------------------------------------------------------------------
    integer i;
    initial begin
        $dumpfile("sim/async_fifo.vcd");
        $dumpvars(0, async_fifo_tb);

        // ---- Test 1: reset state ----
        $display("=== Test 1: reset state ===");
        do_reset;
        check(rempty == 1'b1, "rempty=1 after reset");
        check(wfull  == 1'b0, "wfull=0 after reset");

        // ---- Test 2: fill to full ----
        $display("=== Test 2: fill to full ===");
        for (i = 0; i < DEPTH; i = i + 1) write_one(i + 8'h10);
        repeat (6) @(posedge wclk);
        check(wfull == 1'b1, "wfull asserted after DEPTH writes");
        // try overflowing
        for (i = 0; i < 4; i = i + 1) write_one(8'hEE);
        check(wr_idx == DEPTH, "extra writes while full are ignored");

        // ---- Test 3: drain to empty ----
        $display("=== Test 3: drain to empty ===");
        repeat (6) @(posedge rclk);
        check(rempty == 1'b0, "rempty deasserted when data present");
        for (i = 0; i < DEPTH; i = i + 1) read_one;
        repeat (6) @(posedge rclk);
        check(rempty == 1'b1, "rempty asserted after draining");
        check(rd_idx == DEPTH, "all words read");
        // try underflowing
        for (i = 0; i < 4; i = i + 1) read_one;
        check(rd_idx == DEPTH, "extra reads while empty are ignored");
        repeat (6) @(posedge wclk);
        check(wfull == 1'b0, "wfull cleared after reads");

        // ---- Test 4: fast write / slow read ----
        $display("=== Test 4: fast write, slow read ===");
        wclk_half = 5.0; rclk_half = 13.5;
        random_phase(80, 40, 3000, "fast write / slow read");
        rand_mode = 1; wr_prob = 0; rd_prob = 100;   // drain
        repeat (400) @(posedge rclk);
        rand_mode = 0; #2 rinc = 0;
        drain_all;

        // ---- Test 5: slow write / fast read ----
        $display("=== Test 5: slow write, fast read ===");
        wclk_half = 13.5; rclk_half = 5.0;
        random_phase(40, 80, 3000, "slow write / fast read");
        drain_all;

        // ---- Test 6: near-equal frequencies, odd ratio ----
        $display("=== Test 6: near-equal clocks ===");
        wclk_half = 7.0; rclk_half = 7.3;
        random_phase(70, 70, 4000, "near-equal clocks");
        drain_all;

        // ---- Test 7: reset mid-run ----
        $display("=== Test 7: reset in the middle of traffic ===");
        wclk_half = 5.0; rclk_half = 8.0;
        random_phase(90, 20, 200, "pre-reset traffic");
        do_reset;
        check(rempty == 1'b1, "rempty=1 after mid-run reset");
        check(wfull  == 1'b0, "wfull=0 after mid-run reset");
        random_phase(60, 60, 3000, "post-reset traffic");
        drain_all;

        // ---- Summary ----
        $display("");
        $display("=============================================");
        $display(" Total writes accepted : %0d", total_writes);
        $display(" Total reads  accepted : %0d", total_reads);
        $display(" Max occupancy seen    : %0d / %0d", max_occupancy, DEPTH);
        $display(" Errors                : %0d", errors);
        if (errors == 0) $display(" RESULT: *** PASS ***");
        else             $display(" RESULT: *** FAIL ***");
        $display("=============================================");
        $finish;
    end

    // Safety timeout
    initial begin
        #50_000_000;
        $display("TIMEOUT");
        $finish;
    end
endmodule
