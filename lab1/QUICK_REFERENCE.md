# Quick Reference Card: ICC vs ICX

## Environment Setup

```bash
# ICC (Classic Intel Compiler - Deprecated)
source setup_icc.sh
# OR: module switch stack stack/23.1.0 && module load intel/2023.2.1

# ICX (Modern Intel oneAPI Compiler)
source setup_icx.sh
# OR: module switch stack stack/24.6.0 && module load intel/2025.3.0
```

## Running Exercises

```bash
./run_exercises.sh <1-7|all>    # Run specific or all exercises
```

## Common Commands Comparison

| Task | ICX/ICPX | ICC |
|------|----------|-----|
| **Basic compilation** | `icpx test.cpp -o test` | `icc test.cpp -o test` |
| **Enable all warnings** | `icpx -Wall test.cpp` | `icc -Wall test.cpp` |
| **Enable unused variable (native)** | `icpx -Wall test.cpp` **(included!)** | `icc -diag-warning=177 test.cpp` |
| **Enable unused variable (compat)** | N/A | `icc -Wunused-variable test.cpp` **(GCC compat)** |
| **Suppress unused variable (native)** | `icpx -Wall -Wno-unused-variable test.cpp` | `icc -diag-warning=177 -diag-disable=177 test.cpp` |
| **Suppress unused variable (compat)** | N/A | `icc -diag-warning=177 -Wno-unused-variable test.cpp` **(GCC compat)** |
| **Treat diagnostic as error** | `icpx -Wall -Werror test.cpp` | `icc -diag-error=177 test.cpp` |

## Diagnostic Format

### ICX (Clang-style)
```
test.cpp:4:9: warning: unused variable 'X' [-Wunused-variable]
    4 |     int X;
      |         ^
```
**Enable**: `-Wall` (included by default) or `-Wunused-variable`  
**Disable**: `-Wno-unused-variable`

### ICC (Intel-style)
```
test.cpp(4): warning #177: variable "X" was declared but never referenced
      int X;
          ^
```
**Enable (native)**: `-diag-warning=177`  
**Disable (native)**: `-diag-disable=177`  
**Enable (GCC-compat)**: `-Wunused-variable`  
**Disable (GCC-compat)**: `-Wno-unused-variable`

## Unknown Pragma Handling

| Compiler | Default Behavior | Enable Warnings | Suppress Warnings |
|----------|------------------|-----------------|-------------------|
| **ICX** | Silently ignores | `-Wunknown-pragmas` or `-Wall` | `-Wno-unknown-pragmas` |
| **ICC** | Warns (warning #161) | Default | `-diag-disable=161` |

**Migration Warning**: ICC-specific pragmas (e.g., `#pragma simd`) are silently ignored by ICX! Use `-Wunknown-pragmas` during migration to detect this.

## Pragma Directives (ICX)

### Localized Suppression
```cpp
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"
    int X;  // No warning
#pragma clang diagnostic pop
    int Y;  // Warning appears
```

### File-wide Suppression
```cpp
#pragma clang diagnostic ignored "-Wunused-variable"
// All code after this point: no unused variable warnings
```

## Test Files

- `test.cpp` - Basic unused variable
- `test_pragma_section.cpp` - Localized pragma
- `test_pragma_file.cpp` - File-wide pragma  
- `test_multiple_unused.cpp` - Multiple unused variables

## Interesting Findings

1. **ICC's native diagnostic system**: `-diag-warning=177` (enable) / `-diag-disable=177` (disable)
2. **ICC accepts GCC-style flags** (`-Wunused-variable`, `-Wno-unused-variable`) for GCC compatibility
3. **ICC still reports in Intel format** (warning #177) even when using GCC-style `-W*` flags
4. **CRITICAL: `-Wall` behaves differently!**
   - ICX: `-Wall` **includes** unused variable warnings
   - ICC: `-Wall` **does NOT include** unused variable warnings (needs explicit `-diag-warning=177` or `-Wunused-variable`)
5. **ICX uses Clang/LLVM** - full Clang diagnostic compatibility (that's why it uses `-W*` flags natively)
6. **Unknown pragma handling differs!**
   - ICX: Silently ignores unknown pragmas by default (need `-Wunknown-pragmas` or `-Wall`)
   - ICC: Warns about unknown pragmas by default (more strict!)
   - **Migration risk**: ICC-specific pragmas like `#pragma simd` are silently ignored by ICX!
7. **ICC is deprecated** - transition to ICX recommended

## Useful Flags

### ICX/ICPX (Clang-based)
- `-Wall` - Enable all warnings (includes unused variables)
- `-Wunused-variable` - Enable unused variable warnings
- `-Wno-unused-variable` - Disable unused variable warnings
- `-Werror` - Treat warnings as errors
- `-Wno-error` - Don't treat warnings as errors

### ICC (Intel proprietary)
**Native Intel options:**
- `-Wall` - Enable all warnings (does NOT include unused variables!)
- `-diag-warning=177` - Enable unused variable warning (diagnostic ID 177)
- `-diag-error=177` - Enable unused variable as error (compilation fails)
- `-diag-disable=177` - Disable unused variable warning
- `-diag-enable=<id>` - Enable specific diagnostic by ID
- ⚠️ Note: `-diag-warning=177 -Werror` does NOT work! Use `-diag-error=177` instead
- `-diag-disable=10441` - Suppress ICC deprecation message

**GCC-compatible options (NOT Clang!):**
- `-Wunused-variable` - Enable unused variable warnings
- `-Wno-unused-variable` - Disable unused variable warnings

## Getting Help

```bash
icpx --help           # ICX help
icc --help            # ICC help
./run_exercises.sh    # Show exercise list
```
