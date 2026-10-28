.PHONY: sim wave xsim clean
# Async FIFO - simulation shortcuts
# Usage:  make sim      (Icarus Verilog, free)
#         make wave     (open waveform in GTKWave)
#         make xsim     (Vivado xsim, requires Vivado in PATH)
#         make clean

RTL = rtl/sync_2ff.v rtl/fifo_mem.v rtl/wptr_full.v rtl/rptr_empty.v rtl/async_fifo.v
TB  = tb/async_fifo_tb.v

sim:
	mkdir -p sim
	iverilog -g2005 -Wall -o sim/async_fifo.vvp $(RTL) $(TB)
	vvp sim/async_fifo.vvp | tee sim/sim_log.txt

wave:
	gtkwave sim/async_fifo.vcd &

xsim:
	bash scripts/run_xsim.sh

clean:
	rm -rf sim/*.vvp sim/*.vcd sim/sim_log.txt xsim.dir *.jou *.log *.pb *.wdb webtalk*

# Regenerate docs/images/waveform.png (needs python3 + matplotlib)
.PHONY: wavepng
wavepng:
	mkdir -p sim docs/images
	iverilog -g2005 -o sim/wave_demo.vvp $(RTL) tb/wave_demo_tb.v
	vvp sim/wave_demo.vvp
	python3 scripts/plot_waveform.py sim/wave_demo.vcd docs/images/waveform.png
