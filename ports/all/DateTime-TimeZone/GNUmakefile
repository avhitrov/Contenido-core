##############################################################################
#
###############################################################################

PORTVERSION =		1.75
PERL_MAKEMAKER =	yes
#PERL_MODBUILD =	yes
MASTER_CPAN_SUBDIR =	DateTime
PORT_DEPENDS =		Scalar-List-Utils				\
			Class-Load					\
			List-AllUtils					\
			Class-Singleton					\
			Params-Validate

include ../../etc/perl.mk

ifeq (${shell ${PERL} -e 'print 1 if ${PERL_LEVEL}<500806'},1)
PORT_DEPENDS +=		PathTools
endif

ifeq (${shell ${PERL} -e 'print 1 if ${PERL_LEVEL}<501000'},1)
PORT_DEPENDS +=		parent
endif


include ../../etc/ports.mk
