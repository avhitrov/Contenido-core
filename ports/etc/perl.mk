##############################################################################
#
###############################################################################

PERL ?=				${shell which perl}
PERL_LEVEL ?=			${shell ${PERL} -e '$$]=~/(\d+)\.(\d{3})(\d+)/; printf "%d%03d%02d", $$1,$$2,$$3;'}

PERL_VER =			${shell ${PERL} -e 'my ($$inc) = grep { $$_ =~ /site_perl/ } @INC; $$inc =~ /5\.(\d+)\.(\d)/ ? print "5.$$1.$$2" : $$inc =~ /5\.(\d+)/ ? print "5.$$1" : print '';'}

ifeq (${shell ${PERL} -e '${PERL_LEVEL}<500600 && print 1'},1)
PERL_ARCH ?=			${shell ${PERL} -e 'use Config; print $$Config::Config{archname};'}
else
PERL_ARCH ?=			mach
endif

PERL_LIB ?=			${PREFIX}/lib/perl5/${PERL_VER}					\
				${PREFIX}/lib/perl5/${PERL_VER}/${PERL_ARCH}			\
				${PREFIX}/lib/perl5/site_perl					\
				${PREFIX}/lib/perl5/site_perl/${PERL_VER}			\
				${PREFIX}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}		\
				${PREFIX}/lib/perl5/site_perl/${PERL_ARCH}/${PERL_VER}
PERL_LIBCOL ?=			${shell echo ${PERL_LIB} | perl -pe 's/\s+$$//; s/\s+/:/g'}
