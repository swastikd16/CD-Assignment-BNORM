#!/bin/bash
# ===========================================================================
# add_custom_insn.sh
# Automates adding a new custom RISC-V instruction to the full toolchain.
#
# Usage:
#   bash add_custom_insn.sh <insn_name> <match_hex> [mask_hex]
#
# Example:
#   bash add_custom_insn.sh sigmoid 0x0000102b 0xfe00707f
# ===========================================================================

set -euo pipefail

# -- Colours -----------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC}  $*"; }
die()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

# -- Usage -------------------------------------------------------------------
usage() {
    echo -e "\n${BOLD}Usage:${NC}  bash add_custom_insn.sh <name> <match_hex> [mask_hex]\n"
    echo "  name       lowercase mnemonic     e.g.  sigmoid"
    echo "  match_hex  unique 32-bit opcode   e.g.  0x0000102b"
    echo "  mask_hex   bitmask  (optional)    default: 0xfe00707f"
    echo ""
    echo "  Available custom opcode slots:"
    echo "    custom-0  0x0b   <- used by bnorm"
    echo "    custom-1  0x2b   <- free"
    echo "    custom-2  0x5b   <- free"
    echo "    custom-3  0x7b   <- free"
    echo ""
    exit 1
}

[[ $# -lt 2 ]] && usage

# -- Arguments ---------------------------------------------------------------
INSN="${1,,}"           # lowercase: sigmoid
INSN_UP="${INSN^^}"     # uppercase: SIGMOID
MATCH="$2"
MASK="${3:-0xfe00707f}"

# -- Paths -------------------------------------------------------------------
ROOT=~/src/cdAss/riscv-gnu-toolchain
GCC=$ROOT/gcc/gcc
BINUTILS=$ROOT/binutils
SPIKE=$ROOT/spike
PROJECT=~/src/cdAss

RISCV_OPC_H=$BINUTILS/include/opcode/riscv-opc.h
RISCV_OPC_C=$BINUTILS/opcodes/riscv-opc.c
ENCODING_H=$SPIKE/riscv/encoding.h
RISCV_MK=$SPIKE/riscv/riscv.mk.in
INSNS_DIR=$SPIKE/riscv/insns
INTERNAL_FN=$GCC/internal-fn.def
OPTABS_DEF=$GCC/optabs.def
RISCV_MD=$GCC/config/riscv/riscv.md

# -- Guard: abort if already added -------------------------------------------
if grep -q "MATCH_${INSN_UP}" "$RISCV_OPC_H" 2>/dev/null; then
    die "Instruction '${INSN}' already exists. Aborting to prevent duplicates."
fi

echo ""
echo -e "${BOLD}=================================================${NC}"
echo -e "  Adding custom instruction: ${BOLD}${INSN_UP}${NC} (${INSN})"
echo "  MATCH = $MATCH   MASK = $MASK"
echo -e "${BOLD}=================================================${NC}"
echo ""

# ===========================================================================
# STEP 1: binutils/include/opcode/riscv-opc.h
# ===========================================================================
info "Step 1/8  riscv-opc.h  — declaring MATCH/MASK ..."
sed -i "/^#define MASK_BNORM/a #define MATCH_${INSN_UP} ${MATCH}\n#define MASK_${INSN_UP}  ${MASK}" \
    "$RISCV_OPC_H"
ok "riscv-opc.h patched"

# ===========================================================================
# STEP 2: binutils/opcodes/riscv-opc.c
# ===========================================================================
info "Step 2/8  riscv-opc.c  — registering in opcode table ..."
sed -i "/\"bnorm\".*match_opcode/a {\"${INSN}\",  0, INSN_CLASS_I, \"d,s,t\", MATCH_${INSN_UP}, MASK_${INSN_UP}, match_opcode, 0 }," \
    "$RISCV_OPC_C"
ok "riscv-opc.c patched"

# ===========================================================================
# STEP 3: spike/riscv/encoding.h
# ===========================================================================
info "Step 3/8  encoding.h   — DECLARE_INSN ..."
sed -i "/DECLARE_INSN(bnorm,/a DECLARE_INSN(${INSN}, MATCH_${INSN_UP}, MASK_${INSN_UP})" \
    "$ENCODING_H"
ok "encoding.h patched"

# ===========================================================================
# STEP 4: spike/riscv/insns/<insn>.h  (new file)
# ===========================================================================
info "Step 4/8  insns/${INSN}.h — creating execution logic ..."
cat > "$INSNS_DIR/${INSN}.h" << SPIKE_TEMPLATE
require_rv64;

/*
 * ${INSN}.h  -  Spike hardware execution logic for '${INSN} rd, rs1, rs2'
 *
 *   RS1  =  64-bit pointer to your input struct in RAM
 *   RS2  =  64-bit pointer to your parameter struct in RAM
 *   RD   =  return status written back to CPU register
 *
 * TODO: Replace the body below with your actual formula.
 */

uint64_t input_addr  = RS1;
uint64_t params_addr = RS2;

/* Helper: safely read a 32-bit IEEE-754 float from an MMU address */
auto load_float = [&](uint64_t addr) -> float {
    uint32_t b = MMU.load<uint32_t>(addr);
    union { uint32_t i; float f; } u;
    u.i = b;
    return u.f;
};

/* TODO: load parameters from RAM  */
// float p0 = load_float(params_addr + 0);
// float p1 = load_float(params_addr + 4);

/* TODO: compute your formula      */
// float result = <your formula>;

/* TODO: store result back to RAM  */
// union { uint32_t i; float f; } out;
// out.f = result;
// MMU.store<uint32_t>(output_addr, out.i);

/* Write success status to destination register */
WRITE_RD(1);
SPIKE_TEMPLATE
ok "insns/${INSN}.h created (fill in your formula)"

# ===========================================================================
# STEP 5: spike/riscv/riscv.mk.in
# ===========================================================================
info "Step 5/8  riscv.mk.in  — adding to build list ..."
# Use python to safely handle the backslash-continuation format
python3 - "$RISCV_MK" "$INSN" << 'PYEOF'
import sys
path, insn = sys.argv[1], sys.argv[2]
with open(path) as f:
    content = f.read()
content = content.replace('\tbnorm \\\n', f'\tbnorm \\\n\t{insn} \\\n')
with open(path, 'w') as f:
    f.write(content)
print(f"  inserted '{insn}' into riscv.mk.in")
PYEOF
ok "riscv.mk.in patched"

# ===========================================================================
# STEP 6: gcc/gcc/internal-fn.def
# ===========================================================================
info "Step 6/8  internal-fn.def — DEF_INTERNAL_OPTAB_FN ..."
sed -i "/DEF_INTERNAL_OPTAB_FN (BNORM,/a DEF_INTERNAL_OPTAB_FN (${INSN_UP}, ECF_CONST, ${INSN}, binary)" \
    "$INTERNAL_FN"
ok "internal-fn.def patched"

# ===========================================================================
# STEP 7: gcc/gcc/optabs.def
# ===========================================================================
info "Step 7/8  optabs.def   — OPTAB_D ..."
sed -i "/OPTAB_D (bnorm_optab,/a OPTAB_D (${INSN}_optab, \"${INSN}\$I\$a\")" \
    "$OPTABS_DEF"
ok "optabs.def patched"

# ===========================================================================
# STEP 8: gcc/gcc/config/riscv/riscv.md
# ===========================================================================
info "Step 8/8  riscv.md     — UNSPEC + define_insn ..."
python3 - "$RISCV_MD" "$INSN" "$INSN_UP" << 'PYEOF'
import sys
path, insn, insn_up = sys.argv[1], sys.argv[2], sys.argv[3]

new_block = f"""
;; Custom instruction: {insn}
(define_insn "riscv_{insn}"
  [(set (match_operand:DI 0 "register_operand" "=r")
        (unspec:DI [(match_operand:DI 1 "register_operand" "r")
                    (match_operand:DI 2 "register_operand" "r")]
                   UNSPEC_{insn_up}))]
  ""
  "{insn}\\t%0,%1,%2"
  [(set_attr "type" "arith")
   (set_attr "mode" "DI")])
"""

with open(path) as f:
    content = f.read()

# Part A: add UNSPEC constant after UNSPEC_BNORM
content = content.replace('  UNSPEC_BNORM\n', f'  UNSPEC_BNORM\n  UNSPEC_{insn_up}\n')

# Part B: insert define_insn block after the riscv_bnorm block
anchor = '(define_insn "riscv_bnorm"'
idx = content.find(anchor)
if idx == -1:
    print("ERROR: riscv_bnorm anchor not found", file=sys.stderr)
    sys.exit(1)
end = content.find('\n(', idx + 1)
if end == -1:
    end = len(content)
content = content[:end] + new_block + content[end:]

with open(path, 'w') as f:
    f.write(content)
print(f"  UNSPEC_{insn_up} and define_insn riscv_{insn} added to riscv.md")
PYEOF
ok "riscv.md patched"

# ===========================================================================
# Generate project-level interface files
# ===========================================================================
info "Generating ${INSN}_intrinsic.h ..."
cat > "$PROJECT/${INSN}_intrinsic.h" << HDR_EOF
#ifndef ${INSN_UP}_INTRINSIC_H
#define ${INSN_UP}_INTRINSIC_H

#include <stdint.h>

/*
 * ${INSN}_intrinsic.h  -  Application interface for the '${INSN}' instruction.
 *
 * Pipeline:
 *   ${INSN}_run() -> __builtin_riscv_${INSN} -> IFN_${INSN_UP}
 *   -> ${INSN}_optab -> define_insn "riscv_${INSN}" -> ${INSN} rd,rs1,rs2
 */

/* TODO: define the memory layout your instruction expects via RS1 */
typedef struct {
    /* fields at RS1 pointer */
} ${INSN}_input_t;

/* TODO: define the memory layout your instruction expects via RS2 */
typedef struct {
    /* fields at RS2 pointer */
} ${INSN}_params_t;

/**
 * ${INSN}_run() - Invoke the custom ${INSN} hardware instruction.
 */
static inline unsigned long
${INSN}_run(const ${INSN}_input_t *input, const ${INSN}_params_t *params)
{
    return __builtin_riscv_${INSN}(
        (unsigned long)input,
        (unsigned long)params
    );
}

#endif /* ${INSN_UP}_INTRINSIC_H */
HDR_EOF
ok "${INSN}_intrinsic.h created"

info "Generating test_${INSN}.c ..."
cat > "$PROJECT/test_${INSN}.c" << TEST_EOF
/*
 * test_${INSN}.c  -  Test for the custom '${INSN}' RISC-V instruction.
 *
 * Compile:
 *   riscv64-unknown-elf-gcc -O3 test_${INSN}.c -o test_${INSN} -lm
 *
 * Verify instruction was emitted:
 *   riscv64-unknown-elf-objdump -d test_${INSN} | grep -A5 -B5 "${INSN}"
 *
 * Run on Spike:
 *   spike pk test_${INSN}
 */
#include "${INSN}_intrinsic.h"

int main(void)
{
    ${INSN}_input_t  input  = { /* TODO: fill in your values */ };
    ${INSN}_params_t params = { /* TODO: fill in your values */ };

    ${INSN}_run(&input, &params);

    return 0;
}
TEST_EOF
ok "test_${INSN}.c created"

# ===========================================================================
# Final Summary
# ===========================================================================
echo ""
echo -e "${GREEN}${BOLD}=================================================${NC}"
echo -e "  SUCCESS: '${INSN}' has been added to the toolchain!"
echo -e "${GREEN}${BOLD}=================================================${NC}"
echo ""
echo "  Files modified (8 lines total across existing source):"
printf "    %-12s  %s\n" "binutils"  "$RISCV_OPC_H"
printf "    %-12s  %s\n" "binutils"  "$RISCV_OPC_C"
printf "    %-12s  %s\n" "spike"     "$ENCODING_H"
printf "    %-12s  %s\n" "spike"     "$RISCV_MK"
printf "    %-12s  %s\n" "gcc"       "$INTERNAL_FN"
printf "    %-12s  %s\n" "gcc"       "$OPTABS_DEF"
printf "    %-12s  %s\n" "gcc"       "$RISCV_MD"
echo ""
echo "  Files created:"
printf "    %s\n" "$INSNS_DIR/${INSN}.h        <- FILL IN YOUR FORMULA"
printf "    %s\n" "$PROJECT/${INSN}_intrinsic.h  <- FILL IN YOUR STRUCTS"
printf "    %s\n" "$PROJECT/test_${INSN}.c"
echo ""
echo "  Next steps:"
echo "    1.  Edit  insns/${INSN}.h        — write your Spike formula"
echo "    2.  Edit  ${INSN}_intrinsic.h    — define input/params structs"
echo "    3.  Rebuild:"
echo "          cd ~/src/cdAss/riscv-gnu-toolchain"
echo "          rm stamps/build-gcc-newlib-stage2"
echo "          make"
echo ""
