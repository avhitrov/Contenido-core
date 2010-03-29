##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/libnet/GNUmakefile $
# $Id: GNUmakefile 556 2006-10-30 15:04:58Z lonerr $
###############################################################################

PORTVERSION =		1.19
PERL_MAKEMAKER =	yes
CONFIGURE_PRECMD =	touch ${WRKSRC}/libnet.cfg
INSTALL_PRECMD =	${MAKE_RECURSIVE} pre-install
MASTER_CPAN_SUBDIR =	Net

PORT_DEPENDS =		MIME-Base64


pre-install:

	@cd ${WRKSRC}									\
	&& ${PERL} -pi -e 's/^(INSTALLMAN3DIR) = \/usr\/local/$$1 = \$$(PREFIX)/' Makefile


include ../../etc/ports.mk
