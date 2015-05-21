##############################################################################
#
###############################################################################

include ../../etc/perl.mk


ifeq (${shell perl -e 'print 1 if ${PERL_LEVEL}<500600'},1)
PORTVERSION =		1.37
elif (${shell perl -e 'print 1 if ${PERL_LEVEL}<501200'},1)
PORTVERSION =		1.52
else
PORTVERSION =		1.633
endif

PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	DBI
PORT_DEPENDS =		Storable


include ../../etc/ports.mk
