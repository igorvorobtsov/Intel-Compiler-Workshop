#!/bin/bash
# Setup script for IFX (Intel Fortran Compiler)

echo "Setting up IFX environment..."

# Detect current architecture from loaded modules
CURRENT_ARCH=$(module list -t 2>&1 | grep "stack/" | grep -o "arch=[a-z0-9_]*" | cut -d= -f2)

# Determine best architecture for stack/24.6.0
# Available: icelake, sapphirerapids, skylake_avx512
if [ "$CURRENT_ARCH" = "sapphirerapids" ]; then
    TARGET_ARCH="sapphirerapids"
elif [ "$CURRENT_ARCH" = "icelake" ]; then
    TARGET_ARCH="icelake"
else
    # Default to icelake if unknown
    TARGET_ARCH="icelake"
fi

echo "Current arch: $CURRENT_ARCH, Target arch: $TARGET_ARCH"

# Load stack with explicit architecture
module switch stack stack/24.6.0 arch=$TARGET_ARCH
module load intel/2025.3.0

echo ""
echo "IFX environment loaded!"
echo "Compiler: $(which ifx)"
ifx --version | head -3
echo ""
echo "Usage: ifx [options] source.f90 -o output"
echo "Example: ifx -g -O0 -traceback test.f90 -o test"
