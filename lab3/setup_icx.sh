#!/bin/bash
# Setup script for ICX (Intel oneAPI DPC++/C++ Compiler)

echo "Setting up ICX environment..."
module switch stack stack/24.6.0
module load intel/2025.3.0

echo ""
echo "ICX environment loaded!"
echo "Compiler: $(which icx)"
icx --version | head -3
echo ""
echo "Usage: icx [options] source.c -o output"
echo "Example: icx -Wall test.c -o test"
