**Name:** Swastik Dan  
**Roll No:** 24115094  
**Email:** swastikdan16@gmail.com  
**Group Number:** 10 (Batch Normalisation)

# RISC-V Custom Hardware Acceleration: Batch Normalization (`bnorm`)

## Project Overview

This project involves the complete end-to-end integration of a custom hardware instruction (`bnorm`) into the RISC-V ecosystem. The goal is to hardware-accelerate **Batch Normalization**—a critical algorithm heavily used in Machine Learning and AI workloads.

Unlike standard software projects that compile math into generic CPU instructions, this project implements **Hardware-Software Co-Design**. We modified the lowest levels of the GNU Compiler Collection (GCC), the RISC-V Assembler, and the Spike Architectural Simulator to recognize standard C equations, compile them into a custom 32-bit hardware opcode, and execute them natively on simulated silicon.

---
> **[ !! IMPORTANT !! ]** 
> - **Code Breakdown:** For a complete, line-by-line record of all modifications made to the toolchain, see [**RISCV_Code_Changes.md**](RISCV_Code_Changes.md).  
> - **Project Report:** For the full project documentation and comprehensive report, refer to [**Group10_Batch_Normalization_Documentation.pdf**](Group10_Batch_Normalization_Documentation.pdf).

---

## Toolchain Modifications Map

The following files within the `toolchain_modifications/` directory contain the core logic of our hardware-software integration:

```text
toolchain_modifications/
├── binutils/include/opcode/riscv-opc.h   ← MATCH/MASK defines
├── binutils/opcodes/riscv-opc.c           ← opcode table entry
├── spike/riscv/encoding.h                 ← DECLARE_INSN
├── spike/riscv/riscv.mk.in                ← build list
├── spike/riscv/insns/bnorm.h              ← execution logic
└── gcc/gcc/
    ├── internal-fn.def                    ← IFN_BNORM
    ├── optabs.def                         ← bnorm_optab
    ├── tree-vect-patterns.cc              ← pattern recognizer
    └── config/riscv/riscv.md              ← define_insn RTL
```

## System Architecture & Modification Pipeline

Our modifications span across three primary sub-systems of the RISC-V toolchain:

### 1. The Assembler (GNU Binutils)

Before the CPU can execute an instruction, the assembler must know how to translate human-readable text (`bnorm a5, a4, a3`) into a 32-bit binary machine code.

- **`binutils/include/opcode/riscv-opc.h`**:
  - Defined the custom 32-bit instruction encoding using the `custom-0` opcode space.
  - Added `#define MATCH_BNORM 0x0b` (The exact binary trigger for the instruction).
  - Added `#define MASK_BNORM 0xfe00707f` (The bitmask defining the operand locations).
- **`binutils/opcodes/riscv-opc.c`**:
  - Registered the instruction format string so the assembler understands which registers are required as inputs and outputs.

### 2. The Architectural Simulator (Spike)

Because we are inventing an instruction that doesn't exist on standard processors, we must teach the CPU emulator how to physically compute the math when it receives our 32-bit opcode.

- **`spike/riscv/insns/bnorm.h`**:
  - Contains the core C++ hardware simulation logic. It extracts 64-bit memory pointers from the registers, traverses the RAM to fetch array data, computes `Y = ((X - mu) / sqrt(var + eps)) * gamma + beta`, and writes the results back to memory.
- **`spike/disasm/disasm.cc` & `spike/riscv/encoding.h`**:
  - Registered the instruction into the disassembler so debugging tools (`objdump`) can successfully reverse-engineer the 32-bit binary back into the word `bnorm`.

### 3. The Compiler (GCC Auto-Vectorizer)

To bridge the gap between high-level C code and our new hardware, we modified the GCC compiler pipeline so it can automatically detect Batch Normalization math loops and replace them with our instruction.

- **`gcc/tree-vect-patterns.cc` (The Pattern Matcher)**:
  - Added `vect_recog_bnorm_pattern`. This intercepts the compiler's GIMPLE Abstract Syntax Tree (AST) during the `-ftree-vectorize` pass, hunting for loops that match our batch norm equation.
- **`gcc/internal-fn.def` (Middle-End Tracker)**:
  - Registered `IFN_BNORM` to represent the pattern internally while the compiler optimizes the code.
- **`gcc/optabs.def` (The Bridge)**:
  - Created `bnorm_optab` to connect the internal compiler function to a standardized hardware operation.
- **`gcc/config/riscv/riscv.md` (Machine Description)**:
  - Added `define_insn "riscv_bnorm"`. This Register Transfer Language (RTL) block maps the `optab` directly to the `bnorm \t%0,%1,%2` assembly text, finalizing the emission process.

---

## How to Compile and Run the Project

### Step 1: Initialize the Toolchain Environment

Point the terminal to our custom compiled RISC-V binaries.

```bash
export PATH=/home/swastik/opt/riscv/bin:$PATH
cd ~/src/cdAss
```

### Step 2: Compile the High-Level C Code

We compile `test_di.c`. Notice the inclusion of the `-O3 -ftree-vectorize` flags. This explicitly engages the Auto-Vectorizer compiler pass that we modified in `tree-vect-patterns.cc`.

```bash
riscv64-unknown-elf-gcc -O3 -ftree-vectorize test_di.c -o test_di -lm
```

### Step 3: Verify the Machine Code (Disassembly)

To prove the compiler successfully translated the math equation into our custom hardware instruction, we dump the binary to assembly.

```bash
riscv64-unknown-elf-objdump -d test_di | grep -A 5 -B 5 "bnorm"
```

_Expected Output: You will see the literal `bnorm` instruction mapped to CPU registers._

### Step 4: Execute on Simulated Silicon

Run the generated binary inside the Spike hardware simulator. The Spike engine will intercept the `bnorm` opcode and execute our custom batch normalization logic.

```bash
spike pk test_di
```

---

## Automation & Extensibility: `add_custom_insn.sh`

To make this project easily extensible, we developed a powerful automation script **(template)**: **`add_custom_insn.sh`**. This script allows anyone to add a brand-new custom RISC-V instruction to the entire toolchain (Binutils, Spike, and GCC) in a single command.

- **Purpose:** Automatically patches 8 different source files across the toolchain.
- **Usage:** `bash add_custom_insn.sh <insn_name> <match_hex>`
- **Documentation:** For detailed instructions on how to use this **template system** to add your own hardware accelerators, refer to [**Template_Documentation.md**](Template_Documentation.md).

---

## Automated Opcode Verification: `generate_opcode_macros.sh`

In addition to the patching system, we implemented a tool for **formal verification** of instruction encodings using the official `riscv-opcodes` framework.

- **Purpose:** Automatically calculates the exact `MATCH` and `MASK` binary values for any new instruction definition. It acts as a safety net to ensure custom opcodes do not conflict with the existing RISC-V ISA.
- **Usage:** `./generate_opcode_macros.sh "<instruction_definition>"`
- **Documentation:** For a deep dive into bit-field encoding and instruction set architecture (ISA) design, refer to [**Generate_Opcodes_Guide.md**](Generate_Opcodes_Guide.md).

---

## Why This Project Matters (Compiler Theory)

Standard software development relies on the CPU executing multiple sequential instructions (Fetch -> Load -> Subtract -> Divide -> Multiply -> Add -> Store) just to calculate one array element.

By designing the `bnorm` instruction, we collapsed an entire mathematical loop into **a single hardware dispatch**.
Furthermore, modifying GCC's AST-to-RTL pipeline (`tree-vect-patterns.cc` → `optabs` → `riscv.md`) demonstrates a profound mastery of **Compiler Optimization Passes**. We proved that standard, human-readable C syntax can be structurally analyzed by a compiler and offloaded natively to custom silicon, mimicking the exact design workflows used by companies like Apple and Google when designing modern AI accelerators.

---

## 👥 Group Members (Group 10)

| Roll No | Name | Role |
|---|---|---|
| **24115094** | **SWASTIK DAN** | **Rep** |
| 24115114 | YUG RAO WAGHMARE | Member |
| 24115006 | ADITYA BOXI | Member |
| 24115036 | DEVAM JIGNESH PAREKH | Member |
| 24115052 | KOULIK PODDAR | Member |
| 24115053 | KRIS KUMAR GUPTA | Member |
| 24115093 | SURENDRA MOOND | Member |
| 24115095 | SWASTIK SUNDAR PATTJOSHI | Member |
| 24115099 | TEMBHURNE PARAG PRAMOD | Member |
| 24115115 | YUGANTAR NAG | Member |

---

### Batch Normalization Formula

Batch normalization standardizes inputs within a mini-batch.

**1. Normalization:**
$$\hat{x} = \frac{x - \mu_B}{\sqrt{\sigma_B^2 + \epsilon}}$$

**2. Output Transformation:**
$$y = \gamma\hat{x} + \beta$$

**Where:**
*   $\mu_B$ = batch mean
*   $\sigma_B^2$ = batch variance
*   $\gamma, \beta$ = learnable parameters
*   $\epsilon$ = small constant for numerical stability
