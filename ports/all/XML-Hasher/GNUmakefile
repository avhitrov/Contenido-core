##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/XML-Hasher/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

PORTVERSION =		0.01
PERL_MAKEMAKER =	yes
PORT_DEPENDS =		XML-Parser							\
			cyrillic


do-configure: ;
do-build: ;
do-install:
	@test -d ${PREFIX}/lib/perl5/site_perl/${PERL_VER}/XML				\
	|| mkdir -p ${PREFIX}/lib/perl5/site_perl/${PERL_VER}/XML
	@cp -f ${WRKSRC}/Hasher.pm ${PREFIX}/lib/perl5/site_perl/${PERL_VER}/XML/


include ../../etc/ports.mk
