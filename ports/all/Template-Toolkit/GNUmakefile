##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/Template-Toolkit/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

#include ../../etc/perl.mk

PORTVERSION =		2.15
PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	Template
PORT_DEPENDS =		File-Temp			\
			AppConfig			\
			PathTools

CONFIGURE_POSTARGS =	TT_PREFIX=${PREFIX}/tt2		\
			TT_DOCS=n			\
			TT_EXAMPLES=n			\
			TT_DBI=n			\
			TT_LATEX=n			\
			TT_ACCEPT=y

#ifeq (${shell perl -e 'print 1 if ${PERL_LEVEL}<500600'},1)
#${call die,requires perl 5.6.0 or higher.};
#endif


include ../../etc/ports.mk
