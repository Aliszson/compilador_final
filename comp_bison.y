%{
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

float var[26];
int yylex(void);
extern FILE *yyin;
void yyerror(const char *msg) {
    fprintf(stderr, "Erro de sintaxe: %s\n", msg);
}
%}

%union {
    float flo;
    int   inte;
    char *str;
}

%token <flo>  NUM
%token <inte> VAR
%token <str>  STRING
%token        INICIO FIM ESCREVA LEIA

%left '+' '-'
%left '*' '/'
%right '^'
%right NEG

%type <flo> exp
%type        paramlist valor

%%

prog:
    INICIO cod FIM
  ;

cod:
    /* vazio */
  | cod comando
  ;

comando:
    LEIA '(' VAR ')' {
        printf("> ");
        if (scanf("%f", &var[$3]) != 1) {
            yyerror("Erro ao ler variável");
        }
    }
  | ESCREVA '(' paramlist ')' {
        putchar('\n');
    }
  | VAR '=' exp {
        var[$1] = $3;
    }
  ;

paramlist:
    valor
  | paramlist ',' valor
  ;

valor:
    STRING {
        printf("%s", $1);
        free($1);
    }
  | exp {
        printf("%.2f", $1);
    }
  ;

exp:
      exp '+' exp     { $$ = $1 + $3; }
    | exp '-' exp     { $$ = $1 - $3; }
    | exp '*' exp     { $$ = $1 * $3; }
    | exp '/' exp     {
                          if ($3 == 0.0) {
                              yyerror("Divisão por zero");
                              $$ = 0.0;
                          } else $$ = $1 / $3;
                      }
    | exp '^' exp     { $$ = powf($1, $3); }
    | '-' exp  %prec NEG { $$ = -$2; }
    | '(' exp ')'     { $$ = $2; }
    | NUM             { $$ = $1; }
    | VAR             { $$ = var[$1]; }
  ;

%%

int main(void) {
    yyin = fopen("entrada.txt", "r");
    if (!yyin) {
        perror("Erro ao abrir entrada.txt");
       return 1;
    }
    
    int result = yyparse();
    fclose(yyin);
    return 0;
}
