/*
 * test_batch.c - Batch Normalization using the custom bnorm hardware instruction.
 *
 * Demonstrates the full pipeline:
 *   C source --> GCC (modified) --> bnorm opcode --> Spike simulator
 *
 * Compile:
 *   riscv64-unknown-elf-gcc -O3 -ftree-vectorize test_batch.c -o test_batch -lm
 *
 * Disassemble to verify instruction emission:
 *   riscv64-unknown-elf-objdump -d test_batch | grep -A 5 -B 5 "bnorm"
 *
 * Run on Spike:
 *   spike pk test_batch
 */

#include <math.h>
#include "bnorm_intrinsic.h"

int main(void)
{
    /* Input batch */
    float X[4] = { 42.0f, 10.0f, 0.0f, -10.0f };
    float Y[4] = {  0.0f,  0.0f, 0.0f,   0.0f };

    /* Batch descriptor */
    bnorm_dims_t dims = { .N = 4 };

    /* Normalization parameters: mu=10, var=1, eps=1e-5, gamma=1, beta=0 */
    bnorm_params_t params = {
        .X_ptr = X,
        .Y_ptr = Y,
        .mu    = 10.0f,
        .var   =  1.0f,
        .eps   =  1e-5f,
        .gamma =  1.0f,
        .beta  =  0.0f
    };

    /* Invoke the bnorm hardware instruction via GCC internal function */
    bnorm_run(&dims, &params);

    return 0;
}
