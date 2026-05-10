#include <stdio.h>
#include <math.h>


// this is a program to test the sigmoid function created using Template

int main(void)
{
    /* Static input values */
    float x1 = 5.0f;
    float x2 = 0.0f;
    float x3 = -3.0f;
    float x4 = 1.5f;

    /* Sigmoid formula: f(x) = 1 / (1 + e^(-x)) */
    float r1 = 1.0f / (1.0f + expf(-x1));
    float r2 = 1.0f / (1.0f + expf(-x2));
    float r3 = 1.0f / (1.0f + expf(-x3));
    float r4 = 1.0f / (1.0f + expf(-x4));

    printf("Sigmoid Results:\n");
    printf("sigmoid(%4.1f) = %f\n", x1, r1);
    printf("sigmoid(%4.1f) = %f\n", x2, r2);
    printf("sigmoid(%4.1f) = %f\n", x3, r3);
    printf("sigmoid(%4.1f) = %f\n", x4, r4);

    return 0;
}
