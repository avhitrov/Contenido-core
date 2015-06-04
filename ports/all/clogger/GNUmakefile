##############################################################################
#
###############################################################################

PORTVERSION =		0.1
#CONFIGURE_POSTCMD =	${MAKE_RECURSIVE} post-configure

do-configure:
	@sed -i'' -e '/^__FBSDID/d' ${WRKSRC}/clogger.c
	@echo ${WRKSRC}/Makefile
	@sed -i'' -e 's/gcc/cc/g' ${WRKSRC}/Makefile

#post-configure:
#	@echo 'GCC change'

do-install:
	@test -d ${PREFIX}/bin || mkdir -p ${PREFIX}/bin
	@cp -f ${WRKSRC}/clogger ${PREFIX}/bin/clogger


include ../../etc/ports.mk
