# Live Demo Evaluation Commands

Run these commands sequentially in your terminal

### 1. Set Up Environment & Navigate to Folder
Run this to point your terminal to the newly built custom compiler.

```bash
export PATH=/home/swastik/opt/riscv/bin:$PATH
cd ~/src/cdAss
```

### 2. Clean Up Old Files
Run this to delete your old executable, see you compiling a brand new one live.

```bash
rm -f test_di test_di.dump
```

### 3. Compile the Code (With Auto-Vectorization Flags)
Run this to prove that your modified GCC toolchain understands the C instruction. 
We are intentionally passing the `-O3 -ftree-vectorize` flags! explicitly engaging the compiler's auto-vectorizer pass that we modified in `tree-vect-patterns.cc`.

```bash
riscv64-unknown-elf-gcc -O3 -ftree-vectorize test_di.c -o test_di -lm
```

### 4. Prove the Assembly Generation (Disassemble)
Run this to search the compiled binary for your custom hardware instruction.

```bash
riscv64-unknown-elf-objdump -d test_di | grep -A 5 -B 5 "bnorm"
```
*(Once this prints, point out the line that says `bnorm aX, aX, aX` )*

### 5. Run the Simulation (Proof of Concept)
Run this to show that the Spike Architectural Simulator natively executes the instruction and computes the correct batch normalization outputs.

```bash
spike pk test_di
```
