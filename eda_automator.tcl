#!/usr/bin/env tclsh
# ==============================================================================
# Enterprise-Grade Universal EDA STA & Timing Report Automation Engine
# Author: Senior Automation / STA Architect
# Description: Dynamically ingests heavy STA reports and logs, extracts slacks,
#              handles multi-line blocks & inline logs, and outputs RPT/CSV files.
# ==============================================================================

proc print_usage {} {
    puts "Usage: tclsh eda_automator.tcl <input_file> [output_prefix] [fanout_threshold] [setup_threshold] [hold_threshold]"
    puts "Example: tclsh eda_automator.tcl fusion_compiler_report_timing_practice.rpt run1 20 0.05 0.00"
    exit 1
}

# --- Universal Parsing Engine (Handles both Inline Logs & Multi-Line STA Reports) ---
proc parse_eda_log {filename fanout_threshold} {
    if {![file exists $filename]} {
        puts "Error: Target file '$filename' does not exist."
        exit 1
    }

    set fp [open $filename r]
    set content [read $fp]
    close $fp

    set paths {}
    set high_fanouts {}
    set design_info {}

    # Check file format signature to use the correct parsing strategy
    if {[string match "*Startpoint: *" $content]} {
        # --- Format A: Multi-Line STA / Fusion Compiler Timing Report ---
        # Split blocks by Startpoint marker
        set path_blocks [split $content "Startpoint: "]
        foreach block [lrange $path_blocks 1 end] {
            set lines [split $block "\n"]
            set startpoint [string trim [lindex $lines 0]]
            set endpoint ""
            set slack_status "MET"
            set slack_val 0.0
            set path_type "SETUP" ;# Default to max/setup unless min found

            foreach line $lines {
                if {[string match "Endpoint: *" $line]} {
                    set endpoint [string trim [string range $line [string length "Endpoint: "] end]]
                }
                if {[string match "*Path Type: min*" $line]} {
                    set path_type "HOLD"
                }
                if {[string match "*slack (*)*" $line]} {
                    regexp {slack \(([^)]+)\)\s+([-\d.]+)} $line -> slack_status slack_val
                }
            }

            if {$endpoint ne ""} {
                # Standardize status label
                set final_status $slack_status
                lappend paths [dict type $path_type start $startpoint end $endpoint slack [expr {$slack_val}]]
            }
        }
    } else {
        # --- Format B: Inline Log Format (e.g., pd_practice style) ---
        set lines [split $content "\n"]
        foreach line $lines {
            if {[regexp {^(DESIGN|TECHNOLOGY|CORNER|LIBRARY|MODE|CLOCK):} $line]} {
                lappend design_info $line
            }

            if {[string match "*TIMING SETUP*" $line] || [string match "*TIMING HOLD*" $line]} {
                set type "SETUP"
                if {[string match "*TIMING HOLD*" $line]} { set type "HOLD" }
                
                if {[regexp {START=([^\s]+)\s+END=([^\s]+).*?SLACK=([-\d.]+)} $line -> start end slack]} {
                    lappend paths [dict create type $type start $start end $end slack [expr {$slack}]]
                }
            }

            if {[regexp {INST\s+([^\s]+).*?FANOUT=(\d+)} $line -> inst fanout]} {
                if {$fanout >= $fanout_threshold} {
                    lappend high_fanouts [dict create inst $inst fanout $fanout]
                }
            }
        }
    }

    return [dict create design $design_info paths $paths fanouts $high_fanouts]
}

# --- CSV Export Module ---
proc export_to_csv {violations output_prefix} {
    set csv_file "${output_prefix}_violations.csv"
    set cf [open $csv_file w]
    puts $cf "Path_Type,Startpoint,Endpoint,Slack_Value"
    
    foreach v $violations {
        set type  [dict get $v type]
        set start [dict get $v start]
        set end   [dict get $v end]
        set slack [dict get $v slack]
        puts $cf "$type,$start,$end,$slack"
    }
    close $cf
    return $csv_file
}

# --- Automated Report Generator ---
proc generate_reports {analysis_data output_prefix fanout_threshold setup_thresh hold_thresh} {
    set design_info [dict get $analysis_data design]
    set paths [dict get $analysis_data paths]
    set fanouts [dict get $analysis_data fanouts]

    set summary_file "${output_prefix}_summary_report.rpt"
    set sf [open $summary_file w]

    puts $sf "=================================================================="
    puts $sf " AUTOMATED EDA STA TIMING & REPORT ANALYSIS SUMMARY"
    puts $sf " Generated on: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
    puts $sf "=================================================================="
    
    puts $sf "\n[string repeat "-" 40]"
    puts $sf " 1. DESIGN METADATA & CONFIGURATION"
    puts $sf "[string repeat "-" 40]"
    if {[llength $design_info] > 0} {
        foreach info $design_info { puts $sf "  * $info" }
    } else {
        puts $sf "  * Mode: Multi-Line STA Report Parsing Active"
    }
    puts $sf "  * Total Parsed Timing Paths    : [llength $paths]"
    puts $sf "  * High Fanout Bottlenecks      : [llength $fanouts] (Threshold >= $fanout_threshold)"
    puts $sf "  * Custom Setup Threshold Limit : $setup_thresh"
    puts $sf "  * Custom Hold Threshold Limit  : $hold_thresh"

    if {[llength $paths] == 0} {
        puts $sf "\nWarning: No structured timing paths identified. Review input format."
        close $sf
        puts "Analysis complete. Summary written to $summary_file"
        return
    }

    # Numerical Sorting via Custom Comparator
    set sorted_paths [lsort -command {apply {{a b} {
        set sa [dict get $a slack]
        set sb [dict get $b slack]
        if {$sa < $sb} {return -1}
        if {$sa > $sb} {return 1}
        return 0
    }}} $paths]

    set worst_path [lindex $sorted_paths 0]
    set best_path [lindex $sorted_paths end]

    puts $sf "\n[string repeat "-" 40]"
    puts $sf " 2. SLACK EXTREMES (WNS / BEST)"
    puts $sf "[string repeat "-" 40]"
    puts $sf "  * Worst Slack (WNS) : [dict get $worst_path slack] ([dict get $worst_path type])"
    puts $sf "    Startpoint        : [dict get $worst_path start]"
    puts $sf "    Endpoint          : [dict get $worst_path end]"
    puts $sf "  * Best Slack        : [dict get $best_path slack] ([dict get $best_path type])"

    # Violation Checks & Grouping
    set violations {}
    set path_groups {}

    foreach p $paths {
        set type  [dict get $p type]
        set slack [dict get $p slack]
        set start [dict get $p start]
        set end   [dict get $p end]
        set key   "$start --> $end"
        
        dict lappend path_groups $key $slack
        
        if {($type eq "SETUP" && $slack < $setup_thresh) || ($type eq "HOLD" && $slack < $hold_thresh)} {
            lappend violations $p
        }
    }

    puts $sf "\n[string repeat "-" 40]"
    puts $sf " 3. VIOLATION ANALYSIS"
    puts $sf "[string repeat "-" 40]"
    puts $sf "  * Total Flagged Violations: [llength $violations]"
    
    set viol_file "${output_prefix}_violations_detail.rpt"
    set vf [open $viol_file w]
    puts $vf "=== DETAILED TIMING VIOLATIONS (Setup < $setup_thresh, Hold < $hold_thresh) ==="
    foreach v $violations {
        set line_str "TYPE: [dict get $v type] | START: [dict get $v start] -> END: [dict get $v end] | SLACK: [dict get $v slack]"
        puts $vf $line_str
        puts $sf "    -> $line_str"
    }
    close $vf

    set csv_output [export_to_csv $violations $output_prefix]

    puts $sf "\n[string repeat "-" 40]"
    puts $sf " 4. MULTI-PATH CORRELATION (Same Start & Endpoint)"
    puts $sf "[string repeat "-" 40]"
    
    set multi_count 0
    dict for {pair slacks} $path_groups {
        if {[llength $slacks] > 1} {
            incr multi_count
            set sorted_slacks [lsort -real $slacks]
            puts $sf "  * Path Pair Group : $pair"
            puts $sf "    Variations Found: [llength $slacks]"
            puts $sf "    Worst Sub-Path  : [lindex $sorted_slacks 0]"
            puts $sf "    Best Sub-Path   : [lindex $sorted_slacks end]"
        }
    }
    if {$multi_count == 0} {
        puts $sf "  * No duplicate start/endpoint path configurations found."
    }

    puts $sf "\n[string repeat "-" 40]"
    puts $sf " 5. HIGH FANOUT INSTANCES (>= $fanout_threshold)"
    puts $sf "[string repeat "-" 40]"
    if {[llength $fanouts] > 0} {
        foreach f_item $fanouts {
            puts $sf "  * Instance: [dict get $f_item inst] | Fanout: [dict get $f_item fanout]"
        }
    } else {
        puts $sf "  * No high fanout records logged in this report style."
    }

    close $sf
    puts "=================================================================="
    puts " AUTOMATION SUCCESSFUL!"
    puts " Generated Output Reports:"
    puts "   - Summary Report : $summary_file"
    puts "   - Violation Log  : $viol_file"
    puts "   - CSV Analytics  : $csv_output"
    puts "=================================================================="
}

# --- Main Execution Entrypoint ---
if {[llength $argv] < 1} { print_usage }

set input_file    [lindex $argv 0]
set prefix        [expr {[lindex $argv 1] ne "" ? [lindex $argv 1] : "analysis_out"}]
set fan_thresh    [expr {[lindex $argv 2] ne "" ? [lindex $argv 2] : 20}]
set setup_thresh  [expr {[lindex $argv 3] ne "" ? [lindex $argv 3] : 0.0}]
set hold_thresh   [expr {[lindex $argv 4] ne "" ? [lindex $argv 4] : 0.0}]

puts "Initializing Universal STA Automation Parser for: $input_file..."
set parsed_data [parse_eda_log $input_file $fan_thresh]
generate_reports $parsed_data $prefix $fan_thresh $setup_thresh $hold_thresh