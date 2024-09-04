#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <stdio.h>

#include "symbolTable.h"
#include "ICG.h"

char Primitives[5][20] = {"integer", "address", "character", "Boolean", "$_undefined_type"};
char reverseTypeCategory[8][16] = {"Primitive", "Primitive", "Primitive", "Primitive", "Undefined", "Record", "ArrayMapping", "FunctionMapping"};

// Initializes a Symbol Table
// returns a pointer to an empty SymbolTable, the "Global Scope"
SymbolTable *symbolTableInit() {
    SymbolTable *globalScope = malloc(sizeof(SymbolTable));
    globalScope->parent = NULL;
    globalScope->child = NULL;
    globalScope->next = NULL;
    globalScope->entries = NULL;
    globalScope->line = 1;
    globalScope->col = 1;
    for(int i=0; i<5; i++){
        createPrimitive(globalScope,i);
    }
    return globalScope;
}

// Creates a new SymbolTable inserted underneath the current scope
// returns a pointer to the new empty SymbolTable, the subscope
SymbolTable *createSubscope(SymbolTable *currentScope, int line, int col) {
    SymbolTable *newScope = malloc(sizeof(SymbolTable));
    newScope->line = line;
    newScope->col = col;
    newScope->parent = currentScope;
    newScope->child = NULL;
    newScope->next = currentScope->child;
    newScope->entries = NULL;
    currentScope->child = newScope;
    return newScope;
}

// Given the current scope and the name of a symbol, find it in only the current scope
// returns null if it is not found in the current scope
Symbol *findSymbolInScope(SymbolTable *currentScope, char *name) {
    Symbol *variables = currentScope->entries;
    while (variables != NULL) {             // loop through all variables in each scope 
        if (strcmp(name, variables->name) == 0) {  
            return variables;               // return the variable found
        }
        variables = variables->next;        // variable was not found, prepare for next variable
    }
    return NULL;
}

Symbol *findSymbol(SymbolTable *currentScope, char *name) {
    while (currentScope != NULL) { // loop through all scopes accessible
        Symbol *var = findSymbolInScope(currentScope, name);
        if (var != NULL) {
            return var;
        }
        // if current scope is a function, parent is global
        currentScope = currentScope->parent;        // variable was not found, prepare next scope
    }
    return NULL; // could not find var
}

// Inserts Symbol to the current scope
// returns symbol if successful
// returns NULL if a symbol with the same name is already in the current scope
bool insertSymbol(SymbolTable *currentScope, Symbol *symbol) {
    if (findSymbolInScope(currentScope, symbol->name) == NULL) {
        // add symbol to scope
        symbol->next = currentScope->entries;
        currentScope->entries = symbol;
        return true;
    }
    return false; // variable of same name already created
}

bool insertSymbolGlobal(SymbolTable *currentScope, Symbol *symbol) {
    while (currentScope->parent != NULL) {      // go to Global Scope
        currentScope = currentScope->parent;
    }
    if (findSymbolInScope(currentScope, symbol->name) == NULL) {
        // add symbol to scope
        symbol->next = currentScope->entries;
        currentScope->entries = symbol;
        return true;
    }
    return false; // variable of same name already created
}

// Creates primitives
Symbol *createPrimitive(SymbolTable *globalScope, TypeCategory type) {
    Symbol *symbol = malloc(sizeof(Symbol));
    symbol->name = Primitives[type];
    symbol->symbolType = TYPE_;
    symbol->type.typeCategory=type;
    symbol->type.size = 8;

    if(!insertSymbolGlobal(globalScope, symbol)){
        free(symbol);
        return NULL;
    }
    return symbol;
}

Symbol *createVariableEntry(SymbolTable *currentScope, char *name, Symbol *type) {
    Symbol *symbol = malloc(sizeof(Symbol));
    symbol->name = custom_strdup(name);
    symbol->symbolType = VARIABLE;
    symbol->next = NULL;
    symbol->variable.type = type;
    symbol->variable.truelist = malloc(sizeof(boolN));
    symbol->variable.falselist = malloc(sizeof(boolN));
    symbol->variable.truelist->next = NULL;
    symbol->variable.falselist->next = NULL;
    symbol->constBool = 0;
    symbol->recBool = 0;
    symbol->arrBool = 0;
    symbol->arrSym = malloc(sizeof(Symbol));
    symbol->arrSym = NULL;
    
    if(!insertSymbol(currentScope, symbol)){
        free(symbol);
        return NULL;
    }

    return symbol;
}

Symbol *createFunctionEntry(SymbolTable *currentScope, char *name, Symbol *type, void *codeBlockPointer) {
    Symbol *symbol = malloc(sizeof(Symbol));
    symbol->name = name;
    symbol->symbolType = FUNC;
    symbol->next = NULL;
    symbol->function.codeblockPtr = malloc(sizeof(void*));
    symbol->function.codeblockPtr=codeBlockPointer;
    symbol->function.as = false;
    symbol->function.type = type;
    if(!insertSymbolGlobal(currentScope, symbol)){
        free(symbol);
        return NULL;
    }
    return symbol;
}

Symbol *createSymbol(SymbolTable *scope, char *name, Symbol *type) {
    Symbol *symbol = createSymbolWithoutScope(name, type);

    if(!insertSymbol(scope, symbol)){
        return NULL;
    }
    
    return symbol;
}

Symbol *createSymbolWithoutScope(char *name, Symbol *type) {
    Symbol *symbol = malloc(sizeof(Symbol));
    if (symbol == NULL) {
        return NULL;
    }
    symbol->name = name;
    symbol->symbolType = VARIABLE;
    symbol->next = NULL;
    symbol->variable.type = type;
    symbol->variable.truelist = malloc(sizeof(boolN));
    symbol->variable.falselist = malloc(sizeof(boolN));
    symbol->variable.truelist->next = NULL;
    symbol->variable.falselist->next = NULL;
    symbol->constBool = 0;
    symbol->recBool = 0;
    symbol->arrBool = 0;
    symbol->arrSym = malloc(sizeof(Symbol));
    symbol->arrSym = NULL;
    return symbol;
}

Symbol *createRecords(SymbolTable *scope, char *name, Symbol *fields, int size) {
    Symbol *symbol = malloc(sizeof(Symbol));
    symbol -> symbolType= TYPE_;
    symbol -> name = name;
    symbol -> type.typeCategory = RECORD;
    symbol -> type.recordType = malloc(sizeof(RecordType));
    symbol -> type.recordType->symbols = fields;
    symbol -> type.size = size * 8;

    if(!insertSymbolGlobal(scope, symbol)){
        return NULL;
    }
    return symbol;
}

Symbol *createArrayMapping(SymbolTable *currentScope, char *name, Symbol *type, int dimensions, size_t size) {
    Symbol *symbol = malloc(sizeof(Symbol));
    symbol->name = custom_strdup(name);
    symbol->symbolType = TYPE_;
    symbol->type.size = 0;
    symbol->type.typeCategory = ARRAYMAPPING;
    symbol->type.arrayType = malloc(sizeof(ArrayMappingType));
    symbol->type.arrayType->elementType = type;
    symbol->type.arrayType->dimensions = dimensions;
    if(!insertSymbolGlobal(currentScope, symbol)){
        free(symbol);
        return NULL;
    }
    return symbol;
}

// Creates a new Symbol for a MAPPING FUNCTYPE variable
// returns a pointer to the new MAPPING FUNCTYPE symbol
Symbol *createFunctionMapping(SymbolTable *currentScope, char *name, Symbol *parameterType, Symbol *returnType) {
    Symbol *symbol = malloc(sizeof(Symbol));
    symbol->name = name;
    symbol->symbolType = TYPE_;
    symbol->type.size = 0;
    symbol->type.typeCategory = FUNCTIONMAPPING;
    symbol->type.functionType = malloc(sizeof(FunctionMappingType));
    symbol->type.functionType->returnType = returnType;
    symbol->type.functionType->parameterType = parameterType;
    if(!insertSymbol(currentScope, symbol)){
        free(symbol);
        return NULL;
    }
    return symbol;
}

void printGlobalScope(FILE *file, SymbolTable *anyScope) {
    SymbolTable *currentScope = anyScope;
    while (currentScope->parent != NULL) {      // go to Global Scope
        currentScope = currentScope->parent;
    }
    fprintf(file, "NAME                              : SCOPE  : PARENT : TYPE                             : Extra annotation\n");
    fprintf(file, "----------------------------------:--------:--------:----------------------------------:-----------------------------\n");
    recursivePrintTable(file, currentScope);      
}

void recursivePrintTable(FILE *file, SymbolTable *currentScope) {
    if(currentScope == NULL){
        return;
    }
    SymbolTable *child = currentScope->child;
    SymbolTable *neighbor = currentScope->next;
    int sline = currentScope->line;
    int scol = currentScope->col;
    int pline = currentScope->parent? currentScope->parent->line : 0;
    int pcol = currentScope->parent? currentScope->parent->col : 0;
    recursivePrintSymbol(file, currentScope->entries, sline, scol, pline, pcol);
    fprintf(file, "----------------------------------:--------:--------:----------------------------------:-----------------------------\n");

    recursivePrintTable(file, neighbor);
    recursivePrintTable(file, child);      
}

void recursivePrintSymbol(FILE *file, Symbol *entry, int sline, int scol, int pline, int pcol) {
    if (entry == NULL) {
        return;
    }
    recursivePrintSymbol(file, entry->next, sline, scol, pline, pcol);
    char type[33];
    char *extra;
    switch(entry->symbolType)
    {
        case 0: extra = reverseTypeCategory[entry->type.typeCategory];
            switch(entry->type.typeCategory)
            {
                case UNDEFINED: snprintf(type, sizeof(type), "%s", "Undefined");
                    break;
                case RECORD: snprintf(type, sizeof(type), "%s", "Record");
                    break;
                case ARRAYMAPPING:
                    snprintf(type, sizeof(type), "%i -> %s", entry->type.arrayType->dimensions, entry->type.arrayType->elementType->name);
                    break;
                case FUNCTIONMAPPING:
                    snprintf(type, sizeof(type), "%s -> %s", entry->type.functionType->parameterType->name, entry->type.functionType->returnType->name);
                    break;
                default: 
                    snprintf(type, sizeof(type), "%s", "Primitive");
            }
            break;
        case 1: extra = "Function";
            snprintf(type, sizeof(type), "%s", entry->function.type->name);
            break;
        case 2: extra = "Variable";
            snprintf(type, sizeof(type), "%s", entry->variable.type->name);
            break;
    }
    fprintf(file, "%-34s: %03i%03i : %03i%03i : %-33s: %-28s\n", entry->name, sline, scol, pline, pcol, type, extra);

    if((entry->symbolType == TYPE_) && entry->type.typeCategory == RECORD) {
        recursivePrintRecord(file, entry->type.recordType->symbols);
    }
}

void recursivePrintRecord(FILE *file, Symbol* symbols) {
    if (symbols == NULL) {
        return;
    }
    fprintf(file, " - %s: %s\n", symbols->name, symbols->variable.type->name);
    recursivePrintRecord(file, symbols->next);
}

char* custom_strdup(const char* s) {
    size_t len = strlen(s) + 1;
    char* newStr = (char*)malloc(len);
    if (newStr == NULL) return NULL;
    memcpy(newStr, s, len);
    return newStr;
}