##############################################################################
# $HeadURL: svn://cvs1.rambler.ru/Contenido/trunk/ports/all/P-WebFetcher/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

PORTVERSION =		0.9.5

do-fetch:		;
do-extract:		;
do-configure:		;
do-build:		;

do-install:
	@test -d ${PREFIX}/lib/perl5/site_perl/${PERL_VER}/Jevix || mkdir -p ${PREFIX}/lib/perl5/site_perl/${PERL_VER}/Jevix
	cp ${PORTDIR}/MakeupUTF.pm ${PREFIX}/lib/perl5/site_perl/${PERL_VER}/Jevix/Makeup.pm
	cp ${PORTDIR}/Makeup*.pm ${PREFIX}/lib/perl5/site_perl/${PERL_VER}/Jevix/

include ../../etc/ports.mk
