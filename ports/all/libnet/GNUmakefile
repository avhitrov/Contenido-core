##############################################################################
#
###############################################################################

PORTVERSION =		3.10
PERL_MAKEMAKER =	yes
CONFIGURE_PRECMD =	touch ${WRKSRC}/libnet.cfg
INSTALL_PRECMD =	${MAKE_RECURSIVE} pre-install
MASTER_CPAN_SUBDIR =	Net

PORT_DEPENDS =		MIME-Base64			\
			ExtUtils-MakeMaker

pre-install:

	@cd ${WRKSRC}									\
	&& ${PERL} -pi -e 's/^(INSTALLMAN3DIR) = \/usr\/local/$$1 = \$$(PREFIX)/' Makefile


include ../../etc/ports.mk
