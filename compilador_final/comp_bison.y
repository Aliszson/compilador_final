%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

int yylex(void);
void yyerror(char *s);

/* --- ESTRUTURAS DE DADOS --- */
// A enum permanece a mesma, pois é usada internamente pelo C.
typedef enum { TIPO_NULO, TIPO_INT, TIPO_REAL, TIPO_TEXTO, TIPO_VETOR } TipoVar;

typedef struct ResultadoEval {
    TipoVar tipo;
    union { int val_int; double val_real; char *val_texto; } valor;
} ResultadoEval;
typedef struct Vetor {
    int tamanho;
    TipoVar tipo_elemento;
    void *dados;
} Vetor;
typedef struct Simbolo {
    char nome[50];
    TipoVar tipo;
    union { int val_int; double val_real; char *val_texto; Vetor *val_vetor; } valor;
    struct Simbolo *prox;
} Simbolo;
typedef struct AST {
    char tipo_no;
    struct AST *esq;
    struct AST *dir;
} AST;
typedef struct NoNumero { char tipo_no; ResultadoEval val; } NoNumero;
typedef struct NoTexto { char tipo_no; char *val_texto; } NoTexto;
typedef struct NoRefVar { char tipo_no; char *nome; } NoRefVar;
typedef struct NoRefVetor { char tipo_no; char *nome; AST *indice; } NoRefVetor;
typedef struct NoAtribuicao { char tipo_no; char *nome; AST *valor; AST *indice; } NoAtribuicao;
typedef struct NoFluxo { char tipo_no; AST *cond; AST *bloco_then; AST *bloco_else; } NoFluxo;
typedef struct NoDeclaracao { char tipo_no; TipoVar tipo; char *nome; AST *tamanho; } NoDeclaracao;
typedef struct NoEntrada { char tipo_no; char* nome; TipoVar tipo_leitura; } NoEntrada;

/* --- Tabela de Símbolos Global --- */
Simbolo *tabela_simbolos = NULL;

/* --- Funções Auxiliares (Tabela de Símbolos) --- */
Simbolo* buscar_simbolo(char *nome) {
    for (Simbolo *sp = tabela_simbolos; sp != NULL; sp = sp->prox) {
        /* CORREÇÃO 1: Trocar sp->name por sp->nome */
        if (strcmp(sp->nome, nome) == 0) return sp;
    }
    return NULL;
}
Simbolo* adicionar_simbolo(char *nome, TipoVar tipo, int tamanho_vetor) {
    if (buscar_simbolo(nome)) {
        char erro_msg[100];
        sprintf(erro_msg, "Erro: Variável '%s' já foi declarada.", nome);
        yyerror(erro_msg);
    }
    Simbolo *s = (Simbolo*) malloc(sizeof(Simbolo));
    strcpy(s->nome, nome);
    s->tipo = tipo;
    if (tamanho_vetor > 0) {
        s->tipo = TIPO_VETOR;
        s->valor.val_vetor = (Vetor*) malloc(sizeof(Vetor));
        s->valor.val_vetor->tamanho = tamanho_vetor;
        s->valor.val_vetor->tipo_elemento = tipo;
        if (tipo == TIPO_INT) s->valor.val_vetor->dados = calloc(tamanho_vetor, sizeof(int));
        else if (tipo == TIPO_REAL) s->valor.val_vetor->dados = calloc(tamanho_vetor, sizeof(double));
        else yyerror("Erro: Vetores só podem ser de tipo INTEIRO ou REAL.");
    }
    s->prox = tabela_simbolos;
    tabela_simbolos = s;
    return s;
}

/* O resto das funções C (Construtores, eval, etc.) permanecem iguais */
AST* novo_no_ast(char tipo_no, AST *esq, AST *dir) { AST *a=(AST*)malloc(sizeof(AST)); a->tipo_no=tipo_no; a->esq=esq; a->dir=dir; return a; }
AST* novo_no_num(ResultadoEval val) { NoNumero *n=(NoNumero*)malloc(sizeof(NoNumero)); n->tipo_no='K'; n->val=val; return(AST*)n; }
AST* novo_no_texto(char* val_texto) { NoTexto *n=(NoTexto*)malloc(sizeof(NoTexto)); n->tipo_no='S'; n->val_texto=val_texto; return(AST*)n; }
AST* novo_no_ref_var(char *nome) { NoRefVar *n=(NoRefVar*)malloc(sizeof(NoRefVar)); n->tipo_no='N'; n->nome=nome; return(AST*)n; }
AST* novo_no_ref_vetor(char* nome, AST* i) { NoRefVetor* n=(NoRefVetor*)malloc(sizeof(NoRefVetor)); n->tipo_no='A'; n->nome=nome; n->indice=i; return(AST*)n; }
AST* novo_no_atribuicao(char* nome, AST* v, AST* i) { NoAtribuicao *n=(NoAtribuicao*)malloc(sizeof(NoAtribuicao)); n->tipo_no='='; n->nome=nome; n->valor=v; n->indice=i; return(AST*)n; }
AST* novo_no_fluxo(char t, AST* c, AST* th, AST* el) { NoFluxo *n=(NoFluxo*)malloc(sizeof(NoFluxo)); n->tipo_no=t; n->cond=c; n->bloco_then=th; n->bloco_else=el; return(AST*)n; }
AST* novo_no_declaracao(char *nome, TipoVar tipo, AST *tam) { NoDeclaracao *n=(NoDeclaracao*)malloc(sizeof(NoDeclaracao)); n->tipo_no='D'; n->nome=nome; n->tipo=tipo; n->tamanho=tam; return(AST*)n; }
AST* novo_no_entrada(char* nome, TipoVar tipo_leitura) { NoEntrada *n=(NoEntrada*)malloc(sizeof(NoEntrada)); n->tipo_no='R'; n->nome=nome; n->tipo_leitura=tipo_leitura; return(AST*)n; }
ResultadoEval eval(AST *a);

void executar(AST *a) { if (a) { eval(a); } }
ResultadoEval eval(AST *a) {
    ResultadoEval res; res.tipo = TIPO_NULO; if (!a) return res;
    switch(a->tipo_no) {
        case 'K': return ((NoNumero*)a)->val;
        case 'S': res.tipo=TIPO_TEXTO; res.valor.val_texto=((NoTexto*)a)->val_texto; return res;
        case 'N': {
            Simbolo *s = buscar_simbolo(((NoRefVar*)a)->nome);
            if (!s) { char err[100]; sprintf(err, "Erro: Variável '%s' não declarada.", ((NoRefVar*)a)->nome); yyerror(err); }
            res.tipo = s->tipo;
            if (s->tipo == TIPO_INT) res.valor.val_int = s->valor.val_int;
            else if (s->tipo == TIPO_REAL) res.valor.val_real = s->valor.val_real;
            else if (s->tipo == TIPO_TEXTO) res.valor.val_texto = s->valor.val_texto;
            return res;
        }
        case 'A': {
            Simbolo* s = buscar_simbolo(((NoRefVetor*)a)->nome);
            if (!s || s->tipo != TIPO_VETOR) yyerror("Erro: Vetor não declarado.");
            ResultadoEval i_res = eval(((NoRefVetor*)a)->indice);
            if (i_res.tipo != TIPO_INT) yyerror("Erro: Índice do vetor deve ser um inteiro.");
            int i = i_res.valor.val_int;
            if (i < 0 || i >= s->valor.val_vetor->tamanho) yyerror("Erro: Índice fora dos limites.");
            res.tipo = s->valor.val_vetor->tipo_elemento;
            if (res.tipo == TIPO_INT) res.valor.val_int = ((int*)s->valor.val_vetor->dados)[i];
            else if (res.tipo == TIPO_REAL) res.valor.val_real = ((double*)s->valor.val_vetor->dados)[i];
            return res;
        }
        case '=': {
            char *nome = ((NoAtribuicao*)a)->nome; Simbolo *s = buscar_simbolo(nome);
            if (!s) yyerror("Erro: Variável não declarada para atribuição.");
            ResultadoEval v_res = eval(((NoAtribuicao*)a)->valor); AST* i_no = ((NoAtribuicao*)a)->indice;
            if (i_no) {
                if(s->tipo!=TIPO_VETOR) yyerror("Erro: Acesso de vetor em variável simples.");
                ResultadoEval i_res = eval(i_no); if(i_res.tipo!=TIPO_INT) yyerror("Erro: Índice deve ser inteiro.");
                int i=i_res.valor.val_int; if(i<0||i>=s->valor.val_vetor->tamanho) yyerror("Erro: Índice fora dos limites.");
                if(s->valor.val_vetor->tipo_elemento==TIPO_INT&&v_res.tipo==TIPO_INT) ((int*)s->valor.val_vetor->dados)[i]=v_res.valor.val_int;
                else if(s->valor.val_vetor->tipo_elemento==TIPO_REAL&&(v_res.tipo==TIPO_REAL||v_res.tipo==TIPO_INT)) ((double*)s->valor.val_vetor->dados)[i]=(v_res.tipo==TIPO_REAL)?v_res.valor.val_real:v_res.valor.val_int;
                else yyerror("Erro: Tipo incompatível para atribuição no vetor.");
            } else {
                if(s->tipo==TIPO_INT&&v_res.tipo==TIPO_INT)s->valor.val_int=v_res.valor.val_int;
                else if(s->tipo==TIPO_REAL&&(v_res.tipo==TIPO_REAL||v_res.tipo==TIPO_INT))s->valor.val_real=(v_res.tipo==TIPO_REAL)?v_res.valor.val_real:v_res.valor.val_int;
                else if(s->tipo==TIPO_TEXTO&&v_res.tipo==TIPO_TEXTO)s->valor.val_texto=strdup(v_res.valor.val_texto);
                else yyerror("Erro: Tipo incompatível para atribuição.");
            }
            return res;
        }
        case 'I': if(eval(((NoFluxo*)a)->cond).valor.val_int!=0){return eval(((NoFluxo*)a)->bloco_then);}else if(((NoFluxo*)a)->bloco_else){return eval(((NoFluxo*)a)->bloco_else);} return res;
        case 'W': while(eval(((NoFluxo*)a)->cond).valor.val_int!=0){eval(((NoFluxo*)a)->bloco_then);} return res;
        case 'P': {
            ResultadoEval v_pr=eval(a->esq);
            if(v_pr.tipo==TIPO_INT)printf("%d\n",v_pr.valor.val_int);
            else if(v_pr.tipo==TIPO_REAL)printf("%.2f\n",v_pr.valor.val_real);
            else if(v_pr.tipo==TIPO_TEXTO)printf("%s\n",v_pr.valor.val_texto);
            return res;
        }
        case 'R': {
            NoEntrada *no=(NoEntrada*)a; Simbolo *s=buscar_simbolo(no->nome);
            if(!s)yyerror("Erro: Variável não declarada para leitura.");
            if(s->tipo!=no->tipo_leitura)yyerror("Erro: Tentando ler para tipo incorreto.");
            if(s->tipo==TIPO_INT)scanf("%d",&s->valor.val_int);
            else if(s->tipo==TIPO_REAL)scanf("%lf",&s->valor.val_real);
            else if(s->tipo==TIPO_TEXTO){char b[256];scanf("%255s",b);s->valor.val_texto=strdup(b);}
            return res;
        }
        case 'D': {
            NoDeclaracao *no=(NoDeclaracao*)a; int tam=0;
            if(no->tamanho){ResultadoEval t_res=eval(no->tamanho);if(t_res.tipo!=TIPO_INT||t_res.valor.val_int<=0)yyerror("Erro: Tamanho do vetor deve ser inteiro positivo.");tam=t_res.valor.val_int;}
            adicionar_simbolo(no->nome,no->tipo,tam); return res;
        }
        case 'L': eval(a->esq); return eval(a->dir);
        default: {
            ResultadoEval esq=eval(a->esq); ResultadoEval dir=eval(a->dir);
            if(a->tipo_no=='+'){
                if(esq.tipo==TIPO_TEXTO||dir.tipo==TIPO_TEXTO){
                    char s_e[256],s_d[256];
                    if(esq.tipo==TIPO_INT)sprintf(s_e,"%d",esq.valor.val_int); else if(esq.tipo==TIPO_REAL)sprintf(s_e,"%.2f",esq.valor.val_real); else strcpy(s_e,esq.valor.val_texto);
                    if(dir.tipo==TIPO_INT)sprintf(s_d,"%d",dir.valor.val_int); else if(dir.tipo==TIPO_REAL)sprintf(s_d,"%.2f",dir.valor.val_real); else strcpy(s_d,dir.valor.val_texto);
                    strcat(s_e,s_d); res.tipo=TIPO_TEXTO; res.valor.val_texto=strdup(s_e); return res;
                }
            }
            if((esq.tipo!=TIPO_INT&&esq.tipo!=TIPO_REAL)||(dir.tipo!=TIPO_INT&&dir.tipo!=TIPO_REAL)){yyerror("Erro: Operação com tipo inválido.");}
            double v_e=(esq.tipo==TIPO_INT)?esq.valor.val_int:esq.valor.val_real; double v_d=(dir.tipo==TIPO_INT)?dir.valor.val_int:dir.valor.val_real; double r_d;
            res.tipo=(esq.tipo==TIPO_REAL||dir.tipo==TIPO_REAL)?TIPO_REAL:TIPO_INT;
            switch(a->tipo_no){
                case '+':r_d=v_e+v_d;break; case '-':r_d=v_e-v_d;break; case '*':r_d=v_e*v_d;break; case '/':if(v_d==0)yyerror("Erro: Divisão por zero.");r_d=v_e/v_d;break;
                case '1':res.tipo=TIPO_INT;res.valor.val_int=(v_e>v_d);return res; case '2':res.tipo=TIPO_INT;res.valor.val_int=(v_e<v_d);return res;
                case '3':res.tipo=TIPO_INT;res.valor.val_int=(v_e!=v_d);return res; case '4':res.tipo=TIPO_INT;res.valor.val_int=(v_e==v_d);return res;
                case '5':res.tipo=TIPO_INT;res.valor.val_int=(v_e>=v_d);return res; case '6':res.tipo=TIPO_INT;res.valor.val_int=(v_e<=v_d);return res;
                default:yyerror("Erro interno: operador desconhecido.");
            }
            if(res.tipo==TIPO_INT)res.valor.val_int=(int)r_d; else res.valor.val_real=r_d; return res;
        }
    }
}

%}

/* --- Definição da União e dos Tokens --- */
%union {
    int val_int;
    double val_real;
    char *val_texto;
    int func_comp;
    AST *no;
}
%token <val_int> INTEIRO
%token <val_real> REAL
%token <val_texto> TEXTO IDENTIFICADOR
/* CORREÇÃO 2: Renomear os tokens de tipo */
%token VAR KW_INTEIRO KW_REAL KW_TEXTO
%token SE SENAO ENQUANTO ESCREVA
%token LEIA_INT LEIA_REAL LEIA_TEXTO
%token <func_comp> OP_COMP

%type <no> expr lista_comandos comando declaracao atribuicao comando_escreva comando_leia comando_se comando_enquanto

%left '+' '-'
%left '*' '/'
%left OP_COMP
%right '='

%%

/* --- Regras da Gramática --- */
programa:
    lista_comandos
    ;
lista_comandos:
      comando                  { if($1) { $$ = $1; executar($$); } }
    | lista_comandos comando   { if($2) { $$ = novo_no_ast('L', $1, $2); executar($2); } }
    ;
comando:
      declaracao ';'          { $$ = $1; }
    | atribuicao ';'          { $$ = $1; }
    | comando_escreva ';'     { $$ = $1; }
    | comando_leia ';'        { $$ = $1; }
    | comando_se              { $$ = $1; }
    | comando_enquanto        { $$ = $1; }
    | ';'                     { $$ = NULL; }
    ;
declaracao:
    /* CORREÇÃO 2: Usar os novos tokens na regra */
    /* A ação semântica continua usando a enum TIPO_INT, o que está correto! */
      VAR KW_INTEIRO IDENTIFICADOR                { $$ = novo_no_declaracao($3, TIPO_INT, NULL); }
    | VAR KW_REAL IDENTIFICADOR                   { $$ = novo_no_declaracao($3, TIPO_REAL, NULL); }
    | VAR KW_TEXTO IDENTIFICADOR                  { $$ = novo_no_declaracao($3, TIPO_TEXTO, NULL); }
    | VAR KW_INTEIRO IDENTIFICADOR '[' expr ']'   { $$ = novo_no_declaracao($3, TIPO_INT, $5); }
    | VAR KW_REAL IDENTIFICADOR '[' expr ']'      { $$ = novo_no_declaracao($3, TIPO_REAL, $5); }
    ;
atribuicao:
      IDENTIFICADOR '=' expr                          { $$ = novo_no_atribuicao($1, $3, NULL); }
    | IDENTIFICADOR '[' expr ']' '=' expr             { $$ = novo_no_atribuicao($1, $6, $3); }
    ;
comando_escreva:
    ESCREVA '(' expr ')'                              { $$ = novo_no_ast('P', $3, NULL); }
    ;
comando_leia:
      LEIA_INT '(' IDENTIFICADOR ')'                  { $$ = novo_no_entrada($3, TIPO_INT); }
    | LEIA_REAL '(' IDENTIFICADOR ')'                 { $$ = novo_no_entrada($3, TIPO_REAL); }
    | LEIA_TEXTO '(' IDENTIFICADOR ')'                { $$ = novo_no_entrada($3, TIPO_TEXTO); }
    ;
comando_se:
      SE '(' expr ')' '{' lista_comandos '}'                                { $$ = novo_no_fluxo('I', $3, $6, NULL); }
    | SE '(' expr ')' '{' lista_comandos '}' SENAO '{' lista_comandos '}'   { $$ = novo_no_fluxo('I', $3, $6, $10); }
    ;
comando_enquanto:
    ENQUANTO '(' expr ')' '{' lista_comandos '}'      { $$ = novo_no_fluxo('W', $3, $6, NULL); }
    ;
expr:
      expr '+' expr       { $$ = novo_no_ast('+', $1, $3); }
    | expr '-' expr       { $$ = novo_no_ast('-', $1, $3); }
    | expr '*' expr       { $$ = novo_no_ast('*', $1, $3); }
    | expr '/' expr       { $$ = novo_no_ast('/', $1, $3); }
    | expr OP_COMP expr   { $$ = novo_no_ast('0' + $2, $1, $3); }
    | '(' expr ')'        { $$ = $2; }
    | INTEIRO             { ResultadoEval r; r.tipo = TIPO_INT; r.valor.val_int = $1; $$ = novo_no_num(r); }
    | REAL                { ResultadoEval r; r.tipo = TIPO_REAL; r.valor.val_real = $1; $$ = novo_no_num(r); }
    | TEXTO               { $$ = novo_no_texto($1); }
    | IDENTIFICADOR       { $$ = novo_no_ref_var($1); }
    | IDENTIFICADOR '[' expr ']' { $$ = novo_no_ref_vetor($1, $3); }
    ;

%%

/* --- Função Principal e de Erro --- */
extern FILE *yyin;
extern int yylineno; 

int main(void) {
    yyin = fopen("entrada.txt", "r");
    if (!yyin) {
        perror("Não foi possível abrir o arquivo 'entrada.txt'");
        return 1;
    }
    yyparse();
    fclose(yyin);
    return 0;
}

void yyerror(char *s) {
    fprintf(stderr, "%s na linha %d\n", s, yylineno);
    exit(1);
}