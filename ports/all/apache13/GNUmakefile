##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/apache13/GNUmakefile $
# $Id: GNUmakefile 1526 2010-03-29 11:11:10Z ahitrov $
###############################################################################

PORTVERSION =		1.3.41
DISTFILE =		apache_${PORTVERSION}.tar.gz
MASTER_POST_SITES =	http://archive.apache.org/dist/httpd
CONFIGURE_ARGS =	--prefix=${PREFIX}/apache			\
			--disable-rule=EXPAT

OPSYS ?=		${shell uname}
ifeq (${OPSYS},Linux)
CONFIGURE_COMMAND ?=	OPTIM="-fgnu89-inline" bash ./configure
else
CONFIGURE_COMMAND ?=	OPTIM="-fgnu89-inline" ./configure
endif


ifndef WITHOUT_REWRITE
CONFIGURE_ARGS +=	--enable-module=rewrite
endif

ifndef WITHOUT_PERL
CONFIGURE_ARGS +=	--activate-module=src/modules/perl/libperl.a
endif

CLEAN_PRECMD =		${MAKE_RECURSIVE} pre-clean
pre-clean:
ifndef WITHOUT_PERL
	cd ../mod_perl && ${MAKE_RECURSIVE} clean APACHE_WRKSRC=${WRKSRC}
endif

CONFIGURE_PRECMD =	${MAKE_RECURSIVE} pre-configure
pre-configure:
	cd ${WRKSRC} && patch -p0 < ${PORTDIR}/patch.apache.sighup
ifndef WITHOUT_REAPER_DELAY
	cd ${WRKSRC} && patch -p0 < ${PORTDIR}/patch.reaper.delay
endif
	cd ${WRKSRC} && patch -p0 < ${PORTDIR}/patch-utime
	sed -i.orig 's/getline/_getline/g' \
		$(WRKSRC)/src/support/htdigest.c \
		$(WRKSRC)/src/support/htpasswd.c \
		$(WRKSRC)/src/support/logresolve.c

ifndef WITHOUT_PERL
	cd ../mod_perl && ${MAKE_RECURSIVE} install APACHE_WRKSRC=${WRKSRC}
endif

DEINSTALL_PRECMD =	${MAKE_RECURSIVE} pre-deinstall
pre-deinstall:
ifndef WITHOUT_PERL
	cd ../mod_perl && ${MAKE_RECURSIVE} deinstall
endif


include ../../etc/ports.mk
