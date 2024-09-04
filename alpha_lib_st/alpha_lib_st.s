	.file	"alpha_lib.c"
	.section	.rodata
.LC0:
	.string	"%d"
	.text
	.globl	printInteger
	.type	printInteger, @function
printInteger:
.LFB2:
	pushq	%rbp		# push old base pointer
	movq	%rsp, %rbp	# move base pointer

	subq	$8, %rsp	# make room on stack
	movl	16(%rbp), %eax  # move argument to %eax
	movl	%eax, %esi
	movl	$.LC0, %edi
	movl	$0, %eax
	call	printf
	movl	$0, -8(%rbp)	# return 0 on the stack
	leave
	ret
.LFE2:
	.size	printInteger, .-printInteger

	.globl	printCharacter
	.type	printCharacter, @function
printCharacter:
.LFB4:
	pushq	%rbp
	movq	%rsp, %rbp

	subq	$8, %rsp
	xor	%eax, %eax
	movl	16(%rbp), %eax
	movl	%eax, %edi
	call	putchar
	movl	$0, -8(%rbp)	# return 0 on the stack
	leave
	ret
.LFE4:
	.size	printCharacter, .-printCharacter

	.section	.rodata
.LC2:
	.string	"false"
.LC3:
	.string	"true"
.LC4:
	.string	"%s"

	.text
	.globl	printBoolean
	.type	printBoolean, @function
printBoolean:
.LFB5:
	pushq	%rbp
	movq	%rsp, %rbp

	subq	$8, %rsp
	cmpb	$0, 16(%rbp)
	jne	.L8
	movl	$.LC2, %eax
	jmp	.L9
.L8:
	movl	$.LC3, %eax
.L9:
	movq	%rax, %rsi
	movl	$.LC4, %edi
	movl	$0, %eax
	call	printf
	movl	$0, -8(%rbp)	# return 0 on the stack
	leave
	ret
.LFE5:
	.size	printBoolean, .-printBoolean

	.globl	reserve
	.type	reserve, @function
reserve:
.LFB8:
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$8, %rsp
	movl	16(%rbp), %eax 	# put size of block requested into %eax
	cltq			# sign extend %eax to %rax
	movq	%rax, %rdi	# mv arg of malloc into expected %rdi register
	call	malloc		# malloc will leave its return value (8 bytes) in %rax
	movq 	%rax, -8(%rbp)	# put pointer return value past saved RBP
	movq	%rbp, %rsp
	popq	%rbp
	ret
.LFE8:
	.size	reserve, .-reserve

	.globl	release
	.type	release, @function
release:
.LFB9:
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$8, %rsp
	movq	16(%rbp), %rdi
	call	free
	movq	$0, -8(%rbp)	# return 0 on the stack 
	leave
	ret
.LFE9:
	.size	release, .-release

	.ident	"GCC: (GNU) 6.4.0"
	.section	.note.GNU-stack,"",@progbits
