# Architecture

## Overview

The FIFO is split into five small modules so each clock domain's logic is isolated and the CDC boundary is easy to see.

```
 WRITE DOMAIN (wclk)                                READ DOMAIN (rclk)
 ┌─────────────────┐   waddr / winc / wfull   ┌──────────┐   raddr   ┌─────────────────┐
 │   wptr_full     │ ───────────────────────► │ fifo_mem │ ◄──────── │   rptr_empty    │
 │ bin + Gray wptr │                          │ (RAM)    │ ───────►  │ bin + Gray rptr │
 │ FULL logic      │                          └──────────┘   rdata   │ EMPTY logic     │
 └───────┬─────────┘                                                 └────────┬────────┘
         │ wptr (Gray)                                            rptr (Gray) │
         │                      ═══ clock domain boundary ═══                 │
         ▼                                                                    ▼
   ┌───────────┐  rq2_wptr  (to read domain)          wq2_rptr (to write domain)  ┌───────────┐
   │ sync_2ff  │ ──────────────────────────────►  ◄───────────────────────────────  │ sync_2ff  │
   │   w2r     │       (clocked by rclk)               (clocked by wclk)             │   r2w     │
   └───────────┘                                                                    └───────────┘
```

Only the **Gray-coded pointers** cross between domains, and always through a two-flop synchronizer. Data itself never crosses through a synchronizer; it sits in the memory until the read pointer reaches it.

## Modules

### `async_fifo` (top)
Instantiates and wires the four blocks below. Parameters `DATA_WIDTH` (default 8) and `ADDR_WIDTH` (default 4) set a depth of `2**ADDR_WIDTH`.

### `fifo_mem`
Simple dual-port memory. Writes are synchronous to `wclk` and enabled by `winc && !wfull`. Reads are combinational from `raddr`, so `rdata` already shows the word at the head of the FIFO whenever `rempty` is low.

### `wptr_full` (write clock domain)
- Holds an `ADDR_WIDTH+1`-bit binary counter `wbin`. The lower `ADDR_WIDTH` bits are the memory write address; the MSB is a wrap indicator.
- Computes `wbin_next = wbin + (winc & ~wfull)`, converts it to Gray, and registers it as `wptr`, the pointer sent to the read domain.
- Generates `wfull` by comparing the *next* Gray write pointer with the synchronized read pointer `wq2_rptr` (see [design_notes.md](design_notes.md)).

### `rptr_empty` (read clock domain)
Mirror image of `wptr_full`: maintains `rbin`/`rptr`, drives `raddr`, and sets `rempty` when the next Gray read pointer equals the synchronized write pointer `rq2_wptr`. Resets to `rempty = 1`.

### `sync_2ff`
Two back-to-back flops clocked by the destination clock. The first flop may go metastable; the second gives it a full clock period to settle. Used only for Gray-coded values.

## Parameters

| Parameter | Default | Meaning |
|---|---|---|
| `DATA_WIDTH` | 8 | Bits per word |
| `ADDR_WIDTH` | 4 | log2(depth). Depth = 2^ADDR_WIDTH (16 words by default) |

## Timing behaviour

| Event | Observed on |
|---|---|
| Write accepted at `wclk` edge N | Word stored; Gray `wptr` updates after edge N |
| `rempty` deasserts | About 2 to 3 `rclk` cycles after the write (synchronizer + registered flag) |
| Read accepted at `rclk` edge M | `rptr` updates after edge M |
| `wfull` deasserts | About 2 to 3 `wclk` cycles after the read |

This latency is what makes the flags *pessimistic* (safe): a FIFO can look fuller or emptier than it really is, never the opposite.

## Reset

Each domain has its own active-low asynchronous reset. Reset pointers, flags, and synchronizers in both domains together. After reset: `wfull = 0`, `rempty = 1`, both pointers = 0. Memory contents are not cleared (not needed).
