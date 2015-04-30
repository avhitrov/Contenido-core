##############################################################################
#
###############################################################################

PORTVERSION =		1.10
PERL_MODBUILD =		yes
#PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	Params
PORT_DEPENDS =		Module-Implementation			\
			Test-Fatal				\
			Test-Requires

include ../../etc/perl.mk

ifeq (${shell ${PERL} -e 'print 1 if ${PERL_LEVEL}<501000'},1)
PORT_DEPENDS +=		Attribute-Handlers
endif

include ../../etc/ports.mk
