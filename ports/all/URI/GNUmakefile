##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/URI/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

include ../../etc/perl.mk

PORTVERSION =		1.35
PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	URI

ifeq (${shell perl -e 'print 1 if ${PERL_LEVEL}<500800'},1)
PORT_DEPENDS =		MIME-Base64
endif


include ../../etc/ports.mk
