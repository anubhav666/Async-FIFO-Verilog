`timescale 1ns/1ps
// Short directed demo used only to generate the waveform in docs/images.
module wave_demo_tb;
    reg wclk=0, rclk=0, wrst_n=0, rrst_n=0, winc=0, rinc=0;
    reg [7:0] wdata=0; wire [7:0] rdata; wire wfull, rempty;
    always #5 wclk=~wclk;
    always #13.5 rclk=~rclk;
    async_fifo #(.DATA_WIDTH(8), .ADDR_WIDTH(2)) dut(
        .wclk(wclk),.wrst_n(wrst_n),.winc(winc),.wdata(wdata),.wfull(wfull),
        .rclk(rclk),.rrst_n(rrst_n),.rinc(rinc),.rdata(rdata),.rempty(rempty));
    integer i;
    initial begin
        $dumpfile("sim/wave_demo.vcd"); $dumpvars(0, wave_demo_tb);
        #60 wrst_n=1; rrst_n=1;
        repeat(3) @(posedge wclk);
        for (i=0;i<7;i=i+1) begin @(posedge wclk); #1 winc=1; wdata=8'hA0+i; end
        @(posedge wclk); #1 winc=0;
        repeat(6) @(posedge rclk);
        for (i=0;i<7;i=i+1) begin @(posedge rclk); #1 rinc=1; end
        @(posedge rclk); #1 rinc=0;
        repeat(8) @(posedge rclk);
        $finish;
    end
endmodule
