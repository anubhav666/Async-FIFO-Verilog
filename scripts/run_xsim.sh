#!/usr/bin/env bash
# Run the testbench with Vivado's command-line simulator (xsim).
# Requires Vivado's settings64.sh to be sourced first, e.g.
#   source /tools/Xilinx/Vivado/2023.2/settings64.sh
set -e
cd "$(dirname "$0")/.."
mkdir -p sim

xvlog rtl/sync_2ff.v rtl/fifo_mem.v rtl/wptr_full.v rtl/rptr_empty.v rtl/async_fifo.v tb/async_fifo_tb.v
xelab -debug typical async_fifo_tb -s async_fifo_sim
xsim async_fifo_sim -runall | tee sim/xsim_log.txt
