##############################################################################
# $Id: GNUmakefile 1243 2008-06-17 11:05:36Z abavykin $
###############################################################################

PORTVERSION =		1.00
PERL_MODBUILD =		yes
#PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	ExtUtils
PORT_DEPENDS =		ExtUtils-CBuilder			\
			Module-Build

include ../../etc/perl.mk

ifeq (${shell ${PERL} -e 'print 1 if ${PERL_LEVEL}<501000'},1)
PORT_DEPENDS +=		Attribute-Handlers
endif

include ../../etc/ports.mk
