##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/libapreq/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

include ../../etc/perl.mk


ifeq (${shell perl -e 'print 1 if ${PERL_LEVEL}<500600'},1)
PORTVERSION =		1.2
else
PORTVERSION =		1.33
endif

PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	Apache
PORT_DEPENDS =		mod_perl


include ../../etc/ports.mk
