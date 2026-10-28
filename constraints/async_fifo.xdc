# Example timing constraints for the async FIFO (Vivado / XDC)
# Adjust clock periods and pin names for your design / board.

create_clock -name wclk -period 10.000 [get_ports wclk]   ;# 100 MHz
create_clock -name rclk -period 27.000 [get_ports rclk]   ;# ~37 MHz

# The two clocks are unrelated -> do not time paths between them in the
# normal way. The Gray-pointer crossings are protected by two-flop
# synchronizers and bounded by the max-delay constraints below.
set_clock_groups -asynchronous -group [get_clocks wclk] -group [get_clocks rclk]

# Keep each Gray-coded pointer bit skew small: limit the data path delay
# between the launching pointer register and the first synchronizer flop
# to one source-clock period (a common rule of thumb).
set_max_delay -datapath_only -from [get_cells u_wptr_full/wptr_reg*] \
              -to [get_cells u_sync_w2r/q1_reg*] 10.000
set_max_delay -datapath_only -from [get_cells u_rptr_empty/rptr_reg*] \
              -to [get_cells u_sync_r2w/q1_reg*] 27.000

# Tell Vivado the first synchronizer flops are meant to be sampled
# asynchronously (also helps the CDC report).
set_property ASYNC_REG TRUE [get_cells u_sync_w2r/q1_reg*]
set_property ASYNC_REG TRUE [get_cells u_sync_w2r/q_reg*]
set_property ASYNC_REG TRUE [get_cells u_sync_r2w/q1_reg*]
set_property ASYNC_REG TRUE [get_cells u_sync_r2w/q_reg*]
