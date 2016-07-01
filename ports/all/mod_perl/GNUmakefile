##############################################################################
#
###############################################################################

include ../../etc/perl.mk

ifeq (${shell ${PERL} -e 'print 1 if ${PERL_LEVEL}<501000'},1)
PORTVERSION =		1.29
else
PORTVERSION =		1.31
endif

MASTER_CPAN_SUBDIR =	ModPerl/GOZER
PERL_MAKEMAKER =	yes
PERL_CHECK =		no
CONFIGURE_POSTARGS =	APACHE_SRC=${APACHE_WRKSRC}/src			\
			USE_APACI=1					\
			DO_HTTPD=1					\
			PREP_HTTPD=1					\
			EVERYTHING=1

CONFIGURE_PRECMD =      ${MAKE_RECURSIVE} pre-configure
pre-configure:
ifeq (${shell ${PERL} -e 'print 1 if ${PERL_LEVEL}>=501400'},1)
	cd ${WRKSRC} && patch -p0 < ${PORTDIR}/patch.perl5.14
endif
ifeq (${shell ${PERL} -e 'print 1 if ${PERL_LEVEL}>=501600'},1)
	cd ${WRKSRC} && patch -p0 < ${PORTDIR}/patch.perl5.16
endif
ifeq (${shell ${PERL} -e 'print 1 if ${PERL_LEVEL}>=502000'},1)
	cd ${WRKSRC} && patch -p0 < ${PORTDIR}/patch.perl5.20
endif

include ../../etc/ports.mk
