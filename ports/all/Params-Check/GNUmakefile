##############################################################################
# $Id: GNUmakefile 1243 2008-06-17 11:05:36Z abavykin $
###############################################################################

PORTVERSION =		0.32
PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	Params

include ../../etc/perl.mk

ifeq (${shell ${PERL} -e 'print 1 if ${PERL_LEVEL}<501000'},1)
PORT_DEPENDS =		Locale-Maketext-Simple
endif

include ../../etc/ports.mk
