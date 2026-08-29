# Copyright (C) 2025  AGH University of Science and Technology
# MTM UEC2
# Author: Piotr Kaczmarczyk
#
# Description:
# tcl file sourced to Vivado to load the bitstream specified in the argument to an FPGA.



# Bitstream location
set bitstream_file [lindex ${argv} 0]


# Load bitstream to FPGA
proc program_fpga {bitstream_file} {
    if {[file exists $bitstream_file] == 0} {
        puts "ERROR: Bitstream not found: $bitstream_file"
        exit 1
    } else {
        open_hw_manager
        connect_hw_server -allow_non_jtag

        # Wait up to 5 seconds for hardware target enumeration
        set targets [get_hw_targets]
        set retry 0
        while {[llength $targets] == 0 && $retry < 10} {
            after 500
            refresh_hw_server
            set targets [get_hw_targets]
            incr retry
        }

        if {[llength $targets] == 0} {
            puts "ERROR: No hardware targets found on connected server."
            puts "Please check that:"
            puts "  1. The Basys 3 USB cable is firmly connected to the PC."
            puts "  2. The Basys 3 power switch (SW16) is ON."
            puts "  3. The power jumper (JP1) is set to USB."
            exit 1
        }

        set target [lindex $targets 0]
        puts "INFO: Connecting to target: $target"
        current_hw_target $target
        open_hw_target

        set devices [get_hw_devices]
        if {[llength $devices] == 0} {
            puts "ERROR: No JTAG devices found on target $target."
            exit 1
        }

        set device [lindex $devices 0]
        puts "INFO: Found FPGA device: $device"
        current_hw_device $device
        refresh_hw_device -update_hw_probes false $device

        set_property PROBES.FILE {} $device
        set_property FULL_PROBES.FILE {} $device
        set_property PROGRAM.FILE ${bitstream_file} $device

        puts "INFO: Programming $device with $bitstream_file..."
        program_hw_devices $device
        refresh_hw_device $device
        puts "INFO: FPGA programming completed successfully!"
    }
}


## MAIN
if {${argc} != 1} {
    puts "ERROR: Bitstream not specified"
    exit 1
} else {
    program_fpga $bitstream_file
    exit
}
