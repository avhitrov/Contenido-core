##############################################################################
# $Id: GNUmakefile 1243 2008-06-17 11:05:36Z abavykin $
###############################################################################

PORTVERSION =		0.46
PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	Module
PORT_DEPENDS =		Module-CoreList

include ../../etc/perl.mk

ifeq (${shell ${PERL} -e 'print 1 if ${PERL_LEVEL}<501000'},1)
PORT_DEPENDS +=		Module-Load
endif

ifeq (${shell ${PERL} -e 'print 1 if ${PERL_LEVEL}<500905'},1)
PORT_DEPENDS +=		Locale-Maketext-Simple		\
			Params-Check			\
			version
endif

include ../../etc/ports.mk
