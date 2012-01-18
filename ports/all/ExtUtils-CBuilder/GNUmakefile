##############################################################################
# $Id: GNUmakefile 1243 2008-06-17 11:05:36Z abavykin $
###############################################################################

PORTVERSION =		0.280202
PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	ExtUtils

include ../../etc/perl.mk

ifeq (${shell ${PERL} -e 'print 1 if ${PERL_LEVEL}<501000'},1)
PORT_DEPENDS =		IPC-Cmd
endif

include ../../etc/ports.mk
