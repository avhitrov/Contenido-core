##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/Params-Validate/GNUmakefile $
# $Id: GNUmakefile 1482 2009-11-19 12:34:06Z abavykin $
###############################################################################

include ../../etc/perl.mk

PORTVERSION =		0.92
PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	Devel/DROLSKY

ifeq (${shell perl -e 'print 1 if ${PERL_LEVEL}>=500600 and ${PERL_LEVEL}<500800'},1)
PORT_DEPENDS =		Attribute-Handlers
endif

include ../../etc/ports.mk
