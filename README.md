# Compilador "Portugol-2"

## A Linguagem "Portugol-2"

A linguagem implementada suporta as funcionalidades:

* **Tipos de Dados**:
    * `INTEIRO`: Números inteiros (ex: `10`, `42`).
    * `REAL`: Números de ponto flutuante (ex: `3.14`, `99.5`).
    * `TEXTO`: Cadeias de caracteres (ex: `"ola mundo"`).

* **Declarações**:
    * Variáveis simples: `VAR TIPO nome_variavel;`
    * Vetores (arrays): `VAR TIPO nome_vetor[tamanho];`

* **Comandos**:
    * **Atribuição**: `variavel = expressao;` ou `vetor[indice] = expressao;`
    * **Saída de Dados**: `ESCREVA(expressao);`
    * **Entrada de Dados**: `LEIA_INT(variavel);`, `LEIA_REAL(variavel);`, `LEIA_TEXTO(variavel);`
    * **Controle de Fluxo**:
        * Condicional `SE`/`SENAO`: `SE (condicao) { ... } SENAO { ... }`
        * Laço de Repetição `ENQUANTO`: `ENQUANTO (condicao) { ... }`

* **Expressões**:
    * Aritméticas: `+`, `-`, `*`, `/`.
    * De Comparação: `>`, `<`, `==`, `!=`, `>=`, `<=`. O resultado é sempre um `INTEIRO` (`1` para verdadeiro, `0` para falso).
    * Literais: Números, textos entre aspas.
    * Variáveis e acesso a elementos de vetor.
    * **Concatenação**: O operador `+` é sobrecarregado. Se um dos operandos for `TEXTO`, ele realiza a concatenação.

* **Sintaxe Adicional**:
    * Comandos devem terminar com `;`.
    * Blocos de código são delimitados por chaves `{ ... }`.
    * Comentários de linha única são iniciados com `//`.

## Como Compilar e Executar

1.  **Pré-requisitos**: Você precisa ter o `flex`, o `bison` e um compilador C (como o `gcc`) instalados.

2.  **Compilação**: Salve os arquivos como `comp_flex.l` e `comp_bison.y`. Execute os seguintes comandos no terminal:

    ```bash
    # 1. Gera o parser C (comp_bison.tab.c) e o header (comp_bison.tab.h) a partir do .y
    bison -d comp_bison.y

    # 2. Gera o scanner C (lex.yy.c) a partir do .l
    flex comp_flex.l

    # 3. Compila todos os arquivos .c juntos e cria o executável "interpretador"
    # A flag -lm é necessária para linkar a biblioteca matemática (usada por math.h)
    gcc comp_bison.tab.c lex.yy.c -o interpretador -lm
    ```

3.  **Execução**:
    * Crie um arquivo chamado `entrada.portugol2` com o seu código-fonte.
    * Execute o interpretador:
        ```bash
        ./interpretador
        ```
    * O programa irá ler, interpretar e executar o código contido em `entrada.portugol2`.

4.  **Exemplo de Makefile**:
    ```
    all: comp_bison.l comp_bison.y
        flex comp_bison.l
        bison -d comp_bison.y
        gcc comp_bison.tab.c lex.yy.c -o analisador -lm
        ./analisador 

    clean:
        rm -f analisador lex.yy.c comp_bison.tab.c comp_bison.tab.h	
    ```

### Testes com Vetores:

```
   // Teste de vetores e reais
   VAR REAL notas[3];
   notas[0] = 7.5;
   notas[1] = 9.0;
   notas[2] = 6.5;
   
   VAR REAL media;
   media = (notas[0] + notas[1] + notas[2]) / 3.0;
   
   ESCREVA("A media das notas e: " + media);
```
### Exemplo de Código 1 (`entrada.portugol2`)

```
// Programa para calcular o fatorial de um número

VAR INTEIRO n;
VAR INTEIRO i;
VAR INTEIRO fat;
VAR TEXTO msg;

msg = "Digite um numero inteiro para calcular o fatorial: ";
ESCREVA(msg);
LEIA_INT(n);

SE (n < 0) {
    ESCREVA("Nao existe fatorial para numero negativo.");
} SENAO {
    fat = 1;
    i = 1;
    ENQUANTO (i <= n) {
        fat = fat * i;
        i = i + 1;
    }

    ESCREVA("O fatorial de " + n + " e: " + fat);
}
```

### Exemplo de Código 2 (`entrada.portugol2`)

```
// Exemplo: Sequência de Fibonacci

VAR INTEIRO n;          // Número de termos que o usuário vai digitar
VAR INTEIRO termo_ant;  // Termo anterior na sequência (começa com 0)
VAR INTEIRO termo_atual; // Termo atual na sequência (começa com 1)
VAR INTEIRO proximo;    // Variável para calcular o próximo termo
VAR INTEIRO contador;   // Contador para o laço ENQUANTO

// Inicia a interação com o usuário
ESCREVA("Digite o numero de termos da sequencia de Fibonacci:");
LEIA_INT(n);

// Inicializa as variáveis com os valores base de Fibonacci
termo_ant = 0;
termo_atual = 1;
contador = 0;

ESCREVA("Resultado:");

ENQUANTO (contador < n) {
    ESCREVA(termo_ant); // Imprime o termo atual da sequência

    // Calcula o próximo termo
    proximo = termo_ant + termo_atual;

    // Atualiza os valores para a próxima iteração do laço
    termo_ant = termo_atual;
    termo_atual = proximo;
    
    // Incrementa o contador
    contador = contador + 1;
}

ESCREVA("Fim do programa.");
```
