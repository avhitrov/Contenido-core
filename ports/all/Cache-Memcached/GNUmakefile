##############################################################################
# $HeadURL: svn://cvs1.rambler.ru/Contenido/trunk/ports/all/File-Cache/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

include ../../etc/perl.mk

PORTVERSION =		1.30
PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	Cache
INSTALL_PRECMD =	${MAKE_RECURSIVE} pre-install

PORT_DEPENDS =		String-CRC32		\
			Storable		\
			Time-HiRes

pre-install:

	@cd ${WRKSRC}									\
	&& ${PERL} -pi -e 's/^(INSTALLMAN3DIR) = \/usr\/local/$$1 = \$$(PREFIX)/' Makefile


include ../../etc/ports.mk
