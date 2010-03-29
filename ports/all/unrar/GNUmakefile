##############################################################################
# $HeadURL: svn://cvs1.rambler.ru/Contenido/trunk/ports/all/zip/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

PORTVERSION =		3.8.4
DISTFILE =		${PORTNAME}src-${PORTVERSION}.tar.gz
BUILD_ARGS =		-f makefile.unix all
WRKSRC =                ${WRKDIR}/${PORTNAME}

do-configure: ;
do-install:
	@cp ${WRKDIR}/${PORTNAME}/unrar ${PREFIX}/bin/


include ../../etc/ports.mk
