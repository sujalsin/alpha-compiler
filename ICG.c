#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "ICG.h"
#include "symbolTable.h"

char reverseEnumOP[14][5] = {":=", "+", "-", "*", "/", "%", "-", "res ", "rel ", "|", "&", "<", "==", "!"}; // This is based on the op enum

InstructionArray *instructionArrayInit() {
    InstructionArray *arr = malloc(sizeof(InstructionArray));
    arr->currentLabel = 1;
    arr->currentVar = 1;
    arr->maxSize = 10;
    arr->currentLine = 0;
    arr->instructionArray = calloc(10, sizeof(Instruction *));
    return arr;
}

char *generateCompilerLabel(InstructionArray *IA) {
    char *buffer = calloc(10, sizeof(char));
    snprintf(buffer, 10, ".l%i", IA->currentLabel);
    IA->currentLabel += 1;
    return buffer;
}

char *generateCompilerVar(InstructionArray *IA) {
    char *buffer = calloc(10, sizeof(char));
    snprintf(buffer, 10, "$t%i", IA->currentVar);
    IA->currentVar += 1;
    return buffer;
}

void doubleArraySize(InstructionArray *arr) {
    arr->maxSize = arr->maxSize * 2;
    arr->instructionArray = realloc(arr->instructionArray, arr->maxSize * sizeof(Instruction *));
}

void addParameterInstructions(InstructionArray *arr, Symbol *params) {
    if (params != NULL) {
        addParameterInstructions(arr, params->next);
        if (params->recBool == 1 || params->arrBool == 1) {
            gen(arr, 1, params, 0, NULL, NULL, REC_, NULL);
        } else {
            gen(arr, 1, params, 0, NULL, NULL, NORMAL, NULL);
        }
    }
}

void addAssignmentInstruction(InstructionArray *arr, Symbol *res, OP op, Symbol *arg1, Symbol *arg2) {
    Instruction *instruction = malloc(sizeof(Instruction));
    instruction->type = ASSIGNMENT;
    instruction->assign = malloc(sizeof(AssignInst));
    instruction->assign->arg1 = arg1;
    if (arg2) {
        instruction->assign->arg2 = arg2;
    }
    instruction->assign->op = op;
    instruction->assign->result = res;
    addInstruction(arr, instruction);
}

void addConstantInstruction(InstructionArray *arr, Constant *constant){
    Instruction *instruction = malloc(sizeof(Instruction));
    instruction->type = CONSTANT;
    instruction->constant = constant;
    addInstruction(arr, instruction);
}

Label *addLabel(InstructionArray *arr, char *name, Symbol *params) {
    Instruction *instruction = malloc(sizeof(Instruction));
    instruction->type = LABEL;
    instruction->label = malloc(sizeof(Label));
    instruction->label->name = name;
    instruction->label->params = params;
    addInstruction(arr, instruction);
    return instruction->label;
}

void addInstruction(InstructionArray *arr, Instruction *i) {
    if (arr->maxSize == arr->currentLine){
        doubleArraySize(arr);
    }
    arr->instructionArray[arr->currentLine] = i;
    arr->currentLine++;
}

void printInstructionArray(FILE *file, InstructionArray *arr) {
    for(int i = 0; i < arr->currentLine; i++){
        printLine(file, arr->instructionArray[i], i);
    }
}

char constBuffer[20];
void printLine(FILE *file, Instruction *instruction, int lineno) {
    switch (instruction->type) {
        case CONSTANT:
            switch (instruction->constant->type) {
                case INTEGERCONST:
                    snprintf(constBuffer, sizeof(constBuffer), "%i", instruction->constant->integer);
                    break;
                case ADDRESSCONST:
                    snprintf(constBuffer, sizeof(constBuffer), "%p", NULL);
                    break;
                case BOOLEANCONST:
                    snprintf(constBuffer, sizeof(constBuffer), "%s", instruction->constant->boolean?"true":"false");
                    break;
                case CHARACTERCONST:
                    snprintf(constBuffer, sizeof(constBuffer), "'%c'", instruction->constant->character);
                    break;
                }
            fprintf(file, "    %s := %s\n", instruction->constant->result->name, constBuffer);
            break;
        case LABEL:
            fprintf(file, "%s:\n", instruction->label->name);
            break;
        case ASSIGNMENT: 
            switch(instruction->assign->op) {
                case COPYOP:
                    fprintf(file, "    %s := %s\n", instruction->assign->result->name, instruction->assign->arg1->name);
                    break;
                case RESERVEOP:  
                    fprintf(file, "    %s := *%s\n", instruction->assign->result->name, instruction->assign->arg1->name);
                    break;
                case NOTOP:              
                case NEGATIVEOP:                       
                case RELEASEOP:
                    fprintf(file, "    %s := %s%s\n", instruction->assign->result->name, reverseEnumOP[instruction->assign->op], instruction->assign->arg1->name);
                    break;
                case TRUEOP:
                    fprintf(file, "    %s := true\n", instruction->assign->result->name);
                    break;
                case FALSEOP:
                    fprintf(file, "    %s := false\n", instruction->assign->result->name);
                    break;
                default:
                    fprintf(file, "    %s := %s %s %s\n", instruction->assign->result->name, instruction->assign->arg1->name, reverseEnumOP[instruction->assign->op], instruction->assign->arg2->name);
                    break;
            }
            break;
        case CALL:
            fprintf(file, "    %s := call(%s, %i)\n", instruction->call->result->name, instruction->call->arg1->name, instruction->call->paramLen);
            break;
        case PARAM:
            switch(instruction->param->type) {
                case REC_:
                    fprintf(file, "    param *%s\n", instruction->param->arg1->name);
                    break;
                case NORMAL:
                    fprintf(file, "    param %s\n", instruction->param->arg1->name);
                    break;
            }
            break;
        case RET:
            fprintf(file, "    return %s\n", instruction->returninst->arg1->name);
            break;
        case MEM:
            switch (instruction->memInst->type) {
                case LEFT:
                    fprintf(file, "    *%s := %s\n", instruction->memInst->arg1->name, instruction->memInst->arg2->name);
                    break;
                case RIGHT:
                    fprintf(file, "    %s := *%s\n", instruction->memInst->arg1->name, instruction->memInst->arg2->name);
                    break;
                case BOTH:
                    fprintf(file, "    *%s := *%s\n", instruction->memInst->arg1->name, instruction->memInst->arg2->name);
                    break;
            }
            break;
        case JUMP:
            if(true){};
            char *jumpLabel;
            if(instruction->jump->jumpLabel == NULL){ // If we dont backpatch itll be null
                jumpLabel = "TEMPNULL";
            } else {
                jumpLabel = instruction->jump->jumpLabel->name;
            }
            switch(instruction->jump->jumpType){
            case UNCONDITIONALJUMP:
                fprintf(file, "    goto %s\n", jumpLabel);
                break;
            case LESSTHANJUMP:
                fprintf(file, "    if %s < %s goto %s\n", instruction->jump->arg1->name, instruction->jump->arg2->name, jumpLabel);
                break;
            case EQUALJUMP: 
                fprintf(file, "    if %s == %s goto %s\n", instruction->jump->arg1->name, instruction->jump->arg2->name, jumpLabel);
                break;
        }
    }
}

boolN *makeList(int i) {
    struct boolN *newlist = malloc(sizeof(boolN));
    newlist->instr = i;
    // newlist->next = malloc(sizeof(boolN));
    newlist->next = NULL;
    return newlist;
}

// Concatenate two lists and return a new list
boolN* merge(boolN* p1, boolN* p2) {
    if (!p1) return p2;
    if (!p2) return p1;

    if (!p1 && !p2) {
        return NULL;
    }

    struct boolN *merged = p1;
    while (merged && merged->next != NULL) {
        merged = merged->next;
    }
    merged->next = p2;
    return p1;
}

void backpatch(InstructionArray *arr, boolN *list, Label* actualLabel) {
    if (!arr || !list || !actualLabel) {
        return;
    }
    for (boolN *current = list; current != NULL; current = current->next) {
        if (current->instr > 0 && current->instr < arr->currentLine) {
            Instruction *instr;
            instr = arr->instructionArray[current->instr];
            instr->jump->jumpLabel = actualLabel;
        }
    }
}

void addConditionalAndUnconditionalJumps(InstructionArray *arr, Symbol *arg1, Symbol *arg2, int op, boolN *truelist, boolN *falselist) {
    if (arr->currentLine + 2 > arr->maxSize) {
        doubleArraySize(arr);
    }

    Instruction *JumpInst = malloc(sizeof(Instruction));
    JumpInst->jump = malloc(sizeof(Jump));

    JumpInst->type = JUMP;
    switch(op){
        case LESSTHANOP:
            JumpInst->jump->jumpType = LESSTHANJUMP;
            break;
        case EQUALTOOP: 
            JumpInst->jump->jumpType = EQUALJUMP;
            break;
        default:
            JumpInst->jump->jumpType = UNCONDITIONALJUMP;
            break;
    }
    JumpInst->jump->arg1 = arg1;
    JumpInst->jump->arg2 = arg2;
    JumpInst->jump->jumpLabel = NULL;


    boolN *tempt = makeList(arr->currentLine);
    truelist = merge(truelist, tempt);

    addInstruction(arr, JumpInst);
    
    Instruction *uncondJumpInst = malloc(sizeof(Instruction));
    uncondJumpInst->jump = malloc(sizeof(Jump));
    uncondJumpInst->type = JUMP;
    uncondJumpInst->jump->jumpType = UNCONDITIONALJUMP;
    uncondJumpInst->jump->jumpLabel = NULL;
    
    boolN *tempf = makeList(arr->currentLine);
    falselist = merge(falselist, tempf);

    addInstruction(arr, uncondJumpInst);
}

void printlist(boolN *list) {
    while (list) {
        fprintf(stderr, "%i\n", list->instr);
        list = list->next;
    }
}

void addMem(InstructionArray *arr, int op, Symbol *arg1, Symbol *arg2) {
    Instruction *recInst = malloc(sizeof(Instruction));
    recInst->type = MEM;
    recInst->memInst = malloc(sizeof(MemInst));
    recInst->memInst->type = op;
    recInst->memInst->arg1 = arg1;
    recInst->memInst->arg2 = arg2;
    addInstruction(arr, recInst);
}

void gen(InstructionArray *arr, int op, Symbol *symbol, int paramLen, Label *label, Symbol *result, int paramType, Symbol *offset){
    Instruction *paramInst;
    Instruction *funcCall;
    Instruction *jumpInst;
    Instruction *trueInst;
    Instruction *falseInst;
    Instruction *returnInst;

    switch (op) {
        case 1:                         // 1 -> Param
            paramInst = malloc(sizeof(Instruction));
            paramInst->type = PARAM;
            paramInst->param = malloc(sizeof(ParamInst));
            paramInst->param->type = paramType;
            paramInst->param->arg1 = symbol;
            addInstruction(arr, paramInst);
            break;
        
        case 2:                         // 2 -> Call
            funcCall = malloc(sizeof(Instruction));
            funcCall->type = CALL;
            funcCall->call = malloc(sizeof(CallInst));
            funcCall->call->arg1 = symbol;
            funcCall->call->paramLen = paramLen;
            funcCall->call->result = result;
            addInstruction(arr, funcCall);
            break;

        case 3:                         // 3 -> Goto
            jumpInst = malloc(sizeof(Instruction));
            jumpInst->type = JUMP;
            jumpInst->jump = malloc(sizeof(Jump));
            jumpInst->jump->jumpType = UNCONDITIONALJUMP;
            jumpInst->jump->jumpLabel = label;
            addInstruction(arr, jumpInst);
            break;

        case 4:                         // 4 -> True Assignment
            trueInst = malloc(sizeof(Instruction));
            trueInst->type = ASSIGNMENT;
            trueInst->assign = malloc(sizeof(AssignInst));
            trueInst->assign->arg1 = NULL;
            trueInst->assign->arg2 = NULL;
            trueInst->assign->result = symbol;
            trueInst->assign->op = TRUEOP;
            addInstruction(arr, trueInst);
            break;
        
        case 5:                         // 5 -> False Assignment
            falseInst = malloc(sizeof(Instruction));
            falseInst->type = ASSIGNMENT;
            falseInst->assign = malloc(sizeof(AssignInst));
            falseInst->assign->op = FALSEOP;
            falseInst->assign->arg1 = NULL;
            falseInst->assign->arg2 = NULL;
            falseInst->assign->result = symbol;
            addInstruction(arr, falseInst);
            break;

        case 6:                         // 6 -> Return Statement
            returnInst = malloc(sizeof(Instruction));
            returnInst->type = RET;
            returnInst->returninst = malloc(sizeof(ReturnInst));
            returnInst->returninst->arg1 = symbol;
            addInstruction(arr, returnInst);
            break;

        default:
            break;
    }
}