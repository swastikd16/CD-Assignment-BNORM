#!/bin/bash

# Script to generate MATCH and MASK macros for a custom RISC-V instruction
# using the official riscv-opcodes tool.

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 \"<instruction_definition>\""
    echo "Example: $0 \"bnorm rd rs1 rs2 31..25=0 14..12=0 6..2=0x02 1..0=3\""
    exit 1
fi

INSTRUCTION_DEF="$1"
# Extract the instruction name (the first word)
INSN_NAME=$(echo "$INSTRUCTION_DEF" | awk '{print $1}')
INSN_UPPER=$(echo "$INSN_NAME" | tr '[:lower:]' '[:upper:]')

OPCODES_DIR="$HOME/src/cdAss/riscv-opcodes"

if [ ! -d "$OPCODES_DIR" ]; then
    echo "Error: riscv-opcodes directory not found at $OPCODES_DIR"
    echo "Make sure the repository is cloned in that location."
    exit 1
fi

cd "$OPCODES_DIR" || exit 1

echo "Generating macros for instruction: $INSN_NAME"

# Backup the original rv_i extension file
cp extensions/rv_i extensions/rv_i.bak

# Append the custom instruction to rv_i
echo "$INSTRUCTION_DEF" >> extensions/rv_i

# Run the parser
# We redirect standard output/error to /dev/null to keep the console clean
PYTHONPATH=src python3 -m riscv_opcodes -c rv_i > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "Error: riscv_opcodes parser failed. Check your instruction syntax."
    # Restore backup
    mv extensions/rv_i.bak extensions/rv_i
    exit 1
fi

# Extract the results from encoding.out.h
echo "----------------------------------------"
echo "Results:"
grep -E "#define (MATCH|MASK)_${INSN_UPPER}\b" encoding.out.h
grep -E "DECLARE_INSN\(${INSN_NAME}," encoding.out.h
echo "----------------------------------------"

# Restore the original rv_i file
mv extensions/rv_i.bak extensions/rv_i

echo "Cleanup complete. Original base instruction set restored."
