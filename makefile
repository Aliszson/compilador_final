all: calc_bison.l calc_bison.y
	flex calc_bison.l
	bison -d calc_bison.y
	gcc calc_bison.tab.c lex.yy.c -o analisador -lm
	./analisador 

clean:
	rm -f analisador lex.yy.c calc_bison.tab.c calc_bison.tab.h