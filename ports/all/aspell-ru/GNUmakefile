##############################################################################
# $HeadURL: svn://cvs1.rambler.ru/Contenido/trunk/ports/all/ImageMagick/GNUmakefile $
# $Id: GNUmakefile 195 2006-06-22 07:45:45Z astar $
###############################################################################

PORTVERSION =		6-ru-0.99f7-1
DISTFILE =		aspell${PORTVERSION}.tar.bz2

MASTER_POST_SITES =	http://ftp.gnu.org/gnu/aspell/dict/ru/

WRKSRC =		${WRKDIR}/aspell${PORTVERSION}

do-extract:
	@tar -xjf ${DISTDIR}/${DISTFILE} -C ${WRKDIR}

do-configure:
	@cd ${WRKSRC}							\
	&& PATH=${PREFIX}/bin:$${PATH} ${CONFIGURE_ENV} ${CONFIGURE_POSTENV} ${CONFIGURE_COMMAND}	\
		${CONFIGURE_POSTARGS}


include ../../etc/ports.mk
