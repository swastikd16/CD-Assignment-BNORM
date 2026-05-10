# `add_custom_insn.sh` — Usage Guide
## Template for Adding a Custom RISC-V Instruction to the Toolchain

This document is a step-by-step guide for using the automation script to add a new custom instruction to the RISC-V toolchain (Binutils assembler, Spike simulator, and GCC compiler) without manually editing 8 different source files.

---

## Prerequisites

Before running the script, make sure:

- [ ] The RISC-V toolchain has been successfully built at least once (`~/src/cdAss/riscv-gnu-toolchain/`)
- [ ] Your environment is set up: `export PATH=/home/swastik/opt/riscv/bin:$PATH`
- [ ] `python3` is available in your shell (`python3 --version`)
- [ ] You have decided on a **unique opcode value** for your instruction (see table below)

### Choosing Your Opcode (`match_hex`)

RISC-V reserves four "custom" opcode slots guaranteed never to conflict with any standard extension. Pick a free one:

| Slot | Opcode Bits [6:0] | Hex | Status |
|---|---|---|---|
| `custom-0` | `000 1011` | `0x0b` | ⛔ **Used by `bnorm`** |
| `custom-1` | `010 1011` | `0x2b` | ✅ Free - use this next |
| `custom-2` | `101 1011` | `0x5b` | ✅ Free |
| `custom-3` | `111 1011` | `0x7b` | ✅ Free |

To encode a second instruction in the same custom slot, vary bits `[14:12]` (funct3). For example, `custom-1` with `funct3=001`:
```
MATCH = base | (funct3 << 12) = 0x2b | (0x1 << 12) = 0x0000102b
```

---

## Step 1: Run the Script

Open a terminal in WSL and run:

```bash
cd ~/src/cdAss
bash add_custom_insn.sh <insn_name> <match_hex> [mask_hex]
```

| Argument | Required | Description | Example |
|---|---|---|---|
| `insn_name` | ✅ Yes | Lowercase instruction mnemonic | `sigmoid` |
| `match_hex` | ✅ Yes | Unique 32-bit opcode trigger | `0x0000102b` |
| `mask_hex` | ❌ Optional | Bitmask (default `0xfe00707f` for standard R-type) | `0xfe00707f` |

**Full example:**
```bash
bash add_custom_insn.sh sigmoid 0x0000102b
```

The script will print a coloured progress log as it patches each file. If it succeeds, you will see:

```
=================================================
  SUCCESS: 'sigmoid' has been added to the toolchain!
=================================================
```

> **If it fails:** The most common reason is that the instruction already exists. Check the error message- it will tell you exactly which file and what caused the problem.

---

## Step 2: Fill In Your Execution Logic (Spike)

**File:** `~/src/cdAss/riscv-gnu-toolchain/spike/riscv/insns/<insn_name>.h`

The script creates this file with a working skeleton. You must replace the `TODO` section with your actual formula.

**Open the file:**
```bash
code ~/src/cdAss/riscv-gnu-toolchain/spike/riscv/insns/sigmoid.h
```

**The skeleton looks like this:**
```cpp
require_rv64;

uint64_t input_addr  = RS1;   // RS1 holds pointer to your input data
uint64_t params_addr = RS2;   // RS2 holds pointer to your parameters

auto load_float = [&](uint64_t addr) -> float {
    uint32_t b = MMU.load<uint32_t>(addr);
    union { uint32_t i; float f; } u;
    u.i = b;
    return u.f;
};

// TODO: load parameters from RAM
// float p0 = load_float(params_addr + 0);

// TODO: compute your formula
// float result = <your formula>;

// TODO: store result back to RAM
// MMU.store<uint32_t>(output_addr, uy.i);

WRITE_RD(1);
```

**What you need to fill in:**

| `TODO` | What to Write | Example (sigmoid of a single float) |
|---|---|---|
| Load parameters | `MMU.load<...>` calls | `float x = load_float(input_addr + 0);` |
| Compute formula | Your math | `float result = 1.0f / (1.0f + __builtin_expf(-x));` |
| Store result | `MMU.store<...>` call | `MMU.store<uint32_t>(output_addr, uy.i);` |

**Memory layout reference:**
- `RS1` → points to your input struct → read with `MMU.load<uint32_t>(input_addr + offset)`
- `RS2` → points to your params struct → read with `MMU.load<uint32_t>(params_addr + offset)`
- 64-bit pointers: `MMU.load<uint64_t>()` (8 bytes)
- 32-bit floats: `MMU.load<uint32_t>()` (4 bytes)

---

## Step 3: Define Your Struct Layouts (Intrinsic Header)

**File:** `~/src/cdAss/<insn_name>_intrinsic.h`

The script creates this with empty struct definitions. You must fill them in to match the memory layout your Spike code expects.

**Open the file:**
```bash
code ~/src/cdAss/sigmoid_intrinsic.h
```

**Fill in the structs:**
```c
/* Memory layout read via RS1 pointer — must match insns/sigmoid.h offsets */
typedef struct {
    float x;      /* offset 0 — input value */
} sigmoid_input_t;

/* Memory layout read via RS2 pointer — must match insns/sigmoid.h offsets */
typedef struct {
    float *output; /* offset 0 — pointer to write result */
} sigmoid_params_t;
```

> **Important:** The byte offsets in your C structs **must exactly match** the `MMU.load` offset values you wrote in `insns/sigmoid.h`. If they don't match, the simulator will read garbage values.

---

## Step 4: Fill In Your Test File

**File:** `~/src/cdAss/test_<insn_name>.c`

The script creates a template test file. Fill in the struct values:

```bash
code ~/src/cdAss/test_sigmoid.c
```

**Replace the `TODO` placeholders:**
```c
int main(void)
{
    float output = 0.0f;

    sigmoid_input_t  input  = { .x = 5.0f };
    sigmoid_params_t params = { .output = &output };

    sigmoid_run(&input, &params);

    return 0;
}
```

---

## Step 5: Rebuild the Toolchain

After completing Steps 2–4, rebuild so GCC and Spike pick up your changes:

```bash
cd ~/src/cdAss/riscv-gnu-toolchain

# Delete the GCC build stamp to force recompilation
rm stamps/build-gcc-newlib-stage2

# Rebuild (takes several minutes)
make
```

---

## Step 6: Verify the Instruction Was Added

After the build completes, run these three commands to confirm everything works:

### 6a. Compile your test file
```bash
export PATH=/home/swastik/opt/riscv/bin:$PATH
cd ~/src/cdAss
riscv64-unknown-elf-gcc -O3 test_sigmoid.c -o test_sigmoid -lm
```

### 6b. Confirm the instruction appears in the binary
```bash
riscv64-unknown-elf-objdump -d test_sigmoid | grep -A 5 -B 5 "sigmoid"
```
✅ **Expected:** You should see a line containing `sigmoid  aX, aX, aX`

### 6c. Run on the Spike simulator
```bash
spike pk test_sigmoid
```
✅ **Expected:** The program exits with code `0` (no crash = instruction executed successfully)

---

## What the Script Modified Automatically

For reference, here is every change the script made to the toolchain source code without any manual intervention:

| File | Change Made | Lines |
|---|---|---|
| `binutils/include/opcode/riscv-opc.h` | Added `#define MATCH_SIGMOID` and `#define MASK_SIGMOID` | 2 |
| `binutils/opcodes/riscv-opc.c` | Added one row to the `riscv_opcodes[]` table | 1 |
| `spike/riscv/encoding.h` | Added `DECLARE_INSN(sigmoid, ...)` | 1 |
| `spike/riscv/riscv.mk.in` | Added `sigmoid \` to the build file list | 1 |
| `gcc/gcc/internal-fn.def` | Added `DEF_INTERNAL_OPTAB_FN(SIGMOID, ...)` | 1 |
| `gcc/gcc/optabs.def` | Added `OPTAB_D(sigmoid_optab, ...)` | 1 |
| `gcc/gcc/config/riscv/riscv.md` | Added `UNSPEC_SIGMOID` + `define_insn "riscv_sigmoid"` | ~12 |
| `test_sigmoid.c` | **Created** test program for sigmoid| ~20 |

---

## Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `Instruction 'X' already exists. Aborting.` | Script run twice with same name | Check `riscv-opc.h` — instruction is already there |
| `objdump` shows hex instead of mnemonic | Binutils not rebuilt | Run `make` again from `riscv-gnu-toolchain/` |
| `illegal instruction` trap in Spike | `DECLARE_INSN` or `riscv.mk.in` missing | Check `encoding.h` and the build list |
| Wrong output values | Struct offsets mismatch | Align C struct byte offsets with `MMU.load` offsets in `.h` |
| `__builtin_riscv_X: not found` | GCC not rebuilt after `internal-fn.def` change | Delete `stamps/build-gcc-newlib-stage2` and run `make` |

---

## Quick Reference Card

```
bash add_custom_insn.sh <name> <match>                                # 1. run script
code ~/src/.../spike/riscv/insns/<name>.h                             # 2. fill in formula
code ~/src/cdAss/<name>_intrinsic.h                                   # 3. fill in structs
code ~/src/cdAss/test_<name>.c                                        # 4. fill in test values
rm stamps/build-gcc-newlib-stage2 && make                             # 5. rebuild
riscv64-unknown-elf-gcc -O3 test_<name>.c -o ...                      # 6. compile test
riscv64-unknown-elf-objdump -d test_<name> | grep <name>              # 7. verify
spike pk test_<name>                                                  # 8. run on simulator
```
