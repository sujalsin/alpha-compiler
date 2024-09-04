#include "symbolTable.h"

int main(int argc, char **argv) {
    SymbolTable *current_scope = symbolTableInit(); // Global Scope 0
    Symbol *boolean = findSymbolInScope(current_scope, "Boolean");
    Symbol *char_ = findSymbolInScope(current_scope, "character");
    Symbol *address = findSymbolInScope(current_scope, "address");
    Symbol *integer = findSymbolInScope(current_scope, "integer");
    Symbol *char2int = createFunctionMapping(current_scope, "char2int", char_, integer);
    Symbol *recordSymbols = createSymbolWithoutScope("year", integer);
    Symbol *record1 = createRecords(current_scope, "record1", recordSymbols, 5);
    Symbol *string = createArrayMapping(current_scope,  "string", char_, 1, 1);
    Symbol *char2bool = createFunctionMapping(current_scope, "char2bool", char_, boolean);
    Symbol *int2Address = createFunctionMapping(current_scope, "int2address", integer, address);
    createFunctionEntry(current_scope, "ord", char2int, 0);
    createFunctionEntry(current_scope, "function3", int2Address, 0);
    createFunctionEntry(current_scope, "lowecase", char2bool, 0);

    current_scope = createSubscope(current_scope, 0, 2); // Scope 1
    createVariableEntry(current_scope, "flag", boolean);
    createVariableEntry(current_scope, "t", integer);
    current_scope = createSubscope(current_scope, 0, 3); // Scope 2
    createVariableEntry(current_scope, "flag2", address);
    createVariableEntry(current_scope, "t2", record1);
    current_scope = createSubscope(current_scope, 0, 4); // Scope 3
    createVariableEntry(current_scope, "void *", address);
    current_scope = createSubscope(current_scope->parent, 0, 5); // Scope 4 parent = 2
    createVariableEntry(current_scope, "string", string);
    current_scope = createSubscope(current_scope->parent, 0, 6); // Scope 5 parent = 2
    createVariableEntry(current_scope, "letter", char_);
    current_scope = createSubscope(current_scope->parent, 0, 7); // Scope 6 parent = 2
    current_scope = createSubscope(current_scope->parent, 0, 8); // Scope 7 parent = 2
    current_scope = createSubscope(current_scope, 0, 9); // Scope 8 parent = 7
    createVariableEntry(current_scope, "flag2", boolean);
    createVariableEntry(current_scope, "t2", integer);
    current_scope = createSubscope(current_scope->parent, 0, 10); // Scope 9 parent = 7
    current_scope = createSubscope(current_scope->parent->next->next->next, 0, 11); // Scope 10 parent = 4
    current_scope = createSubscope(current_scope, 0, 12); // Scope 11 parent = 10

    printGlobalScope(stdout, current_scope);
    return 0;
}

// SCOPES
// 1 -> 
// |
// V
// 2 -> 
// |
// V
// 3 -> 
// |
// V
// 8 -> 7 -> 6 -> 5 -> 4 -> 
// |              |
// V              V
// 10 -> 9 ->     11
//                |
//                V
//                12

// Traversal order 1 2 3 8 7 6 5 4 11 12 10 9


// NAME             : SCOPE  : PARENT : TYPE                 : Extra annotation
// -----------------:--------:--------:----------------------:-----------------------------
// Boolean          : 001001 :        : primitive            : type
// character        : 001001 :        : primitive            : type
// integer          : 001001 :        : primitive            : type
// string           : 001001 :        : 1 -> character       : type
// int2int          : 001001 :        : integer -> integer   : type
// string2int       : 001001 :        : string -> integer    : type
// square           : 001001 :        : int2int              : function
// entry            : 001001 :        : string2int           : function
// -----------------:--------:--------:----------------------:-----------------------------
// x                : 014014 : 001001 : integer              : parameter (of square)
// -----------------:--------:--------:----------------------:-----------------------------
// arg              : 021015 : 001001 : string               : parameter (of entry)
// record           : 021015 : 001001 : string               : parameter (of entry)
//      - x: int
//      - y: 
// input            : 021015 : 001001 : integer              : local
// expected         : 021015 : 001001 : integer              : local
// actual           : 021015 : 001001 : integer              : local
// result           : 021015 : 001001 : $_undefined_type     : local
// -----------------:--------:--------:----------------------:-----------------------------