##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/Class-Container/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

include ../../etc/perl.mk

PORTVERSION =		0.12
PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	Class
PORT_DEPENDS =		Params-Validate

ifeq (${shell perl -e 'print 1 if ${PERL_LEVEL}<500800'},1)
PORT_DEPENDS +=		Scalar-List-Utils
endif

#ifeq (${shell perl -e 'print 1 if ${PERL_LEVEL}<500600'},1)
#${call die,requires perl 5.6.x or higher.};
#endif

include ../../etc/ports.mk
