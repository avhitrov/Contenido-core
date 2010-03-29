##############################################################################
# $HeadURL: svn://cvs1.rambler.ru/Contenido/trunk/ports/all/Date-Calc/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

PORTVERSION =		0.06
PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	Text
PORT_DEPENDS =		aspell				\
			aspell-ru

CONFIGURE_POSTARGS =	CCFLAGS=-I${PREFIX}/include	\
			LIBS="-L${PREFIX}/lib -laspell"

include ../../etc/ports.mk
