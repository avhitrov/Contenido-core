##############################################################################
# $HeadURL: svn://cvs1.rambler.ru/Contenido/trunk/ports/all/ImageMagick/GNUmakefile $
# $Id: GNUmakefile 195 2006-06-22 07:45:45Z astar $
###############################################################################

PORTVERSION =		0.60.4

MASTER_POST_SITES =	http://ftp.gnu.org/gnu/aspell/

CONFIGURE_PRECMD =	${MAKE_RECURSIVE} pre-configure

pre-configure:
	cd ${WRKSRC} && patch -p1 < ${PORTDIR}/patch.aspell.extra_qualification_fix

include ../../etc/ports.mk
