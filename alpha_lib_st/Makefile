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
ALPHA_LIB = alpha_lib_st.s     ## Stack-based parameter passing

# Adjust for the parameter passing approach your compiler uses:
#   alpha_driver_reg.s for register-based parameter passing
#   alpha_driver_st.s for stack-based parameter passing
# This file provides a main function that packages up argv[1] (or "") as an alpha string
# (type 1->character) and calls entry with that argument

#ALPHA_DRIVER = alpha_driver_reg.s   ## Register-based parameter passing
ALPHA_DRIVER = alpha_driver_st.s     ## Stack-based parameter passing


# Create an assembly (.s) file from an alpha source file
# This involves several steps:
%.s : %.alpha
	@mv $< $<._temporary_			# 1. rename input file so we can us it as 
	@$(CPP) $(CPPFLAGS) $<._temporary_ > $< # 2. input to CPP, writing output to original filename
	@$(AC) $(AFLAGS) $<			# 3. run the alpha compiler on the pre-processed file
	@mv $<._temporary_ $<			# 4. restore the original input file



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

