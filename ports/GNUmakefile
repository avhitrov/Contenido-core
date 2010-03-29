##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

MAKE_RECURSE =			${MAKE} -s MFLAGS= MAKEFLAGS= MAKELEVEL=

%:
	@for PORT in `find ./all/ -type d -mindepth 1 -maxdepth 1 |			\
		grep -v .svn | sort -f `; do						\
		cd $${PORT}								\
		&& ${MAKE_RECURSE} $@							\
		&& cd ../..;								\
	done
