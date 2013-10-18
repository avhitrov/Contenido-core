##############################################################################
# $HeadURL: svn://cvs1.rambler.ru/Contenido/trunk/ports/etc/ports.mk $
# $Id: ports.mk 71 2006-06-03 14:32:52Z lonerr $
###############################################################################

PERL ?=				${shell which perl}
PERL_LEVEL ?=			${shell ${PERL} -e '$$]=~/(\d+)\.(\d{3})(\d+)/; printf "%d%03d%02d", $$1,$$2,$$3;'}

ifeq (${shell ${PERL} -e '${PERL_LEVEL}<500600 && print 1'},1)
PERL_VER =			${shell ${PERL} -e '$$]=~/(\d+)\.(\d{3})(\d+)/; printf "%d.%03d", $$1,$$2;'}
endif

ifeq (${shell ${PERL} -e '${PERL_LEVEL}<501205 && print 1'},1)
PERL_VER ?=			${shell ${PERL} -e '$$]=~/(\d+)\.(\d{3})(\d+)/; printf "%d.%d.%d", $$1,$$2,$$3;'}
else
PERL_VER ?=			${shell ${PERL} -e '$$]=~/(\d+)\.(\d{3})(\d+)/; printf "%d.%d", $$1,$$2;'}
endif

ifeq (${shell ${PERL} -e '${PERL_LEVEL}<500600 && print 1'},1)
PERL_ARCH ?=			${shell ${PERL} -e 'use Config; print $$Config::Config{archname};'}
else
PERL_ARCH ?=			mach
endif

PERL_LIB ?=			${PREFIX}/lib/perl5/${PERL_VER}					\
				${PREFIX}/lib/perl5/${PERL_VER}/${PERL_ARCH}			\
				${PREFIX}/lib/perl5/site_perl					\
				${PREFIX}/lib/perl5/site_perl/${PERL_VER}			\
				${PREFIX}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}
PERL_LIBCOL ?=			${shell echo ${PERL_LIB} | perl -pe 's/\s+$$//; s/\s+/:/g'}
