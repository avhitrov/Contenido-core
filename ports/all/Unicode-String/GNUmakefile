##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/Unicode-String/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

include ../../etc/perl.mk

PORTVERSION =		2.09
PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	Unicode

ifeq (${shell perl -e 'print 1 if ${PERL_LEVEL}<500804'},1)
PORT_DEPENDS =		MIME-Base64
endif


include ../../etc/ports.mk
