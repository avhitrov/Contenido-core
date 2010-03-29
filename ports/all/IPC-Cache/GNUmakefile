##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/IPC-Cache/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

include ../../etc/perl.mk

PORTVERSION =		0.02
PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	IPC
PORT_DEPENDS =		IPC-ShareLite

ifeq (${shell perl -e 'print 1 if ${PERL_LEVEL}<500800'},1)
PORT_DEPENDS +=		Storable
endif


include ../../etc/ports.mk
