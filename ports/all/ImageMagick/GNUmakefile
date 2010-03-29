##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/ImageMagick/GNUmakefile $
# $Id: GNUmakefile 1077 2007-10-09 09:48:29Z lonerr $
###############################################################################

PORTVERSION =		6.2.7-8
CONFIGURE_ENV =		CPPFLAGS="$${CPPFLAGS} -I${PREFIX}/include" LDFLAGS="$${LDFLAGS} -L${PREFIX}/lib"
CONFIGURE_ARGS =	--prefix=${PREFIX} --without-perl --without-threads --with-jpeg
PORT_DEPENDS =		jpeg

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


include ../../etc/ports.mk
