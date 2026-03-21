#!/bin/bash
set -e

# compile all SystemVerilog files
iverilog -g2012 -o sim \
    *.sv

# run simulation
vvp sim

# open waveform viewer
#gtkwave wave.vcd