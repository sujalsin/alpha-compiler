# Alpha Language Compiler
## CSE 443 Compilers Carl Alphonce
### Matthew Liddiard, Sujal Singh, Tyler D'Angelo, Volodymyr Semenov
### PM: Nitin Pai

## Project Overview:
Takes an Alpha language program and compiles it into x86-64 assembly language code.

## Sprint 1:
#### Lexical Analyzer - 
Takes an Alpha language program file and converts the text into tokens.
#### Syntax Analyzer - 
Takes the tokens from the lexical analyzer and ensures the program is grammatically correct.
#### Integrated Analyzer - 
Combines the lexical and syntax analyzers.

### How to use:
#### Lexical Analyzer
> `make lexer_sa`  
> `./lexer input_filename.alpha output_filename.tok`

#### Syntax Analyzer
(Include specific commands here if needed)

#### Integrated Analyzer
> `make compiler`  
> `./alpha test_source_code/test_input1`

## Sprint 2:
#### Semantic Analyzer - 
Performs type checking and ensures that the program adheres to the semantic rules of the Alpha language.
#### Symbol Table - 
Manages scope and bindings for variables, functions, and types throughout the compilation process.
#### Intermediate Code Generation (ICG) - 
Generates an intermediate representation (IR) of the program that is easier to translate into assembly code.

### How to use:
#### Semantic Analyzer
(Include specific commands here if needed)

#### Symbol Table
(Include specific commands here if needed)

#### Intermediate Code Generation (ICG)
> `make icg`  
> `./alpha test_source_code/test_input2 -ir`

## Sprint 3:
#### Code Generation - 
Translates the intermediate representation into x86-64 assembly language code.
#### Optimizations - 
Performs basic optimizations to improve the performance of the generated code.

### How to use:
#### Code Generation
> `make code_gen`  
> `./alpha test_source_code/test_input3 -cg`

#### Optimizations
(Include specific commands here if needed)

## Sprint 4:
#### Final Integration - 
Integrates all the components (Lexical, Syntax, Semantic Analyzers, ICG, Code Generation, and Optimizations) into a single, fully functional compiler.
#### Testing and Validation - 
Runs a comprehensive suite of tests to validate the compiler's correctness and efficiency.

### How to use:
#### Final Integrated Compiler
> `make compiler`  
> `./alpha test_source_code/final_test_input.alpha`

#### Running Test Cases
> `make test`  
> `./run_tests`

## Additional Information:
For more details, refer to the Alpha language specification document and the provided test cases in the `test_source_code/` directory.
