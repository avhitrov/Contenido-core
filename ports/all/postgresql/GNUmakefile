##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/postgresql/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

PORTVERSION =		8.1.4
CONFIGURE_ARGS =	--prefix=${PREFIX}/pgsql				\
			--enable-debug						\
			--enable-locale						\
			--enable-syslog
BUILD_POSTCMD =		cd ${WRKSRC}/contrib/intarray				\
			&& ${BUILD_ENV} ${BUILD_COMMAND} ${BUILD_ARGS} ${BUILD_POSTARGS}
INSTALL_POSTCMD =	cd ${WRKSRC}/contrib/intarray				\
			&& ${INSTALL_ENV} ${INSTALL_COMMAND} ${INSTALL_ARGS} ${INSTALL_POSTARGS}

MASTER_POST_SITES =	ftp://ftp.at.postgresql.org/db/www.postgresql.org/pub/source/v${PORTVERSION}/	\
			ftp://ftp2.nl.postgresql.org/mirror/postgresql/source/v${PORTVERSION}/

initdb:	install
	@if [ -d ${PREFIX}/pgsql/data ]; then					\
		if [ $$((`ls -1A ${PREFIX}/pgsql/data | wc -l`)) -ne 0 ]; then	\
			echo "WARNING: database cluster already initialized";	\
			exit 0;							\
		fi;								\
	fi;									\
	mkdir -m 700 ${PREFIX}/pgsql/data					\
	&& ${PREFIX}/pgsql/bin/initdb -D ${PREFIX}/pgsql/data


include ../../etc/ports.mk
