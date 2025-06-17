%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "calc_bison.tab.h"
extern void yyerror(const char *msg);
%}

/* expressões regulares */
DIGITO      [0-9]
NUM         {DIGITO}+(\.{DIGITO}+)?  
ID          [a-z]
STRING      \"([^\\"]|\\.)*\"
ESPACO      [ \t\r]+
NL          [\r\n]+

%%

"INICIO"            { return INICIO; }
"FIM"               { return FIM; }

"leia"              { return LEIA; }
"escreva"           { return ESCREVA; }

{NUM}               { yylval.flo = atof(yytext); return NUM; }

{ID}                { yylval.inte = yytext[0] - 'a'; return VAR; }

{STRING}            {
                        /* copia sem as aspas */
                        int len = yyleng;
                        yylval.str = strndup(yytext+1, len-2);
                        return STRING;
                    }

"="                 { return '='; }

"("                 { return '('; }
")"                 { return ')'; }
","                 { return ','; }
"+"                 { return '+'; }
"*"                 { return '*'; }
"-"                 { return '-'; }
"/"                 { return '/'; }

{ESPACO}            { /* ignora espaços e tabs */ }
{NL}                { /* ignora quebras de linha */ }

.                   { fprintf(stderr, "Caractere desconhecido: %s\n", yytext); }

%%

int yywrap(void) {
    return 1;
}
