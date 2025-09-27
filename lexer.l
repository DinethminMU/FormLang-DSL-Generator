%{
#include "parser.tab.h"
#include <string.h>
%}

%%

form        { return FORM; }
meta        { return META; }
section     { return SECTION; }
field       { return FIELD; }
validate    { return VALIDATE; }
if          { return IF; }
error       { return ERROR; }

required    { return REQ; }
min         { return MIN; }
max         { return MAX; }
default     { return DEFAULT; }

true        { yylval.text = strdup(yytext); return BOOL; }
false       { yylval.text = strdup(yytext); return BOOL; }

":"         { return COLON; }
";"         { return SEMICOLON; }
"="         { return EQUALS; }  
"{"         { return LBRACE; }
"}"         { return RBRACE; }
"["         { return LBRACK; }
"]"         { return RBRACK; }
","         { return COMMA; }

"<"         { return LESS_THAN; }  
">"         { return GREATER_THAN; }  
"=="        { return EQUAL_TO; }  

[0-9]+      { yylval.number = atoi(yytext); return NUMBER; }

\"[^\"]+\"  {
    yylval.text = strdup(yytext + 1);
    yylval.text[strlen(yylval.text)-1] = '\0';
    return STRING;
}

[a-zA-Z_][a-zA-Z0-9_]* {
    yylval.text = strdup(yytext);
    return NAME;
}

[ \t\r\n]+  ; // Ignore whitespace
.           { return *yytext; }

%%

int yywrap() { return 1; }
