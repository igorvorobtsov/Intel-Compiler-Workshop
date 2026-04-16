#!/bin/bash
# Setup script for ICX (Intel oneAPI DPC++/C++ Compiler)

echo "Setting up ICX environment..."
module switch stack stack/24.6.0
module load intel/2025.3.0

echo ""
echo "ICX environment loaded!"
echo "Compiler: $(which icpx)"
icpx --version | head -3
echo ""
echo "Usage: icpx [options] source.cpp -o output"
echo "Example: icpx -Wall test.cpp -o test"
