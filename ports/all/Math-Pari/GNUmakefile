##############################################################################
#
###############################################################################

PORTVERSION =		2.010709
PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	Math
PORT_DEPENDS = 		pari

CONFIGURE_PRECMD =      ${MAKE_RECURSIVE} pre-configure
CONFIGURE_POSTARGS =	parilib="-L${PREFIX}/lib -lpari"		\
			paridir=`${MAKE_RECURSIVE} -C ${PORTSDIR}/all/pari wrksrc | head -1`

pre-configure:
	cd ../pari && ${MAKE_RECURSIVE} extract
	cd ${WRKSRC} && patch -p0 < ${PORTDIR}/patch-makefile

BUILD_POSTCMD =      ${MAKE_RECURSIVE} post-build

post-build:
	cd ../pari && ${MAKE_RECURSIVE} clean

include ../../etc/ports.mk
