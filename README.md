# Intel Compiler Workshop

Hands-on labs for learning Intel compiler features including diagnostics, debugging, and vectorization optimization.

## Workshop Materials

📊 [Intel Developer Workshop - Compilers.pdf](./Intel%20Developer%20Workshop%20-%20Compilers.pdf) - Presentation slides and reference materials

## Labs

### [Lab 1: ICC vs ICX Compiler Diagnostics](./lab1)
Explore differences between Intel's legacy ICC compiler and modern ICX/ICPX compilers in handling diagnostic messages and warnings.

**Topics:** Clang-based diagnostics, warning control, pragma-based suppression

### [Lab 2: Debugging with Fortran Compiler (IFX)](./lab2)
Learn to use Intel Fortran Compiler debugging options to catch common programming errors at compile-time and runtime.

**Topics:** Debug builds, runtime checks, uninitialized variables, array bounds, floating-point exceptions

### [Lab 3: Vectorization with Intel Compilers](./lab3)
Master Intel Compiler vectorization features to optimize code performance using SIMD instructions.

**Topics:** Auto-vectorization, optimization reports, vector ISA selection (SSE/AVX/AVX-512), loop multiversioning, user mandated vectorization

## Quick Start

Each lab includes:
- Detailed README with exercises
- Quick reference guide
- Setup scripts for environment configuration
- Sample code and automated test runner

### Running a Lab

```bash
cd lab1  # or lab2, lab3
source setup_icx.sh  # or setup_icc.sh, setup_ifx.sh
./run_exercises.sh   # automated exercises
```

Or follow individual exercises in each lab's README.

## Requirements

- Intel Compilers (ICX/IFX version 2025.3.0+, ICC/IFORT 2021.10.0)
- Linux environment with module system
- Basic C/C++ or Fortran knowledge

## Lab Structure

```
lab1/  - C++ compiler diagnostics (ICC vs ICX)
lab2/  - Fortran debugging (IFX)
lab3/  - Vectorization optimization (ICX)
```

Each lab is self-contained and can be completed independently.
