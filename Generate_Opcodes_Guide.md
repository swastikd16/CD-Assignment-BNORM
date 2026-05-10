# RISC-V Custom Opcode Generator Guide

This guide explains how to use the automated `generate_opcode_macros.sh` script to quickly calculate the `MATCH` and `MASK` binary macros for any custom RISC-V instruction.

## Why Use This Tool?

When adding a custom instruction to the RISC-V toolchain (Binutils, GCC, Spike), you need exact hexadecimal `MATCH` and `MASK` values. Calculating these manually can lead to errors. This script utilizes the official `riscv-opcodes` Python parser to:
1. Verify that your opcode encoding is valid.
2. Ensure it doesn't accidentally conflict with existing instructions.
3. Automatically generate the exact `#define` macros formatted for your C headers.

## How to Run the Script

### 1. Make the Script Executable
Before running it for the first time, ensure it has execute permissions:
```bash
cd ~/src/cdAss
chmod +x generate_opcode_macros.sh
```

### 2. Run the Script
Pass your complete instruction definition as a single string (wrapped in quotes) to the script.

**Syntax:**
```bash
./generate_opcode_macros.sh "<instruction_name> <operands> <bitfields>"
```

### Where Do You Get These Values?

You design these values yourself based on the RISC-V ISA (Instruction Set Architecture) format. The definition string is composed of three parts:

1. **<instruction_name>**: The custom name you chose for your instruction (e.g., `bnorm`, `mod`, `sigmoid`).
2. **<operands>**: The registers your instruction uses. For example, `rd rs1 rs2` is used for a standard 3-register R-Type instruction, while `rd rs1` might be used for an I-Type instruction.
3. **<bitfields>**: This is where you explicitly tell the CPU hardware how to decode your instruction. You must define these specific binary fields:
   - **1..0=3**: This identifies the instruction as a standard 32-bit length instruction. You almost always leave this as `3`.
   - **6..2=...**: The main opcode. For custom hardware instructions, you typically pick an unused code from the standard `custom-0` to `custom-3` spaces (e.g., `0x02` for custom-0, `0x2b` for custom-1).
   - **14..12=...**: The `funct3` value (choose a number from `0` to `7`).
   - **31..25=...**: The `funct7` value (usually used in R-type instructions to differentiate them).

*Tip: You (the developer) choose the `funct3`, `funct7`, and `opcode` manually. The beauty of this script is that it will throw a parser error if you accidentally pick a combination that clashes with a standard RISC-V instruction!*

**Example (R-Type Instruction - `bnorm`):**
```bash
./generate_opcode_macros.sh "bnorm rd rs1 rs2 31..25=0 14..12=0 6..2=0x02 1..0=3"
```

**Example (I-Type Instruction - `custom_load`):**
```bash
./generate_opcode_macros.sh "custom_load rd rs1 31..20=0 14..12=2 6..2=0x03 1..0=3"
```

## Expected Output

The script temporarily injects your instruction into the toolchain parser, extracts the results, and cleans up after itself. You will see output resembling this:

```text
Generating macros for instruction: bnorm
----------------------------------------
Results:
#define MATCH_BNORM 0xb
#define MASK_BNORM 0xfe00707f
DECLARE_INSN(bnorm, MATCH_BNORM, MASK_BNORM)
----------------------------------------
Cleanup complete. Original base instruction set restored.
```

## Where Do These Values Go?

Once the script generates the `MATCH` and `MASK` values, you copy and paste them directly into your toolchain source files:
- **Binutils:** `binutils/include/opcode/riscv-opc.h`
- **Spike:** `spike/riscv/encoding.h`

## How It Works (Behind the Scenes)
1. **Backups:** Copies the standard `extensions/rv_i` file to a safe `.bak` backup.
2. **Injects:** Appends your custom instruction to the bottom of the `rv_i` file.
3. **Parses:** Invokes the Python-based `riscv_opcodes` official parser.
4. **Extracts:** Searches the generated `encoding.out.h` header for your new C macros.
5. **Restores:** Overwrites the modified `rv_i` with the original backup to keep your repository perfectly clean.
