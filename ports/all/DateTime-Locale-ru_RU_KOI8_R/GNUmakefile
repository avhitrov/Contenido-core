##############################################################################
# $HeadURL: svn://cvs1.rambler.ru/Contenido/trunk/ports/all/P-WebFetcher/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

PORTVERSION =		0.2
PORT_DEPENDS =		DateTime-Locale

do-fetch:		;
do-extract:		;
do-configure:	;
do-build:		;

do-install:
	@test -d ${PREFIX}/lib/perl5/site_perl/${PERL_VER} || mkdir -p ${PREFIX}/lib/perl5/site_perl/${PERL_VER}
	PERL5LIB='${PERL_LIBCOL}' perl ${PORTDIR}/install.pl

include ../../etc/ports.mk
