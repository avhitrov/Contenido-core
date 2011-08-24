##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/TrivialSAX/GNUmakefile $
# $Id: GNUmakefile 1489 2009-11-27 14:15:17Z abavykin $
###############################################################################

PORTVERSION =		0.03
PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	XML
PORT_DEPENDS =		libxml-perl


do-configure: ;

do-build: ;

do-install:
	@test -d ${PREFIX}/lib/perl5/site_perl/${PERL_VER}/XML/TrivialSAX			\
	|| mkdir -p ${PREFIX}/lib/perl5/site_perl/${PERL_VER}/XML/TrivialSAX
	@cp -f ${WRKSRC}/*.pm ${PREFIX}/lib/perl5/site_perl/${PERL_VER}/XML/TrivialSAX/
	@sed -i '' -e 's/koi8-r/utf-8/g' ${PREFIX}/lib/perl5/site_perl/${PERL_VER}/XML/TrivialSAX/Handler.pm


include ../../etc/ports.mk
