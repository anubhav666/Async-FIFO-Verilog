# Verification

## Environment

- Testbench: `tb/async_fifo_tb.v` (plain Verilog-2001, self-checking)
- Simulators used: Icarus Verilog 12 (results below). The code is also written to run under Vivado xsim; see [vivado_flow.md](vivado_flow.md).
- Run: `make sim`

## Testbench architecture

```
  random / directed drivers                  DUT                   monitors
  ┌────────────┐  winc,wdata   ┌──────────────────────┐  rinc   ┌────────────┐
  │ write side │ ────────────► │      async_fifo      │ ◄────── │ read side  │
  └────────────┘               └──────────────────────┘         └────────────┘
        │ accepted writes (winc && !wfull)        accepted reads (rinc && !rempty) │
        ▼                                                                          ▼
   ┌───────────────────────── Scoreboard (reference array) ───────────────────────┐
   │  store at wr_idx++                       compare rdata with ref[rd_idx++]    │
   └──────────────────────────────────────────────────────────────────────────────┘
        + flag checkers (full/empty never wrongly low) + overflow/underflow checks
```

Clock periods are variables, so each test can use different frequency ratios. The write clock starts at a 10 ns period and the read clock at 27 ns. This non-integer ratio makes the clock edges drift through many different phase relationships.

## Checks performed

| Check | How |
|---|---|
| Data integrity and ordering | Every accepted read is compared to the scoreboard entry |
| No overflow | Occupancy (`wr_idx − rd_idx`) never exceeds depth |
| No underflow | No read accepted when scoreboard is empty |
| `wfull` never low when truly full | Checked every `wclk` negedge |
| `rempty` never low when truly empty | Checked every `rclk` negedge |
| Reset state | `rempty = 1`, `wfull = 0` after reset (including mid-run reset) |
| Extra writes while full are ignored | Directed test |
| Extra reads while empty are ignored | Directed test |

## Test plan

| # | Test | Clocks (wclk / rclk) | Purpose |
|---|---|---|---|
| 1 | Reset state | 100 / ~37 MHz | Flags correct after reset |
| 2 | Fill to full | 100 / ~37 MHz | `wfull` asserts after DEPTH writes; extra writes ignored |
| 3 | Drain to empty | 100 / ~37 MHz | In-order data, `rempty` asserts; extra reads ignored; `wfull` clears |
| 4 | Random, write-heavy (80% / 40%) | 100 / ~37 MHz | FIFO runs near full |
| 5 | Random, read-heavy (40% / 80%) | ~37 / 100 MHz | FIFO runs near empty |
| 6 | Random, near-equal clocks (70% / 70%) | ~71 / ~68 MHz | Slowly drifting phase relationship |
| 7 | Reset during traffic, then random (60% / 60%) | 100 / ~63 MHz | Recovery from reset with data inside |

## Results (Icarus Verilog 12)

```
 Total writes accepted : 5507
 Total reads  accepted : 5491
 Max occupancy seen    : 16 / 16
 Errors                : 0
 RESULT: *** PASS ***
```

The 16-word difference between writes and reads is the data that was inside the FIFO when test 7 applied its mid-run reset (that data is intentionally discarded).

### Parameter sweep

Same testbench with overridden parameters (`-P async_fifo_tb.DATA_WIDTH=.. -P async_fifo_tb.ADDR_WIDTH=..`):

| DATA_WIDTH | ADDR_WIDTH | Depth | Result |
|---|---|---|---|
| 8 | 4 (default) | 16 | PASS |
| 8 | 2 | 4 | PASS |
| 16 | 3 | 8 | PASS |
| 32 | 5 | 32 | PASS |

### Mutation testing (is the testbench actually able to fail?)

Two bugs were injected deliberately; the testbench must report FAIL for each.

| Mutation | Expected | Result |
|---|---|---|
| `wptr_full`: removed the MSB inversion in the full comparison | FIFO overflows or flags wrong | **FAIL** (7 errors) |
| `rptr_empty`: compared binary next-pointer instead of Gray with the synchronized pointer | Empty flag wrong | **FAIL** (thousands of errors) |

## Coverage observations

- FIFO reached 100% occupancy (16/16) and returned to empty repeatedly.
- Both fast-write/slow-read and slow-write/fast-read were exercised.
- Not measured: formal code/functional coverage (a possible extension with a SystemVerilog/UVM testbench).

## Not covered / caveats

- **Metastability** is not modelled in RTL simulation. Use the Vivado CDC report (`report_cdc`) on the synthesized design.
- **Gate-level / post-implementation timing simulation** has not been run.
- Clock-ratio sweep is finite. Any additional ratio can be added by editing `wclk_half` / `rclk_half` in the testbench.
