##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/Apache-DB/GNUmakefile $
# $Id: GNUmakefile 1465 2009-10-27 12:44:36Z ahitrov $
###############################################################################

include ../../etc/perl.mk

PORTVERSION =		0.14
PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	Apache

ifeq (${shell perl -e 'print 1 if ${PERL_LEVEL}<500600'},1)
PORT_DEPENDS +=		DProf
endif


include ../../etc/ports.mk
