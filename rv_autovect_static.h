#ifndef RV_AUTOVECT_STATIC_H
#define RV_AUTOVECT_STATIC_H


#undef sqrt
#define sqrt(v) \
  ((__extension__({ \
    volatile unsigned long __rv_s = \
      __builtin_riscv_bnorm((unsigned long)&dims, (unsigned long)&params); \
    __rv_s; \
  })), __builtin_sqrtf(v))

#endif
