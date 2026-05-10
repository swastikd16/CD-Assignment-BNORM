#include <stdio.h>
#include "rv_autovect.h"
#include <math.h>


int main(void)
{
    // Simulate a mini-batch of 4 Floating Point inputs
    float X[4] = { 42.0f, 10.0f, 0.0f, -10.0f };
    float Y[4] = {  0.0f,  0.0f, 0.0f,   0.0f }; // Output Target Array
    
    // Define the Dimensions mapping struct
    typedef struct { 
        unsigned int N; 
    } bnorm_dims_t;
    
    // Define the Parameters mapping struct exactly mirroring Spike layout:
    // Pointers (8 bytes each) followed by 5 floats (4 bytes each)
    typedef struct { 
        float *X_ptr; 
        float *Y_ptr; 
        float mu; 
        float var; 
        float eps; 
        float gamma; 
        float beta; 
    } bnorm_params_t;

    bnorm_dims_t dims = { 4 };
    
    // Set parameters parameters: mu=10, var=1, eps=0.00001, gamma=1, beta=0
    bnorm_params_t params = { X, Y, 10.0f, 1.0f, 1e-5f, 1.0f, 0.0f };

    
    for (int i = 0; i < dims.N; i++) {
        Y[i] = ((X[i] - params.mu) / sqrt(params.var + params.eps)) * params.gamma + params.beta;
    }

    return 0;
}
