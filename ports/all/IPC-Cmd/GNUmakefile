##############################################################################
# $Id: GNUmakefile 1243 2008-06-17 11:05:36Z abavykin $
###############################################################################

PORTVERSION =		0.72
PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	IPC
PORT_DEPENDS =		IPC-Run

include ../../etc/perl.mk

ifeq (${shell ${PERL} -e 'print 1 if ${PERL_LEVEL}<500905'},1)
PORT_DEPENDS +=         Locale-Maketext-Simple		\
			Params-Check			\
			Module-Load-Conditional
endif

include ../../etc/ports.mk
