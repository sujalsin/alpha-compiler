	.file	"printBoolean.c"
	.text
	.globl	main
	.type	main, @function
main:
.LFB0:
	pushq	%rbp
	movq	%rsp, %rbp

# CALL printBoolean(true)
	pushq	$1		# write argument ('true') to stack
	call	printBoolean	# call alpha_lib_st function printBoolean
	addq	$8, %rsp	# restore stack pointer

# CALL printCharacter('\n')
	pushq	$10		# write argument ('\n') onto stack
	call 	printCharacter 	# call alpha_lib_st function printCharacter
	addq	$8, %rsp	# restore stack pointer

# CALL printBoolean(false)
	pushq	$0
	call	printBoolean
	addq	$8, %rsp

# CALL printCharacter('\n')
	pushq	$10
	call 	printCharacter 	
	addq	$8, %rsp	


	movl	$0, %eax
	leave
	ret
.LFE0:
	.size	main, .-main
	.ident	"GCC: (GNU) 6.4.0"
	.section	.note.GNU-stack,"",@progbits
