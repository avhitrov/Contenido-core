##############################################################################
#
###############################################################################

include ../../etc/perl.mk

ifeq (${shell perl -e 'print 1 if ${PERL_LEVEL}<500600'},1)
PORTVERSION =		1.2
else
PORTVERSION =		1.34
endif

PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	Apache
PORT_DEPENDS =		mod_perl		\
			Apache-Test

CONFIGURE_POSTCMD =	${MAKE_RECURSIVE} post-configure

post-configure:
	${PERL} ${PORTDIR}/patch_configs.pl ${WRKSRC}

include ../../etc/ports.mk
