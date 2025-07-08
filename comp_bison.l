%{
#include <string.h>

typedef struct AST AST;

#include "comp_bison.tab.h" 

void yyerror(char *s);
extern int yylineno; 

char *remover_aspas(char *texto) {
    int len = strlen(texto);
    if (len >= 2 && texto[0] == '"' && texto[len-1] == '"') {
        memmove(texto, texto + 1, len - 2);
        texto[len - 2] = '\0';
    }
    return texto;
}
%}

%option noyywrap

/* Definições Regulares */
INTEIRO [0-9]+
REAL    [0-9]+\.[0-9]+
ID      [a-zA-Z_][a-zA-Z0-9_]*

%%
[ \t\r\n]+ {
    for (int i = 0; yytext[i] != '\0'; i++) {
        if (yytext[i] == '\n') {
            yylineno++;
        }
    }
}

"//".* { /* Ignora comentários de linha única. Não faz nada. */ }

"VAR"         { return VAR; }
"INTEIRO"     { return KW_INTEIRO; }
"REAL"        { return KW_REAL; }
"TEXTO"       { return KW_TEXTO; }

"SE"          { return SE; }
"SENAO"       { return SENAO; }
"ENQUANTO"    { return ENQUANTO; }
"ESCREVA"     { return ESCREVA; }
"LEIA_INT"    { return LEIA_INT; }
"LEIA_REAL"   { return LEIA_REAL; }
"LEIA_TEXTO"  { return LEIA_TEXTO; }

{INTEIRO}     { yylval.val_int = atoi(yytext); return INTEIRO; }
{REAL}        { yylval.val_real = atof(yytext); return REAL; }

\"([^"\\\n]|\\.)*\" { 
    yylval.val_texto = strdup(remover_aspas(yytext)); 
    return TEXTO; 
}

{ID}          { yylval.val_texto = strdup(yytext); return IDENTIFICADOR; }

">"           { yylval.func_comp = 1; return OP_COMP; }
"<"           { yylval.func_comp = 2; return OP_COMP; }
"!="          { yylval.func_comp = 3; return OP_COMP; }
"=="          { yylval.func_comp = 4; return OP_COMP; }
">="          { yylval.func_comp = 5; return OP_COMP; }
"<="          { yylval.func_comp = 6; return OP_COMP; }

[-+*/=();,\[\]{}] { return *yytext; }

.             { yyerror("Erro de sintaxe: Caractere não reconhecido"); }

%%