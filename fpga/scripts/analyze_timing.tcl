# ===============================================================================
# OptiBolt Timing Analysis Script
# Opens top_basys3_routed.dcp and reports detailed timing violation statistics
# ===============================================================================

open_checkpoint fpga/build/optibolt_project.runs/impl_1/top_basys3_routed.dcp

file mkdir results

puts "================================================================="
puts "Generating detailed timing reports..."
puts "================================================================="

# Generate report with top 50 failing paths
report_timing -max_paths 50 -slack_lesser_than 0 -file results/timing_worst50.rpt

# Generate timing summary with unconstrained and setup/hold details
report_timing_summary -max_paths 20 -file results/timing_summary_detailed.rpt

# Analyze failing endpoints by hierarchy
set failing_paths [get_timing_paths -max_paths 500 -slack_lesser_than 0]
set fp [open "results/timing_failing_endpoints.txt" "w"]
puts $fp "Slack(ns)\tSource\tDestination\tLevels\tDataDelay"

foreach path $failing_paths {
    set slack [get_property SLACK $path]
    set src   [get_property STARTPOINT_PIN $path]
    set dst   [get_property ENDPOINT_PIN $path]
    set lvl   [get_property LOGIC_LEVELS $path]
    set dat   [get_property DATAPATH_DELAY $path]
    puts $fp "$slack\t$src\t$dst\t$lvl\t$dat"
}
close $fp

puts "================================================================="
puts "Timing analysis reports generated in results/:"
puts "  - results/timing_worst50.rpt"
puts "  - results/timing_summary_detailed.rpt"
puts "  - results/timing_failing_endpoints.txt"
puts "================================================================="

exit 0
