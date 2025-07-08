all: comp_bison.l comp_bison.y
	flex comp_bison.l
	bison -d comp_bison.y
	gcc comp_bison.tab.c lex.yy.c -o analisador -lm
	./analisador 

clean:
	rm -f analisador lex.yy.c comp_bison.tab.c comp_bison.tab.h	