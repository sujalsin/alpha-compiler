%{
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <libgen.h>

#include "symbolTable.h"
#include "semantics.h"
#include "ICG.h"
#include "cg.h"

#define YYDEBUG 1

extern int yylex(void);
extern int yyparse(void);

extern int line_number;
extern int column_number;
extern char* yytext;

struct SymbolTable *symbolTableglobal;
struct SymbolTable *currentScope;
struct InstructionArray *intermediateCodeArray;

char error[300];
struct Symbol *returnType;
bool as_;

struct Symbol *globalUndefinedType;
struct Symbol *globalIntegerType;
struct Symbol *globalCharacterType;
struct Symbol *globalBooleanType;
struct Symbol *globalAddressType;

typedef enum {
    SYNTAX_ERROR,
    TYPE_ERROR
} ErrorType;

void yyerror(const char *);
void alphaerror(const char *, ErrorType);

%}
%verbose

%define parse.trace

%union{
    Symbol *symbol;
    char *name;
    int const_integer;
    char const_character;
    char *const_string;
    struct Label *labelM;
    struct boolN *boolN;
    struct assignableSemantic *assignable;
    struct opSemantic *op;
}

%token YYEOF 0
%token <name> ID 101
// type names
%token T_INTEGER 201 
%token T_ADDRESS 202 
%token T_BOOLEAN 203 
%token T_CHARACTER 204 
%token T_STRING 205
// constants (literals)
%token <const_integer> C_INTEGER 301 
%token C_NULL 302 
%token <const_character> C_CHARACTER 303 
%token <const_string> C_STRING 304 
%token C_TRUE 305 
%token C_FALSE 306
// other keywords
%token WHILE 401 
%token IF 402 
%token THEN 403 
%token ELSE 404 
%token TYPE 405 
%token FUNCTION 406 
%token RETURN 407 
%token EXTERNAL 408 
%token AS 409
// punctuation - grouping
%token L_PAREN 501 
%token R_PAREN 502 
%token L_BRACKET 503 
%token R_BRACKET 504
%token L_BRACE 505 
%token R_BRACE 506
// punctuation - other
%token SEMI_COLON 507 
%token COLON 508 
%token COMMA 509 
%token ARROW 510
// operators
%token ADD 601 
%token SUB_OR_NEG 602
%token MUL 603 
%token DIV 604 
%token REM 605 
%token LESS_THAN 606 
%token EQUAL_TO 607 
%token ASSIGN 608 
%token NOT 609 
%token AND 610 
%token OR 611 
%token DOT 612
%token RESERVE 613
%token RELEASE 614

%nonassoc RESERVE RELEASE
%nonassoc DOT
%left MUL DIV REM
%left LESS_THAN
%left EQUAL_TO
%left AND
%left OR
%right NOT
%left ADD SUB_OR_NEG
%nonassoc ASSIGN

%type <symbol> type constant expression
%type <symbol> record_dblock record_declaration_list record_declaration 
%type <symbol> ablock argument_list
%type <symbol> parameter idlist memOp
%type <op> unaryOp binaryOp
%type <labelM> labelM
%type <boolN> boolN sblock compound_statement statement_list
%type <assignable> assignable


%start program

%%

program:
    prototype-or-definition-list 
    | YYEOF
;


prototype-or-definition-list:
    prototype prototype-or-definition-list
    | definition prototype-or-definition-list
    | prototype
    | definition
    | error prototype-or-definition-list {yyerrok;}  /* Error Recovery */
    | error YYEOF {yyerrok;}   /* Error Recovery */
;

prototype: // Function Prototypes
    EXTERNAL FUNCTION ID COLON type {
        if ($5 == globalUndefinedType) {
            sprintf(error, "Failed to find function mapping type %s for external function %s", $5->name, $3);
            alphaerror(error, SYNTAX_ERROR);
        } else {
            createFunctionEntry(symbolTableglobal, $3, $5, NULL);
        }
    }
    | EXTERNAL FUNCTION RESERVE COLON type {
        if ($5 == globalUndefinedType) {
            sprintf(error, "Failed to find function mapping type %s for reserve", $5->name);
            alphaerror(error, SYNTAX_ERROR);
        } else {
            createFunctionEntry(symbolTableglobal, "reserve", $5, NULL);
        }
    }
    | EXTERNAL FUNCTION RELEASE COLON type {
        if ($5 == globalUndefinedType) {
            sprintf(error, "Failed to find function mapping type %s for release", $5->name);
            alphaerror(error, SYNTAX_ERROR);
        } else {
            createFunctionEntry(symbolTableglobal, "release", $5, NULL);
        }
    }
    | FUNCTION ID COLON type {
        if ($4 == globalUndefinedType) {
            sprintf(error, "Failed to find function mapping type %s for function %s", $4->name, $2);
            alphaerror(error, SYNTAX_ERROR);
        } else {
            createFunctionEntry(symbolTableglobal, $2, $4, NULL);
        }   
    }
;

type: 
    T_ADDRESS {$$ = globalAddressType;}
    | T_BOOLEAN {$$ = globalBooleanType;}
    | T_CHARACTER {$$ = globalCharacterType;}
    | T_INTEGER {$$ = globalIntegerType;}
    | T_STRING {
        $$ = findSymbolInScope(symbolTableglobal, "string");
        if ($$ == NULL) {
            sprintf(error, "Type string not defined in the global scope");
            alphaerror(error, SYNTAX_ERROR);
            $$ = globalUndefinedType;
        }
    }    
    | ID { 
        $$ = findSymbolInScope(symbolTableglobal, $1);
        if ($$ == NULL) {
            sprintf(error, "Type %s not defined in the global scope", $1);
            alphaerror(error, SYNTAX_ERROR);
            $$ = globalUndefinedType;
        }
    }
;

constant:
    C_INTEGER {
        char *tempName = generateCompilerVar(intermediateCodeArray);
        Symbol *newSymbol = createVariableEntry(currentScope, tempName, globalIntegerType);
        Constant *newConstant = malloc(sizeof(Constant));
        newConstant->type = INTEGERCONST;
        newConstant->result = newSymbol;
        newConstant->integer = $1;
        addConstantInstruction(intermediateCodeArray, newConstant);
        $$ = newSymbol;
    }
    | C_STRING {
        Symbol *stringType = findSymbolInScope(symbolTableglobal, "string");
        Symbol *reserveFunction = findSymbolInScope(symbolTableglobal, "reserve");
        if (stringType == NULL) {
            sprintf(error, "Make sure to #include library.alpha if you use strings. String type is not defined");
            alphaerror(error, SYNTAX_ERROR);
            stringType = findSymbolInScope(symbolTableglobal, "$_undefined_type");
        }
        if (reserveFunction == NULL) {
            sprintf(error, "Make sure to #include library.alpha if you use strings. reserve is not defined");
            alphaerror(error, SYNTAX_ERROR);
            reserveFunction = findSymbolInScope(symbolTableglobal, "$_undefined_type");
        }

        // Do a reserve call with proper size
        int strSize = (strlen($1) - 2);
        char *sizeTempName = generateCompilerVar(intermediateCodeArray);
        Symbol *sizeSymbol = createVariableEntry(currentScope,sizeTempName, globalIntegerType);        
        Constant *newConstant = malloc(sizeof(Constant));
        newConstant->type = INTEGERCONST;
        newConstant->integer = 8 + strSize*8;
        newConstant->result = sizeSymbol;
        addConstantInstruction(intermediateCodeArray, newConstant);
        gen(intermediateCodeArray, 1, sizeSymbol, 0, NULL, NULL, NORMAL, NULL); // Param for size
        
        // First generate a temp for the string
        char *stringTempName = generateCompilerVar(intermediateCodeArray);
        Symbol *stringSymbol = createSymbolWithoutScope(stringTempName, stringType);
        gen(intermediateCodeArray, 2, reserveFunction, 1, NULL, stringSymbol, 0, NULL);  // Reserve Call

        // Store size of string
        char *arrSizeTempName = generateCompilerVar(intermediateCodeArray);
        Symbol *arrSizeSymbol = createVariableEntry(currentScope, arrSizeTempName, globalIntegerType);        
        Constant *arrSizeConstant = malloc(sizeof(Constant));
        arrSizeConstant->type = INTEGERCONST;
        arrSizeConstant->integer = strSize;
        arrSizeConstant->result = arrSizeSymbol;
        addConstantInstruction(intermediateCodeArray, arrSizeConstant);
        addMem(intermediateCodeArray, LEFT, stringSymbol, arrSizeSymbol);

        // For each letter do a storeInst into the correct spot
        for (int i=0; i<strSize; i++) {
            char *charTempName = generateCompilerVar(intermediateCodeArray);
            Symbol *charSymbol = createSymbolWithoutScope(charTempName, globalCharacterType);
            Constant *charConstant = malloc(sizeof(Constant));
            charConstant->type = CHARACTERCONST;
            charConstant->result = charSymbol;
            charConstant->character = $1[1+i];
            addConstantInstruction(intermediateCodeArray, charConstant);

            char *offsetTempName = generateCompilerVar(intermediateCodeArray);
            Symbol *offsetSymbol = createSymbolWithoutScope(offsetTempName, globalIntegerType);
            Constant *offsetConstant = malloc(sizeof(Constant));
            offsetConstant->type = INTEGERCONST;
            offsetConstant->result = offsetSymbol;
            offsetConstant->integer = 8 + i*8;
            addConstantInstruction(intermediateCodeArray, offsetConstant);


            char *locationTempName = generateCompilerVar(intermediateCodeArray);
            Symbol *locationSymbol = createSymbolWithoutScope(locationTempName, stringType); 

            addAssignmentInstruction(intermediateCodeArray, locationSymbol, ADDOP, stringSymbol, offsetSymbol); 
            addMem(intermediateCodeArray, LEFT, locationSymbol, charSymbol);
        }
        $$ = stringSymbol;
 
    } 
    | C_CHARACTER {
        char *tempName = generateCompilerVar(intermediateCodeArray);
        Symbol *newSymbol= createVariableEntry(currentScope, tempName, globalCharacterType);
        Constant *newConstant = malloc(sizeof(Constant));
        newConstant->type = CHARACTERCONST;
        newConstant->result = newSymbol;
        newConstant->character = $1;
        addConstantInstruction(intermediateCodeArray, newConstant);
        $$ = newSymbol;
    }
    | C_NULL {
        char *tempName = generateCompilerVar(intermediateCodeArray);
        Symbol *newSymbol= createVariableEntry(currentScope, tempName, globalAddressType);
        Constant *newConstant = malloc(sizeof(Constant));
        newConstant->type = ADDRESSCONST;
        newConstant->result = newSymbol;
        newConstant->address = NULL;
        addConstantInstruction(intermediateCodeArray, newConstant);
        $$ = newSymbol;
    }
    | C_TRUE {
        char *tempName = generateCompilerVar(intermediateCodeArray);
        Symbol *newSymbol= createVariableEntry(currentScope, tempName, globalBooleanType);
        Constant *newConstant = malloc(sizeof(Constant));
        newConstant->type = BOOLEANCONST;
        newConstant->result = newSymbol;
        newConstant->boolean = true;
        addConstantInstruction(intermediateCodeArray, newConstant);
        $$ = newSymbol;
    }
    | C_FALSE {
        char *tempName = generateCompilerVar(intermediateCodeArray);
        Symbol *newSymbol= createVariableEntry(currentScope, tempName, globalBooleanType);
        Constant *newConstant = malloc(sizeof(Constant));
        newConstant->type = BOOLEANCONST;
        newConstant->result = newSymbol;
        newConstant->boolean = false;
        addConstantInstruction(intermediateCodeArray, newConstant);
        $$ = newSymbol;
    }
;

definition:
    TYPE ID COLON record_dblock %prec DOT {
        Symbol *temp = $4;
        int s = 0;
        while (temp != NULL) {
            temp = temp -> next;
            s += 1;
        }
        Symbol *symbol = createRecords(symbolTableglobal, $2, $4, s);
        if (symbol == NULL) {
            sprintf(error, "Failed to define record %s", $2);
            alphaerror(error, SYNTAX_ERROR);
        }
    }
    | TYPE ID COLON C_INTEGER ARROW type {
        Symbol *symbol = createArrayMapping(symbolTableglobal, $2, $6, $4, $6->type.size);
        if (symbol == NULL) {
            sprintf(error, "Failed to define array mapping %s of  %s", $2, $6->name);
            alphaerror(error, SYNTAX_ERROR);
        }
    }
    | TYPE T_STRING COLON C_INTEGER ARROW T_CHARACTER {
        Symbol *char_ = globalCharacterType;
        Symbol *symbol = createArrayMapping(symbolTableglobal, "string", char_, 1, sizeof(char*));
        if (symbol == NULL) {
            alphaerror("Failed to define array mapping string", SYNTAX_ERROR);
        }
    }
    | TYPE ID COLON type ARROW type {
        Symbol *symbol = createFunctionMapping(symbolTableglobal, $2, $4, $6);
        if (symbol == NULL) {
            sprintf(error, "Failed to define function mapping %s of type %s to %s", $2, $4->name, $6->name);
            alphaerror(error, SYNTAX_ERROR);
        }
    }
    | ID parameter assignOp {
        currentScope = createSubscope(currentScope, line_number, column_number);
        Symbol *symbol = findSymbolInScope(symbolTableglobal, $1);
        if (symbol == NULL) {
            sprintf(error, "Function Prototype %s is not declared", $1);
            alphaerror(error, SYNTAX_ERROR);
        } else if(symbol->symbolType == TYPE_) {
            sprintf(error, "%s is not a function, it is a type", $1);
            alphaerror(error, SYNTAX_ERROR);
        } else if(symbol->symbolType == VARIABLE) {
            sprintf(error, "%s is not a function, it is a variable of type %s", $1, symbol->variable.type->name);
            alphaerror(error, SYNTAX_ERROR);
        } else {
            symbol->function.as = as_;
            Symbol *paramsForCG = NULL;
            if (!as_) {
                $2->variable.type = symbol->function.type->type.functionType->parameterType;
                insertSymbol(currentScope, $2);
                paramsForCG = malloc(sizeof(Symbol));
                paramsForCG->name = $2->name;
                paramsForCG->constBool = $2->constBool;
                paramsForCG->recBool = $2->recBool;
                paramsForCG->arrBool = $2->arrBool;
                paramsForCG->arrSym = $2->arrSym;
                paramsForCG->symbolType = $2->symbolType;
                paramsForCG->variable = $2->variable;
                paramsForCG->next = NULL;
            } else {
                Symbol *parameters = $2;
                Symbol *temp = $2;
                Symbol *prevCG = NULL;
                Symbol *paraType = symbol->function.type->type.functionType->parameterType;
                if (paraType != NULL) {
                    if (paraType->type.typeCategory == RECORD) { // record parameter
                        Symbol *rec = paraType->type.recordType->symbols;
                        while (parameters != NULL) {
                            parameters->variable.type = rec->variable.type;
                            rec = rec->next;
                            parameters = parameters->next;
                            if (rec == NULL) {
                                break;
                            }
                            temp = temp->next;
                        }
                        if (parameters != NULL) {
                            sprintf(error, "Too many arguments: Parameter type does not match record type %s", paraType->name);
                            alphaerror(error, SYNTAX_ERROR);
                            temp->next = NULL;
                        } else if (rec != NULL) {
                            sprintf(error, "Too few arguments: Parameter type does not match record type %s", paraType->name);
                            alphaerror(error, SYNTAX_ERROR);
                        }
                        parameters = $2;
                        while (parameters != NULL) {
                            Symbol *next = parameters->next;
                            Symbol *tempCG = malloc(sizeof(Symbol));
                            tempCG->name = parameters->name;
                            tempCG->constBool = parameters->constBool;
                            tempCG->recBool = parameters->recBool;
                            tempCG->arrBool = parameters->arrBool;
                            tempCG->arrSym = parameters->arrSym;
                            tempCG->symbolType = parameters->symbolType;
                            tempCG->variable = parameters->variable;
                            tempCG->next = NULL;
                            if (prevCG != NULL) {
                                prevCG->next = tempCG;
                            } else {
                                paramsForCG = tempCG;
                            }
                            prevCG = tempCG;
                            if (!insertSymbol(currentScope, parameters)) {
                                sprintf(error, "Cannot use parameters with the same name %s", parameters->name);
                                alphaerror(error, SYNTAX_ERROR);
                            }
                            parameters = next;
                        }
                    } else {
                        sprintf(error, "Parameter is of type %s, which is not a record, cannot use as keyword", paraType->name);
                        alphaerror(error, TYPE_ERROR);
                    }
                } else {
                    sprintf(error, "Could not find parameter type %s", symbol->function.type->type.functionType->parameterType->name);
                    alphaerror(error, SYNTAX_ERROR);
                }
            }
            returnType = symbol->function.type->type.functionType->returnType;
            addLabel(intermediateCodeArray, symbol->name, paramsForCG);
        }
    } sblock { /* Function Definition */
        currentScope = currentScope->parent;
        returnType = NULL;
    }
    | error sblock {yyerrok;} /* Error Recovery */
;

parameter: 
    L_PAREN ID R_PAREN {
        $$ = createSymbolWithoutScope($2, NULL);
        if ($$ == NULL) {
            sprintf(error, "Failed to create ID %s as the function parameter", $2);
            alphaerror(error, SYNTAX_ERROR);
            $$ = createSymbolWithoutScope($2, globalUndefinedType);
        }
        as_ = false;
    }
    | AS L_PAREN idlist R_PAREN {
        $$ = $3;
        as_ = true;
    }
;

idlist:
    ID COMMA idlist {
        $$ = createSymbolWithoutScope($1, NULL);
        if ($$ == NULL) {
            sprintf(error, "Failed to create ID %s as a parameter", $1);
            alphaerror(error, SYNTAX_ERROR);
            $$ = createSymbolWithoutScope($1, globalUndefinedType);
        }
        $$->next = $3;
    }
    | ID {
        $$ = createSymbolWithoutScope($1, NULL);
        if ($$ == NULL) {
            sprintf(error, "Failed to create ID %s as a parameter (end)", $1);
            alphaerror(error, SYNTAX_ERROR);
            $$ = createSymbolWithoutScope($1, globalUndefinedType);
        }
    }
;

sblock:
    L_BRACE dblock statement_list R_BRACE {
        $$ = makeList(0);
    }
    | L_BRACE statement_list R_BRACE {
        $$ = makeList(0);
    }
    | L_BRACE error R_BRACE {
        yyerrok;
        $$ = makeList(0);
    } /* Error Recovery */
;

record_dblock:
    L_BRACKET record_declaration_list R_BRACKET {
        $$ = $2;
    }
    | L_BRACKET error R_BRACKET {
        yyerrok; 
        $$ = createSymbolWithoutScope("undefined", globalUndefinedType);
    }   /* Error Recovery */
;

record_declaration_list:
    record_declaration SEMI_COLON record_declaration_list {
        Symbol *temp = $3;
        Symbol *prev = NULL;
        while(temp != NULL) {
            if (strcmp($1->name, temp->name) == 0) {
                sprintf(error, "Record has 2 fields with the same name %s", $1->name);
                alphaerror(error, SYNTAX_ERROR);
                break;
            }
            prev = temp;
            temp = temp->next;
        }
        $1->next = $3;
        if (temp != NULL) {
            if (prev != NULL) {
                prev->next = temp->next;
            } else {
                $1->next = temp->next;
            }
        }
        $$ = $1;
    }
    | record_declaration {
        $$ = $1;
    }
;

record_declaration:
    type COLON ID {
        $$ = createSymbolWithoutScope($3, $1);
        if ($$ == NULL) {
            sprintf(error, "Failed to add %s with type %s to record", $3, $1->name);
            alphaerror(error, TYPE_ERROR);
            $$ = createSymbolWithoutScope($3, globalUndefinedType);
        }
    }
;

dblock:
    L_BRACKET declaration_list R_BRACKET 
    | L_BRACKET error R_BRACKET {yyerrok;} /* Error Recovery */
;

declaration_list:
    declaration SEMI_COLON declaration_list 
    | declaration 
;

declaration:
    type COLON ID {
        Symbol *symbol = createSymbol(currentScope, $3, $1);
        if (symbol == NULL) {
            sprintf(error, "Failed to add %s with type %s to scope, check if variable named %s already exists", $3, $1->name, $3);
            alphaerror(error, TYPE_ERROR);
        }
    }
;

statement_list:
      compound_statement labelM statement_list { 
        backpatch(intermediateCodeArray, $1, $2);
        $$ = makeList(0); 
    }
    | compound_statement labelM {
        $$ = $1;
        backpatch(intermediateCodeArray, $1, $2);
        $$ = makeList(0); 
    }
    | simple_statement SEMI_COLON statement_list {$$ = $3;}
    | simple_statement SEMI_COLON {$$ = makeList(0);}
    | error SEMI_COLON statement_list {yyerrok;}   /* Error Recovery */
    | error SEMI_COLON {yyerrok;}   /* Error Recovery */
;

compound_statement:
      compound_statement_subscope WHILE labelM L_PAREN expression R_PAREN labelM sblock {
        currentScope = currentScope->parent;
        backpatch(intermediateCodeArray, $8, $3);
        backpatch(intermediateCodeArray, $5->variable.truelist, $7);
        $$ = $5->variable.falselist;
        gen(intermediateCodeArray, 3, NULL, 0, $3, NULL, 0, NULL);
    }
    | compound_statement_subscope IF L_PAREN expression R_PAREN THEN labelM sblock boolN ELSE labelM <boolN> { 
        currentScope = currentScope->parent; 
        currentScope = createSubscope(currentScope, line_number, column_number); 
        backpatch(intermediateCodeArray, $4->variable.truelist, $7);
        backpatch(intermediateCodeArray, $4->variable.falselist, $11);
    } 
    sblock { 
        currentScope = currentScope->parent;
        boolN *temp = merge($8, $9);
        $$ = merge(temp, $12); // currently the type is boolN, but we might have to use symbol.
    }
    | compound_statement_subscope IF L_PAREN error R_PAREN THEN sblock ELSE {
        currentScope = currentScope->parent;
        currentScope = createSubscope(currentScope, line_number, column_number);
    } sblock {
        currentScope = currentScope->parent;
        yyerrok;
    }   /* Error Recovery */
    | compound_statement_subscope sblock {
        currentScope = currentScope->parent;
    }
;

compound_statement_subscope: // solely used to create a subscope before the sblock in compound_statement
    %empty {
        currentScope = createSubscope(currentScope, line_number, column_number);
    }
;

labelM: 
    %empty {
        $$ = addLabel(intermediateCodeArray, generateCompilerLabel(intermediateCodeArray), NULL);
    }
;

boolN: 
    %empty {
        struct boolN *tempBool = makeList(intermediateCodeArray->currentLine);
        gen(intermediateCodeArray, 3, NULL, 0, NULL, NULL, 0, NULL);
        $$ = tempBool;
    }
;

simple_statement:
      assignable assignOp expression {
        Symbol *assignableExpression = $1->expressionType;
        if (assignableExpression->symbolType == FUNC) {
            if (assignableExpression->function.type->type.functionType->returnType != $3) {
                sprintf(error, "Using this as a return statement with incompatible types, expected type %s and assigned type %s", assignableExpression->function.type->type.functionType->returnType->name, $3->name);
                alphaerror(error, TYPE_ERROR);
            }
        } else if ($3->variable.type == globalBooleanType) {
            if ($3->constBool == 1) {
                addAssignmentInstruction(intermediateCodeArray, assignableExpression, COPYOP, $3, NULL);
            } else {
                Label *label1 = addLabel(intermediateCodeArray, generateCompilerLabel(intermediateCodeArray), NULL);
                gen(intermediateCodeArray, 4, assignableExpression, 0, NULL, NULL, 0, NULL);                           
                gen(intermediateCodeArray, 3, NULL, 0, NULL, NULL, 0, NULL);
                // printf("%s\n", label1->name);   // TODO: remove this line when done testing labels
                Label *label2 = addLabel(intermediateCodeArray, generateCompilerLabel(intermediateCodeArray), NULL);
                gen(intermediateCodeArray, 5, assignableExpression, 0, NULL, NULL, 0, NULL);
                gen(intermediateCodeArray, 3, NULL, 0, NULL, NULL, 0, NULL);
                backpatch(intermediateCodeArray, $3->variable.truelist, label1);
                backpatch(intermediateCodeArray, $3->variable.falselist, label2);
            }
        } else if (($3->recBool == 1) && (assignableExpression->recBool == 1)) {
            addMem(intermediateCodeArray, BOTH, assignableExpression, $3);
        } else if ($3->recBool == 1) {
            addMem(intermediateCodeArray, RIGHT, assignableExpression, $3);
        } else if (assignableExpression->recBool == 1) {
            addMem(intermediateCodeArray, LEFT, assignableExpression, $3);
        } else if (($3->recBool == 1) && (assignableExpression->recBool == 1)) {
            addMem(intermediateCodeArray, BOTH, assignableExpression, $3);
        } else if ($3->arrBool == 1) {
            addMem(intermediateCodeArray, RIGHT, assignableExpression, $3);
        } else if (assignableExpression->arrBool == 1) {
            addMem(intermediateCodeArray, LEFT, assignableExpression, $3);
        } else {
            addAssignmentInstruction(intermediateCodeArray, assignableExpression, COPYOP, $3, NULL);
        }
    }
    | RETURN expression {
        if (returnType == NULL) {
            alphaerror("Cannot use return statement if function is not properly declared", SYNTAX_ERROR);
        } else if (returnType != $2->variable.type) {
            sprintf(error, "Invalid return type, expected type %s and received type %s", returnType->name, $2->variable.type->name);
            alphaerror(error, TYPE_ERROR);
        }
        gen(intermediateCodeArray, 6, $2, 0, NULL, NULL, 0, NULL);
    }
;

assignable:
      ID {
        $$ = malloc(sizeof(assignableSemantic));
        Symbol *IDSymbol = findSymbol(currentScope, $1);
        if (IDSymbol == NULL) {
            sprintf(error, "Failed to find symbol %s", $1);
            alphaerror(error, SYNTAX_ERROR);
            $$->expressionType = createVariableEntry(currentScope, generateCompilerVar(intermediateCodeArray), globalUndefinedType);
        } else {
            if (IDSymbol->symbolType == FUNC) {
                as_ = IDSymbol->function.as;
                $$->expressionType = IDSymbol;
            } else if (IDSymbol->symbolType == VARIABLE) {
                $$->expressionType = createSymbolWithoutScope($1, IDSymbol->variable.type);
            } else {
                sprintf(error, "Assignable %s cannot be a type", $1);
                alphaerror(error, SYNTAX_ERROR);
                $$->expressionType = createSymbolWithoutScope($1, globalUndefinedType);
            }
        }
        $$->reserveType = $$->expressionType;
    }
    | assignable ablock {
        $$ = malloc(sizeof(assignableSemantic));
        int count = 0;
        Symbol *tempSym = $2;
        while (tempSym != NULL) {
            tempSym = tempSym -> next;
            count += 1;
        }

        Symbol *assignableExpression = $1->expressionType;
        if (assignableExpression->symbolType == FUNC) {
            Symbol *parameterType = assignableExpression->function.type->type.functionType->parameterType;
            if (as_) {
                if (parameterType->type.typeCategory == RECORD) {
                    Symbol *parameters = parameterType->type.recordType->symbols;
                    Symbol *arguments = $2;
                    addParameterInstructions(intermediateCodeArray, arguments);
                    while (parameters != NULL && arguments != NULL) {
                        if (parameters->variable.type != arguments->variable.type) {
                            sprintf(error, "Argument has type %s, but expected parameter type %s", arguments->variable.type->name, parameters->variable.type->name);
                            alphaerror(error, TYPE_ERROR);
                        }
                        if (arguments->recBool == 1 || arguments->arrBool == 1) {
                            gen(intermediateCodeArray, 1, arguments, 0, NULL, NULL, REC_, NULL);
                        } else {
                            gen(intermediateCodeArray, 1, arguments, 0, NULL, NULL, NORMAL, NULL);
                        }
                        parameters = parameters->next;
                        arguments = arguments->next;
                    }
                    if (parameters != NULL) {
                        alphaerror("Too few arguments", TYPE_ERROR);
                    } else if (arguments != NULL) {
                        alphaerror("Too many arguments", TYPE_ERROR);
                    }
                } else {
                    sprintf(error, "Only expected one argument of non-record type %s", parameterType->name);
                    alphaerror(error, TYPE_ERROR);
                }
            } else {
                if ($2->next != NULL) {
                    sprintf(error, "Received too many arguments, expected one argument of type %s", parameterType->name);
                    alphaerror(error, TYPE_ERROR);
                } 
                if (parameterType != $2->variable.type) {
                    sprintf(error, "Argument type %s does not match parameter type %s", $2->variable.type->name, parameterType->name);
                    alphaerror(error, TYPE_ERROR);
                }
                if ($2->recBool == 1 || $2->arrBool == 1) {
                    gen(intermediateCodeArray, 1, $2, 0, NULL, NULL, REC_, NULL);
                } else {
                    gen(intermediateCodeArray, 1, $2, 0, NULL, NULL, NORMAL, NULL);
                }
            }
            $$->expressionType = createSymbolWithoutScope(assignableExpression->name, assignableExpression->function.type->type.functionType->returnType);
            gen(intermediateCodeArray, 2, assignableExpression, count, NULL, $$->expressionType, 0, NULL);
        } else if (assignableExpression->symbolType == VARIABLE && assignableExpression->variable.type->type.typeCategory == ARRAYMAPPING) {
            int dimensions = assignableExpression->variable.type->type.arrayType->dimensions;
            Symbol *index = $2;
            Symbol *prev = NULL;                    // ?????
            int count = 0;                          // ?????
            while (index != NULL) {
                dimensions--;
                if (index->variable.type != globalIntegerType) {
                    sprintf(error, "Expecting array index type integer, received type %s", index->variable.type->name);
                    alphaerror(error, TYPE_ERROR);
                }
                char *tempN = generateCompilerVar(intermediateCodeArray);
                Symbol *temp1 = createSymbolWithoutScope(tempN, globalIntegerType);             // need to do type checking here
                if (count == 0) {
                    addAssignmentInstruction(intermediateCodeArray, temp1, COPYOP, index, NULL);
                } else {
                    addAssignmentInstruction(intermediateCodeArray, temp1, MULTIPLYOP, index, prev);
                }
                prev = temp1;
                count += 1;
                index = index->next;
            }
            if (dimensions > 0) {
                sprintf(error, "Expecting %d arguments, received too few", assignableExpression->variable.type->type.arrayType->dimensions);
                alphaerror(error, SYNTAX_ERROR);
            } else if (dimensions < 0) {
                sprintf(error, "Expecting %d arguments, received too many", assignableExpression->variable.type->type.arrayType->dimensions);
                alphaerror(error, SYNTAX_ERROR);
            }

            // Multiplying 8
            char *tempName = generateCompilerVar(intermediateCodeArray);
            Symbol *newSymbol = createVariableEntry(currentScope, tempName, globalIntegerType);
            Constant *newConstant = malloc(sizeof(Constant));
            newConstant->type = INTEGERCONST;
            newConstant->result = newSymbol;
            newConstant->integer = 8;
            addConstantInstruction(intermediateCodeArray, newConstant);
            char *tempN = generateCompilerVar(intermediateCodeArray);
            Symbol *temp1 = createSymbolWithoutScope(tempN, globalIntegerType);
            addAssignmentInstruction(intermediateCodeArray, temp1, MULTIPLYOP, prev, newSymbol);

            // Adding 8
            char *tempName1 = generateCompilerVar(intermediateCodeArray);
            Symbol *newSymbol1 = createVariableEntry(currentScope, tempName1, globalIntegerType);
            Constant *newConstant1 = malloc(sizeof(Constant));
            newConstant1->type = INTEGERCONST;
            newConstant1->result = newSymbol1;
            newConstant1->integer = 8;
            addConstantInstruction(intermediateCodeArray, newConstant1);
            char *tempN1 = generateCompilerVar(intermediateCodeArray);
            Symbol *temp2 = createSymbolWithoutScope(tempN1, globalIntegerType);
            addAssignmentInstruction(intermediateCodeArray, temp2, ADDOP, temp1, newSymbol1);

            $$->expressionType = createSymbolWithoutScope(assignableExpression->name, assignableExpression->variable.type->type.arrayType->elementType);
            $$->expressionType->arrBool = 1;
            $$->expressionType->arrSym = temp2;

            $$->reserveSize = temp2; // TODO make reserve use this
        } else {
            sprintf(error, "Assignable %s is not a Function or Array", assignableExpression->variable.type->name);
            alphaerror(error, TYPE_ERROR);
            $$->expressionType = createSymbolWithoutScope(assignableExpression->name, globalUndefinedType);
        }
        $$->reserveType = $1->reserveType;
    }
    | assignable recOp ID {
        $$ = malloc(sizeof(assignableSemantic));
        int count = 0;
        Symbol *assignableExpression = $1->expressionType;
        if (assignableExpression->variable.type->type.typeCategory == RECORD) {
            char *tempName = generateCompilerVar(intermediateCodeArray);
            Symbol *fields = assignableExpression->variable.type->type.recordType->symbols;
            while (fields != NULL) {
                if (strcmp(fields->name, $3) == 0) {
                    $$->expressionType = createSymbolWithoutScope(tempName, fields->variable.type);
                    char *tempName1 = generateCompilerVar(intermediateCodeArray);
                    Symbol *newSymbol1 = createVariableEntry(currentScope, tempName1, globalIntegerType);
                    Constant *newConstant1 = malloc(sizeof(Constant));
                    newConstant1->type = INTEGERCONST;
                    newConstant1->result = newSymbol1;
                    newConstant1->integer = count * 8 + 8;
                    addConstantInstruction(intermediateCodeArray, newConstant1);
                    addAssignmentInstruction(intermediateCodeArray, $$->expressionType, ADDOP, assignableExpression, newSymbol1);
                    break;
                }
                count += 1;
                fields = fields->next;
            }
            if (fields == NULL) {
                sprintf(error, "Failed to find field %s of record type %s", $3, assignableExpression->variable.type->name);
                alphaerror(error, SYNTAX_ERROR);
                $$->expressionType = createSymbolWithoutScope(assignableExpression->name, globalUndefinedType);
            }
            $$->expressionType->recBool = 1;
        } else if (assignableExpression->variable.type->type.typeCategory == ARRAYMAPPING) {
            int dimensions = assignableExpression->variable.type->type.arrayType->dimensions;
            char underscore = *$3;
            int lookup = atoi($3+1);
            if (underscore != '_') {
                sprintf(error, "Record access on an array is not allowed. Attempting to access %s", $3);
                alphaerror(error, SYNTAX_ERROR);
                $$->expressionType = createSymbolWithoutScope(assignableExpression->name, globalUndefinedType);
            } else if (lookup <= dimensions) {
                char *tempName = generateCompilerVar(intermediateCodeArray);
                Symbol *newSymbol = createVariableEntry(currentScope, tempName, globalIntegerType);
                if (lookup == 0) {
                    Constant *newConstant = malloc(sizeof(Constant));
                    newConstant->type = INTEGERCONST;
                    newConstant->result = newSymbol;
                    newConstant->integer = $1->expressionType->variable.type->type.arrayType->dimensions;
                    addConstantInstruction(intermediateCodeArray, newConstant);
                } else {
                    char *tempNameOffset = generateCompilerVar(intermediateCodeArray);
                    Symbol *offsetSymbol = createVariableEntry(currentScope, tempNameOffset, globalIntegerType);
                    Constant *offsetConstant = malloc(sizeof(Constant));
                    offsetConstant->type = INTEGERCONST;
                    offsetConstant->result = offsetSymbol;
                    offsetConstant->integer = (lookup - 1) * 8;
                    addConstantInstruction(intermediateCodeArray, offsetConstant);

                    char *locationTempName = generateCompilerVar(intermediateCodeArray);
                    Symbol *locationTempSymbol = createVariableEntry(currentScope, locationTempName, globalIntegerType);
                    addAssignmentInstruction(intermediateCodeArray, locationTempSymbol, ADDOP, offsetSymbol, $1->expressionType);
                    
                    addMem(intermediateCodeArray, RIGHT, newSymbol, locationTempSymbol);
                }
                $$->expressionType = newSymbol;

            } else {
                sprintf(error, "Dimension lookup %d is out of bounds of array type %s with %d dimensions", atoi($3+1), assignableExpression->variable.type->name, dimensions);
                alphaerror(error, SYNTAX_ERROR);
                $$->expressionType = createSymbolWithoutScope(assignableExpression->name, globalUndefinedType);
            }      
        } else {
            sprintf(error, "Cannot access field %s of non-record type %s (or dimension of non-array type)", $3, assignableExpression->variable.type->name);
            alphaerror(error, SYNTAX_ERROR);
            $$->expressionType = createSymbolWithoutScope(assignableExpression->name, globalUndefinedType);
        }
        $$->reserveType = $$->expressionType;
    }
;


expression:
      constant {
        $1->constBool = 1;
        $$ = $1;
    }
    | unaryOp expression %prec NOT {
        char *tempName = generateCompilerVar(intermediateCodeArray);
        Symbol *newSymbol = createVariableEntry(currentScope, tempName, $2->variable.type);
        if ($1->op == NOTOP && $2->variable.type != globalBooleanType) {
            sprintf(error, "Expression must be of type Boolean with this unary operator, not of type %s", $2->name);
            alphaerror(error, TYPE_ERROR);
        }
        if ($1->op == NEGATIVEOP && $2->variable.type != globalIntegerType) {
            sprintf(error, "Expression must be of type integer with this unary operator, not of type %s", $2->name);
            alphaerror(error, TYPE_ERROR);
        }
        if ($1->op == NOTOP) {
            newSymbol->variable.truelist = $2->variable.falselist;
            newSymbol->variable.falselist = $2->variable.truelist;
        } else {
            addAssignmentInstruction(intermediateCodeArray, newSymbol, $1->op, $2, NULL);
        }
        $$ = newSymbol;
    }
    | assignable {
        if ($1->expressionType->arrBool == 1) {
            char *tempName = generateCompilerVar(intermediateCodeArray);
            Symbol *newSymbol= createSymbolWithoutScope(tempName, globalAddressType);
            addAssignmentInstruction(intermediateCodeArray, newSymbol, ADDOP, $1->expressionType, $1->expressionType->arrSym);
            newSymbol->arrBool = 1;
            newSymbol->arrSym = $1->expressionType->arrSym;
            $$ = newSymbol;
        } else {
            $$ = $1->expressionType;
        }
    }
    | expression binaryOp expression %prec ADD {
        Symbol *type = $1->variable.type;
        struct boolN *truelist = makeList(0);
        struct boolN *falselist = makeList(0);
        char *tempName = generateCompilerVar(intermediateCodeArray);;
        Symbol *newSymbol;
        switch($2->op) {
            case EQUALTOOP:
                if ($1->variable.type != $3->variable.type) {
                    sprintf(error, "Expressions must be of the same type for this operator: type 1 is %s and type 2 is %s", $1->variable.type->name, $3->variable.type->name);
                    alphaerror(error, TYPE_ERROR);
                    type = globalUndefinedType;
                } else {
                    type = globalBooleanType;
                }
                addConditionalAndUnconditionalJumps(intermediateCodeArray, $1, $3, $2->op, truelist, falselist);
                newSymbol = createVariableEntry(currentScope, tempName, type);
                newSymbol->variable.truelist = truelist;
                newSymbol->variable.falselist = falselist;
                break;
            case LESSTHANOP:
                if (($1->variable.type != $3->variable.type) || !($1->variable.type == globalCharacterType || $1->variable.type == globalIntegerType)) {
                    sprintf(error, "Expressions must be of type integer or character for this operator: type 1 is %s and type 2 is %s", $1->variable.type->name, $3->variable.type->name);
                    alphaerror(error, TYPE_ERROR);
                    type = globalUndefinedType;
                } else {
                     type = globalBooleanType;
                }
                addConditionalAndUnconditionalJumps(intermediateCodeArray, $1, $3, $2->op, truelist, falselist);
                newSymbol = createVariableEntry(currentScope, tempName, type);
                newSymbol->variable.truelist = truelist;
                newSymbol->variable.falselist = falselist;
                break;
            case ANDOP:
                 if ($1->variable.type != globalBooleanType || $1->variable.type != $3->variable.type) {
                    sprintf(error, "Expressions must be of the Boolean type with this binary operator: type 1 is %s and type 2 is %s", $1->name, $3->name);
                    alphaerror(error, TYPE_ERROR);
                    type = globalUndefinedType;
                } else {
                    type = globalBooleanType;
                }
                newSymbol = createVariableEntry(currentScope, tempName, type);
                backpatch(intermediateCodeArray, $1->variable.truelist, $2->label);
                break;
            case OROP:
                if ($1->variable.type->name != $3->variable.type->name || $1->variable.type != globalBooleanType) {
                    sprintf(error, "Expressions must both be of the type Boolean with this binary operator: type 1 is %s and type 2 is %s", $1->variable.type->name, $3->variable.type->name);
                    alphaerror(error, TYPE_ERROR);
                    type = globalUndefinedType;
                } else {
                    type = globalBooleanType;
                }
                newSymbol = createVariableEntry(currentScope, tempName, type);
                backpatch(intermediateCodeArray, $1->variable.falselist, $2->label);
                break;
            default:
                if ($1->variable.type->name != $3->variable.type->name || $1->variable.type != globalIntegerType) {
                    sprintf(error, "Expressions must both be of the type Integer with this binary operator: type 1 is %s and type 2 is %s", $1->variable.type->name, $3->variable.type->name);
                    alphaerror(error, TYPE_ERROR);
                    type = globalUndefinedType;
                }
                newSymbol = createVariableEntry(currentScope, tempName, type);
                addAssignmentInstruction(intermediateCodeArray, newSymbol, $2->op, $1, $3); 
                break;
        }
        $$ = newSymbol;
    }
    | L_PAREN expression R_PAREN {
        $$ = $2;
    }
    | memOp assignable {
        if ($2->reserveType->arrBool == 1) {
            gen(intermediateCodeArray, 1, $2->reserveType->arrSym, 0, NULL, NULL, NORMAL, NULL);
            $$ = createSymbolWithoutScope($2->reserveType->name, globalAddressType);
            gen(intermediateCodeArray, 2, $1, 1, NULL, $$, 0, NULL);
            $$->arrBool = 1;
        } else {
            // TODO
            gen(intermediateCodeArray, 1, $2->reserveType, 0, NULL, NULL, NORMAL, NULL); // This should be something other than reserveType
            $$ = createSymbolWithoutScope($2->reserveType->name, globalAddressType);

            gen(intermediateCodeArray, 2, $1, 1, NULL, $$, 0, NULL);
        }
        if ($2->reserveType->variable.type->type.typeCategory != RECORD && $2->reserveType->variable.type->type.typeCategory != ARRAYMAPPING) {
                sprintf(error, "Memory operation using incompatible type %s", $2->reserveType->variable.type->name);
                alphaerror(error, SYNTAX_ERROR);
                $$ = createSymbolWithoutScope($2->reserveType->name, globalUndefinedType);
        }
    }
    | L_PAREN error R_PAREN {yyerrok;}   /* Error Recovery */
;

ablock:
    L_PAREN argument_list R_PAREN {
        $$ = $2;
    }
;

argument_list:
      expression COMMA argument_list {
        $$ = createSymbolWithoutScope($1->name, $1->variable.type);
        if ($$ == NULL) {
            sprintf(error, "Failed to use parameter of type %s", $1->variable.type->name);
            alphaerror(error, TYPE_ERROR);
            $$ = createSymbolWithoutScope($1->name, globalUndefinedType);
        }
        $$->next = $3;
    }
    | expression { 
        $$ = createSymbolWithoutScope($1->name, $1->variable.type);
    }
;

unaryOp:
      SUB_OR_NEG {
        $$ = malloc(sizeof(opSemantic));
        $$->op = NEGATIVEOP;
    }
    | NOT {
        $$ = malloc(sizeof(opSemantic));
        $$->op = NOTOP;
    }

;

memOp:
      RESERVE {
        $$ = findSymbolInScope(symbolTableglobal, "reserve");
    }
    | RELEASE { 
        $$ = findSymbolInScope(symbolTableglobal, "release");
    }
;

assignOp:
    ASSIGN
;

recOp: 
    DOT
;

binaryOp:
      ADD {
        $$ = malloc(sizeof(opSemantic));
        $$->op = ADDOP;
    }
    | SUB_OR_NEG {
        $$ = malloc(sizeof(opSemantic));
        $$->op = SUBTRACTOP;
    }
    | MUL {
        $$ = malloc(sizeof(opSemantic));
        $$->op = MULTIPLYOP;
    }
    | DIV {
        $$ = malloc(sizeof(opSemantic));
        $$->op = DIVIDEOP;
    }
    | REM {
        $$ = malloc(sizeof(opSemantic));
        $$->op = MODOP;
    }
    | AND labelM {
        $$ = malloc(sizeof(opSemantic));
        $$->op = ANDOP;
        $$->label = $2;
    }
    | OR labelM {
        $$ = malloc(sizeof(opSemantic));
        $$->op = OROP;
        $$->label = $2;
    }
    | LESS_THAN {
        $$ = malloc(sizeof(opSemantic));
        $$->op = LESSTHANOP;
    }
    | EQUAL_TO {
        $$ = malloc(sizeof(opSemantic));
        $$->op = EQUALTOOP;
    }
;

%%

void printHelp(void);
int generateTokenFile(char *, char *);
int generateSymbolTableFile(char *);
int generateAnnotatedSourceCodeFile(char *, char *, bool);
int generateIntermediateRepresentationFile(char *);
int generateAssemblyCode(char *);
extern char* yytext;
int token_mode = 0;             // If 0 then comments won't be returned by parser as a 700 token 
extern int line_number, column_number;
extern FILE *yyin;

typedef struct ErrorAnnotation {
    char type[10]; // "Syntax" or "Type"
    int line;
    int column;
    char message[256];
} ErrorAnnotation;

ErrorAnnotation *errors;
int error_count = 0;
int error_capacity = 0;

void yyerror(const char *s) {
    alphaerror(s, SYNTAX_ERROR);
}

void alphaerror(const char *s, ErrorType error_type) {
    fprintf(stderr, "Error: %s at line %d\n", s, line_number);
    if (error_count >= error_capacity) {
        int initial_capacity = 10; 
        int growth_factor = 2; 

        if (error_capacity == 0) {
            error_capacity = initial_capacity;
            errors = (ErrorAnnotation *)malloc(error_capacity * sizeof(ErrorAnnotation));
            if (errors == NULL) {
                perror("Failed to allocate memory for errors");
                exit(EXIT_FAILURE); 
            }
        } else {
            error_capacity *= growth_factor;
            ErrorAnnotation *new_errors = (ErrorAnnotation *)realloc(errors, error_capacity * sizeof(ErrorAnnotation));
            if (new_errors == NULL) {
                perror("Failed to reallocate memory for errors");
                free(errors);
                exit(EXIT_FAILURE);
            }
            errors = new_errors;
        }
    }

    switch (error_type) {
        case SYNTAX_ERROR:
            strcpy(errors[error_count].type, "Syntax");
            break;
        case TYPE_ERROR:
            strcpy(errors[error_count].type, "Type");
            break;
        default:
            strcpy(errors[error_count].type, "Semantic");
            break;
    }
    errors[error_count].line = line_number;
    errors[error_count].column = column_number;
    strncpy(errors[error_count].message, s, sizeof(errors[error_count].message) - 1);
    error_count++;
}

int main(int argc, char **argv) {
    char *inputFilename;
    char baseName[260];
    char preprocessorCommand[400]; // Buffer for preprocessor command

    int foundFile = 0;
    int printSymbolTable = 0;
    int printIntermediateCodeArray = 0;
    int printASCMode = 0;
    int typeCheckingMode = 0;
    int printCodeGeneration = 0;

    ++argv, --argc; // skip over program name
    symbolTableglobal = symbolTableInit();
    intermediateCodeArray = instructionArrayInit();
    currentScope = symbolTableglobal;
    globalUndefinedType = findSymbolInScope(symbolTableglobal, "$_undefined_type");
    globalIntegerType = findSymbolInScope(symbolTableglobal, "integer");
    globalCharacterType = findSymbolInScope(symbolTableglobal, "character");
    globalBooleanType = findSymbolInScope(symbolTableglobal, "Boolean");
    globalAddressType = findSymbolInScope(symbolTableglobal, "address");

    for (int i=0;i<argc;i++){
        if (!strcmp("-help", argv[i])) {
            printHelp();
            return EXIT_SUCCESS;
        } else if (!strcmp("-tok", argv[i])) {
            token_mode = 1;
        } else if (!strcmp("-st", argv[i])) {
            printSymbolTable = 1;
        } else if (!strcmp("-asc", argv[i])) {
            printASCMode = 1;
        } else if (!strcmp("-tc", argv[i])) {
            typeCheckingMode = 1;
        } else if (!strcmp("-ir", argv[i])) {
            printIntermediateCodeArray = 1;
        } else if (!strcmp("-cg", argv[i])) {
            printCodeGeneration = 1;
        } else if (!strcmp("-debug", argv[i])) {
            yydebug = 1;
        } else {
            if (foundFile == 1) { // 2 files given
                fprintf(stderr, "Usage: ./alpha [options] <filename>\nRun ./alpha -help for more info\n");
                return EXIT_FAILURE;
            }
            foundFile = 1;
            inputFilename = argv[i];
            strcpy(baseName, basename(inputFilename)); // Extract the base name 
            char *alphaPtr = strstr(baseName, ".alpha");
            if (alphaPtr) {
                *alphaPtr = '\0'; // Replace .alpha with end of string, effectively removing it
            }
        }
    }

    if (!foundFile) {
        fprintf(stderr, "Usage: ./alpha [options] <filename>\nRun ./alpha -help for more info\n");
        exit(EXIT_FAILURE);        
    }

    yyin = fopen(inputFilename, "r");
    if (yyin == NULL) {
        fprintf(stderr, "Can't Open %s\n", inputFilename);
        exit(EXIT_FAILURE);
    }
    fclose(yyin);
    
    if (token_mode) {
        generateTokenFile(inputFilename, baseName);
    }

    snprintf(preprocessorCommand, sizeof(preprocessorCommand), "gcc -E -P -nostdinc -C -x c -o pp.txt %s", inputFilename);
    system(preprocessorCommand);

    line_number = 1; 
    column_number = 1;

    yyin = fopen(inputFilename, "r");
    char line[1024];
    while(fgets(line, sizeof(line), yyin) != NULL){
        line_number++;
    }
    fclose(yyin);
    yyin = fopen("pp.txt", "r");
    while(fgets(line, sizeof(line), yyin) != NULL){
        line_number--;
    }
    rewind(yyin);

    if (yyparse() == 0) {         // Parsing successful
    } else {                      // Parsing failed
        fprintf(stdout, "%s", yytext);
        printf("Too many errors. I give up.\n");
    }

    if (printSymbolTable == 1) {
        generateSymbolTableFile(baseName);
    }
    if (printIntermediateCodeArray == 1) {
        generateIntermediateRepresentationFile(baseName);
    }
    if (printCodeGeneration == 1) {
        generateAssemblyCode(baseName);
    }

    if (typeCheckingMode == 1 && printASCMode == 1) {
        generateAnnotatedSourceCodeFile(inputFilename, baseName, true);
    } else if (printASCMode == 1) {
        generateAnnotatedSourceCodeFile(inputFilename, baseName, false);
    }

    fclose(yyin);
    // system("rm pp.txt");
    return 0;
}

void printHelp(void){
    fprintf(stdout, 
    "HELP:"
    "\nHow to run the alpha compiler:"
    "\n./alpha [options] <filename>"
    "\nValid options:"
    "\n-tok output the token number, token, line number, and column number for each of the tokens to the .tok file"
    "\n-st output the symbol table for the program to the .st file"
    "\n-asc output the annotated source code for the program to the .asc file, including syntax errors"
    "\n-tc run the type checker and report type errors to the .asc file"
    "\n-ir run the intermediate representation generator, writing output to the .ir file"
    "\n-cg run the (x86 assembly) code generator, writing output to the .s file"
    "\n-debug produce debugging messages to stderr"
    "\n-help print this message and exit the alpha compiler\n"
    );
}

int generateTokenFile(char *inputFilename, char *baseName) {
    char tokOutputFilename[260]; // Buffer for output filename
    FILE *tokFileOut;
    int tokenCode;

    snprintf(tokOutputFilename, sizeof(tokOutputFilename), "%s.tok", baseName); // Construct output path
    yyin = fopen(inputFilename, "r");
    tokFileOut = fopen(tokOutputFilename, "w");
    if (!yyin) {
        perror("Error opening file");
        exit(EXIT_FAILURE);
    }

    if (!tokFileOut) {
        perror("Error creating output file");
        exit(EXIT_FAILURE);
    }

    fprintf(tokFileOut, "Ln  Col  Tok  Text\n");
    while ((tokenCode = yylex()) != 0) {
        fprintf(tokFileOut, "%-3d %-3d  %-3d  \"%s\"\n", line_number, column_number, tokenCode, yytext);
    }
    if (tokFileOut)
	    fclose(tokFileOut);
    if (yyin)
	    fclose(yyin);
    token_mode = 0;
    return EXIT_SUCCESS;
}

int generateSymbolTableFile(char *baseName){
    char stOutputFilename[260]; // Buffer for output filename
    FILE *symbolTableOut;
    
    snprintf(stOutputFilename, sizeof(stOutputFilename), "%s.st", baseName); // Construct output path
    symbolTableOut = fopen(stOutputFilename, "w");
    printGlobalScope(symbolTableOut, symbolTableglobal);

    if (symbolTableOut)
	    fclose(symbolTableOut);
    return EXIT_SUCCESS;
}

int generateIntermediateRepresentationFile(char *baseName){
    char icOutputFilename[260]; // Buffer for output filename
    FILE *intermediateCodeOut;

    snprintf(icOutputFilename, sizeof(icOutputFilename), "%s.ir", baseName); // Construct output path
    intermediateCodeOut = fopen(icOutputFilename, "w");
    printInstructionArray(intermediateCodeOut, intermediateCodeArray);
    
    if (intermediateCodeOut)
	    fclose(intermediateCodeOut);
    return EXIT_SUCCESS;
}



int generateAssemblyCode(char *baseName){
    char cgOutputFilename[260]; // Buffer for output filename
    FILE *assemblyCodeOut;

    snprintf(cgOutputFilename, sizeof(cgOutputFilename), "%s.s", baseName); // Construct output path
    assemblyCodeOut = fopen(cgOutputFilename, "w");
    assemblyCodeGeneration(assemblyCodeOut, intermediateCodeArray);

    if (assemblyCodeOut)
	    fclose(assemblyCodeOut);
    return EXIT_SUCCESS;
}

int generateAnnotatedSourceCodeFile(char *inputFilename, char *baseName, bool tc) {
    char ascOutputFilename[260];
    char lineBuffer[1024];       
    int lineNumber = 1;
    FILE *inputFile, *ascFileOut;

    snprintf(ascOutputFilename, sizeof(ascOutputFilename), "%s.asc", baseName);

    inputFile = fopen(inputFilename, "r");
    ascFileOut = fopen(ascOutputFilename, "w");
    if (!inputFile) {
        perror("Error opening input file");
        perror(inputFilename);
        exit(EXIT_FAILURE);
    }

    if (!ascFileOut) {
        perror("Error creating ASC output file");
        exit(EXIT_FAILURE);
    }

    while (fgets(lineBuffer, sizeof(lineBuffer), inputFile) != NULL) {
        fprintf(ascFileOut, "%03d: %s", lineNumber, lineBuffer);
        
        if (!tc) {
            for (int i = 0; i < error_count; ++i) {
                if (strcmp(errors[i].type, "Type") != 0) {
                    if (errors[i].line == lineNumber) {
                        fprintf(ascFileOut, "LINE %d:%d ** ERROR: %s\n", errors[i].line, errors[i].column, errors[i].message);
                    }
                }
            }
        } else {
            for (int i = 0; i < error_count; ++i) {
                if (errors[i].line == lineNumber) {
                    fprintf(ascFileOut, "LINE %d:%d ** ERROR: %s\n", errors[i].line, errors[i].column, errors[i].message);
                }
            }
        }
        lineNumber++;
    }

    if (ascFileOut)
        fclose(ascFileOut);
    if (inputFile)
        fclose(inputFile);
    
    return EXIT_SUCCESS;
}