##############################################################################
# $HeadURL: svn://cvs1.rambler.ru/Contenido/trunk/ports/all/URI/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

include ../../etc/perl.mk

CONFIGURE_PRECMD =  ${MAKE_RECURSIVE} pre-configure
pre-configure:
	cd ${WRKSRC} && patch -p0 < ${PORTDIR}/config.in.patch


PORTVERSION =		0.30
PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	BerkeleyDB


include ../../etc/ports.mk
