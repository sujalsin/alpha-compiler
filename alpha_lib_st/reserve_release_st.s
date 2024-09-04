	.file	"reserve_release.c"
	.text
	.globl	main
	.type	main, @function
main:
.LFB0:
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$16, %rsp


# This example shows how to allocate and free space for record with this structure:
# 
# 	struct pair {
# 	   int x;	// size 4 bytes, offset 0 from start of block
# 	   int y;	// size 4 bytes, offset 4 from start of block
# 	};
#
# The corresponding C code to manipulate the structure is: 
#
# 	struct pair * a;
# 	a = (struct pair *) reserve(sizeof(*a));	// sizeof(*a) is 8 bytes (= 4 bytes + 4 bytes)
# 	(*a).x = 20;	// x is located at (*a)
# 	(*a).y = 45;	// y is located at (*a)+4
# 	printInteger((*a).y);
# 	printCharacter(10);	// '\n' has value 10
# 	release(a);


# CALL reserve(8)
	pushq	$8
	call	reserve		
	addq	$8, %rsp	

# Assign values into a->x and a->y
	movq	-32(%rsp), %rax	# put returned value, base pointer of struct (a), into %rax
	movq	%rax, -8(%rbp)	# preserve pointer to local memory on stack ( a = ... )

	movq	-8(%rbp), %rax	# put a into %rax
	movl	$20, 0(%rax)	# put value 20 into location pointed at by %rax --> (*a).x  (could also write just (%rax))
	movl	$45, 4(%rax)	# put value 45 into location 4(%rax) --> (*a).y

	movq	-8(%rbp), %rax	# put base pointer of struct (a) into %rax 

# CALL printCharacter('x')
	pushq	$120		# write argument ('x') onto stack
	call 	printCharacter 	# call alpha_lib_st function printCharacter
	addq	$8, %rsp	# restore stack pointer

# CALL printCharacter('=')
	pushq	$61		# write argument ('=') onto stack
	call 	printCharacter 	# call alpha_lib_st function printCharacter
	addq	$8, %rsp	# restore stack pointer

# CALL printInteger((*a).x)
	movq	-8(%rbp), %rax	# put a into %rax
	pushq	0(%rax)		# write argument ('\n') onto stack
	call	printInteger	# call alpha_lib_st function printInteger
	addq	$8, %rsp	# restore stack pointer

# CALL printCharacter('\n')
	pushq	$10		# write argument ('\n') onto stack
	call 	printCharacter 	# call alpha_lib_st function printCharacter
	addq	$8, %rsp	# restore stack pointer

# CALL printCharacter('y')
	pushq	$121		# write argument ('x') onto stack
	call 	printCharacter 	# call alpha_lib_st function printCharacter
	addq	$8, %rsp	# restore stack pointer

# CALL printCharacter('=')
	pushq	$61		# write argument ('=') onto stack
	call 	printCharacter 	# call alpha_lib_st function printCharacter
	addq	$8, %rsp	# restore stack pointer

# CALL printInteger((*a).y)
	movq	-8(%rbp), %rax	# put a into %rax
	pushq	4(%rax)		# write argument ('\n') onto stack
	call	printInteger	# call alpha_lib_st function printInteger
	addq	$8, %rsp	# restore stack pointer

# CALL printCharacter('\n')
	pushq	$10		# write argument ('\n') onto stack
	call 	printCharacter 	# call alpha_lib_st function printCharacter
	addq	$8, %rsp	# restore stack pointer

	movq	-8(%rbp), %rax	# put base pointer of struct (a) into %rax

# CALL release(a)
	pushq	%rax
	call	release		
	addq	$8, %rsp	
	
	movl	$0, %eax
	leave
	ret
.LFE0:
	.size	main, .-main
	.ident	"GCC: (GNU) 6.4.0"
	.section	.note.GNU-stack,"",@progbits
