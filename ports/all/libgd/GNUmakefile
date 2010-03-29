##############################################################################
# $HeadURL: svn://cvs1.rambler.ru/Contenido/trunk/ports/all/apache13/GNUmakefile $
# $Id: GNUmakefile 511 2006-10-10 14:49:33Z lonerr $
###############################################################################

PORTVERSION =		2.0.33
MASTER_POST_SITES =	http://www.boutell.com/gd/http
PORT_DEPENDS =		jpeg libpng
DISTFILE =		gd-${PORTVERSION}.tar.gz

CONFIGURE_POSTARGS =	--with-jpeg=${PREFIX} --with-png=${PREFIX} --with-pic

do-configure:
	@export PATH=${PREFIX}/bin:$${PATH}							\
	&& cd ${WRKSRC}										\
	&& ${CONFIGURE_ENV} ${CONFIGURE_POSTENV} ${CONFIGURE_COMMAND} ${CONFIGURE_ARGS}		\
	   ${CONFIGURE_POSTARGS}

	@sed -i '' -E -e 's/LDFLAGS =(.*)/LDFLAGS = \1 -pthread/'				\
		${WRKSRC}/Makefile


include ../../etc/ports.mk
