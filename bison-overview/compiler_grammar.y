/* 	This is an example file that I (Tyler) have been working on to learn how to write bison files. 
	It likely has many issues, but can still be useful to see how some of the file can be written. 
*/

%start program

%union {
	float num;
	char *id;
	};

/* identifier */
%token IDENTIFIER 101

/* type names */
%token T_INTEGER 201
%token T_ADDRESS 202
%token T_BOOLEAN 203
%token T_CHARACTER 204
%token T_STRING 205

/* constants (literals) */
%token C_INTEGER 301
%token C_NULL 302
%token C_CHARACTER 303
%token C_STRING 304
%token C_TRUE 305
%token C_FALSE 306

/* other keywords */
%token WHILE 401
%token IF 402
%token THEN 403
%token ELSE 404
%token TYPE 405
%token FUNCTION 406
%token RETURN 407
%token EXTERNAL 408
%token AS 409

/* punctuation - grouping */
%token L_PAREN 501
%token R_PAREN 502
%token L_BRACKET 503
%token R_BRACKET 504
%token L_BRACE 505
%token R_BRACE 506

/* punctuation - other */
%token SEMI_COLON 507
%token COLON 508
%token COMMA 509
%token ARROW 510

/* operators - in order of ascending precendence */
%nonassoc ASSIGN 608
%left OR 611
%left AND 610
%left EQUAL_TO 607
%left LESS_THAN 606
%left ADD 601 SUB_OR_NEG 602
%left TIMES 603 DIVIDE 604 MODULUS 605
%nonassoc NOT 609
%nonassoc NEG
%nonassoc DOT 612
%nonassoc RESERVE "reserve" RELEASE "release"
	/* need a token number for these two. must be consistant with lexer */

%%
program:
  prototype-or-definition-list
;


prototype-or-definition-list:
  prototype-or-definition-list prototype
| prototype-or-definition-list definition
| prototype
| definition
;


prototype:
  FUNCTION IDENTIFIER COLON IDENTIFIER
  	/* IDENTIFIER 1 - a function name
	   IDENTIFIER 2 - the return type of the function
	*/
| EXTERNAL FUNCTION IDENTIFIER COLON IDENTIFIER
	/* EXTERNAL - tells the compiler that this function is in another file
	   IDENTIFIER 1 - a function name
	   IDENTIFIER 2 - the return type of the function
	*/
;


definition:
	/* type is used to start (most) definitions */
  a_type IDENTIFIER COLON dblock
  	/* IDENTIFIER - name of the record type */
| a_type IDENTIFIER COLON constant ARROW IDENTIFIER
	/* Mapping a new array type
	   IDENTIFIER 1 - array type name (custom)
	   constant 2 - dimensions of the array (i.e. 2D, 3D, etc.)
	   IDENTIFIER 3 - element type name
	*/
| a_type IDENTIFIER COLON IDENTIFIER ARROW IDENTIFIER
	/* Mapping a new function type
	   IDENTIFIER 1 - function type name
	   IDENTIFIER 2 - domain type
	   IDENTIFIER 3 - range type
	*/
| IDENTIFIER parameter ASSIGN sblock
	/* Function definition
	   IDENTIFIER - name of the function
	*/
;


parameter:
  L_PAREN IDENTIFIER R_PAREN
| IDENTIFIER AS L_PAREN idlist R_PAREN
;


idlist:
  idlist COMMA IDENTIFIER
| IDENTIFIER
;


sblock:
  L_BRACE statement-list R_BRACE
| L_BRACE dblock statement-list R_BRACE
;


dblock:
  L_BRACKET declaration-list R_BRACKET
;


declaration-list:
  declaration-list SEMI_COLON declaration
| declaration
;


declaration:
  IDENTIFIER COLON IDENTIFIER
;


statement-list:
  statement-list compound-statement
| compound-statement
| statement-list SEMI_COLON simple-statement
| simple-statement SEMI_COLON
;


compound-statement:
  WHILE L_PAREN expression R_PAREN sblock
| IF L_PAREN expression R_PAREN THEN sblock ELSE sblock
| sblock
;


simple-statement:
  assignable ASSIGN expression
| RETURN expression
;


assignable:
  IDENTIFIER
| assignable ablock
| assignable recOp IDENTIFIER
;


expression:
  constant
| UnaryOperator expression
| assignable
| expression binaryOperator expression
| L_PAREN expression R_PAREN
| memOp assignable
;


ablock:
  L_PAREN argument-list R_PAREN
;


argument-list:
  argument-list COMMA expression
| expression
;


UnaryOperator:
  SUB_OR_NEG %prec NEG
| NOT
;


memOp:
  RESERVE
| RELEASE
;


recOp:
  DOT
;


binaryOperator:
  ADD
| SUB_OR_NEG
| TIMES
| DIVIDE
| MODULUS
| AND
| OR
| LESS_THAN
| EQUAL_TO
;


constant: 
  C_INTEGER
| C_NULL
| C_CHARACTER
| C_STRING
| C_TRUE
| C_FALSE
;

a_type:
  TYPE
| T_ADDRESS
| T_BOOLEAN
| T_CHARACTER
| T_INTEGER
| T_STRING
;
%%