#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

typedef struct VariableMemory {
    char *name;
    int offset;
    struct VariableMemory *next;
} VariableMemory;

typedef struct FunctionMemory {
    VariableMemory *variables;
    int topOfStack;
} FunctionMemory;

void assemblyCodeGeneration(FILE *, InstructionArray *);

void generateAssembly(Instruction *);

void getReg(Instruction *);

void loadFromStack(char *, char *);

void storeOnStack(char *, char *);