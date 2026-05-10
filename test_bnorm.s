	.file	"test_bnorm.c"
	.option nopic
	.text
	.align	1
	.globl	bnorm_standard
	.type	bnorm_standard, @function
bnorm_standard:
	fadd.s	fa2,fa2,fa3
	fsub.s	fa1,fa0,fa1
	fmv.s.x	fa3,zero
	frflags	a4
	flt.s	a5,fa2,fa3
	fsflags	a4
	bne	a5,zero,.L6
	fsqrt.s	fa2,fa2
	fdiv.s	fa0,fa1,fa2
	fmadd.s	fa0,fa0,fa4,fa5
	ret
.L6:
	fmv.s	fa0,fa2
	addi	sp,sp,-32
	sd	ra,24(sp)
	fsw	fa5,12(sp)
	fsw	fa4,8(sp)
	fsw	fa1,4(sp)
	call	sqrtf
	flw	fa1,4(sp)
	flw	fa5,12(sp)
	flw	fa4,8(sp)
	fdiv.s	fa0,fa1,fa0
	ld	ra,24(sp)
	addi	sp,sp,32
	fmadd.s	fa0,fa0,fa4,fa5
	jr	ra
	.size	bnorm_standard, .-bnorm_standard
	.align	1
	.globl	bnorm_custom
	.type	bnorm_custom, @function
bnorm_custom:
	bnorm	fa0,fa0,fa1
	ret
	.size	bnorm_custom, .-bnorm_custom
	.ident	"GCC: (GNU) 15.2.0"
	.section	.note.GNU-stack,"",@progbits
