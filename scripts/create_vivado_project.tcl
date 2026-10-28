# Creates a Vivado project for the async FIFO.
# Usage (from repo root):  vivado -mode batch -source scripts/create_vivado_project.tcl
# Change the part below to match your board:
#   Basys 3 -> xc7a35tcpg236-1     Arty A7-35 -> xc7a35ticsg324-1L
set part xc7a35tcpg236-1

create_project async_fifo_proj ./vivado_proj -part $part -force

add_files -norecurse [glob rtl/*.v]
add_files -fileset sim_1 -norecurse tb/async_fifo_tb.v
add_files -fileset constrs_1 -norecurse constraints/async_fifo.xdc

set_property top async_fifo [current_fileset]
set_property top async_fifo_tb [get_filesets sim_1]
update_compile_order -fileset sources_1

puts "Project created. Run simulation:  launch_simulation"
puts "Run synthesis:                    launch_runs synth_1 -jobs 4"
