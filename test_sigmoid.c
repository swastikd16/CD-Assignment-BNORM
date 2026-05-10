/*
 * test_sigmoid.c  -  Test for the custom 'sigmoid' RISC-V instruction.
 *
 * Compile:
 *   riscv64-unknown-elf-gcc -O3 test_sigmoid.c -o test_sigmoid -lm
 *
 * Verify instruction was emitted:
 *   riscv64-unknown-elf-objdump -d test_sigmoid | grep -A5 -B5 "sigmoid"
 *
 * Run on Spike:
 *   spike pk test_sigmoid
 */
#include "sigmoid_intrinsic.h"

int main(void)
{
    sigmoid_input_t  input  = { /* TODO: fill in your values */ };
    sigmoid_params_t params = { /* TODO: fill in your values */ };

    sigmoid_run(&input, &params);

    return 0;
}
