##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/DBD-Pg/GNUmakefile $
# $Id: GNUmakefile 1418 2009-06-05 09:17:07Z phoinix $
###############################################################################


include ../../etc/perl.mk


ifeq (${shell perl -e 'print 1 if ${PERL_LEVEL}<500600'},1)
PORTVERSION =		1.32
else
PORTVERSION =		2.11.8
endif

PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	DBD
PORT_DEPENDS =		DBI version
CONFIGURE_PRECMD =	${MAKE_RECURSIVE} pre-configure
CONFIGURE_POSTENV =	POSTGRES_HOME=${WRKSRC}/pgsql

pre-configure:

	@rm -Rf ${WRKSRC}/pgsql							\
	&& mkdir ${WRKSRC}/pgsql						\
	&& mkdir ${WRKSRC}/pgsql/bin						\
	&& mkdir ${WRKSRC}/pgsql/include					\
	&& mkdir ${WRKSRC}/pgsql/lib

	@cd ../postgresql/							\
	&& ${MAKE_RECURSIVE} build

	PG=`cd ../postgresql/ && ${MAKE_RECURSIVE} get-WRKSRC`			\
	&& cp  $${PG}/src/bin/pg_config/pg_config ${WRKSRC}/pgsql/bin		\
	&& cp  $${PG}/src/interfaces/libpq/*.h ${WRKSRC}/pgsql/include		\
	&& cp  $${PG}/src/include/postgres_ext.h ${WRKSRC}/pgsql/include	\
	&& cp  $${PG}/src/interfaces/libpq/libpq.a ${WRKSRC}/pgsql/lib


include ../../etc/ports.mk
