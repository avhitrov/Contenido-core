##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/mod_perl/GNUmakefile $
# $Id: GNUmakefile 1526 2010-03-29 11:11:10Z ahitrov $
###############################################################################

include ../../etc/perl.mk

ifeq (${shell ${PERL} -e 'print 1 if ${PERL_LEVEL}<501000'},1)
PORTVERSION =		1.29
else
PORTVERSION =		1.31
endif

MASTER_CPAN_SUBDIR =	ModPerl/GOZER
PERL_MAKEMAKER =	yes
PERL_CHECK =		no
CONFIGURE_POSTARGS =	APACHE_SRC=${APACHE_WRKSRC}/src			\
			USE_APACI=1					\
			DO_HTTPD=1					\
			PREP_HTTPD=1					\
			EVERYTHING=1


include ../../etc/ports.mk
