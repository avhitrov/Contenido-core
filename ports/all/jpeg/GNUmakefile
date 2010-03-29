##############################################################################
# $HeadURL: svn://cvs1.rambler.ru/Contenido/trunk/ports/all/zip/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

PORTVERSION =		6b
DISTFILE =		jpegsrc.v${PORTVERSION}.tar.gz
WRKSRC =		${WRKDIR}/${PORTNAME}-${PORTVERSION}

CONFIGURE_ARGS =        --prefix=${PREFIX}
INSTALL_PRECMD =	@for D in bin include lib man/man1; do mkdir -p ${PREFIX}/$${D}; done
INSTALL_ARGS =		prefix=${PREFIX} install install-lib

CONFIGURE_POSTCMD = 	${MAKE_RECURSIVE} post-configure

post-configure:
	cd ${WRKSRC} && patch -p0 < ${PORTDIR}/patch-pic

include ../../etc/ports.mk
