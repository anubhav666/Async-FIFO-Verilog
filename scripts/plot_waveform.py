#!/usr/bin/env python3
"""Render a simple waveform PNG from a VCD file (no GTKWave needed).
Usage: python3 scripts/plot_waveform.py sim/wave_demo.vcd docs/images/waveform.png
"""
import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

SIGNALS = ["wclk", "winc", "wdata", "wfull", "rclk", "rinc", "rdata", "rempty"]

def parse_vcd(path, top_scope="wave_demo_tb"):
    ids, vals, scope = {}, {}, []
    t = 0
    with open(path) as f:
        in_defs = True
        for line in f:
            line = line.strip()
            if in_defs:
                if line.startswith("$scope"):
                    scope.append(line.split()[2])
                elif line.startswith("$upscope"):
                    scope.pop()
                elif line.startswith("$var") and len(scope) == 1 and scope[0] == top_scope:
                    p = line.split()
                    name = p[4]
                    if name in SIGNALS and p[3] not in ids:
                        ids[p[3]] = (name, int(p[2]))
                        vals[name] = []
                elif line.startswith("$enddefinitions"):
                    in_defs = False
                continue
            if line.startswith("#"):
                t = int(line[1:])
            elif line and line[0] in "01xz" and line[1:] in ids:
                vals[ids[line[1:]][0]].append((t, line[0]))
            elif line.startswith("b"):
                v, i = line[1:].split()
                if i in ids:
                    vals[ids[i][0]].append((t, v))
    return vals

def main(vcd, out):
    vals = parse_vcd(vcd)
    tmax = max(t for s in vals.values() for t, _ in s)
    fig, axes = plt.subplots(len(SIGNALS), 1, figsize=(12, 7), sharex=True)
    for ax, name in zip(axes, SIGNALS):
        ev = vals[name]
        ax.set_ylabel(name, rotation=0, ha="right", va="center", fontsize=9)
        ax.set_yticks([])
        for sp in ("top", "right", "left"):
            ax.spines[sp].set_visible(False)
        if name in ("wdata", "rdata"):
            for i, (t, v) in enumerate(ev):
                t2 = ev[i + 1][0] if i + 1 < len(ev) else tmax
                lab = f"{int(v, 2):02X}" if set(v) <= {"0", "1"} else "XX"
                ax.fill_between([t / 1000, t2 / 1000], 0, 1, color="#cfe3ff", ec="#2b6cb0", lw=0.6)
                if (t2 - t) > 12000:
                    ax.text((t + t2) / 2000, 0.5, lab, ha="center", va="center", fontsize=7)
            ax.set_ylim(-0.1, 1.1)
        else:
            xs, ys = [], []
            for i, (t, v) in enumerate(ev):
                y = 1 if v == "1" else 0
                if xs:
                    xs.append(t / 1000); ys.append(ys[-1])
                xs.append(t / 1000); ys.append(y)
            xs.append(tmax / 1000); ys.append(ys[-1])
            ax.step(xs, ys, where="post", lw=1.2, color="#c53030" if name in ("wfull", "rempty") else "#1a202c")
            ax.set_ylim(-0.2, 1.3)
    axes[-1].set_xlabel("time (ns)")
    fig.suptitle("Async FIFO (depth 4): write burst until wfull, then read burst until rempty", fontsize=11)
    fig.tight_layout()
    fig.savefig(out, dpi=140)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
