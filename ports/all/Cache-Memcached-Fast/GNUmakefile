include ../../etc/perl.mk

PORTVERSION =		0.10
PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	Cache

PORT_DEPENDS =		Compress-Zlib

CONFIGURE_PRECMD =	${MAKE_RECURSIVE} pre-configure
pre-configure:
	cd ${WRKSRC} && patch -p0 < ${PORTDIR}/patch-newline

include ../../etc/ports.mk
