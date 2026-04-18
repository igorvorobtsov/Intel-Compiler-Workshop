#!/bin/bash
# Setup script for ICC (Intel C++ Compiler Classic)

echo "Setting up ICC environment..."
module unload intel 2>/dev/null || true
module switch stack stack/23.1.0 2>/dev/null
module load intel/2023.2.1 2>/dev/null

echo ""
echo "ICC environment loaded!"
echo "Compiler: $(which icc)"
icc --version 2>&1 | grep -v "remark #10441"
echo ""
echo "Usage: icc [options] source.cpp -o output"
echo "Example: icc -diag-warning=177 test.cpp -o test"
