##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/ImageMagick/GNUmakefile $
# $Id: GNUmakefile 1549 2010-06-08 14:23:45Z lonerr $
###############################################################################

PORTVERSION =		6.2.7-8
CONFIGURE_ENV =		CPPFLAGS="-I${PREFIX}/include $${CPPFLAGS}" LDFLAGS="$${LDFLAGS} -L${PREFIX}/lib"
CONFIGURE_ARGS =	--prefix=${PREFIX} --without-perl --without-threads --with-jpeg
CONFIGURE_POSTCMD = 	${MAKE_RECURSIVE} post-configure
PORT_DEPENDS =		jpeg libpng

MASTER_POST_SITES =	ftp://ftp.imagemagick.org/pub/ImageMagick/						\
			ftp://gd.tuwien.ac.at/pub/graphics/ImageMagftp://ftp.carnet.hr/misc/imagemagick/	\
			ftp://ftp.fu-berlin.de/unix/X11/graphics/ImageMagick/					\
			ftp://ftp.kddlabs.co.jp/graphics/ImageMagick/						\
			ftp://ftp.u-aizu.ac.jp/pub/graphics/image/ImageMagick/imagemagick.org/			\
			ftp://zoffy.asahi-net.or.jp/pub/graphics/ImageMagick/					\
			ftp://ftp.nluug.nl/pub/ImageMagick/							\
			ftp://ftp.sunet.se/pub/multimedia/graphics/ImageMagick/					\
			ftp://ftp.fifi.org/pub/ImageMagick/


WRKSRC =		${WRKDIR}/${PORTNAME}-${shell perl -e 'print +(split "-", "${PORTVERSION}")[0]'}

post-configure:
	cd ${WRKSRC} && pwd && sed -i .orig -E 's|^(CPPFLAGS =)(.*)|\1 -I${PREFIX}/include \2|' Makefile


include ../../etc/ports.mk
