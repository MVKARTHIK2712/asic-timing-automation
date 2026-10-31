# Universal EDA STA & Timing Report Automation Engine

![Language](https://img.shields.io/badge/Language-Tcl%208.6%2B-blue.svg)
![Domain](https://img.shields.io/badge/Domain-Physical%20Design%20%7C%20STA-orange.svg)
![Tools](https://img.shields.io/badge/Tools-PrimeTime%20%7C%20Fusion%20Compiler%20%7C%20ICC2-green.svg)
![License](https://img.shields.io/badge/License-MIT-brightgreen.svg)

An enterprise-grade **Tcl-based Static Timing Analysis (STA) parser and reporting framework**. This tool automates post-processing of massive, complex semiconductor design logs and timing reports, transforming unformatted EDA text streams into actionable summary analytics, detailed violation logs, and structured CSV datasets.

---

## 📌 Executive Summary & Motivation

In modern ASIC physical design flows, timing closure and sign-off verification generate gigabytes of log output across thousands of corners and modes. Manual inspection using standard text searching (`grep`/`awk`) is slow, error-prone, and inefficient for multi-path tracking.

This automation engine provides a **unified data extraction pipeline** capable of parsing both flat inline logs and complex, multi-line block timing reports (e.g., Synopsys PrimeTime or Fusion Compiler). It automatically computes Worst Negative Slack (WNS), isolates high-fanout logic bottlenecks, performs multi-path start/endpoint correlation, and enforces custom sign-off slack margins.

---

## 🔥 Key Features

* **Universal Format Ingestion:** Seamlessly parses both multi-line block STA reports (`Startpoint: ... Endpoint: ... slack (...)`) and single-line consolidated log strings (`TIMING SETUP START=...`).
* **Dynamic Threshold Customization:** Accepts user-defined setup and hold sign-off thresholds via command-line flags to flag critical violations and marginal near-zero risk paths.
* **Numerical Slack Engine:** Employs custom Tcl floating-point comparison algorithms to precisely sort and extract WNS and best slack extremes across large datasets.
* **Multi-Path Correlation:** Groups alternate timing paths sharing identical startpoint-endpoint register pairs using Tcl dictionaries, contrasting worst vs. best sub-paths.
* **High-Fanout Bottleneck Detection:** Extracts driver cell instances exceeding user-configured fanout limits to highlight congestion and capacitive load risks.
* **Multi-Format Sign-off Export:** Automatically outputs three clean, production-ready files:
  1. `*_summary_report.rpt` — Executive overview of design metadata, extremes, and path correlation.
  2. `*_violations_detail.rpt` — Detailed text log isolating flagged setup and hold paths.
  3. `*_violations.csv` — CSV data output optimized for Excel, pivot tables, and automated regression tracking.

---

## 🛠️ System Architecture & Data Flow

```text
   ┌─────────────────────────────────────────────────────────────┐
   │             Input EDA Data Stream (.log / .rpt)             │
   │   (Multi-Line Block Reports OR Flat Inline Timing Logs)     │
   └──────────────────────────────┬──────────────────────────────┘
                                  │
                                  ▼
   ┌─────────────────────────────────────────────────────────────┐
   │        Universal Parsing Engine (eda_automator.tcl)         │
   │  - Pattern Signature Matching & Block Splitting             │
   │  - Regular Expression Extraction (Start/End/Slack/Fanout)   │
   └──────────────────────────────┬──────────────────────────────┘
                                  │
                                  ▼
   ┌─────────────────────────────────────────────────────────────┐
   │         Analytical Data Processing & Dictionary Store       │
   │  - Custom Floating-Point Numerical Sorting                  │
   │  - Dynamic Threshold Check (Setup & Hold Sign-off Margins)   │
   │  - Multi-Path Startpoint-to-Endpoint Correlation            │
   └──────────────────────────────┬──────────────────────────────┘
                                  │
            ┌─────────────────────┼─────────────────────┐
            ▼                     ▼                     ▼
 ┌────────────────────┐ ┌────────────────────┐ ┌────────────────────┐
 │  _summary_report   │ │ _violations_detail │ │   _violations.csv  │
 │     (.rpt)         │ │       (.rpt)       │ │       (.csv)       │
 └────────────────────┘ └────────────────────┘ └────────────────────┘
```

---

## 📋 File Deliverables Overview

Running the script produces three distinct outputs targeting different analytical needs:

| File Generated | Description | Primary Audience / Use Case |
| :--- | :--- | :--- |
| **`*_summary_report.rpt`** | Executive text summary including metadata, WNS/Best path extremes, multi-path pair groupings, and high-fanout instances. | Timing Leads & Sign-off Review |
| **`*_violations_detail.rpt`** | Isolated text listing of every path violating the configured setup/hold margins. | Block Owners & ECO Engineers |
| **`*_violations.csv`** | Structured tabular dataset (`Path_Type,Startpoint,Endpoint,Slack_Value`). | Downstream Analytics & Pivot Tables |

---

## 🚀 Execution & Usage Guide

### Prerequisites
* **OS:** Linux / WSL (Windows Subsystem for Linux)
* **Interpreter:** `tclsh` (Tcl 8.5 or higher)

### Command Syntax
```bash
tclsh eda_automator.tcl <input_file> [output_prefix] [fanout_threshold] [setup_threshold] [hold_threshold]
```

### Parameter Reference

1. `<input_file>` *(Required)*: Path to the input STA report or EDA log file.
2. `[output_prefix]` *(Optional)*: Prefix for output files (Default: `analysis_out`).
3. `[fanout_threshold]` *(Optional)*: Minimum fanout to flag as a bottleneck (Default: `20`).
4. `[setup_threshold]` *(Optional)*: Maximum slack value to flag setup violations (Default: `0.00`).
5. `[hold_threshold]` *(Optional)*: Maximum slack value to flag hold violations (Default: `0.00`).

---

## 💡 Usage Examples

### 1. Default Sign-off Violation Run
Parses a standard STA report and flags all paths with negative slack (`< 0.00`):
```bash
tclsh eda_automator.tcl fusion_compiler_report_timing_practice.rpt run_default 20 0.00 0.00
```

### 2. Sign-off Margin Risk Check (Near-Zero Slack Filtering)
Flags setup paths with slack tighter than `0.05 ns` (capturing marginal paths) and hold paths below `0.00 ns`:
```bash
tclsh eda_automator.tcl pd_practice.log run_margin 20 0.05 0.00
```

### 3. Full Data Capture Mode (Export All Paths to CSV)
Sets loose thresholds to dump all extracted paths directly into the CSV dataset:
```bash
tclsh eda_automator.tcl fusion_compiler_report_timing_practice.rpt full_dump 50 10.0 10.0
```

---

## 📊 Sample Output Preview (`_summary_report.rpt`)

```text
==================================================================
 AUTOMATED EDA STA TIMING & REPORT ANALYSIS SUMMARY
 Generated on: 2026-10-31 10:30:00
==================================================================

----------------------------------------
 1. DESIGN METADATA & CONFIGURATION
----------------------------------------
  * Mode: Multi-Line STA Report Parsing Active
  * Total Parsed Timing Paths    : 450
  * High Fanout Bottlenecks      : 3 (Threshold >= 20)
  * Custom Setup Threshold Limit : 0.05
  * Custom Hold Threshold Limit  : 0.00

----------------------------------------
 2. SLACK EXTREMES (WNS / BEST)
----------------------------------------
  * Worst Slack (WNS) : -0.214 (SETUP)
    Startpoint        : u_core/u_alu/reg_a_reg[0]/CLK
    Endpoint          : u_core/u_alu/reg_out_reg[0]/D
  * Best Slack        : 1.452 (SETUP)

----------------------------------------
 3. VIOLATION ANALYSIS
----------------------------------------
  * Total Flagged Violations: 12
    -> TYPE: SETUP | START: u_core/reg_1/CLK -> END: u_core/reg_2/D | SLACK: -0.214
    -> TYPE: SETUP | START: u_mem/ctrl_reg/CLK -> END: u_mem/data_reg/D | SLACK: 0.021

----------------------------------------
 4. MULTI-PATH CORRELATION (Same Start & Endpoint)
----------------------------------------
  * Path Pair Group : u_core/reg_1/CLK --> u_core/reg_2/D
    Variations Found: 3
    Worst Sub-Path  : -0.214
    Best Sub-Path   : 0.045

----------------------------------------
 5. HIGH FANOUT INSTANCES (>= 20)
----------------------------------------
  * Instance: u_clk_gate_main | Fanout: 64
  * Instance: u_rst_driver   | Fanout: 42
==================================================================
 AUTOMATION SUCCESSFUL!
 Generated Output Reports:
   - Summary Report : run_margin_summary_report.rpt
   - Violation Log  : run_margin_violations_detail.rpt
   - CSV Analytics  : run_margin_violations.csv
==================================================================
```

---

## 📂 Repository Structure

```text
.
├── eda_automator.tcl                          # Master Tcl automation engine
├── pd_practice.log                            # Sample inline tool log
├── fusion_compiler_report_timing_practice.rpt # Sample multi-line STA report
├── README.md                                  # Technical documentation
└── .gitignore                                 # Git ignore file for generated reports
```

---

## 🔬 Key Engineering Concepts Applied
* **Tcl Scripting:** Procedural programming, file I/O operations, custom list sorting (`lsort -command`), dictionary data structures (`dict`).
* **Regular Expressions (RegEx):** Pattern matching, string trimming, data capture groups.
* **Static Timing Analysis:** WNS/TNS calculation, setup/hold constraints, path startpoint/endpoint correlation, fanout congestion analysis.
* **Data Engineering:** Automated transformation of unstructured text into structured CSV files for analytics.

---

## 📄 License
This project is open-source and available under the MIT License.