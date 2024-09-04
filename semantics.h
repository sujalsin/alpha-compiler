#ifndef include_overlap3
#define include_overlap3

#include "symbolTable.h"
#include "ICG.h"

// How do we know if arr(10) is going to be used to access the element at 10
// or used in a reserve call? We don't so we pass up both as the semantic value
// and choose which to use later.
typedef struct assignableSemantic {              
    struct Symbol *reserveType;
    struct Symbol *expressionType; 
    struct Symbol *reserveSize; 
} assignableSemantic;

typedef struct opSemantic {
    int op;
    Label *label;
} opSemantic;

#endif