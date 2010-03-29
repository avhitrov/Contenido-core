##############################################################################
# $HeadURL: svn://cvs1.rambler.ru/Contenido/trunk/ports/all/apache13/GNUmakefile $
# $Id: GNUmakefile 511 2006-10-10 14:49:33Z lonerr $
###############################################################################

PORTVERSION =		0.1

do-configure:
	@sed -i'' -e '/^__FBSDID/d' ${WRKSRC}/clogger.c

do-install:
	@test -d ${PREFIX}/bin || mkdir -p ${PREFIX}/bin
	@cp -f ${WRKSRC}/clogger ${PREFIX}/bin/clogger


include ../../etc/ports.mk
