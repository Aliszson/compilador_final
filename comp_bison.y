%{
#include <stdio.h>     
#include <stdlib.h>     
#include <string.h>     
#include <math.h>       

// Protótipos de funções que o Bison espera que existam.
int yylex(void);        // Função do analisador léxico (gerada pelo Flex/Lex)
void yyerror(char *s);  // Função para reportar erros de sintaxe

/*
* *
* DEFINIÇÃO DAS ESTRUTURAS DE DADOS                        *
* *
*/

/**
 * @enum TipoVar
 * @brief Enumeração para os tipos de dados suportados pela linguagem.
 */
typedef enum { 
    TIPO_NULO,          // Representa um tipo vazio ou sem valor
    TIPO_INT,           // Tipo Inteiro
    TIPO_REAL,          // Tipo Real (ponto flutuante)
    TIPO_TEXTO,         // Tipo Texto (string)
    TIPO_VETOR          // Tipo especial para identificar vetores na Tabela de Símbolos
} TipoVar;

/**
 * @struct ResultadoEval
 * @brief Estrutura para armazenar o resultado da avaliação de uma expressão,
 * contendo tanto o valor quanto o seu tipo.
 */
typedef struct ResultadoEval {
    TipoVar tipo;
    union { 
        int val_int; 
        double val_real; 
        char *val_texto; 
    } valor;
} ResultadoEval;

/**
 * @struct Vetor
 * @brief Representa um vetor (array), contendo seus metadados e os dados.
 */
typedef struct Vetor {
    int tamanho;                // Número de elementos do vetor
    TipoVar tipo_elemento;      // O tipo de cada elemento do vetor (TIPO_INT ou TIPO_REAL)
    void *dados;                // Ponteiro genérico para o bloco de memória alocado
} Vetor;

/**
 * @struct Simbolo
 * @brief Representa uma entrada na Tabela de Símbolos.
 * A tabela é implementada como uma lista ligada de Símbolos.
 */
typedef struct Simbolo {
    char nome[50];              // Nome do identificador (variável)
    TipoVar tipo;               // Tipo da variável (TIPO_INT, TIPO_VETOR, etc.)
    union { 
        int val_int; 
        double val_real; 
        char *val_texto; 
        Vetor *val_vetor;       // Ponteiro para a estrutura do vetor, se for o caso
    } valor;
    struct Simbolo *prox;       // Ponteiro para o próximo símbolo na lista
} Simbolo;


// --- Estruturas dos Nós da Árvore Sintática Abstrata (AST) ---

/**
 * @struct AST
 * @brief Nó genérico da Árvore Sintática Abstrata (AST).
 */
typedef struct AST {
    char tipo_no;               // Caractere que identifica o tipo do nó (ex: '+', 'I' para IF)
    struct AST *esq;            // Ponteiro para a sub-árvore esquerda
    struct AST *dir;            // Ponteiro para a sub-árvore direita
} AST;

/**
 * @brief Nós especializados da AST, convertidos (type-cast) a partir de um AST*.
 */
typedef struct NoNumero { char tipo_no; ResultadoEval val; } NoNumero;               // Nó para um literal numérico ('K')
typedef struct NoTexto { char tipo_no; char *val_texto; } NoTexto;                   // Nó para um literal de texto ('S')
typedef struct NoRefVar { char tipo_no; char *nome; } NoRefVar;                       // Nó para uma referência a uma variável ('N')
typedef struct NoRefVetor { char tipo_no; char *nome; AST *indice; } NoRefVetor;      // Nó para acesso a um elemento de vetor ('A')
typedef struct NoAtribuicao { char tipo_no; char *nome; AST *valor; AST *indice; } NoAtribuicao; // Nó para um comando de atribuição ('=')
typedef struct NoFluxo { char tipo_no; AST *cond; AST *bloco_then; AST *bloco_else; } NoFluxo; // Nó para SE ('I') ou ENQUANTO ('W')
typedef struct NoDeclaracao { char tipo_no; TipoVar tipo; char *nome; AST *tamanho; } NoDeclaracao; // Nó para declaração ('D')
typedef struct NoEntrada { char tipo_no; char* nome; TipoVar tipo_leitura; } NoEntrada; // Nó para um comando de leitura ('R')


/*
* *
* VARIÁVEIS GLOBAIS DO INTERPRETADOR                         *
* *
*/

// Ponteiro para o início da Tabela de Símbolos (lista ligada).
Simbolo *tabela_simbolos = NULL;

// Ponteiro para a raiz da Árvore Sintática Abstrata, preenchido pelo parser.
AST *raiz_ast = NULL;


/*
* *
* FUNÇÕES AUXILIARES E MOTOR DE EXECUÇÃO                   *
* *
*/

// --- Funções da Tabela de Símbolos ---

/**
 * @brief Procura um símbolo na tabela pelo nome.
 * @param nome O nome do símbolo a ser buscado.
 * @return Ponteiro para o Simbolo se encontrado, ou NULL.
 */
Simbolo* buscar_simbolo(char *nome) {
    for (Simbolo *sp = tabela_simbolos; sp != NULL; sp = sp->prox) {
        if (strcmp(sp->nome, nome) == 0) 
            return sp;
    }
    return NULL;
}

/**
 * @brief Adiciona um novo símbolo (variável ou vetor) à tabela.
 * @param nome Nome do novo símbolo.
 * @param tipo Tipo do novo símbolo.
 * @param tamanho_vetor Se > 0, cria um vetor com este tamanho.
 * @return Ponteiro para o novo Simbolo criado.
 */
Simbolo* adicionar_simbolo(char *nome, TipoVar tipo, int tamanho_vetor) {
    // Verifica se a variável já existe
    if (buscar_simbolo(nome)) {
        char erro_msg[100];
        sprintf(erro_msg, "Erro semântico: Variável '%s' já foi declarada.", nome);
        yyerror(erro_msg);
    }
    
    // Aloca e inicializa o novo símbolo
    Simbolo *s = (Simbolo*) malloc(sizeof(Simbolo));
    strcpy(s->nome, nome);
    s->tipo = tipo;
    
    // Se for um vetor, aloca a memória para seus dados
    if (tamanho_vetor > 0) {
        s->tipo = TIPO_VETOR;
        s->valor.val_vetor = (Vetor*) malloc(sizeof(Vetor));
        s->valor.val_vetor->tamanho = tamanho_vetor;
        s->valor.val_vetor->tipo_elemento = tipo;
        
        if (tipo == TIPO_INT) {
            s->valor.val_vetor->dados = calloc(tamanho_vetor, sizeof(int));
        } else if (tipo == TIPO_REAL) {
            s->valor.val_vetor->dados = calloc(tamanho_vetor, sizeof(double));
        } else {
            yyerror("Erro semântico: Vetores só podem ser de tipo INTEIRO ou REAL.");
        }
    }
    
    // Insere o novo símbolo no início da lista
    s->prox = tabela_simbolos;
    tabela_simbolos = s;
    return s;
}

// --- Funções Construtoras da AST (Fábricas de Nós) ---
// Cada função aloca e inicializa um tipo específico de nó da árvore.

AST* novo_no_ast(char tipo_no, AST *esq, AST *dir) { AST *a = (AST*)malloc(sizeof(AST)); a->tipo_no = tipo_no; a->esq = esq; a->dir = dir; return a; }
AST* novo_no_num(ResultadoEval val) { NoNumero *n = (NoNumero*)malloc(sizeof(NoNumero)); n->tipo_no = 'K'; n->val = val; return (AST*)n; }
AST* novo_no_texto(char* val_texto) { NoTexto *n = (NoTexto*)malloc(sizeof(NoTexto)); n->tipo_no = 'S'; n->val_texto = val_texto; return (AST*)n; }
AST* novo_no_ref_var(char *nome) { NoRefVar *n = (NoRefVar*)malloc(sizeof(NoRefVar)); n->tipo_no = 'N'; n->nome = nome; return (AST*)n; }
AST* novo_no_ref_vetor(char* nome, AST* i) { NoRefVetor* n = (NoRefVetor*)malloc(sizeof(NoRefVetor)); n->tipo_no = 'A'; n->nome = nome; n->indice = i; return (AST*)n; }
AST* novo_no_atribuicao(char* nome, AST* v, AST* i) { NoAtribuicao *n = (NoAtribuicao*)malloc(sizeof(NoAtribuicao)); n->tipo_no = '='; n->nome = nome; n->valor = v; n->indice = i; return (AST*)n; }
AST* novo_no_fluxo(char t, AST* c, AST* th, AST* el) { NoFluxo *n = (NoFluxo*)malloc(sizeof(NoFluxo)); n->tipo_no = t; n->cond = c; n->bloco_then = th; n->bloco_else = el; return (AST*)n; }
AST* novo_no_declaracao(char *nome, TipoVar tipo, AST *tam) { NoDeclaracao *n = (NoDeclaracao*)malloc(sizeof(NoDeclaracao)); n->tipo_no = 'D'; n->nome = nome; n->tipo = tipo; n->tamanho = tam; return (AST*)n; }
AST* novo_no_entrada(char* nome, TipoVar tipo_leitura) { NoEntrada *n = (NoEntrada*)malloc(sizeof(NoEntrada)); n->tipo_no = 'R'; n->nome = nome; n->tipo_leitura = tipo_leitura; return (AST*)n; }

// --- Motor de Execução (Interpretador) ---

// Protótipo da função principal de avaliação.
ResultadoEval eval(AST *a);

/**
 * @brief Ponto de entrada para a execução da AST.
 * @param a Ponteiro para a raiz da AST a ser executada.
 */
void executar(AST *a) { 
    if (a) { 
        eval(a); 
    } 
}

/**
 * @brief Função recursiva que "caminha" pela AST e interpreta o programa.
 * @param a O nó da AST a ser avaliado.
 * @return O resultado da avaliação da sub-árvore (se aplicável).
 */
ResultadoEval eval(AST *a) {
    ResultadoEval res; 
    res.tipo = TIPO_NULO; 
    
    // Caso base da recursão: nó nulo não faz nada.
    if (!a) 
        return res;
    
    // Avalia o nó com base em seu tipo.
    switch(a->tipo_no) {
        // 'K': Nó de constante numérica. Retorna o valor armazenado.
        case 'K': 
            return ((NoNumero*)a)->val;
            
        // 'S': Nó de string literal. Retorna o texto.
        case 'S': 
            res.tipo = TIPO_TEXTO; 
            res.valor.val_texto = ((NoTexto*)a)->val_texto; 
            return res;
            
        // 'N': Referência a uma variável (Nome). Busca na tabela de símbolos.
        case 'N': {
            Simbolo *s = buscar_simbolo(((NoRefVar*)a)->nome);
            if (!s) { 
                char err[100]; 
                sprintf(err, "Erro: Variável '%s' não declarada.", ((NoRefVar*)a)->nome); 
                yyerror(err); 
            }
            
            res.tipo = s->tipo;
            if (s->tipo == TIPO_INT) {
                res.valor.val_int = s->valor.val_int;
            } else if (s->tipo == TIPO_REAL) {
                res.valor.val_real = s->valor.val_real;
            } else if (s->tipo == TIPO_TEXTO) {
                res.valor.val_texto = s->valor.val_texto;
            }
            return res;
        }
        
        // 'A': Acesso a um vetor (Array). Avalia o índice e retorna o elemento.
        case 'A': {
            Simbolo* s = buscar_simbolo(((NoRefVetor*)a)->nome);
            if (!s || s->tipo != TIPO_VETOR) {
                yyerror("Erro: Vetor não declarado.");
            }
            
            ResultadoEval i_res = eval(((NoRefVetor*)a)->indice);
            if (i_res.tipo != TIPO_INT) {
                yyerror("Erro: Índice do vetor deve ser um inteiro.");
            }
            
            int i = i_res.valor.val_int;
            if (i < 0 || i >= s->valor.val_vetor->tamanho) {
                yyerror("Erro: Índice fora dos limites.");
            }
            
            res.tipo = s->valor.val_vetor->tipo_elemento;
            if (res.tipo == TIPO_INT) {
                res.valor.val_int = ((int*)s->valor.val_vetor->dados)[i];
            } else if (res.tipo == TIPO_REAL) {
                res.valor.val_real = ((double*)s->valor.val_vetor->dados)[i];
            }
            return res;
        }
        
        // '=': Atribuição. Avalia a expressão da direita e atualiza a tabela de símbolos.
        case '=': {
            char *nome = ((NoAtribuicao*)a)->nome; 
            Simbolo *s = buscar_simbolo(nome);
            
            if (!s) {
                yyerror("Erro: Variável não declarada para atribuição.");
            }
            
            ResultadoEval v_res = eval(((NoAtribuicao*)a)->valor); 
            AST* i_no = ((NoAtribuicao*)a)->indice;
            
            if (i_no) { // Atribuição em um elemento de vetor
                if (s->tipo != TIPO_VETOR) {
                    yyerror("Erro: Acesso de vetor em variável simples.");
                }
                
                ResultadoEval i_res = eval(i_no); 
                if (i_res.tipo != TIPO_INT) {
                    yyerror("Erro: Índice deve ser inteiro.");
                }
                
                int i = i_res.valor.val_int; 
                if (i < 0 || i >= s->valor.val_vetor->tamanho) {
                    yyerror("Erro: Índice fora dos limites.");
                }
                
                // Atribui o valor com checagem de tipo
                if (s->valor.val_vetor->tipo_elemento == TIPO_INT && v_res.tipo == TIPO_INT) {
                    ((int*)s->valor.val_vetor->dados)[i] = v_res.valor.val_int;
                } else if (s->valor.val_vetor->tipo_elemento == TIPO_REAL && (v_res.tipo == TIPO_REAL || v_res.tipo == TIPO_INT)) {
                    ((double*)s->valor.val_vetor->dados)[i] = (v_res.tipo == TIPO_REAL) ? v_res.valor.val_real : v_res.valor.val_int;
                } else {
                    yyerror("Erro: Tipo incompatível para atribuição no vetor.");
                }
            } else { // Atribuição em variável simples
                if (s->tipo == TIPO_INT && v_res.tipo == TIPO_INT) {
                    s->valor.val_int = v_res.valor.val_int;
                } else if (s->tipo == TIPO_REAL && (v_res.tipo == TIPO_REAL || v_res.tipo == TIPO_INT)) {
                    s->valor.val_real = (v_res.tipo == TIPO_REAL) ? v_res.valor.val_real : v_res.valor.val_int;
                } else if (s->tipo == TIPO_TEXTO && v_res.tipo == TIPO_TEXTO) {
                    s->valor.val_texto = strdup(v_res.valor.val_texto); // Duplica a string para segurança
                } else {
                    yyerror("Erro: Tipo incompatível para atribuição.");
                }
            }
            return res;
        }
        
        // 'I': Comando SE (If). Avalia a condição e executa o bloco 'then' ou 'else'.
        case 'I': 
            if (eval(((NoFluxo*)a)->cond).valor.val_int != 0) {
                return eval(((NoFluxo*)a)->bloco_then);
            } else if (((NoFluxo*)a)->bloco_else) {
                return eval(((NoFluxo*)a)->bloco_else);
            } 
            return res;
            
        // 'W': Comando ENQUANTO (While). Avalia a condição e executa o bloco em laço.
        case 'W': 
            while (eval(((NoFluxo*)a)->cond).valor.val_int != 0) {
                eval(((NoFluxo*)a)->bloco_then);
            } 
            return res;
            
        // 'P': Comando ESCREVA (Print). Avalia a expressão e imprime o resultado.
        case 'P': {
            ResultadoEval v_pr = eval(a->esq);
            if (v_pr.tipo == TIPO_INT) {
                printf("%d\n", v_pr.valor.val_int);
            } else if (v_pr.tipo == TIPO_REAL) {
                printf("%.2f\n", v_pr.valor.val_real);
            } else if (v_pr.tipo == TIPO_TEXTO) {
                printf("%s\n", v_pr.valor.val_texto);
            }
            return res;
        }
        
        // 'R': Comando LEIA (Read). Lê um valor e armazena na variável.
        case 'R': {
            NoEntrada *no = (NoEntrada*)a; 
            Simbolo *s = buscar_simbolo(no->nome);
            
            if (!s) {
                yyerror("Erro: Variável não declarada para leitura.");
            }
            
            if (s->tipo != no->tipo_leitura) {
                yyerror("Erro: Tentando ler para tipo incorreto.");
            }
            
            if (s->tipo == TIPO_INT) {
                scanf("%d", &s->valor.val_int);
            } else if (s->tipo == TIPO_REAL) {
                scanf("%lf", &s->valor.val_real);
            } else if (s->tipo == TIPO_TEXTO) {
                char b[256];
                scanf("%255s", b);
                s->valor.val_texto = strdup(b);
            }
            return res;
        }
        
        // 'D': Declaração. Adiciona um novo símbolo à tabela de símbolos.
        case 'D': {
            NoDeclaracao *no = (NoDeclaracao*)a; 
            int tam = 0;
            
            if (no->tamanho) { // Se for uma declaração de vetor
                ResultadoEval t_res = eval(no->tamanho);
                if (t_res.tipo != TIPO_INT || t_res.valor.val_int <= 0) {
                    yyerror("Erro: Tamanho do vetor deve ser inteiro positivo.");
                }
                tam = t_res.valor.val_int;
            }
            
            adicionar_simbolo(no->nome, no->tipo, tam); 
            return res;
        }
        
        // 'L': Nó de Lista de comandos. Executa a esquerda e depois a direita.
        case 'L': 
            eval(a->esq); 
            return eval(a->dir);
            
        // default: Tratamento para operadores binários.
        default: { 
            ResultadoEval esq = eval(a->esq); 
            ResultadoEval dir = eval(a->dir);
            
            // Tratamento especial para concatenação com o operador '+'
            if (a->tipo_no == '+') {
                if (esq.tipo == TIPO_TEXTO || dir.tipo == TIPO_TEXTO) {
                    char s_e[256], s_d[256];
                    
                    if (esq.tipo == TIPO_INT) sprintf(s_e, "%d", esq.valor.val_int);
                    else if (esq.tipo == TIPO_REAL) sprintf(s_e, "%.2f", esq.valor.val_real);
                    else strcpy(s_e, esq.valor.val_texto);
                    
                    if (dir.tipo == TIPO_INT) sprintf(s_d, "%d", dir.valor.val_int);
                    else if (dir.tipo == TIPO_REAL) sprintf(s_d, "%.2f", dir.valor.val_real);
                    else strcpy(s_d, dir.valor.val_texto);
                    
                    strcat(s_e, s_d); 
                    res.tipo = TIPO_TEXTO; 
                    res.valor.val_texto = strdup(s_e); 
                    return res;
                }
            }
            
            // Validação de tipos para operações numéricas
            if ((esq.tipo != TIPO_INT && esq.tipo != TIPO_REAL) || 
                (dir.tipo != TIPO_INT && dir.tipo != TIPO_REAL)) {
                yyerror("Erro: Operação com tipo inválido.");
            }
            
            // Converte operandos para double para realizar os cálculos
            double v_e = (esq.tipo == TIPO_INT) ? esq.valor.val_int : esq.valor.val_real; 
            double v_d = (dir.tipo == TIPO_INT) ? dir.valor.val_int : dir.valor.val_real; 
            double r_d;
            
            res.tipo = (esq.tipo == TIPO_REAL || dir.tipo == TIPO_REAL) ? TIPO_REAL : TIPO_INT;
            
            switch(a->tipo_no) {
                case '+': r_d = v_e + v_d; break;
                case '-': r_d = v_e - v_d; break;
                case '*': r_d = v_e * v_d; break;
                case '/': 
                    if (v_d == 0) yyerror("Erro: Divisão por zero.");
                    r_d = v_e / v_d; 
                    break;
                // Operadores de comparação (retornam 0 ou 1, sempre INTEIRO)
                case '1': res.tipo = TIPO_INT; res.valor.val_int = (v_e > v_d); return res;
                case '2': res.tipo = TIPO_INT; res.valor.val_int = (v_e < v_d); return res;
                case '3': res.tipo = TIPO_INT; res.valor.val_int = (v_e != v_d); return res;
                case '4': res.tipo = TIPO_INT; res.valor.val_int = (v_e == v_d); return res;
                case '5': res.tipo = TIPO_INT; res.valor.val_int = (v_e >= v_d); return res;
                case '6': res.tipo = TIPO_INT; res.valor.val_int = (v_e <= v_d); return res;
                default:
                    yyerror("Erro interno: operador desconhecido.");
            }
            
            if (res.tipo == TIPO_INT) res.valor.val_int = (int)r_d;
            else res.valor.val_real = r_d; 
            return res;
        }
    }
}
%}

/*
* *
* DEFINIÇÕES DO ANALISADOR SINTÁTICO (BISON)                    *
* *
*/

/**
 * @brief Define os tipos de dados que podem ser armazenados na pilha de valores do Bison.
 */
%union {
    int val_int;
    double val_real;
    char *val_texto;
    int func_comp;
    AST *no;
}

// Declaração dos TOKENS (símbolos terminais) e seus tipos.
%token <val_int> INTEIRO
%token <val_real> REAL
%token <val_texto> TEXTO IDENTIFICADOR
%token VAR KW_INTEIRO KW_REAL KW_TEXTO
%token SE SENAO ENQUANTO ESCREVA
%token LEIA_INT LEIA_REAL LEIA_TEXTO
%token <func_comp> OP_COMP

// Declaração dos SÍMBOLOS NÃO-TERMINAIS e o tipo que eles produzem (um nó da AST).
%type <no> expr lista_comandos comando declaracao atribuicao comando_escreva comando_leia comando_se comando_enquanto

// Definição da PRECEDÊNCIA e ASSOCIATIVIDADE dos operadores.
%left '+' '-'
%left '*' '/'
%left OP_COMP
%right '='

%%

/*
* *
* REGRAS DA GRAMÁTICA                               *
* *
*/

// A regra inicial (axioma). Um programa é uma lista de comandos.
programa:
    lista_comandos { 
        // Ação: Salva a AST completa na variável global 'raiz_ast'.
        raiz_ast = $1; 
    }
    ;

// Regra recursiva para uma sequência de comandos.
lista_comandos:
    comando { 
        $$ = $1; // Um único comando já é uma lista de comandos válida.
    }
    | lista_comandos comando { 
        // Ação: Encadeia o novo comando ($2) à lista existente ($1) usando um nó de lista ('L').
        if ($1 && $2) {
            $$ = novo_no_ast('L', $1, $2); 
        } else if ($2) {
            $$ = $2;
        } else {
            $$ = $1;
        }
    }
    ;

// Define os diferentes tipos de comandos válidos na linguagem.
comando:
    declaracao ';'      { $$ = $1; }
    | atribuicao ';'      { $$ = $1; }
    | comando_escreva ';' { $$ = $1; }
    | comando_leia ';'    { $$ = $1; }
    | comando_se          { $$ = $1; }
    | comando_enquanto    { $$ = $1; }
    | ';'                 { $$ = NULL; } // Comando vazio.
    ;

// Regras para declaração de variáveis e vetores.
declaracao:
    VAR KW_INTEIRO IDENTIFICADOR                { $$ = novo_no_declaracao($3, TIPO_INT, NULL); }
    | VAR KW_REAL IDENTIFICADOR                 { $$ = novo_no_declaracao($3, TIPO_REAL, NULL); }
    | VAR KW_TEXTO IDENTIFICADOR                { $$ = novo_no_declaracao($3, TIPO_TEXTO, NULL); }
    | VAR KW_INTEIRO IDENTIFICADOR '[' expr ']' { $$ = novo_no_declaracao($3, TIPO_INT, $5); }
    | VAR KW_REAL IDENTIFICADOR '[' expr ']'    { $$ = novo_no_declaracao($3, TIPO_REAL, $5); }
    ;

// Regras para atribuição a variáveis ou elementos de vetor.
atribuicao:
    IDENTIFICADOR '=' expr                  { $$ = novo_no_atribuicao($1, $3, NULL); }
    | IDENTIFICADOR '[' expr ']' '=' expr   { $$ = novo_no_atribuicao($1, $6, $3); }
    ;

comando_escreva:
    ESCREVA '(' expr ')'                    { $$ = novo_no_ast('P', $3, NULL); }
    ;

comando_leia:
    LEIA_INT '(' IDENTIFICADOR ')'          { $$ = novo_no_entrada($3, TIPO_INT); }
    | LEIA_REAL '(' IDENTIFICADOR ')'         { $$ = novo_no_entrada($3, TIPO_REAL); }
    | LEIA_TEXTO '(' IDENTIFICADOR ')'        { $$ = novo_no_entrada($3, TIPO_TEXTO); }
    ;

comando_se:
    SE '(' expr ')' '{' lista_comandos '}'  
        { $$ = novo_no_fluxo('I', $3, $6, NULL); }
    | SE '(' expr ')' '{' lista_comandos '}' SENAO '{' lista_comandos '}' 
        { $$ = novo_no_fluxo('I', $3, $6, $10); }
    ;

comando_enquanto:
    ENQUANTO '(' expr ')' '{' lista_comandos '}' 
        { $$ = novo_no_fluxo('W', $3, $6, NULL); }
    ;

// Regras para expressões (aritméticas, lógicas, literais, etc.).
expr:
    expr '+' expr               { $$ = novo_no_ast('+', $1, $3); }
    | expr '-' expr               { $$ = novo_no_ast('-', $1, $3); }
    | expr '*' expr               { $$ = novo_no_ast('*', $1, $3); }
    | expr '/' expr               { $$ = novo_no_ast('/', $1, $3); }
    | expr OP_COMP expr           { $$ = novo_no_ast('0' + $2, $1, $3); }
    | '(' expr ')'                { $$ = $2; } // Parênteses apenas agrupam
    | INTEIRO                     { ResultadoEval r; r.tipo = TIPO_INT; r.valor.val_int = $1; $$ = novo_no_num(r); }
    | REAL                        { ResultadoEval r; r.tipo = TIPO_REAL; r.valor.val_real = $1; $$ = novo_no_num(r); }
    | TEXTO                       { $$ = novo_no_texto($1); }
    | IDENTIFICADOR               { $$ = novo_no_ref_var($1); }
    | IDENTIFICADOR '[' expr ']'  { $$ = novo_no_ref_vetor($1, $3); }
    ;

%%

/*
* *
* FUNÇÃO PRINCIPAL E DE TRATAMENTO DE ERRO                 *
* *
*/

// Variáveis externas que o Bison usa para rastrear a posição no arquivo.
extern FILE *yyin;
extern int yylineno; 

/**
 * @brief Ponto de entrada do programa interpretador.
 */
int main(void) {
    // Abre o arquivo de entrada para leitura.
    yyin = fopen("entrada.portugol2", "r");
    if (!yyin) {
        perror("Não foi possível abrir o arquivo 'entrada.portugol2'");
        return 1;
    }
    
    // Inicia a análise sintática. yyparse() retorna 0 em caso de sucesso.
    if (yyparse() == 0 && raiz_ast != NULL) {
        // Se a análise foi bem-sucedida, inicia a execução do programa.
        executar(raiz_ast);
    }
    
    // Fecha o arquivo e termina o programa.
    fclose(yyin);
    return 0;
}

/**
 * @brief Função chamada pelo Bison ao encontrar um erro de sintaxe.
 * @param s A mensagem de erro gerada pelo Bison.
 */
void yyerror(char *s) {
    // Imprime a mensagem de erro formatada com o número da linha.
    fprintf(stderr, "Erro na linha %d: %s\n", yylineno, s);
    exit(1); // Encerra o programa.
}