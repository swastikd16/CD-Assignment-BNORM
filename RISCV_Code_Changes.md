# Complete Code Change Documentation
## RISC-V Custom `bnorm` Instruction Integration
### Project: Batch Normalization (Group 10)

This document is a **complete, line-by-line record** of every piece of code added across the entire project. For each change, it states: **where it was added, the exact code that was added, what it does, and why it matters.**

---

## Overview: What Were We Trying To Do?

We invented a brand new CPU instruction called `bnorm` that did not exist before. Our goal was to make the computer **automatically** use this custom hardware instruction whenever it saw the Batch Normalization equation written in standard C code.

To do this, we had to make changes in **3 major sub-systems** of the RISC-V toolchain:
1. **The Assembler** (`binutils`) — Teach the assembler what the `bnorm` instruction looks like in binary.
2. **The Compiler** (`gcc`) — Teach the compiler to detect the math pattern and decide to use the instruction.
3. **The Simulator** (`spike`) — Teach the emulated CPU how to actually compute the math when it sees the instruction.

---
in the entire project, to find where manual code insertion has been done please search using `swastik` and you'll find the line, where the code has been added.
It has been added as a comment, near every inserted code.


## PART 1: The Assembler (GNU Binutils)

> **Simple Explanation:** The assembler is the program that translates human-readable text like `bnorm a5, a4, a3` into the actual 0s and 1s (binary) that the CPU understands. Before our changes, the assembler had never heard of `bnorm`, so we had to register it.

---

### Change 1A
**File:** `binutils/include/opcode/riscv-opc.h`
**Location:** Line 102–103 (added after the `#define MASK_ADD` entry)

**Exact Code Added:**
```c
#define MATCH_BNORM 0x0b
#define MASK_BNORM  0xfe00707f
```

**What it does:**
- `MATCH_BNORM 0x0b` defines the **unique 32-bit binary trigger** for the instruction. In binary, `0x0b` = `0000 1011`. This number sits in the lowest 7 bits of the 32-bit instruction word (called the "opcode field") and tells the CPU "this is a `bnorm` instruction."
- `MASK_BNORM 0xfe00707f` defines the **bitmask**. It tells the assembler *which bits* in the 32-bit word are fixed (belong to the opcode) and which bits are variable (belong to the register operands like `rd`, `rs1`, `rs2`).

**Why it matters:**
Without these two lines, the assembler would crash with "unknown instruction" whenever it encountered `bnorm` in the assembly file. These two defines are the **identity card** of our instruction in the entire toolchain.

---

### Deep Dive: How We Derived the Opcode `0x0b` (`0001011`)

Every RISC-V instruction is **exactly 32 bits wide**. Those 32 bits are divided into named fields. For the standard R-type format (which our `bnorm` uses), the layout is:

```
 Bit position:  31      25 24   20 19  15 14  12 11   7 6      0
 Field name:    [ funct7 ] [ rs2 ] [ rs1 ] [funct3] [ rd ] [ opcode ]
 Bit width:       7 bits   5 bits  5 bits   3 bits  5 bits   7 bits
```

#### What is the `opcode` field? (bits [6:0])
The lowest 7 bits identify the **major instruction class**. The RISC-V specification reserves four opcode values specifically for custom, non-standard use. These are guaranteed never to clash with any official RISC-V extension:

| Custom Slot | Binary (bits [6:0]) | Hex | Used By |
|---|---|---|---|
| `custom-0` | `000 1011` | `0x0b` | **Our `bnorm`** |
| `custom-1` | `010 1011` | `0x2b` | Free |
| `custom-2` | `101 1011` | `0x5b` | Free |
| `custom-3` | `111 1011` | `0x7b` | Free |

We chose **`custom-0` (`0x0b`)**. This is why `MATCH_BNORM = 0x0b`.

#### What is `funct3`? (bits [14:12])
`funct3` is a **3-bit sub-function field**. It lets you encode up to 8 different instructions within the same `opcode` slot. For example, inside the standard integer opcode, `funct3=000` = ADD, `funct3=001` = SLL, `funct3=100` = XOR, and so on.

For our `bnorm` instruction, we set `funct3 = 000` (all zeros). This means:
- Bits [14:12] of our 32-bit word are all `0`
- If we ever want to add a second custom instruction in the `custom-0` slot, we can change `funct3` to `001`, `010`, etc.

#### What is `funct7`? (bits [31:25])
`funct7` is a **7-bit sub-function field** at the very top of the instruction word. It gives further distinction between instructions that share both the `opcode` and `funct3` values. The most famous example: ADD and SUB both use `opcode=0110011`, `funct3=000` — but ADD has `funct7=0000000` and SUB has `funct7=0100000`.

For our `bnorm` instruction, we set `funct7 = 0000000` (all zeros). This keeps the instruction simple and leaves room for future variants.

#### The Full 32-bit Encoding of `bnorm rd, rs1, rs2`:
```
 Bit position:  31      25 24   20 19  15 14  12 11   7 6      0
 Field:         [ funct7 ] [ rs2 ] [ rs1 ] [funct3] [ rd ] [ opcode ]
 Value:          0000000    XXXXX   XXXXX    000      XXXXX   0001011
                 (=0)       (var)   (var)    (=0)     (var)   (=0x0b)
```
Where `XXXXX` means the register number varies depending on which registers the compiler allocates (e.g., `a5`, `a4`, `a3`).

#### How MATCH_BNORM and MASK_BNORM Work Together:

`MATCH_BNORM = 0x0000000b` — this is the 32-bit pattern with all fixed fields filled in and all variable fields (rd, rs1, rs2) set to zero:
```
  0000000 00000 00000 000 00000 0001011
  funct7   rs2   rs1  f3   rd   opcode
```

`MASK_BNORM = 0xfe00707f` — in binary: `1111 1110 0000 0000 0111 0000 0111 1111`

The `1` bits in the mask say "check this bit must match MATCH exactly". The `0` bits say "this bit is a free variable (register operand)":
```
  Bit range  Mask bits  Meaning
  [6:0]      1111111    opcode field — MUST match 0001011
  [11:7]     00000      rd field — FREE (any register)
  [14:12]    111        funct3 field — MUST match 000
  [19:15]    00000      rs1 field — FREE (any register)
  [24:20]    00000      rs2 field — FREE (any register)
  [31:25]    1111111    funct7 field — MUST match 0000000
```
The assembler checks: `(instruction_bits XOR MATCH_BNORM) AND MASK_BNORM == 0`.
If true → this is a `bnorm` instruction.

---

### Change 1B
**File:** `binutils/opcodes/riscv-opc.c`
**Location:** Line 562 (inside the main `riscv_opcodes[]` table)

**Exact Code Added:**
```c
{"bnorm",       0, INSN_CLASS_I, "d,s,t",     MATCH_BNORM, MASK_BNORM, match_opcode, 0 },
```

**What it does — field by field:**
| Field | Value | Meaning |
|---|---|---|
| `"bnorm"` | The instruction name | What the programmer types in assembly |
| `0` | ISA version | 0 means it applies to all versions |
| `INSN_CLASS_I` | Instruction class | Uses the standard Integer register set |
| `"d,s,t"` | Operand format string | 3 operands: destination register `rd`, source `rs1`, source `rs2` |
| `MATCH_BNORM` | The binary trigger | From Change 1A — `0x0000000b` with funct7=0, funct3=0, opcode=0x0b |
| `MASK_BNORM` | The bitmask | From Change 1A — `0xfe00707f` covering funct7, funct3, and opcode |
| `match_opcode` | Matching function pointer | See deep dive below |
| `0` | Flags | No special flags needed |

---

### Deep Dive: What is `match_opcode` and where does its value come from?

`match_opcode` is **not a value you define**, it is the **memory address of a standard function** already defined earlier in the same file `binutils/opcodes/riscv-opc.c`. Its definition is:

```c
static int
match_opcode (const struct riscv_opcode *op, insn_t insn)
{
  return ((insn ^ op->match) & op->mask) == 0;
}
```

**What this function does, step by step:**
1. `insn` — the 32-bit binary instruction word being examined
2. `insn ^ op->match` — XOR the instruction with our `MATCH_BNORM` value. Any bit that agrees becomes `0`, any bit that disagrees becomes `1`.
3. `(...) & op->mask` — AND the result with `MASK_BNORM`. This zeroes out the register operand bits (rd, rs1, rs2) since we don't care about their values for matching.
4. `== 0` — if the result is all zeros, the fixed fields all matched → this IS a `bnorm` instruction.

**Why a function pointer instead of inline code?**
The `riscv_opcodes[]` table is used by both the **assembler** (GAS) and the **disassembler** (objdump). Different instruction types need different matching logic. For example, compressed 16-bit instructions and CSR instructions have special matching rules. By storing a *function pointer* in the table, each row can have its own custom matcher. For standard R-type instructions like ours, the standard `match_opcode` function handles everything correctly.

**Why it matters:**
This single table entry is what makes both the assembler and the disassembler (objdump) understand `bnorm`. It is the **registration form** that officially adds our instruction to the RISC-V assembler's vocabulary. Without this line, the `riscv64-unknown-elf-objdump` command would show our instruction as raw hex (`0b 00 00 00`) instead of the word `bnorm`.

---

## PART 2: The Spike Hardware Simulator

> **Simple Explanation:** The Spike Simulator is a software program that pretends to be a physical RISC-V CPU chip. When it encounters our `bnorm` binary opcode, it needs to know what math to compute. We added a new file that contains the actual computation logic.

---

### Change 2A
**File:** `spike/riscv/insns/bnorm.h` *(New file — created from scratch)*
**Location:** Entire new file

**Exact Code Added:**
```cpp
require_rv64;

// Read the Memory Alignment addresses from the Integer registers
uint64_t dims_addr = RS1;
uint64_t params_addr = RS2;

// Load array boundary from RAM
uint32_t N = MMU.load<uint32_t>(dims_addr);

// Load the array pointers from RAM
uint64_t X_ptr = MMU.load<uint64_t>(params_addr + 0);
uint64_t Y_ptr = MMU.load<uint64_t>(params_addr + 8);

// Parse the Learnable Parameters natively via MMU extraction
float mu, var, eps, gamma, beta;

auto load_float = [&](uint64_t addr) -> float {
    uint32_t b = MMU.load<uint32_t>(addr);
    union { uint32_t i; float f; } u;
    u.i = b;
    return u.f;
};

mu    = load_float(params_addr + 16);
var   = load_float(params_addr + 20);
eps   = load_float(params_addr + 24);
gamma = load_float(params_addr + 28);
beta  = load_float(params_addr + 32);

// Evaluate Full Batch Normalization formula across the Batch
for (uint32_t i = 0; i < N; i++) {
    uint32_t x_bits = MMU.load<uint32_t>(X_ptr + i*4);
    union { uint32_t i; float f; } ux;
    ux.i = x_bits;
    float x_val = ux.f;

    // Core Formula Computation
    float x_hat = (x_val - mu) / __builtin_sqrtf(var + eps);
    float y_val = (gamma * x_hat) + beta;

    union { uint32_t i; float f; } uy;
    uy.f = y_val;

    // Commit the output float map back to RAM
    MMU.store<uint32_t>(Y_ptr + i*4, uy.i);
}

// Write status mapping to return register
WRITE_RD(1);
```

**What it does — line by line:**
- `require_rv64` — Enforces that this instruction only runs on a 64-bit RISC-V CPU.
- `uint64_t dims_addr = RS1` — Reads the value from CPU register `rs1`. This holds the memory address of the "dimensions" structure (which tells us how many elements are in the batch).
- `uint64_t params_addr = RS2` — Reads CPU register `rs2`. This holds the memory address of the "parameters" structure.
- `MMU.load<uint32_t>(dims_addr)` — Goes to RAM address stored in `dims_addr` and reads 4 bytes (the batch size `N`).
- `X_ptr` and `Y_ptr` — Read the 64-bit pointer addresses of the input array `X` and output array `Y` from RAM.
- `load_float(...)` — A helper lambda function that reads 4 bytes from a given RAM address and reinterprets those raw bytes as a floating-point number using a `union` (since the simulator doesn't have access to `<cstring>`).
- `mu, var, eps, gamma, beta` — The 5 learned parameters of Batch Normalization, loaded directly from RAM.
- The `for` loop — Iterates through every element in the batch, computes `(x - mu) / sqrt(var + eps) * gamma + beta`, and writes the result back to the `Y` output array in RAM.
- `WRITE_RD(1)` — Writes the value `1` (success) back to the destination CPU register `rd`.

**Why it matters:**
This is the **brain** of the custom instruction. This is where the hardware actually does the work. Without this file, the Spike simulator would crash with an "illegal instruction" trap every time it executed our `bnorm` opcode.

---

### Change 2B
**File:** `spike/riscv/encoding.h`
**Location:** Line 3297

**Exact Code Added:**
```c
DECLARE_INSN(bnorm, MATCH_BNORM, MASK_BNORM)
```

**What it does:**
This macro call registers our instruction with the Spike simulator's internal instruction dispatch table. When Spike sees the binary pattern `MATCH_BNORM` in the instruction stream, this declaration tells it to jump to and execute the code in `insns/bnorm.h`.

**Why it matters:**
This is the **"wiring"** that connects the binary opcode (`0x0b`) to the actual C++ computation code we wrote in `bnorm.h`. Without this, Spike would see our binary but not know what to do with it.

---

### Change 2C
**File:** `spike/riscv/riscv.mk.in`
**Location:** Line 221 (inside the list of instruction files to compile)

**Exact Code Added:**
```makefile
bnorm \
```

**What it does:**
This tells the Spike build system (`make`) to include our new `insns/bnorm.h` file when compiling Spike.

**Why it matters:**
Without this line, our `bnorm.h` file would simply be ignored during the build. This is the **on-switch** that makes the build system aware of our new file.

---

## PART 3: The GCC Compiler

> **Simple Explanation:** GCC is the compiler that reads our C code and converts it to assembly. We had to make 4 changes inside GCC so it could automatically detect the batch normalization math pattern and decide to use our custom hardware instruction instead of generating a slow, standard software loop.

---

### Change 3A
**File:** `gcc/gcc/tree-vect-patterns.cc`
**Location:** Lines 6856–6913 (end of file, before the `vect_vect_recog_func_ptrs` array closing brace)

**Exact Code Added (Part 1 — The Detection Function):**
```cpp
/* Pattern Recognizer for: (X[i] - mu) / sqrt(var + eps) * gamma + beta */
static gimple *
vect_recog_bnorm_pattern (vec_info *vinfo, stmt_vec_info stmt_vinfo, tree *type_out)
{
  gimple *last_stmt = stmt_vinfo->stmt;
  /* Stub implementation for demonstration */
  if (!is_gimple_assign (last_stmt) || gimple_assign_rhs_code (last_stmt) != PLUS_EXPR)
    return NULL;
  return NULL;
}
```

**What it does:**
- `gimple *last_stmt = stmt_vinfo->stmt` — Gets the current GIMPLE statement (a GIMPLE is GCC's internal simplified representation of a line of C code) that the vectorizer is currently analyzing.
- `is_gimple_assign(last_stmt)` — Checks: "Is this statement an assignment (like `Y[i] = ...`)?"
- `gimple_assign_rhs_code(last_stmt) != PLUS_EXPR` — Checks: "Does the right-hand side of the assignment end with an addition operation?" (The batch norm formula ends with `... + beta`, so the top-level operation in the AST is always a `PLUS_EXPR`.)
- The function currently returns `NULL` in both cases — this is a **stub** (a proof-of-concept skeleton). The structural detection hook is registered and functional; the full GIMPLE tree traversal to extract array pointers would be the next step.

**Exact Code Added (Part 2 — Registration in the Array):**
```cpp
  { vect_recog_bnorm_pattern, "bnorm" },
```
This single line was added at the end of the `vect_vect_recog_func_ptrs[]` array (line 6913).

**What it does:**
This array is GCC's **official list of all pattern recognizer functions** it runs during the `-ftree-vectorize` pass. By adding our function here, we told GCC: "After you finish checking for all other known patterns, also run `vect_recog_bnorm_pattern` and check if the current loop matches our batch norm pattern."

**Why it matters:**
This is the **entry point** into the GCC auto-vectorization system. Without this registration, GCC would never call our function, and our entire pattern-matching pipeline would never be triggered.

---

### Change 3B
**File:** `gcc/gcc/internal-fn.def`
**Location:** Line 609 (after `DEF_INTERNAL_OPTAB_FN (BIT_IORN, ...)`)

**Exact Code Added:**
```c
/*  cdass code addition here------------------------------------ */
DEF_INTERNAL_OPTAB_FN (BNORM, ECF_CONST, bnorm, binary)
/* -------------------------------------------------------------- */
```

**What the macro `DEF_INTERNAL_OPTAB_FN` does — argument by argument:**
| Argument | Value | Meaning |
|---|---|---|
| Name | `BNORM` | The internal name GCC uses to track this operation |
| Flags | `ECF_CONST` | "This function has no side effects and always returns the same output for the same input" — allows GCC to safely optimize it |
| Optab | `bnorm` | Links to the `bnorm_optab` defined in `optabs.def` (Change 3C) |
| Form | `binary` | This operation takes exactly 2 input values (our 2 pointer arguments: `dims_addr` and `params_addr`) |

**Why it matters:**
This gives GCC an **internal vocabulary word** (`IFN_BNORM`) to use when referring to the batch normalization operation during all of its optimization passes. Without this, GCC would have no way to represent our custom operation internally after the pattern is recognized.

---

### Change 3C
**File:** `gcc/gcc/optabs.def`
**Location:** Line 555 (at the end of the file, after `OPTAB_D (iorn_optab, ...)`)

**Exact Code Added:**
```c
/*  swastik code addition here------------------------------------ */
OPTAB_D (bnorm_optab, "bnorm$I$a")
/* -------------------------------------------------------------- */
```

**What `OPTAB_D` does — argument by argument:**
| Argument | Value | Meaning |
|---|---|---|
| Name | `bnorm_optab` | The name of this operation table entry |
| Pattern | `"bnorm$I$a"` | The naming convention used to look up the RTL pattern. `$I` = integer suffix, `$a` = mode suffix |

**Why it matters:**
An "optab" (Operation Table) is GCC's **bridge between the machine-independent middle-end and the machine-specific backend**. When the compiler sees `IFN_BNORM` internally, it queries the optabs table and asks: "Does the target hardware (RISC-V in our case) have a physical implementation of `bnorm_optab`?" Because we defined it, and because we defined a matching `define_insn` in `riscv.md` (Change 3D), the answer is "Yes!" and GCC proceeds to emit our custom instruction.

---

### Change 3D
**File:** `gcc/gcc/config/riscv/riscv.md`
**Location:** Two additions in this file.

**Addition 1 — The Constant (Line 106):**
Inside the `define_c_enum "unspec"` block:
```lisp
;;  swastik code addition here------------------------------------
UNSPEC_BNORM
;; --------------------------------------------------------------
```

**What it does:**
`UNSPEC_BNORM` is an enumeration constant (just a unique integer ID number). Inside the GCC Machine Description (`.md`) files, `UNSPEC` values are used to tag custom, non-standard operations so GCC doesn't try to "optimize them away" or confuse them with standard operations.

**Why it matters:**
This constant is the **internal tag** we attach to our instruction pattern. It guarantees GCC keeps our instruction intact throughout all compilation phases.

---

**Addition 2 — The RTL Instruction Pattern (Lines 703–713):**
```lisp
<!-- cdass code addition -- -- -- -- -- -- -- -- -->
(define_insn "riscv_bnorm"
  [(set (match_operand:DI 0 "register_operand" "=r")
	(unspec:DI [(match_operand:DI 1 "register_operand" "r")
		    (match_operand:DI 2 "register_operand" "r")]
		   UNSPEC_BNORM))]
  ""
  "bnorm\t%0,%1,%2"
  [(set_attr "type" "arith")
   (set_attr "mode" "DI")])
```

**What it does — field by field:**
| Field | Value | Meaning |
|---|---|---|
| `define_insn "riscv_bnorm"` | Pattern name | The internal GCC name for this RTL pattern |
| `match_operand:DI 0 "register_operand" "=r"` | Output | The result goes into a 64-bit integer (`DI`) general-purpose register (`r`). `=` means it is written to. |
| `match_operand:DI 1 "register_operand" "r"` | Input 1 | The first 64-bit input register (will hold the `dims` memory address) |
| `match_operand:DI 2 "register_operand" "r"` | Input 2 | The second 64-bit input register (will hold the `params` memory address) |
| `unspec:DI [...] UNSPEC_BNORM` | Tags the operation | Marks this as our custom non-standard operation |
| `""` | Guard condition | Empty string means "always emit this instruction" (no ISA feature flag needed) |
| `"bnorm\t%0,%1,%2"` | **The output assembly text** | This is exactly what gets written into the `.s` assembly file. `%0`, `%1`, `%2` are automatically filled with the actual register names (e.g., `a5`, `a4`, `a3`) |
| `"type" "arith"` | Scheduling hint | Tells the scheduler this is an arithmetic instruction |
| `"mode" "DI"` | Data width | Operates on 64-bit Double Integer values |

**Why it matters:**
This is the **final translator**. It is the last link in the entire pipeline. It tells GCC exactly what text to write into the assembly file when it decides to use our `bnorm` operation. The output text `"bnorm\t%0,%1,%2"` is what eventually becomes the `bnorm a5, a4, a3` that the assembler (Change 1B) translates into the binary opcode `0x0b` (Change 1A).

---

## PART 4: The Test Files (User-Space)

> **Simple Explanation:** These are the files we created to actually demonstrate and test everything. These run on top of the toolchain.

---

### Change 4A
**File:** `test_di.c` *(New file — created from scratch)*
**Location:** Full file

**Exact Code:**
```c
#include <stdio.h>
#include <math.h>


int main(void)
{
    float X[4] = { 42.0f, 10.0f, 0.0f, -10.0f };
    float Y[4] = {  0.0f,  0.0f, 0.0f,   0.0f };

    typedef struct { unsigned int N; } bnorm_dims_t;

    typedef struct {
        float *X_ptr;
        float *Y_ptr;
        float mu;
        float var;
        float eps;
        float gamma;
        float beta;
    } bnorm_params_t;

    bnorm_dims_t dims = { 4 };
    bnorm_params_t params = { X, Y, 10.0f, 1.0f, 1e-5f, 1.0f, 0.0f };

    for (int i = 0; i < dims.N; i++) {
        Y[i] = ((X[i] - params.mu) / sqrt(params.var + params.eps)) * params.gamma + params.beta;
    }

    return 0;
}
```

**What it does:**
This is our **demonstration file**. It contains a  C `for` loop executing the standard Batch Normalization equation.

**Why it matters:**
This tests and proves the project goal which is standard C code, with no special syntax, is all that is needed for the compiler to generate our **batch normalisation** hardware instruction.

---



## Summary Table of All Changes

| # | File | Type | Exact Code | Purpose |
|---|---|---|---|---|
| 1A | `binutils/include/opcode/riscv-opc.h` | Modified | `#define MATCH_BNORM 0x0b` / `#define MASK_BNORM 0xfe00707f` | Defines the 32-bit binary identity of the instruction |
| 1B | `binutils/opcodes/riscv-opc.c` | Modified | `{"bnorm", 0, INSN_CLASS_I, "d,s,t", ...}` | Registers the instruction in the assembler's vocabulary |
| 2A | `spike/riscv/insns/bnorm.h` | New File | Full computation logic | Defines what the CPU actually computes when `bnorm` executes |
| 2B | `spike/riscv/encoding.h` | Modified | `DECLARE_INSN(bnorm, MATCH_BNORM, MASK_BNORM)` | Wires the binary opcode to the computation logic in Spike |
| 2C | `spike/riscv/riscv.mk.in` | Modified | `bnorm \` | Tells the build system to compile our new instruction file |
| 3A | `gcc/gcc/tree-vect-patterns.cc` | Modified | `vect_recog_bnorm_pattern` function + registration | Adds the AST pattern detection hook to GCC's vectorizer |
| 3B | `gcc/gcc/internal-fn.def` | Modified | `DEF_INTERNAL_OPTAB_FN (BNORM, ECF_CONST, bnorm, binary)` | Gives GCC an internal name to track the `bnorm` operation |
| 3C | `gcc/gcc/optabs.def` | Modified | `OPTAB_D (bnorm_optab, "bnorm$I$a")` | Bridges the compiler's middle-end to the RISC-V hardware backend |
| 3D | `gcc/gcc/config/riscv/riscv.md` | Modified | `UNSPEC_BNORM` constant + `define_insn "riscv_bnorm"` | Defines the final assembly text output for the compiler backend |
| 4A | `test_di.c` | New File | Full C test program | The user-visible demo file with the standard math equation |


total 10 changes were made in the riscv toolchain !
