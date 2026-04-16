# Lab 1: ICC vs ICX Compiler Diagnostics

## Overview

This lab explores the differences between Intel's legacy **ICC** compiler and the modern **ICX/ICPX** (Intel oneAPI DPC++/C++ Compiler) in handling diagnostic messages and warnings.

### Key Differences

- **ICX/ICPX**: Uses Clang-based diagnostic options with descriptive phrases (e.g., `-Wunused-variable`)
- **ICC**: Uses Intel's traditional `-diag` options to control diagnostic information during compilation

## Code Example

The following code will be used throughout this lab:

```cpp
#include <iostream>

int main() {
    int X;
    std::cout << "Hello World!";
    return 0;
}
```

**Note**: The variable `X` is declared but never used, which triggers diagnostic warnings.

## Running the Lab

### Option 1: On This Machine (Recommended)

This repository includes test files and helper scripts to run all exercises locally.

#### Setup Environment

**For ICC (Intel C++ Compiler Classic)**:
```bash
source setup_icc.sh
# Or manually:
# module switch stack stack/23.1.0
# module load intel/2023.2.1
```

**For ICX (Intel oneAPI DPC++/C++ Compiler)**:
```bash
source setup_icx.sh
# Or manually:
# module switch stack stack/24.6.0
# module load intel/2025.3.0
```

#### Run Exercises

You can run individual exercises or all at once:

```bash
# Run a specific exercise (1-7)
./run_exercises.sh 1

# Run all exercises
./run_exercises.sh all
```

**Features**:
- Code display: Each exercise shows the code being compiled with highlighted relevant lines
- Reduced output: Loads only compiler modules (not full toolkit) for cleaner output
- Color-coded: Commands, output, and section headers are color-coded for readability

#### Manual Compilation Examples

```bash
# ICX examples
icpx test.cpp -o test                       # Default (no warnings)
icpx -Wall test.cpp -o test                 # Enable warnings
icpx -Wall -Wno-unused-variable test.cpp    # Suppress specific warning

# ICC examples
icc test.cpp -o test                        # Default (no warnings)
icc -Wall test.cpp -o test                  # Enable warnings
icc -Wall -diag-disable=177 test.cpp        # Suppress using diagnostic ID
```

### Option 2: Using Godbolt (Alternative)

If you prefer to use an online compiler explorer, all exercises can be performed using this Godbolt link:
**https://godbolt.org/z/38q8jcan9**

---

## Exercises

### Exercise 1: Observe Default Diagnostic Behavior

**Task**: Examine the diagnostic information emitted by both compilers.

**On this machine**:
```bash
./run_exercises.sh 1

# Or manually:
# ICX
source setup_icx.sh
icpx test.cpp -o test          # No warnings by default
icpx -Wall test.cpp -o test    # Shows: warning: unused variable 'X' [-Wunused-variable]

# ICC
source setup_icc.sh
icc -Wall test.cpp -o test     # Shows: warning #177: variable "X" was declared but never referenced
```

**Alternative**: https://godbolt.org/z/38q8jcan9

**Questions to answer**:
- What warning message does ICX display? (Clang-style: `-Wunused-variable`)
- What diagnostic message does ICC display? (Intel-style: `#177`)
- What is the diagnostic ID number for ICC? (`177`)

**Important Discoveries**:
- **ICX**: `-Wall` includes unused variable warnings
- **ICC**: `-Wall` does NOT include unused variable warnings
  - Native option: `-diag-warning=177` (to enable warning #177)
  - GCC-compatible: `-Wunused-variable` also works (GCC compatibility, not Clang!)

---

### Exercise 2: Control Diagnostic Severity (Warnings vs Errors)

**Task**: Understand how to treat diagnostics as errors vs warnings in both compilers.

**On this machine**:
```bash
./run_exercises.sh 2

# Or manually:
# ICX - warnings as errors (fails)
icpx -Wall -Werror test.cpp -o test

# ICX - warnings allowed (succeeds)
icpx -Wall -Wno-error test.cpp -o test

# ICC - diagnostic #177 as error (fails)
icc -diag-error=177 test.cpp -o test

# ICC - diagnostic #177 as warning (succeeds)
icc -diag-warning=177 test.cpp -o test
```

**Important ICC distinction**:
- **ICX**: Use `-Werror` to treat all warnings as errors
- **ICC**: Use `-diag-error=<id>` to treat a specific diagnostic as an error
  - `-diag-warning=177` = enable as warning
  - `-diag-error=177` = enable as error (compilation fails)
  - ⚠️ `-diag-warning=177 -Werror` does **NOT** work!

**Expected result**: 
- With `-Werror` (ICX) or `-diag-error=177` (ICC), compilation fails
- With `-Wno-error` (ICX) or `-diag-warning=177` (ICC), code compiles with warnings

---

### Exercise 3: Add `-Wunused-variable` to ICC

**Task**: Compare ICC's native diagnostic option with GCC-compatible flags.

**On this machine**:
```bash
./run_exercises.sh 3

# Or manually:
source setup_icc.sh
icc -diag-warning=177 test.cpp -o test         # ICC native option
icc -Wunused-variable test.cpp -o test         # GCC-compatible option
```

**Questions**:
- What is ICC's native option? (`-diag-warning=177`)
- Does ICC recognize `-Wunused-variable`? (Yes, for GCC compatibility)
- Is this Clang compatibility? (No! GCC compatibility)

**Result**: ICC's native option is `-diag-warning=177`. ICC also accepts `-Wunused-variable` for **GCC compatibility** (not Clang), but still displays warnings in Intel's format (warning #177).

---

### Exercise 4: Enable All Warnings and Suppress Specific Warning (ICX)

**Task**: Enable all warnings with `-Wall`, then suppress the unused variable warning specifically.

**On this machine**:
```bash
./run_exercises.sh 4

# Or manually:
source setup_icx.sh
icpx -Wall test.cpp -o test                      # Shows warning
icpx -Wall -Wno-unused-variable test.cpp -o test # No warning
```

**Expected result**: All warnings are enabled except for unused variables. The code should compile without warnings about variable `X`.

---

### Exercise 5: Disable Warning for Specific Code Section (ICX)

**Task**: Use `#pragma` directives to disable the unused variable warning for a specific section of code.

**On this machine**:
```bash
./run_exercises.sh 5

# Or manually:
source setup_icx.sh
icpx -Wall test.cpp -o test                     # Shows warning
icpx -Wall test_multiple_unused.cpp -o test    # X suppressed, Y warns
```

**Test file** (`test_multiple_unused.cpp`):
```cpp
#include <iostream>

int main() {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"
    int X;
#pragma clang diagnostic pop

    int Y;  // This should still trigger a warning
    std::cout << "Hello World!";
    return 0;
}
```

**Expected result**: The unused variable warning for `X` is suppressed within the pragma block, but `Y` still generates a warning - proving the pragma scope is limited!

---

### Exercise 6: Suppress Diagnostic in ICC

**Task**: Suppress the unused variable warning in ICC using Intel's diagnostic system.

**On this machine**:
```bash
./run_exercises.sh 6

# Or manually:
source setup_icc.sh
icc -diag-warning=177 test.cpp -o test                    # Shows warning #177
icc -diag-warning=177 -diag-disable=177 test.cpp -o test  # No warning (native Intel method)
icc -diag-warning=177 -Wno-unused-variable test.cpp       # No warning (GCC-compatible)
```

**Questions**:
- What is ICC's native enable option? (`-diag-warning=177`)
- What is ICC's native disable option? (`-diag-disable=177`)
- Does `-Wno-unused-variable` work with ICC? (Yes, for GCC compatibility, NOT Clang!)
- Which approach is native to ICC? (`-diag-warning=177` / `-diag-disable=177`)

**Important**: 
- **177** is the diagnostic ID for unused variable in ICC
- ICC accepts `-W*` flags for **GCC compatibility**, not Clang compatibility
- ICX accepts `-W*` flags because it's based on Clang/LLVM

---

### Exercise 7: Suppress Warnings Locally with Pragma (ICX)

**Task**: Use `#pragma` directives in two different ways with ICX.

**On this machine**:
```bash
./run_exercises.sh 7

# Or manually:
source setup_icx.sh
icpx -Wall test_multiple_unused.cpp -o test  # Shows warning for Y only
icpx -Wall test_pragma_file.cpp -o test      # No warnings at all
```

**Option 1 - Localized suppression** (`test_multiple_unused.cpp`):
```cpp
#include <iostream>

int main() {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"
    int X;
#pragma clang diagnostic pop
    
    int Y;  // This should still trigger a warning
    std::cout << "Hello World!";
    return 0;
}
```

**Option 2 - Suppress for remainder of file** (`test_pragma_file.cpp`):
```cpp
#include <iostream>

#pragma clang diagnostic ignored "-Wunused-variable"

int main() {
    int X;  // No warning
    int Y;  // No warning
    std::cout << "Hello World!";
    return 0;
}
```

**Expected results**:
- Option 1: Warning appears for `Y` but not for `X`
- Option 2: No warnings for either `X` or `Y`

---

### Exercise 8: Unknown/Unsupported Pragma Handling

**Task**: Understand how ICC and ICX handle unknown or unsupported pragmas by default.

**On this machine**:
```bash
./run_exercises.sh 8

# Or manually:
# ICX - default (no warnings!)
source setup_icx.sh
icpx test_pragmas.cpp -o test_pragmas

# ICX - with -Wall (warns about unknown pragmas)
icpx -Wall test_pragmas.cpp -o test_pragmas

# ICX - explicit warning
icpx -Wunknown-pragmas test_pragmas.cpp -o test_pragmas

# ICC - default (WARNS by default!)
source setup_icc.sh
icc test_pragmas.cpp -o test_pragmas
```

**Test file** (`test_pragmas.cpp`):
```cpp
int main(void) {
    float arr[1000];

    #pragma totallybogus           // Unknown to both compilers
    #pragma simd                   // ICC Classic pragma; NOT supported by ICX
    #pragma vector                 // Recognized and implemented by ICX
    for (int k=0; k<1000; k++) {
        arr[k] = 42.0;
    }

    return 0;
}
```

**Critical Difference**:
- **ICX**: By default, **SILENTLY IGNORES** unknown pragmas
  - Need `-Wunknown-pragmas` (or `-Wall`) to warn
  - `#pragma simd` (ICC Classic) is silently ignored
  - `#pragma vector` is recognized and implemented
  
- **ICC**: By default, **WARNS** about unknown pragmas
  - `warning #161` for truly unknown pragmas (`totallybogus`)
  - `warning #3948` for deprecated `simd` pragma
  - `#pragma vector` is recognized

**Suppression**:
- ICX: `-Wno-unknown-pragmas`
- ICC: `-diag-disable=161,3948,13379`

**Important for Migration**: Code with ICC-specific pragmas (like `simd`) will compile silently in ICX but won't have the optimization effect! Use `-Wunknown-pragmas` to detect this during migration.

---

## Summary

After completing these exercises, you should understand:

1. **ICX/ICPX** uses Clang-based diagnostics with `-W` flags (e.g., `-Wunused-variable`, `-Wno-unused-variable`)
2. **ICC** natively uses Intel's `-diag` system:
   - Enable diagnostic: `-diag-warning=177`
   - Disable diagnostic: `-diag-disable=177`
   - 177 is the ID for unused variable warnings
3. **Important clarification**: ICC also accepts `-W*` flags (e.g., `-Wunused-variable`, `-Wno-unused-variable`) for **GCC compatibility**, NOT Clang compatibility. ICC still reports diagnostics in Intel's format (warning #177).
4. **Critical difference**: 
   - ICX: `-Wall` **includes** unused variable warnings
   - ICC: `-Wall` **does NOT include** unused variable warnings - needs explicit `-diag-warning=177` or `-Wunused-variable`
5. **Pragma directives**:
   - ICX supports `#pragma clang diagnostic` (push/pop or file-wide)
   - ICC has its own pragma system (`#pragma warning`)
6. **Unknown pragma handling** (Exercise 8):
   - ICX: Silently ignores by default, warns with `-Wunknown-pragmas` or `-Wall`
   - ICC: Warns by default (more strict!)
   - Critical for migration: ICC pragmas like `#pragma simd` are silently ignored by ICX!

## Key Takeaways

| Feature | ICX/ICPX | ICC |
|---------|----------|-----|
| Compiler base | Clang/LLVM-based | Intel proprietary (deprecated) |
| Warning format | `-Wunused-variable` | `warning #177` |
| Native enable syntax | `-Wunused-variable` | `-diag-warning=177` |
| Native disable syntax | `-Wno-unused-variable` | `-diag-disable=177` |
| Cross-compatibility | Native Clang flags | Accepts `-W*` flags for **GCC compatibility** |
| `-Wall` behavior | **Includes unused variable warnings** | **Does NOT include unused variable warnings** |
| Enable unused warnings | `-Wall` (included) | `-diag-warning=177` or `-Wunused-variable` |
| Pragma support | `#pragma clang diagnostic` | `#pragma warning` |
| Availability | intel/2025.3.0 (stack 24.6.0) | intel/2023.2.1 (stack 23.1.0) |

## Additional Resources

- [Intel oneAPI DPC++/C++ Compiler Documentation](https://www.intel.com/content/www/us/en/docs/dpcpp-cpp-compiler/developer-guide-reference/2025-2/overview.html)
- [Compiler Explorer (Godbolt)](https://godbolt.org/)
