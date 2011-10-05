##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/libwww/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

#include ../../etc/perl.mk

PORTVERSION =		5.836
DISTFILE =		${PORTNAME}-perl-${PORTVERSION}.tar.gz
PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	LWP
PORT_DEPENDS =		URI						\
			Digest-MD5					\
			MIME-Base64					\
			HTML-Parser					\
			Compress-Zlib					\
			libnet
PERL_CHECK_MODULE =	LWP
CONFIGURE_COMMAND =	${PERL} Makefile.PL -n

#ifeq (${shell perl -e 'print 1 if ${PERL_LEVEL}<500600'},1)
#${call die,requires at least Perl 5.6 due to dependencies.};
#endif


include ../../etc/ports.mk
