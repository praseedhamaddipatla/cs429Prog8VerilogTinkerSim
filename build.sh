#!/bin/bash
set -e

mkdir -p sim vvp

iverilog -g2012 -o vvp/hw8.vvp \
    tinker.sv \
    test/testbench.sv

vvp vvp/hw8.vvp