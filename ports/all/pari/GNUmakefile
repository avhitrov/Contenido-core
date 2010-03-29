##############################################################################
# $HeadURL: svn://cvs1.rambler.ru/Contenido/trunk/ports/all/expat/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

MASTER_POST_SITES = 	http://pari.math.u-bordeaux.fr/pub/pari/unix/
PORTVERSION =		2.3.3

CONFIGURE_COMMAND =	./Configure
BUILD_ARGS =		all

CONFIGURE_PRECMD =      ${MAKE_RECURSIVE} pre-configure
pre-configure:
	cd ${WRKSRC} && patch -p0 < ${PORTDIR}/patch-pic

wrksrc:
	@echo ${WRKSRC}

include ../../etc/ports.mk
