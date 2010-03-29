##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/DBI/GNUmakefile $
# $Id: GNUmakefile 1418 2009-06-05 09:17:07Z phoinix $
###############################################################################

include ../../etc/perl.mk


ifeq (${shell perl -e 'print 1 if ${PERL_LEVEL}<500600'},1)
PORTVERSION =		1.37
else
PORTVERSION =		1.52
endif

PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	DBI
PORT_DEPENDS =		Storable


include ../../etc/ports.mk
