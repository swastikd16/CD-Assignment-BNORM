/*
 * test_scalar.c - Single-value Batch Normalization using the bnorm instruction.
 *
 * Demonstrates a single-element (N=1) invocation of the hardware instruction,
 * equivalent to computing the BNORM formula for one static scalar value.
 *
 * Compile:
 *   riscv64-unknown-elf-gcc -O3 test_scalar.c -o test_scalar -lm
 *
 * Disassemble:
 *   riscv64-unknown-elf-objdump -d test_scalar | grep -A 5 -B 5 "bnorm"
 *
 * Run:
 *   spike pk test_scalar
 */

#include <math.h>
#include "bnorm_intrinsic.h"

int main(void)
{
    /* Static scalar input */
    float X[1] = { 42.0f };
    float Y[1] = {  0.0f };

    bnorm_dims_t dims = { .N = 1 };

    bnorm_params_t params = {
        .X_ptr = X,
        .Y_ptr = Y,
        .mu    = 10.0f,
        .var   =  1.0f,
        .eps   =  1e-5f,
        .gamma =  1.0f,
        .beta  =  0.0f
    };

    /* Hardware computes: Y[0] = ((42 - 10) / sqrt(1 + 1e-5)) * 1 + 0 */
    bnorm_run(&dims, &params);

    return 0;
}
