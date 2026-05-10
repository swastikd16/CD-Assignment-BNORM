#ifndef SIGMOID_INTRINSIC_H
#define SIGMOID_INTRINSIC_H

#include <stdint.h>

/*
 * sigmoid_intrinsic.h  -  Application interface for the 'sigmoid' instruction.
 *
 * Pipeline:
 *   sigmoid_run() -> __builtin_riscv_sigmoid -> IFN_SIGMOID
 *   -> sigmoid_optab -> define_insn "riscv_sigmoid" -> sigmoid rd,rs1,rs2
 */

/* TODO: define the memory layout your instruction expects via RS1 */
typedef struct {
    /* fields at RS1 pointer */
} sigmoid_input_t;

/* TODO: define the memory layout your instruction expects via RS2 */
typedef struct {
    /* fields at RS2 pointer */
} sigmoid_params_t;

/**
 * sigmoid_run() - Invoke the custom sigmoid hardware instruction.
 */
static inline unsigned long
sigmoid_run(const sigmoid_input_t *input, const sigmoid_params_t *params)
{
    return __builtin_riscv_sigmoid(
        (unsigned long)input,
        (unsigned long)params
    );
}

#endif /* SIGMOID_INTRINSIC_H */
