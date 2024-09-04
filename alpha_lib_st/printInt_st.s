	.file	"printInt.c"
	.text
	.globl	main
	.type	main, @function
main:
.LFB0:
	pushq	%rbp
	movq	%rsp, %rbp

# CALL printInteger(10)
	pushq	$10		# write argument (10) to stack
	call	printInteger	# call alpha_lib_st function printInteger
	addq	$8, %rsp	# restore stack pointer

# CALL printCharacter('\n')
	pushq	$10		# write argument ('\n') onto stack
	call 	printCharacter 	# call alpha_lib_st function printCharacter
	addq	$8, %rsp	# restore stack pointer

	movl	$0, %eax
	leave
	ret
.LFE0:
	.size	main, .-main
	.section	.rodata
	.align 8
.LC0:
	.ident	"GCC: (GNU) 6.4.0"
	.section	.note.GNU-stack,"",@progbits
