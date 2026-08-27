# ===============================================================================
# OptiBolt Script: Fast Synthesis & Resource Check (`quick_synth.tcl`)
# ===============================================================================
#
# Author: Tomasz Więcławski & Sebastian Zoń
# Project: OptiBolt Protocol & Evaluation Platform
#
# DESCRIPTION:
#   Performs an out-of-context or in-memory synthesis of the entire OptiBolt
#   design directly from source files defined in `project_details.tcl`.
#   
#   Why use this?
#   - Full bitstream generation (`generate_bitstream.ps1`) takes 10–15 minutes
#     because it runs synthesis, place, route, physical optimizations, and bitstream.
#   - `quick_synth.tcl` runs ONLY the synthesis step in ~2–3 minutes, immediately
#     verifying that:
#       1. All SystemVerilog, Verilog, and VHDL syntax is valid.
#       2. The design fits within the 20,800 LUT limit of the Artix-7 xc7a35t.
#       3. No loops fail to converge (DRC/Synth errors).
#
# USAGE:
#   From project root directory in PowerShell:
#     vivado -mode batch -source fpga/scripts/quick_synth.tcl
#   Or using the PowerShell wrapper:
#     .\tools\quick_synth.ps1
# ===============================================================================

cd fpga
source scripts/project_details.tcl

puts "================================================================="
puts "OptiBolt Fast Synthesis Check: $top_module ($target)"
puts "================================================================="

# Read design sources
if {[info exists sv_files]} {
    foreach f $sv_files { read_verilog -sv $f }
}
if {[info exists verilog_files]} {
    foreach f $verilog_files { read_verilog $f }
}
if {[info exists vhdl_files]} {
    foreach f $vhdl_files { read_vhdl $f }
}
if {[info exists mem_files]} {
    foreach f $mem_files { read_mem $f }
}
if {[info exists xdc_files]} {
    foreach f $xdc_files { read_xdc $f }
}

# Run in-memory synthesis
synth_design -top $top_module -part $target -flatten_hierarchy rebuilt

file mkdir ../results

puts "INFO: Generating results/top_utilization.rpt ..."
report_utilization -file ../results/top_utilization.rpt

puts "INFO: Generating results/hierarchical_utilization.rpt ..."
report_utilization -hierarchical -file ../results/hierarchical_utilization.rpt

puts "================================================================="
puts "SUCCESS: Fast synthesis check completed successfully!"
puts "Reports written to results/top_utilization.rpt and results/hierarchical_utilization.rpt"
puts "================================================================="
exit 0

