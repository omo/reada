
COFFEE = coffee -l
CO_SRC_DIR = ./
JS_OBJ_DIR = ./
JS_LIB_DIR = ./lib/
CO_SRC := ${wildcard ${CO_SRC_DIR}/*.coffee}
JS_OBJ := ${patsubst %.coffee,%.js,${CO_SRC}}
JS_LIB := ${wildcard ${JS_LIB_DIR}/*.js}
JS_BIN  = phantomp.js
#RUN_URL = http://radar.oreilly.com/2011/03/social-media-human-behavior.html
RUN_URL = http://informationweek.com/news/showArticle.jhtml?articleID=204203573

${JS_OBJ_DIR}/%.js: ${CO_SRC_DIR}/%.coffee
	${COFFEE} -o ${JS_OBJ_DIR} $<

obj: ${JS_OBJ}
${JS_BIN}: ${JS_LIB} ${JS_OBJ}
	cat $^ > $@

bin: ${JS_BIN}

run: bin
	phantomjs ${JS_BIN} ${RUN_URL}
clean:
	rm ${JS_BIN} ${JS_OBJ}

.PHONY: run clean