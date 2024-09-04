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
> make lexer_sa
> ./lexer input_filename.alpha output_filename.tok
#### Syntax Analyzer
>
#### Integrated Analyzer
> make compiler
> ./alpha test_source_code/test_input1

## Sprint 2: 
