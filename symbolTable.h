#ifndef include_overlap2
#define include_overlap2
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

typedef enum TypeCategory {
    INTEGER,
    ADDRESS,
    CHAR,
    BOOLEAN,
    UNDEFINED,
    RECORD,
    ARRAYMAPPING,
    FUNCTIONMAPPING
} TypeCategory;

typedef enum SymbolType {
    TYPE_,
    FUNC,
    VARIABLE
} SymbolType;

typedef struct RecordType { 
    struct Symbol *symbols;
} RecordType;

typedef struct ArrayMappingType {
    int dimensions;
    struct Symbol *elementType;
} ArrayMappingType;

typedef struct FunctionMappingType { 
    struct Symbol *returnType;
    struct Symbol *parameterType;
} FunctionMappingType;

typedef struct Type { // A type class that can be a primitive, record(struct) type, arrayMapping type, or functionMapping type
    int size;
    enum TypeCategory typeCategory;
    union {
        struct RecordType *recordType;   
        struct ArrayMappingType *arrayType;
        struct FunctionMappingType *functionType;
    };
} Type;

typedef struct Variable {
    struct Symbol *type;
    struct boolN *truelist;
    struct boolN *falselist;
    
} Variable;

typedef struct Function {
    void *codeblockPtr;
    bool as;
    struct Symbol *type;
} Function;

typedef struct boolN {
    int instr;
    struct boolN *next;
} boolN;

typedef struct Symbol { // Type, Function, or Variable
    char *name;
    int constBool;
    int recBool;
    int arrBool;
    struct Symbol *arrSym;
    enum SymbolType symbolType;
    union {
        struct Type type;    
        struct Function function;
        struct Variable variable; 
    };
    struct Symbol *next;
} Symbol;

typedef struct SymbolTable { // Symbol Table Node
    char *name;
    int line;
    int col;
    struct SymbolTable *parent;
    struct SymbolTable *child;
    struct SymbolTable *next;
    struct Symbol *entries;
} SymbolTable;


SymbolTable *symbolTableInit();

SymbolTable *createSubscope(SymbolTable *, int, int); 

Symbol *findSymbolInScope(SymbolTable *, char *);

Symbol *findSymbol(SymbolTable *, char *); 

bool insertSymbol(SymbolTable *, Symbol *);

bool insertSymbolGlobal(SymbolTable *, Symbol *); 

Symbol *createPrimitive(SymbolTable *, TypeCategory); 

Symbol *createVariableEntry(SymbolTable *, char *, Symbol *); 

Symbol *createFunctionEntry(SymbolTable *, char *, Symbol *, void *);

Symbol *createSymbol(SymbolTable *, char *, Symbol *);

Symbol *createSymbolWithoutScope(char *, Symbol *);

Symbol *createRecords(SymbolTable *, char *, Symbol *, int);

Symbol *createArrayMapping(SymbolTable *,char *, Symbol *, int, size_t); 

Symbol *createFunctionMapping(SymbolTable *, char *, Symbol *, Symbol *); 

void printGlobalScope(FILE *, SymbolTable *);

void recursivePrintTable(FILE *, SymbolTable *);

void recursivePrintSymbol(FILE *, Symbol *, int, int, int, int);

void recursivePrintRecord(FILE *, Symbol *);

char* custom_strdup(const char* s);

#endif
