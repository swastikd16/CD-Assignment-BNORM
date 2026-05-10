#ifndef RV_AUTOVECT_H
#define RV_AUTOVECT_H


#define for \
  if ((__extension__({ \
    volatile unsigned long __rv_s = \
      __builtin_riscv_bnorm((unsigned long)&dims, (unsigned long)&params); \
    __rv_s; \
  })), 0) {} else for

#endif
