#ifndef include_overlap1
#define include_overlap1

#include "symbolTable.h"
#include "stdbool.h"
// Quadruples
typedef enum LineType {
    CONSTANT,
    LABEL,
    ASSIGNMENT,
    CALL,
    PARAM,
    JUMP, 
    RET, 
    MEM
} LineType;

typedef enum OP { // If you change this, update reverseEnumOP
    COPYOP,             // UNARY 
    //Arithmetic
    ADDOP,
    SUBTRACTOP,
    MULTIPLYOP,
    DIVIDEOP,
    MODOP,
    NEGATIVEOP,         // UNARY
    //Memory
    RESERVEOP,          // UNARY
    RELEASEOP,          // UNARY
    // Boolean 
    // Won't be used for AssignInst. It will be handled with jumps
    OROP,
    ANDOP,
    LESSTHANOP,
    EQUALTOOP,
    NOTOP,              // UNARY
    TRUEOP,             // BINARY
    FALSEOP             // BINARY
} OP;

typedef enum ConstantType {
    ADDRESSCONST,
    BOOLEANCONST,
    CHARACTERCONST,
    INTEGERCONST
} ConstantType;

typedef enum JumpType {
    UNCONDITIONALJUMP,
    LESSTHANJUMP,
    EQUALJUMP
} JumpType;

typedef enum MemType {
    LEFT, 
    RIGHT, 
    BOTH
} MemType;

typedef enum ParamType {
    REC_, 
    NORMAL
} ParamType;


typedef struct Constant {
    enum ConstantType type;
    union {
        char *address;
        bool boolean;
        char character;
        int integer;
    };
    Symbol *result;
} Constant;

typedef struct Label {
    char *name;
    Symbol *params;
} Label;

typedef struct ReturnInst {
    Symbol *arg1;
} ReturnInst;

typedef struct MemInst{
    enum MemType type;
    Symbol *arg1;
    Symbol *arg2;
} MemInst;

typedef struct AssignInst {
    enum OP op;
    Symbol *arg1;         // For Unary and Binary
    Symbol *arg2;         // For Binary
    Symbol *result;
} AssignInst;

typedef struct JumpInst {
    enum JumpType jumpType;
    Symbol *arg1;         // For Unary and Binary
    Symbol *arg2;         // For Binary
    Label *jumpLabel;
} Jump;

typedef struct CallInst {
    Symbol *arg1;
    Symbol *result;
    int paramLen;
} CallInst;

typedef struct ParamInst {
    enum ParamType type;
    Symbol *arg1;
} ParamInst;

typedef struct Instruction {
    enum LineType type;
    union {
        Constant *constant;
        Label *label;
        AssignInst *assign;
        Jump *jump;
        CallInst *call;
        ParamInst *param;
        ReturnInst *returninst;
        MemInst *memInst;
    };
} Instruction;

typedef struct InstructionArray  {
    int maxSize;
    int currentLine;
    int currentVar;
    int currentLabel;
    struct Instruction **instructionArray;
} InstructionArray;

InstructionArray *instructionArrayInit();

char *generateCompilerLabel(InstructionArray *IA);

char *generateCompilerVar(InstructionArray *IA);

void doubleArraySize(InstructionArray *arr);

void addParameterInstructions(InstructionArray *arr, Symbol *params);

void addAssignmentInstruction(InstructionArray *arr, Symbol *, OP op, Symbol *, Symbol *);

void addConstantInstruction(InstructionArray *arr, Constant *);

Label *addLabel(InstructionArray *, char *, Symbol *);

void addInstruction(InstructionArray *arr, Instruction *i);

void printInstructionArray(FILE *file, InstructionArray *arr);

void printLine(FILE *file, Instruction *instruction, int lineno);

boolN *makeList(int i);

boolN* merge(boolN* p1, boolN* p2);

void backpatch(InstructionArray *arr, boolN *list, Label* actualLabel);

void addConditionalAndUnconditionalJumps(InstructionArray *arr, Symbol *arg1, Symbol *arg2, int op, boolN *truelist, boolN *falselist);

void addMem(InstructionArray *arr, int op, Symbol *arg1, Symbol *arg2);

void printlist(boolN *list);

void gen(InstructionArray *arr, int op, Symbol *symbol, int paramLen, Label *label, Symbol *result, int paramType, Symbol *offset);

#endif