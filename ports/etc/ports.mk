##############################################################################
# $HeadURL: svn+ssh://svn@vcs.dev.rambler.ru/Contenido/branches/utf8/ports/etc/ports.mk $
# $Id: ports.mk 1777 2017-06-22 14:12:52Z ahitrov $
###############################################################################

PREFIX ?=			${error PREFIX must be defined}
PORTSWRK ?=			${error PORTSWRK must be defined}

PORTSDIR ?=			${basename ${shell cd ../../ && pwd}}
PORTSDB ?=			${PORTSWRK}/db
DISTDIR ?=			${PORTSWRK}/distfiles

MASTER_CPAN_SITES ?=														\
				http://www.cpan.dk/modules/by-module/								\
				ftp://ftp.kddlabs.co.jp/lang/perl/CPAN/modules/by-module/					\
				ftp://ftp.dti.ad.jp/pub/lang/CPAN/modules/by-module/						\
				ftp://ftp.sunet.se/pub/lang/perl/CPAN/modules/by-module/					\
				ftp://mirror.hiwaay.net/CPAN/modules/by-module/							\
				ftp://ftp.mirrorservice.org/sites/ftp.funet.fi/pub/languages/perl/CPAN/modules/by-module/	\
				ftp://bioinfo.weizmann.ac.il/pub/software/perl/CPAN/modules/by-module/				\
				ftp://csociety-ftp.ecn.purdue.edu/pub/CPAN/modules/by-module/					\
				ftp://ftp.isu.net.sa/pub/CPAN/modules/by-module/						\
				ftp://ftp.ucr.ac.cr/pub/Unix/CPAN/modules/by-module/						\
				ftp://ftp.cs.colorado.edu/pub/perl/CPAN/modules/by-module/					\
				ftp://cpan.pop-mg.com.br/pub/CPAN/modules/by-module/						\
				ftp://ftp.is.co.za/programming/perl/CPAN/modules/by-module/					\
				http://at.cpan.org/modules/by-module/								\
				ftp://ftp.chg.ru/pub/lang/perl/CPAN/modules/by-module/						\
				ftp://ftp.auckland.ac.nz/pub/perl/CPAN/modules/by-module/


MASTER_SITES ?=			/usr/local/dist							\
				http://contenido.me/repos/Contenido/cnddist

MASTER_POST_SITES ?=

ifdef MASTER_CPAN_SUBDIR
MASTER_SITES +=			${addsuffix ${MASTER_CPAN_SUBDIR},${MASTER_CPAN_SITES}}
endif

PORTDIR =			${basename ${shell pwd}}
PORTNAME ?=			${shell echo ${PORTDIR} | sed 's/.*\///'}
PORTVERSION ?=			${error PORTVERSION must be defined}
DISTFILE ?=			${PORTNAME}${PORTVERSION:%=-%}.tar.gz
WRKDIR =			${PORTSWRK}/work/${PORTNAME}
WRKSRC ?=			${WRKDIR}/${DISTFILE:%.tar.gz=%}

OPSYS = 			${shell uname}

FETCH_CMD ?=			${shell which fetch || which wget || echo ''}
FETCH_ARGS ?=			${shell perl -e 'print "-o" if "${FETCH_CMD}" =~ /fetch$$/;	\
						 print "-P" if "${FETCH_CMD}" =~ /wget$$/;'}

MAKE_RECURSIVE =		${MAKE} -s MFLAGS= MAKEFLAGS= MAKELEVEL= PERL_CHECKED=
MAKE_RECURSIVE_PERL =		${MAKE} -s MFLAGS= MAKEFLAGS= MAKELEVEL=

include ${PORTSDIR}/etc/perl.mk


#########################
# Common for Perl modules
#########################
ifneq (${PERL_MAKEMAKER}${PERL_MODBUILD},)
CONFIGURE_ENV ?=		PERL5LIB='${PERL_LIBCOL}' MAKE=${MAKE}
BUILD_ENV ?=			PERL5LIB='${PERL_LIBCOL}' MAKE=${MAKE}
INSTALL_ENV ?=			PERL5LIB='${PERL_LIBCOL}' MAKE=${MAKE} OPSYS=${OPSYS}

PERL_CHECK ?=			yes
PERL_CHECK_MODE ?=		interactive
PERL_CHECK_MODULE ?=		${PORTNAME}
PERL_CHECK_VERSION ?=		${PORTVERSION}
endif


#####################
# ExtUtils::MakeMaker
#####################
ifdef PERL_MAKEMAKER
CONFIGURE_COMMAND ?=		${PERL} Makefile.PL

ifeq (${OPSYS},FreeBSD)
CONFIGURE_ARGS ?=		INSTALLDIRS="site"								\
				PREFIX="${PREFIX}"								\
				INSTALLPRIVLIB="${PREFIX}/lib/perl5/site_perl/${PERL_VER}"			\
				INSTALLARCHLIB="${PREFIX}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}"
else
CONFIGURE_ARGS ?=		INSTALLDIRS="site"								\
				PREFIX="${PREFIX}"								\
				INSTALLPRIVLIB="${PREFIX}/lib/perl5/site_perl/${PERL_VER}"			\
				INSTALLARCHLIB="${PREFIX}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}"		\
				INSTALLSITELIB="${PREFIX}/lib/perl5/site_perl/${PERL_VER}"			\
				INSTALLSITEARCH="${PREFIX}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}"
endif

endif


#####################
# Module::Build
#####################
ifdef PERL_MODBUILD
CONFIGURE_COMMAND ?=		${PERL} Build.PL
CONFIGURE_ARGS ?=		create_packlist=0								\
				install_path=lib="${PREFIX}/lib/perl5/site_perl/${PERL_VER}"			\
				install_path=arch="${PREFIX}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}"	\
				install_path=script="${PREFIX}/bin"						\
				install_path=bin="${PREFIX}/bin"						\
				install_path=libdoc="${PREFIX}/man/man3"					\
				install_path=bindoc="${PREFIX}/man/man1"
BUILD_COMMAND ?=		${PERL} Build
INSTALL_COMMAND ?=		${PERL} Build install
endif


#####################
# default
#####################
PORT_DEPENDS ?=

CLEAN_PRECMD ?=
CLEAN_POSTCMD ?=

CONFIGURE_PRECMD ?=
CONFIGURE_POSTCMD ?=
CONFIGURE_ENV ?=
CONFIGURE_POSTENV ?=
ifeq (${OPSYS},Linux)
CONFIGURE_COMMAND ?=		bash ./configure
else
CONFIGURE_COMMAND ?=		./configure
endif
CONFIGURE_ARGS ?=		--prefix=${PREFIX}
CONFIGURE_POSTARGS ?=

BUILD_PRECMD ?=
BUILD_POSTCMD ?=
BUILD_ENV ?=
BUILD_COMMAND ?=		${MAKE}
BUILD_ARGS ?=
BUILD_POSTARGS ?=

INSTALL_PRECMD ?=
INSTALL_POSTCMD ?=
INSTALL_ENV ?=
INSTALL_COMMAND ?=		${BUILD_COMMAND}
INSTALL_ARGS ?=			install
INSTALL_POSTARGS ?=

DEINSTALL_PRECMD ?=
DEINSTALL_POSTCMD ?=

DRY_RUN ?=


# fetching
fetch: ${DISTDIR}/${DISTFILE}
	@echo ${DISTFILE} fetched

${DISTDIR}/%:
	@test -d ${DISTDIR} || mkdir -p ${DISTDIR}
	@${MAKE_RECURSIVE} do-fetch

def-fetch:
	@for SITE in ${MASTER_SITES} ${MASTER_POST_SITES}; do						\
		if [ -f ${DISTDIR}/${DISTFILE} ]; then							\
			exit 0;										\
		fi;											\
		if [ \! -z "`echo $${SITE} | perl -ne '/^svn:\/\// && print 1'`" ]; then		\
			echo "Trying subversion: $${SITE}";						\
			svn ls $${SITE}/${DISTFILE} >&- 2>&-						\
			&& svn cat $${SITE}/${DISTFILE} > ${DISTDIR}/${DISTFILE};			\
		elif [ \! -z "`echo $${SITE} | perl -ne '/^(ftp|http):\/\// && print 1'`" ]; then	\
			if [ \! -z "${FETCH_CMD}" ]; then						\
				echo "Trying site: $${SITE}";						\
				${FETCH_CMD} ${FETCH_ARGS} ${DISTDIR}/ $${SITE}/${DISTFILE} >&- ;	\
			else										\
				echo "Skip site: $${SITE}, no available fetcher found";			\
			fi;										\
		elif [ \! -z "`echo $${SITE} | perl -ne 'm|^/| && print 1'`" ]; then			\
			echo "Trying local storage: $${SITE}";						\
			test -f $${SITE}/${DISTFILE} && cp $${SITE}/${DISTFILE} ${DISTDIR}/ >&- ;	\
		else											\
			${call die,Scheme unknown - $${SITE}/${DISTFILE}};				\
		fi;											\
	done;												\
	if [ \! -f ${DISTDIR}/${DISTFILE} ]; then							\
		${call die,Can not fetch ${DISTFILE}};							\
	fi


# distcleaning
distclean:
	@${MAKE_RECURSIVE} do-$@
	@echo ${DISTFILE} removed

def-distclean:
	@rm -f ${DISTDIR}/${DISTFILE}


# cleaning
clean:
	@${MAKE_RECURSIVE} do-$@
	@echo ${PORTNAME} cleaned

def-clean:
	@${CLEAN_PRECMD}

	@rm -Rf ${WRKDIR}

	@${CLEAN_POSTCMD}


# extracting
extract: ${WRKDIR}/.extract
	@echo ${DISTFILE} extracted

${WRKDIR}/.extract:
	@${MAKE_RECURSIVE} fetch
	@test -d ${WRKDIR} || mkdir -p ${WRKDIR}
	@${MAKE_RECURSIVE} do-extract
	@date > $@

def-extract:
	@tar -xzf ${DISTDIR}/${DISTFILE} -C ${WRKDIR}


# configuring
configure: ${WRKDIR}/.configure
	@echo ${PORTNAME} configured

${WRKDIR}/.configure:
ifneq (${PERL_MAKEMAKER}${PERL_MODBUILD},)
	@if [ \! -d ${PREFIX}/lib/perl5 ]; then							\
		mkdir -p ${PREFIX}/lib/perl5;							\
	fi;
endif
	@${MAKE_RECURSIVE} extract

	@for DEP in ${PORT_DEPENDS}; do								\
		cd ${PORTSDIR}/all/$${DEP}							\
		&& ${MAKE_RECURSIVE} install || exit 1;						\
	done;

	@${MAKE_RECURSIVE} do-configure
	@date > $@

def-configure:
	@${CONFIGURE_PRECMD}

	@cd ${WRKSRC}										\
	&& ${CONFIGURE_ENV} ${CONFIGURE_POSTENV} ${CONFIGURE_COMMAND} ${CONFIGURE_ARGS}		\
	   ${CONFIGURE_POSTARGS}

ifdef PERL_MAKEMAKER
	@cd ${WRKSRC}										\
	&& ${PERL} -pi -e 's/ doc_(perl|site|\$$\(INSTALLDIRS\))_install$$//' Makefile
ifeq (${shell perl -e 'print 1 if ${PERL_LEVEL}<=500503'},1)
	@cd ${WRKSRC}										\
	&& ${PERL} -pi -e 's/^(INSTALLSITELIB|INSTALLSITEARCH|SITELIBEXP|SITEARCHEXP|INSTALLMAN1DIR|INSTALLMAN3DIR) = \/usr\/local/$$1 = \$$(PREFIX)/' Makefile
endif
endif

	@${CONFIGURE_POSTCMD}


# building
build: ${WRKDIR}/.build
	@echo ${PORTNAME} built

${WRKDIR}/.build:
	@${MAKE_RECURSIVE} configure
	@${MAKE_RECURSIVE} do-build
	@date > $@

def-build:
	@${BUILD_PRECMD}

	@cd ${WRKSRC}										\
	&& ${BUILD_ENV} ${BUILD_COMMAND} ${BUILD_ARGS} ${BUILD_POSTARGS}

	@${BUILD_POSTCMD}

# installing
install: ${PORTSDB}/${PORTNAME}
ifndef DRY_RUN
	@echo "${PORTNAME} installed"
	@echo "----------------------------------------"
	@cat $^
	@echo "----------------------------------------"
endif

${PORTSDB}/%:
	@test -d ${PORTSDB} || mkdir -p ${PORTSDB}
ifneq (${PERL_CHECK},yes)
ifndef DRY_RUN
	@${MAKE_RECURSIVE} build
	@${PORTSDIR}/etc/snapshot ${PREFIX}			> $@.before
	@${MAKE_RECURSIVE} do-install
	@echo "State:   installed"				> $@
	@echo "Date:    "`date`					>> $@
	@echo "Name:    ${PORTNAME}"				>> $@
	@echo "Version: ${PORTVERSION}"				>> $@
	@${PORTSDIR}/etc/snapshot -d $@.before ${PREFIX}	> $@.content
else
	@echo "UNKNOWN:   ${PORTNAME}"
endif
else

ifeq (${PERL_CHECKED},cancel)
	@${call die,Cancelled}
else
ifeq (${PERL_CHECKED},skip)
ifndef DRY_RUN
	@echo "State:   skipped"				> $@
	@echo "Date:    "`date`					>> $@
	@echo "Name:    ${PORTNAME}"				>> $@
	@echo "Version: ${PORTVERSION}"				>> $@
	@${call warn,Skipped}
else
	@echo "FOUND:     ${PORTNAME}"
endif
else
ifeq (${PERL_CHECKED},install)
ifndef DRY_RUN
	@${MAKE_RECURSIVE} build
	@${PORTSDIR}/etc/snapshot ${PREFIX}			> $@.before
	@${MAKE_RECURSIVE} do-install
	@echo "State:   installed"				> $@
	@echo "Date:    "`date`					>> $@
	@echo "Name:    ${PORTNAME}"				>> $@
	@echo "Version: ${PORTVERSION}"				>> $@
	@${PORTSDIR}/etc/snapshot -d $@.before ${PREFIX}	> $@.content
else
	@echo "NOT FOUND: ${PORTNAME}"
endif
else
	@`${PORTSDIR}/etc/chkmod ${PERL_CHECK_MODULE} ${PERL_CHECK_VERSION} ${PERL_CHECK_MODE}` && ${MAKE_RECURSIVE_PERL} $@
endif
endif
endif
endif

def-install:
	@${INSTALL_PRECMD}

	@cd ${WRKSRC}										\
	&& ${INSTALL_ENV} ${INSTALL_COMMAND} ${INSTALL_ARGS} ${INSTALL_POSTARGS}

	@${INSTALL_POSTCMD}


# deinstalling
deinstall:
	@${DEINSTALL_PRECMD}

	@if [ \! -f ${PORTSDB}/${PORTNAME} ]; then						\
		${call warn,${PORTNAME} is not installed};					\
	else											\
		${MAKE_RECURSIVE} clean;							\
		if [ -f ${PORTSDB}/${PORTNAME}.content ]; then					\
			${PORTSDIR}/etc/snaprm ${PREFIX} ${PORTSDB}/${PORTNAME}.content;	\
		fi;										\
		rm -f ${PORTSDB}/${PORTNAME};							\
		rm -f ${PORTSDB}/${PORTNAME}.before;						\
		rm -f ${PORTSDB}/${PORTNAME}.content;						\
	fi;

	@${DEINSTALL_POSTCMD}


# reinstalling
reinstall: deinstall install


# service
get-%:
	@echo -n ${$*}


# default do-
do-%:
	@${MAKE_RECURSIVE} def-$*


# utils
define info
	echo "##############################################################################";	\
	echo "#";										\
	echo "# INFO: "${1};									\
	echo "#";										\
	echo "##############################################################################"
endef

define warn
	echo "##############################################################################";	\
	echo "#";										\
	echo "# WARNING: "${1};									\
	echo "#";										\
	echo "##############################################################################"
endef

define die
	echo "##############################################################################";	\
	echo "#";										\
	echo "# ERROR: "${1};									\
	echo "#";										\
	echo "##############################################################################";	\
	exit 99
endef
