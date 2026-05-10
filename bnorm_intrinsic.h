#ifndef BNORM_INTRINSIC_H
#define BNORM_INTRINSIC_H

#include <stdint.h>

/*
 * bnorm_intrinsic.h
 * -----------------
 * Application-level interface for the custom RISC-V bnorm instruction.
 *
 * Compiler Architecture:
 *   This header is the top layer of a 4-layer GCC extension pipeline:
 *
 *   [C Code] --> [IFN_BNORM / bnorm_optab]
 *           --> [define_insn "riscv_bnorm"] --> [bnorm rd, rs1, rs2]
 *
 *   Layer 1: gcc/gcc/internal-fn.def
 *     DEF_INTERNAL_OPTAB_FN (BNORM, ECF_CONST, bnorm, binary)
 *     Registers the operation as a GCC internal function (IFN_BNORM).
 *
 *   Layer 2: gcc/gcc/optabs.def
 *     OPTAB_D (bnorm_optab, "bnorm$I$a")
 *     Maps IFN_BNORM to a hardware optab entry, bridging the compiler
 *     middle-end to the RISC-V machine backend.
 *
 *   Layer 3: gcc/gcc/config/riscv/riscv.md
 *     (define_insn "riscv_bnorm" ...)
 *     RTL pattern that emits the literal assembly text "bnorm %0,%1,%2".
 *
 *   Layer 4: binutils/include/opcode/riscv-opc.h
 *     #define MATCH_BNORM 0x0b
 *     #define MASK_BNORM  0xfe00707f
 *     Assembler encoding for the 32-bit opcode.
 *
 * Instruction Operand Layout:
 *   bnorm  rd, rs1, rs2
 *          |    |    |
 *          |    |    +-- RS2: 64-bit pointer to bnorm_params_t in RAM
 *          |    +------- RS1: 64-bit pointer to bnorm_dims_t in RAM
 *          +------------ RD:  Return status (1 = success)
 */

/* --- Data Structures --- */

/**
 * bnorm_dims_t - Batch dimension descriptor.
 * @N: Number of elements in the batch to process.
 */
typedef struct {
    unsigned int N;
} bnorm_dims_t;

/**
 * bnorm_params_t - Batch normalization parameter block.
 *
 * Memory layout (mirroring Spike simulator extraction order):
 *   Offset  0: X_ptr   (8 bytes) - pointer to input float array
 *   Offset  8: Y_ptr   (8 bytes) - pointer to output float array
 *   Offset 16: mu      (4 bytes) - mean
 *   Offset 20: var     (4 bytes) - variance
 *   Offset 24: eps     (4 bytes) - epsilon (numerical stability)
 *   Offset 28: gamma   (4 bytes) - scale parameter
 *   Offset 32: beta    (4 bytes) - shift parameter
 */
typedef struct {
    float *X_ptr;
    float *Y_ptr;
    float  mu;
    float  var;
    float  eps;
    float  gamma;
    float  beta;
} bnorm_params_t;

/* --- Intrinsic Function --- */

/**
 * bnorm_run() - Invoke the bnorm hardware instruction.
 *
 * Calls the GCC internal function, which was
 * registered via internal-fn.def and lowers through bnorm_optab to
 * the "riscv_bnorm" RTL pattern, emitting a single bnorm opcode.
 *
 * The Spike simulator intercepts this opcode and executes:
 *   Y[i] = ((X[i] - mu) / sqrt(var + eps)) * gamma + beta
 * for all i in [0, N).
 *
 * @dims:   Pointer to a bnorm_dims_t describing the batch size.
 * @params: Pointer to a bnorm_params_t containing all BN parameters.
 * @return: 1 on success.
 */
static inline unsigned long
bnorm_run(const bnorm_dims_t *dims, const bnorm_params_t *params)
{
    return __builtin_riscv_bnorm(
        (unsigned long)dims,
        (unsigned long)params
    );
}

#endif /* BNORM_INTRINSIC_H */
