%option never-interactive
%option nounput
%option noinput
%option warn

%s TOKEN NORMAL
%{
    #include <string.h>
    #include "symbolTable.h"
    #include "parser.tab.h"
    #define ID 101
    #define T_INTEGER 201
    #define T_ADDRESS 202
    #define T_BOOLEAN 203
    #define T_CHARACTER 204
    #define T_STRING 205
    #define C_INTEGER 301
    #define C_NULL 302
    #define C_CHARACTER 303
    #define C_STRING 304
    #define C_TRUE 305
    #define C_FALSE 306
    #define WHILE 401
    #define IF 402
    #define THEN 403
    #define ELSE 404
    #define TYPE 405
    #define FUNCTION 406
    #define RETURN 407
    #define EXTERNAL 408
    #define AS 409
    #define L_PAREN 501
    #define R_PAREN 502
    #define L_BRACKET 503
    #define R_BRACKET 504
    #define L_BRACE 505
    #define R_BRACE 506
    #define SEMI_COLON 507
    #define COLON 508
    #define COMMA 509
    #define ARROW 510
    #define ADD 601
    #define SUB_OR_NEG 602
    #define MUL 603
    #define DIV 604
    #define REM 605
    #define LESS_THAN 606
    #define EQUAL_TO 607
    #define ASSIGN 608
    #define NOT 609
    #define AND 610
    #define OR 611
    #define DOT 612
    #define RESERVE 613
    #define RELEASE 614
    #define COMMENT 700
    #define INCLUDE 800
    #define ERROR 801
    #define YY_USER_ACTION column_number = column_number + prev_col_add; prev_col_add = strlen(yytext); line_number = line_number + prev_row_add; prev_row_add = 0;

    int prev_col_add = 0;
    int prev_row_add = 0;
    int token_mode;
    int line_number = 1;
    int column_number = 1;
    int countSubString(const char *haystack, const char *needle){
        int count = 0;
        const char *tmp = haystack;
        while((tmp = strstr(tmp, needle))) {
            count++;
            tmp++;
        }
        return count;
    }

%}
%%
	if (token_mode)
		BEGIN(TOKEN);
	else
		BEGIN(NORMAL);

" " 
[\t] {prev_col_add=4;}
[\n] {line_number++; column_number=1; prev_col_add=0;}
<TOKEN>"(*"([^*]|("*"[^)]))*"*)" {prev_row_add = countSubString(yytext, "\n"); return COMMENT;}
<TOKEN>"#include"" "*(((\")[a-zA-Z.\\]*\")|(\<[a-zA-Z.\\]*\>)) {return INCLUDE;}
<NORMAL>"(*"([^*]|("*"[^)]))*"*)" {prev_row_add = countSubString(yytext, "\n");}
\"([^\n"]|(\\\"))*\" {yylval.const_string = custom_strdup(yytext); return C_STRING;}
"integer" {return T_INTEGER;}
"address" {return T_ADDRESS;}
"Boolean" {return T_BOOLEAN;}
"character" {return T_CHARACTER;}
"string" {return T_STRING;}
[0-9]+ {yylval.const_integer = atoi(yytext); return C_INTEGER;}
"null" {return C_NULL;}
'([^'\\]|"\\t"|"\\\\"|"\\'"|"\\n")' {yylval.const_character = yytext[1]; return C_CHARACTER;}
"true" {return C_TRUE;}
"false" {return C_FALSE;}
"while" {return WHILE;}
"if" {return IF;}
"then" {return THEN;}
"else" {return ELSE;}
"type" {return TYPE;}
"function" {return FUNCTION;}
"return" {return RETURN;}
"external" {return EXTERNAL;}
"as" {return AS;}
"(" {return L_PAREN;}
")" {return R_PAREN;}
"[" {return L_BRACKET;}
"]" {return R_BRACKET;}
"{" {return L_BRACE;}
"}" {return R_BRACE;}
";" {return SEMI_COLON;}
":" {return COLON;}
"," {return COMMA;}
"->" {return ARROW;}
"+" {return ADD;}
"-" {return SUB_OR_NEG;}
"*" {return MUL;}
"/" {return DIV;}
"%" {return REM;}
"<" {return LESS_THAN;}
"=" {return EQUAL_TO;}
":=" {return ASSIGN;}
"!" {return NOT;}
"&" {return AND;}
"|" {return OR;}
"." {return DOT;}
"reserve" {return RESERVE;}
"release" {return RELEASE;}
[a-zA-Z_][0-9a-zA-Z_]* {yylval.name = custom_strdup(yytext); return ID;}
. {return ERROR;} // This is so random characters like $ and % cause errors rather than being ignored
%%
int yywrap(){
    return 1;
}