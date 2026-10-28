# Vivado Flow

Tested versions: any Vivado with xsim (2018+). The example part is Basys 3 (`xc7a35tcpg236-1`); change it for your board.

## 1. Simulation (command line)

```bash
source /tools/Xilinx/Vivado/<version>/settings64.sh
make xsim            # runs scripts/run_xsim.sh
```

The script runs `xvlog` → `xelab` → `xsim` and prints the PASS/FAIL summary.

## 2. Simulation (GUI)

```bash
vivado -mode batch -source scripts/create_vivado_project.tcl   # creates ./vivado_proj
vivado vivado_proj/async_fifo_proj.xpr
```
Then **Flow Navigator → Run Simulation → Run Behavioral Simulation**. In the Tcl console type `run all` (the testbench ends with `$finish`). Add `wclk`, `rclk`, `winc`, `rinc`, `wfull`, `rempty`, `wdata`, `rdata` to the wave window.

## 3. Synthesis

1. Run Synthesis.
2. Open **Reports → Report Utilization** and note LUTs, FFs and LUTRAM. Because `fifo_mem` uses asynchronous read, Vivado infers *distributed RAM*.
3. Fill in the table in the README.

## 4. Constraints

`constraints/async_fifo.xdc` contains:
- `create_clock` for both clocks
- `set_clock_groups -asynchronous` so Vivado does not try to time the unrelated clocks against each other
- `set_max_delay -datapath_only` on the Gray pointer crossings (keeps bit skew small, which is what Gray coding relies on)
- `ASYNC_REG` on the synchronizer flops (keeps them together and tells Vivado they are intentionally asynchronous)

The cell names in the `.xdc` (`u_wptr_full/wptr_reg*`, `u_sync_w2r/q1_reg*`, ...) assume the FIFO is the top module. If you instantiate it inside a larger design, prefix them with the instance path, or use `get_cells -hier -filter {...}`.

## 5. CDC check

After synthesis run in the Tcl console:

```tcl
report_cdc -details -file cdc_report.txt
report_clock_interaction -file clk_interaction.txt
```

Expected: the only crossings are the Gray pointer buses, each reported as safe via a 2-flop synchronizer. Any "unsafe" or "no synchronizer" entries mean the constraints or instance paths need fixing.

## 6. Running on hardware (optional)

For a board demo, wrap the FIFO in a small top module:
- `wclk` from a PLL/MMCM output (e.g. 100 MHz), `rclk` from another (e.g. 37.5 MHz)
- A counter writes incrementing values whenever `!wfull`
- The read side reads whenever `!rempty` and checks that data increments by one; error → LED
- Use ILA or VIO to observe `wfull` / `rempty`

Note that two outputs of the **same** MMCM are *related* clocks. They still work with this FIFO, but to test real asynchronicity use two independent clock sources.
