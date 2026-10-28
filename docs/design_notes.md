# Design Notes

## 1. Why a normal FIFO fails across clocks

A synchronous FIFO compares the write and read pointers directly. With two unrelated clocks, a multi-bit pointer sampled by the other clock can be caught mid-transition: several bits flip at slightly different times, so the receiver may see a value that was never valid (e.g. binary `0111 → 1000` could be seen as `1111` or `0000`). That would make the FIFO appear full or empty at the wrong time and corrupt data.

## 2. Gray code solves the multi-bit problem

In Gray code, consecutive values differ by exactly **one bit**. If the receiving clock samples a pointer during its transition, it sees either the old or the new value, both valid. The worst case is a one-count-late pointer, which only makes the flags more conservative.

```
Binary  Gray            Binary → Gray:  gray = (bin >> 1) ^ bin
0000    0000
0001    0001
0010    0011
0011    0010
0100    0110  ...
```

Pointers are therefore **converted to Gray in their own domain, registered, and then synchronized**. Registering the Gray value before the synchronizer ensures that no combinational glitches reach the crossing.

## 3. Extra wrap bit

For a FIFO of depth 2^N, the pointers are N+1 bits. The lower N bits address the memory; the MSB toggles each time the pointer wraps. This distinguishes *full* from *empty*, since in both cases the lower N bits are equal:

| Condition | Lower N bits | MSB |
|---|---|---|
| Empty | equal | equal |
| Full | equal | different |

## 4. Empty flag (read domain)

`rempty` is set when the **next** read Gray pointer equals the synchronized write Gray pointer:

```verilog
rempty_val = (rgray_next == rq2_wptr);
```

Because `rq2_wptr` is the write pointer a few cycles ago, the real write pointer may be ahead, so `rempty` can be a little late to deassert (safe), but it can never assert while data is still present.

## 5. Full flag (write domain)

In Gray code the full condition is not simply "all bits differ in the MSB". Reflecting the sequence means the **two MSBs are inverted and the remaining bits are equal**:

```verilog
wfull_val = (wgray_next == {~wq2_rptr[N:N-1], wq2_rptr[N-2:0]});
```

Likewise `rptr` may be a few cycles old, so the FIFO may look full slightly longer than it truly is (safe), but never not-full when it is full.

## 6. Why use the *next* pointer

Comparing the next pointer and registering the result makes `wfull`/`rempty` change on the same clock edge as the pointer that caused it. Flags are therefore flop outputs (good for timing) and reflect the state immediately after each accepted operation. Overflow and underflow are prevented by gating the increment with `~wfull` / `~rempty`.

## 7. Metastability

The first flop of each synchronizer can become metastable when its input changes near the clock edge. The second flop gives it one full destination-clock period to resolve. Two flops are typically enough for moderate clock rates; for very high rates compute MTBF and consider three flops.

RTL simulation does **not** model metastability. Verification of the CDC structure is done by (a) design rules (single-bit-change pointers, registered before crossing, nothing but synchronizers on the crossing), (b) the Vivado CDC report, and (c) timing constraints (see `constraints/async_fifo.xdc`).

## 8. Sizing the FIFO

Minimum depth depends on burst length and the clock ratio. For a burst of `B` writes at `fw`, read at `fr` (reads continuously, no gaps):

```
depth ≥ B − B × (fr / fw)       (when fw > fr)
```

Add a margin for synchronizer latency (about 2 to 3 cycles) and round up to a power of two.

*Example:* burst of 160 words, `fw` = 100 MHz, `fr` = 40 MHz → 160 − 64 = 96 → plus margin → 128 words (`ADDR_WIDTH` = 7).

## 9. Coding guidelines followed

- Separate modules per clock domain; no signal is used in two clock domains except through `sync_2ff`.
- Only Gray-coded values cross the boundary.
- Non-blocking assignments in all clocked blocks; continuous assigns for combinational logic.
- Asynchronous active-low reset with a consistent reset value in each domain.
