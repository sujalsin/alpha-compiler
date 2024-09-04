alpha: parser
	rm -f parser.tab.c parser.tab.h parser.output lex.yy.c

parser: parser.tab.c lex.yy.c symbolTable.c ICG.c
	gcc -std=c11 -Wall -g -o alpha parser.tab.c lex.yy.c symbolTable.c ICG.c semantics.c cg.c

#-ferror-limit=1000

parser.tab.c: parser.y
	bison -d -v parser.y -Wcounterexamples

lex.yy.c: lexer.l
	flex lexer.l

# Clean
clean:
	rm -f lex.yy.c lexer
	rm -f parser.tab.c parser.tab.h parser.output alpha 
	rm -f st_test
	rm -f pp.txt
	rm -f *.tok
	rm -f *.st
	rm -f *.asc
	rm -f *.tc
	rm -f *.ir
	rm -f *.s

# Standalone SymbolTable Testing file
st_test: st_sa
	./st_test

st_sa:
	gcc -std=c11 -Wall -o st_test symbolTableTest.c  symbolTable.c

st_test_input:
	./alpha -st -tc test_source_code/test_input1.alpha
	./alpha -st -tc test_source_code/test_input2.alpha
	./alpha -st -tc test_source_code/test_input3.alpha
	./alpha -st -tc test_source_code/test_input4.alpha
	./alpha -st -tc test_source_code/test_input5.alpha
	./alpha -st -tc test_source_code/test_record.alpha
	./alpha -st -tc test_source_code/test_array.alpha
	./alpha -st -tc test_source_code/test_operations.alpha

st_test_p:
	./alpha -st -tc test_source_code/p0.alpha
	./alpha -st -tc test_source_code/p1.alpha
	./alpha -st -tc test_source_code/p2.alpha
	./alpha -st -tc test_source_code/p3.alpha

st_test_e:
	./alpha -st -tc test_source_code/e0.alpha
	./alpha -st -tc test_source_code/e1.alpha
	./alpha -st -tc test_source_code/e2.alpha
	./alpha -st -tc test_source_code/e3.alpha
	./alpha -st -tc test_source_code/e4.alpha

# Makefile to make executables from alpha source code files
# and also make executables from some sample assembly files execising the alpha library
#
# Carl Alphonce
# April 20, 2024

# The alpha compiler and flags (adjust the flags as needed)
AC := ./alpha
AFLAGS := -tok -asc -tc -st -ir -cg

# The preprocessor and flags (you should not adjust these)
CPP := cpp
CPPFLAGS := -P -x c

# Adjust for the library your team is using (register-based or stack-based parameter passing)

#ALPHA_LIB = alpha_lib_reg.s   ## Register-based parameter passing
ALPHA_LIB = alpha_lib_st/alpha_lib_st.s     ## Stack-based parameter passing

# Adjust for the parameter passing approach your compiler uses:
#   alpha_driver_reg.s for register-based parameter passing
#   alpha_driver_st.s for stack-based parameter passing
# This file provides a main function that packages up argv[1] (or "") as an alpha string
# (type 1->character) and calls entry with that argument

#ALPHA_DRIVER = alpha_driver_reg.s   ## Register-based parameter passing
ALPHA_DRIVER = alpha_lib_st/alpha_driver_st.s     ## Stack-based parameter passing


# Create an assembly (.s) file from an alpha source file
# This involves several steps:
%.s : %.alpha alpha 
	./alpha -tok -asc -tc -st -ir -cg $<

# Examples of assembly code using the alpha library files
# In these examples the calling code is in assembly, and defines main (so the driver is not included here)

# Example #1: calling the printBoolean function
printBoolean : printBoolean_st.s
	@gcc $< $(ALPHA_LIB) -no-pie -o $@

# Example #2: calling the printInt function
printInt : printInt_st.s
	@gcc $< $(ALPHA_LIB) -no-pie -o $@

# Example #3: calling the reserve and release functions
reserve_release : reserve_release_st.s
	@gcc $< $(ALPHA_LIB) -no-pie -o $@


# The rule for assembling .s files and linking them together (using the gcc compiler driver)
# to produce an executable (assuming no earlier make rule triggers first)

% : %.s $(ALPHA_LIB) $(ALPHA_DRIVER) 
	@gcc $< $(ALPHA_LIB) $(ALPHA_DRIVER) -no-pie -o $@

