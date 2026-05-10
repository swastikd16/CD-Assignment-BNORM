# The 32-Bit Instruction Breakdown for `bnorm`

When the C code is compiled into an executable, the GCC compiler generates the exact hexadecimal instruction `0x00e7878b` for our custom Batch Normalization hardware.

If you translate `0x00e7878b` into a 32-bit binary sequence, here is exactly how it fits into the official RISC-V R-Type Hardware format:

| `funct7` (7 bits) | `rs2` (5 bits) | `rs1` (5 bits) | `funct3` (3 bits) | `rd` (5 bits) | `opcode` (7 bits) |
| :---: | :---: | :---: | :---: | :---: | :---: |
| `0000000` | `01110` | `01111` | `000` | `01111` | `0001011` |

### What These Bits Mean to the CPU:

1. **`opcode` (`0001011`):** 
   * This equals `0x0b` in Hex. 
   * This is the empty `custom-0` space we found in the RISC-V manual and assigned to `bnorm`.
2. **`rd` (`01111`):** 
   * This is Decimal `15`. 
   * It tells the CPU to save the return status in register **`a5`**.
3. **`funct3` (`000`):** 
   * Set to zero (forced by our `MASK_BNORM` setting).
4. **`rs1` (`01111`):** 
   * This is Decimal `15`. 
   * It tells the CPU to read the "Dimensions Pointer" from register **`a5`**.
5. **`rs2` (`01110`):** 
   * This is Decimal `14`. 
   * It tells the CPU to read the "Parameters Pointer" from register **`a4`**.
6. **`funct7` (`0000000`):** 
   * Set to zero (forced by our `MASK_BNORM` setting).
