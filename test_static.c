#include <stdio.h>
#include <math.h>
#include "rv_autovect_static.h"


// Demonstrates a single-element (N=1) invocation of the hardware instruction, 
// equivalent to computing the BNORM formula for one static scalar value.

int main(void)
{
    /* --- Static Input Values (no loop, single scalar computation) --- */
    float x     = 42.0f;   /* Input value       */
    float mu    = 10.0f;   /* Mean              */
    float var   =  1.0f;   /* Variance          */
    float eps   =  1e-5f;  /* Epsilon (stability) */
    float gamma =  1.0f;   /* Scale (gamma)     */
    float beta  =  0.0f;   /* Shift (beta)      */

    /* Required by the hardware instruction (single-element arrays) */
    float X[1] = { x };
    float Y[1] = { 0.0f };

    typedef struct { unsigned int N; } bnorm_dims_t;
    typedef struct {
        float *X_ptr;
        float *Y_ptr;
        float mu;
        float var;
        float eps;
        float gamma;
        float beta;
    } bnorm_params_t;

    bnorm_dims_t   dims   = { 1 };
    bnorm_params_t params = { X, Y, mu, var, eps, gamma, beta };

    /* Batch Normalization equation — static values ONLY, no loop */
    float result = ((x - mu) / sqrt(var + eps)) * gamma + beta;

    return 0;
}
