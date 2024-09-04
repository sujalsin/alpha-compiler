#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <stdio.h>

#include "symbolTable.h"
#include "ICG.h"
#include "cg.h"

char *rs;
char *rd;
FunctionMemory *mem;

FILE *file;

void assemblyCodeGeneration(FILE *fileIn, InstructionArray *instructions) {
    file = fileIn;
    for (int i = 0; i < instructions->currentLine; i++) {
        Instruction *instr = instructions->instructionArray[i];
        // printLine(stderr, instr, 0);
        // fprintf(file, "\t\t# ");
        // printLine(file, instr, 0);
        generateAssembly(instr);
    }
}

void generateAssembly(Instruction *instr) {
    getReg(instr);
    switch (instr->type) {
        case CONSTANT:
            switch (instr->constant->type) {
                case INTEGERCONST:
                    fprintf(file, "\tmov $%d, %s\n", instr->constant->integer, rd); // %rd = $integer
                    break;
                case ADDRESSCONST:
                    fprintf(file, "\tmov $0, %s\n", rd);    // %rd = $0
                    break;
                case BOOLEANCONST:
                    fprintf(file, "\tmov $%s, %s\n", instr->constant->boolean?"1":"0", rd); // %rd = $1 OR %rd = $0
                    break;
                case CHARACTERCONST:
                    fprintf(file, "\tmov $%d, %s\n", instr->constant->character, rd);   // %rd = $(ascii character)
                    break;
                }
            storeOnStack(rd, instr->constant->result->name);
            break;
        case LABEL:
            if (instr->label->name[0] != '.') { // function label
                fprintf(file, "\n");
                fprintf(file, "%s:\n", instr->label->name); // function:
                fprintf(file, "\tpush %%rbp\n");            //     %rsp -= 8; (%rsp) = %rbp
                fprintf(file, "\tmov %%rsp, %%rbp\n");      //     %rbp = %rsp
                Symbol *params = instr->label->params;
                int offset = 16;
                while (params != NULL) {
                    fprintf(file, "\tmov %d(%%rbp), %s\n", offset, rd); // %rd = (%rbp + offset)
                    storeOnStack(rd, params->name);
                    offset += 8;
                    params = params->next;
                }
            } else {    // compiler label
                fprintf(file, "%s:\n", instr->label->name); // label:
            }
            break;
        case ASSIGNMENT: 
            switch(instr->assign->op) {
                case COPYOP:
                    fprintf(file, "\tmov %s, %s\n", rs, rd);    // %rd = %rs
                    break;
                case NEGATIVEOP:
                    fprintf(file, "\tneg %s\n", rd);            // %rd = -%rd
                    break;
                case ADDOP:
                    fprintf(file, "\tadd %s, %s\n", rs, rd);    // %rd += %rs
                    break;
                case SUBTRACTOP:
                    fprintf(file, "\tsub %s, %s\n", rs, rd);    // %rd -= %rs
                    break;
                case MULTIPLYOP:
                    fprintf(file, "\timul %s, %s\n", rs, rd);   // %rd *= %rs
                    break;
                case DIVIDEOP:
                    fprintf(file, "\tdiv %s, %s\n", rs, rd);    // %rd /= %rs
                    break;
                case MODOP:
                    fprintf(file, "\tmod %s, %s\n", rs, rd);    // %rd %= %rs
                    break;
                case OROP:
                    fprintf(file, "\tor %s, %s\n", rs, rd);     // %rd |= %rs
                    break;
                case ANDOP:
                    fprintf(file, "\tand %s, %s\n", rs, rd);    // %rd &= %rs
                    break;
                case NOTOP:
                    fprintf(file, "\tnot %s\n", rd);            // %rd = !%rs
                    break;
                case LESSTHANOP:
                    fprintf(file, "\tcmp %s, %s\n", rs, rd);    // %eflags := %rd - %rs
                    fprintf(file, "\tmov %s, %%eflags\n", rd);  // %rd = %eflags
                    fprintf(file, "\tand %s, $128\n", rd);      // %rd &= $128      # mask the negative bit
                    fprintf(file, "\trsh %s, $7\n", rd);        // %rd >>= $7
                    break;
                case EQUALTOOP:
                    fprintf(file, "\tcmp %s, %s\n", rs, rd);    // %eflags := %rd -= %rs
                    fprintf(file, "\tmov %s, %%eflags\n", rd);  // %rd = %eflags
                    fprintf(file, "\tand %s, $64\n", rd);       // %rd &= $64       # mask the zero bit
                    fprintf(file, "\trsh %s, $6\n", rd);        // %rd >>= $6
                    break;
                case RESERVEOP:
                case RELEASEOP:
                    fprintf(file, "\t# I don't think this is used\n");  // function call should be recognized first
                    break;
                case TRUEOP:
                    fprintf(file, "\tmov %s, $1\n", rd);    // %rd = $1
                    break;
                case FALSEOP:
                    fprintf(file, "\tmov %s, $0\n", rd);    // %rd = $0
                    break;
            }
            storeOnStack(rd, instr->assign->result->name);
            break;
        case CALL:
            fprintf(file, "\tcall %s\n", instr->call->arg1->name);  // call function
            fprintf(file, "\tadd %%rsp, $%d\n", 8 * instr->call->paramLen); // %rsp -= 8 * numParams    # adjust stack to ignore params
            storeOnStack(rd, instr->call->result->name);
            break;
        case PARAM:
            switch(instr->param->type) {
                case REC_:
                    fprintf(file, "\tmov (%s), %s\n", rd, rd);  // %rd = (%rd)
                case NORMAL:
                    fprintf(file, "\tpush %s\n", rd);   // %rsp -= 8; (%rsp) = %rd
                    break;
            }
            break;
        case RET:
            fprintf(file, "\tmov %%rbp, %%rsp\n");  // %rsp = %rbp
            fprintf(file, "\tpop %%rbp\n");         // %rbp = (%rsp); %rsp -= 8
            fprintf(file, "\tret\n");               // ret
            break;
        case JUMP:
            if (instr->jump->jumpLabel == NULL) {
                fprintf(file, "# can't jump since there is no label. fix backpatching. vvv\n# IR representation: ");
                printLine(file, instr, 0);
                break;
            }
            switch(instr->jump->jumpType) {
                case UNCONDITIONALJUMP:
                    fprintf(file, "\tj %s\n", instr->jump->jumpLabel->name);    // goto label
                    break;
                case LESSTHANJUMP:
                    fprintf(file, "\tcmp %s, %s\n", rs, rd);                    // %eflags := %rd - %rs
                    fprintf(file, "\tjlt %s\n", instr->jump->jumpLabel->name);  // if %eflags NEGATIVE goto label
                    break;
                case EQUALJUMP:
                    fprintf(file, "\tcmp %s, %s\n", rs, rd);                                    // %eflags := %rd - %rs
                    fprintf(file, "\tjeq %s\n", instr->jump->jumpLabel->name);  // if %eflags ZERO goto label
                    break;
            }
            break;
        case MEM:
            switch (instr->memInst->type) {
                case LEFT:
                    fprintf(file, "\tmov %s, (%s)\n", rs, rd);      // (%rd) = %rs
                    break;
                case RIGHT:
                    fprintf(file, "\tmov (%s), %s\n", rs, rd);      // %rd = (%rs)
                    storeOnStack(rd, instr->memInst->arg1->name);
                    break;
                case BOTH:
                    fprintf(file, "\tmov (%s), %s\n", rs, rs);      // %rs = (%rs)
                    fprintf(file, "\tmov %s, (%s)\n", rs, rd);      // (%rd) = %rs
                    break;
            }
            break;
    }
}

void getReg(Instruction *instr) {
    rd = "%rdx";
    rs = "%rcx";
    switch (instr->type) {
        case CONSTANT:
            break;
        case LABEL:
            if (instr->label->name[0] != '.') { 
                mem = malloc(sizeof(FunctionMemory));
                mem->topOfStack = 0;
                mem->variables = NULL;
            }
            break;
        case ASSIGNMENT: 
            switch(instr->assign->op) {
                case ADDOP:
                case SUBTRACTOP:
                case MULTIPLYOP:
                case DIVIDEOP:
                case MODOP:
                case ANDOP:
                case OROP:
                case EQUALTOOP:
                case LESSTHANOP:
                    loadFromStack(rs, instr->assign->arg2->name);
                case COPYOP:
                case NEGATIVEOP:
                case NOTOP:
                    loadFromStack(rd, instr->assign->arg1->name);
                    break;
                case RESERVEOP:
                case RELEASEOP:
                case TRUEOP:
                case FALSEOP:
                    break; 
            }
            break;
        case CALL:
            break;
        case PARAM:
            switch(instr->param->type) {
                case REC_:
                case NORMAL:
                    loadFromStack(rd, instr->param->arg1->name);
                    break;
            }
            break;
        case RET:
            rd = "%rax";
            loadFromStack(rd, instr->returninst->arg1->name);
            break;
        case MEM:
            switch(instr->memInst->type) {
                case LEFT:
                case BOTH:
                    loadFromStack(rd, instr->memInst->arg1->name);
                case RIGHT:
                    loadFromStack(rs, instr->memInst->arg2->name);
                    break;
            }
            break;
        case JUMP:
            switch(instr->jump->jumpType) {
                case UNCONDITIONALJUMP:
                    break;
                case LESSTHANJUMP:
                case EQUALJUMP: 
                    loadFromStack(rs, instr->jump->arg1->name);
                    loadFromStack(rd, instr->jump->arg2->name);
                    break;
            }
            break;
    }
}

void loadFromStack(char *reg, char *var) {
    VariableMemory *temp = mem->variables;
    while (temp != NULL) {
        if (strcmp(temp->name, var) == 0) {
            break;
        }
        temp = temp->next;
    }
    if (temp == NULL) {
        fprintf(file, "# unknown variable %s\n", var);
    } else {
        fprintf(file, "\tmov %d(%%rbp), %s\n", temp->offset, reg);  // %reg = (%rbp + offset)
    }
}

void storeOnStack(char *reg, char *var) {
    VariableMemory *temp = mem->variables;
    while (temp != NULL) {
        if (strcmp(temp->name, var) == 0) {
            break;
        }
        temp = temp->next;
    }
    if (temp == NULL) {
        VariableMemory *new = malloc(sizeof(VariableMemory));
        new->name = var;
        mem->topOfStack -= 8;
        new->offset = mem->topOfStack;
        new->next = mem->variables;
        mem->variables = new;
        fprintf(file, "\tpush %s\n", reg);                          // %rsp -= 8; (%rsp) = %reg
    } else {
        fprintf(file, "\tmov %s, %d(%%rbp)\n", reg, temp->offset);  // (%rbp + offset) = %reg
    }
}