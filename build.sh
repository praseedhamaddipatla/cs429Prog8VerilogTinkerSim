#!/bin/bash
set -e

# compile all SystemVerilog files
iverilog -g2012 -o hw8 \
    *.sv

# run simulation
vvp hw8