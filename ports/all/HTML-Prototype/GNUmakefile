##############################################################################
# $HeadURL: svn+ssh://svn@dev/Contenido/trunk/ports/all/HTML-Mason/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

#include ../../etc/perl.mk

PORTVERSION =		1.48
MASTER_CPAN_SUBDIR =	HTML
PERL_MODBUILD =		yes
PORT_DEPENDS =		Class-Accessor				\
			HTML-Parser				\
			HTML-Tagset
#PORT_DEPENDS =		Params-Validate				\
#			Exception-Class				\
#			Class-Container				\
#			Cache-Cache				\
#			HTML-Parser				\
#			PathTools

#ifeq (${shell perl -e 'print 1 if ${PERL_LEVEL}<500600'},1)
#${call die,requires perl 5.6.0 or higher.};
#endif


include ../../etc/ports.mk
