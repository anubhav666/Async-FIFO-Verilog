# Future Work

## Functional extensions
- **Almost-full / almost-empty** flags, with a programmable threshold, to give upstream logic early warning.
- **Occupancy counters** for each side (convert the other side's Gray pointer to binary and subtract; remember they are conservative).
- **Registered / first-word-fall-through output stage** for Block RAM inference and better read-path timing.
- **Show-ahead vs. standard read mode** parameter.
- **Different read/write widths** (width converter FIFO).
- **Synchronous reset variant** with reset synchronizers per domain.

## Verification extensions
- SystemVerilog testbench with constrained-random stimulus and functional coverage.
- SVA assertions (e.g., `!(wfull && winc && accepted)`, Gray pointers change by at most one bit per cycle).
- UVM environment with a write agent, read agent and scoreboard.
- Formal verification (SymbiYosys) of no overflow / no underflow / data ordering.
- Post-synthesis and post-implementation timing simulation.

## FPGA extensions
- Board demo with two independent clock sources and an ILA capture.
- Use a Xilinx simple-dual-port BRAM instead of LUTRAM and compare utilization.

## Link to the Virtuoso / mixed-signal side
Since this repo is meant to sit beside analog work in Cadence Virtuoso:
- **ADC output buffer:** a SAR or delta-sigma ADC samples in its own clock domain; this FIFO moves its samples into the system clock domain.
- **ASIC flow:** the same RTL can go through Genus (synthesis) and Innovus (place and route), then be brought into Virtuoso as a digital block next to analog cells. Avoid the FPGA-specific `ASYNC_REG` constraint there and use your foundry's synchronizer cell guidance instead.
- **AMS co-simulation:** import the Verilog module into Virtuoso and simulate it with the analog front end using AMS Designer.
- Replace the behavioural memory with a register-file or SRAM macro from the PDK.
