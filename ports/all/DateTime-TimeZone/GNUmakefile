##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/DateTime-TimeZone/GNUmakefile $
# $Id: GNUmakefile 1624 2011-10-26 15:16:01Z ahitrov $
###############################################################################

PORTVERSION =		1.41
PERL_MAKEMAKER =        yes
#PERL_MODBUILD =		yes
MASTER_CPAN_SUBDIR =	DateTime
PORT_DEPENDS =		Class-Load					\
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
