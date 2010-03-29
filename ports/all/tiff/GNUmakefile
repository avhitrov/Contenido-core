##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/tiff/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

PORTVERSION =		v3.6.0
CONFIGURE_POSTARGS =	--noninteractive
CONFIGURE_PRECMD =	${MAKE_RECURSIVE} pre-configure

pre-configure:

	@cd ../libtiff-lzw-compression-kit					\
	&& ${MAKE_RECURSIVE} extract

	LTK=`cd ../libtiff-lzw-compression-kit && ${MAKE_RECURSIVE} get-WRKSRC`	\
	&& cp $${LTK}/tif_lzw.c ${WRKSRC}/libtiff


include ../../etc/ports.mk
