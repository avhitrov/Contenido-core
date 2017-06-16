##############################################################################
# Project default & calculated settings
###############################################################################


# it must!
PROJECT_NAME ?=			$(error "ERROR: PROJECT_NAME not defined")

ifeq (${DB_TYPE},NONE)
PGSQL_PORT =
PGSQL_BASE =

BASE_HOST =
BASE_USER =
BASE_PASSWD =
else
PGSQL_PORT ?=			$(error "ERROR: PGSQL_PORT not defined")
PGSQL_BASE ?=			$(error "ERROR: PGSQL_BASE not defined")

BASE_HOST ?=			$(error "ERROR: BASE_HOST not defined")
BASE_USER ?=			$(error "ERROR: BASE_USER not defined")
BASE_PASSWD ?=			$(error "ERROR: BASE_PASSWD not defined")
endif

# additional DB for replications
MASTER_BASE_HOST ?=		${BASE_HOST}
MASTER_BASE_NAME ?=		${PGSQL_BASE}
MASTER_BASE_PASSWD ?=		${BASE_PASSWD}
MASTER_BASE_PORT ?=		${PGSQL_PORT}
MASTER_BASE_USER ?=		${BASE_USER}

# additional ports if any
PROJECT_REQUIRED ?=
SERIALIZE_WITH ?=
VCS_TYPE ?=			svn

# defaults
PRELOADS ?=
PERSISTENT_CONN ?=		YES
PGSQL_REAL_PREPARE ?=		YES

MEMCACHED_BACKEND ?=		Cache::Memcached::Fast
MEMCACHED_ENABLE ?=		NO
MEMCACHED_SELECT_TIMEOUT ?=	0.5
MEMCACHED_SERVERS ?=
MEMCACHED_ENABLE_COMPRESS ?=	YES
MEMCACHED_DELAYED ?=		NO
MEMCACHED_SET_MODE ?=		SET

STORE_METHOD ?=			TOAST
CASCADE ?=			YES

# TODO drop PREVIEW!
PREVIEW ?=			150x150
AUTH_COOKIE ?=			rsid

DEFAULT_HANDLER ?=		HTML::Mason::ApacheHandler
DEFAULT_ESCAPE_FLAGS ?=

# main preamble hanler
PREAMBLE_HANDLER ?= 
# extra preamble handlers relative path 
PREAMBLE_HANDLER_PATH ?= 

RSYNC_DIRS ?=
RSYNC_CORE_DIRS +=		contenido/i

# apache pool
${PROJECT_LC}_START_SERVERS ?=	1
START_SERVERS ?=		${${PROJECT_LC}_START_SERVERS}

${PROJECT_LC}_MAX_CLIENTS ?=	3
MAX_CLIENTS ?=			${${PROJECT_LC}_MAX_CLIENTS}

${PROJECT_LC}_MIN_SPARE_SERVERS ?= 1
MIN_SPARE_SERVERS ?=		${${PROJECT_LC}_MIN_SPARE_SERVERS}

${PROJECT_LC}_MAX_SPARE_SERVERS ?=	${shell perl -e 'print ${MIN_SPARE_SERVERS}+1'}
MAX_SPARE_SERVERS ?=		${${PROJECT_LC}_MAX_SPARE_SERVERS}

${PROJECT_LC}_SPARE_REAPER_DELAY ?= 0
SPARE_REAPER_DELAY ?=		${${PROJECT_LC}_SPARE_REAPER_DELAY}

SPARE_REAPER_DELAY_FAKEMOD ?=	${shell perl -e 'print ${SPARE_REAPER_DELAY} ? "http_core" : "nonexistent"'}

# logging
${PROJECT_LC}_HTTPD_ELOG_LEVEL ?= info
HTTPD_ELOG_LEVEL ?=		${${PROJECT_LC}_HTTPD_ELOG_LEVEL}

# kinds of limits
MAX_PROCESS_SIZE ?=		65535
LIMIT_CMD ?=			/usr/bin/limits
LIMIT_VMEMORY_HTTPD ?=		256m
LISTEN_BACK_LOG_PERCHILD ?=	5
LISTEN_BACK_LOG ?=		${shell perl -e 'print ${LISTEN_BACK_LOG_PERCHILD}*${MAX_CLIENTS}'}

# logging options
RSYSLOG_ENABLE ?=		NO
RSYSLOG_HOST ?=			lc.park.rambler.ru
LOGGER ?=			${LOCAL}/bin/clogger

# disable 'start' command
DISABLE ?=			${${PROJECT_LC}_DISABLE}

# cronolog options
CRONOLOG_ENABLE ?=		NO
CRONOLOG_FORMAT ?=		%Y/%m/%d/

# load cron tab
CRON_ENABLE ?=			NO

LOCALE ?=			ru_RU.UTF-8

# use mtt or old rewrite?
USE_MTT ?=			NO

# use READONLY mode
READONLY ?=			NO

# later captcha setting
USE_CAPTCHA ?=			NO
ifeq (${USE_CAPTCHA},YES)
CORE_REQUIRED +=		Authen-Captcha
endif

# Calculated
MODULES =
ifeq (${shell perl -e 'print lc "${DEVELOPMENT}"'},yes)
MODULES =			${PROJ_SRC}/${PROJECT}/lib
endif
MODULES +=			${PROJ_USR}/${PROJECT}/lib
ifneq (${PLUGINS},)
MODULES +=			${addprefix ${PLUG_USR}/,${addsuffix /lib,${PLUGINS}}}
endif
MODULES +=			${CORE_USR}/lib

PLUGIN_COMP ?=			${shell perl -e 'print lc "${DEVELOPMENT}" eq "yes" ? "${PLUG_SRC}" : "${PLUG_USR}"'}
MASON_COMP ?=			${shell perl -e 'print lc "${DEVELOPMENT}" eq "yes" ? "${PROJ_SRC}" : "${PROJ_USR}"'}/${PROJECT}/comps
CORE_COMP ?=			${shell perl -e 'print lc "${DEVELOPMENT}" eq "yes" ? "${CORE_SRC}" : "${CORE_USR}"'}/comps
RSYNC_ROOT ?=			${PROJ_USR}/${PROJECT}/comps
RSYNC_CORE_ROOT ?=		${CORE_USR}/comps
ASSETS_ROOT ?=			${PROJ_VAR}/${PROJECT}
BINARY ?=			${MASON_COMP}/binary
ifdef FRONTENDS
FILES ?=			${addprefix http://, ${addsuffix /dav/${PROJECT_LC}, ${FRONTENDS}}}
else
FILES ?=			${MASON_COMP}/files
endif
IMAGES ?=			${MASON_COMP}/images
STATIC_SOURCE_TOUCH_FILE ?=	${MASON_COMP}/.touch

# Files are stored in NFS (=Common) or independently on each front (=Separate)
FILE_WEB_STORAGE ?=		Separate

HTTPD_DOCS ?=			${MASON_COMP}/www
CONF ?=				${PROJ_USR}/${PROJECT}/conf

# pregenerate static
PREGEN_GLOB ?=			keeper project state
PREGEN_LIST ?=

# Mason caching
MASON_CACHE_ENABLED ?=		YES

# Mason caching via Memcached
MASON_MEMCACHED_BACKEND ?=	${MEMCACHED_BACKEND}
MASON_MEMCACHED_DEBUG ?=	NO
MASON_MEMCACHED_ENABLED ?=	NO
MASON_MEMCACHED_NAMESPACE ?=	${PROJECT}:${PROJECT_VERSION}
MASON_MEMCACHED_SERVERS ?=
COMP_TIMINGS_DISABLE ?=		YES

# overrides
ifeq (${DB_TYPE},SINGLE)
BASE_HOST =
endif

# psql wrappers
PSQL ?=				${shell export PATH=${LOCAL}/pgsql/bin:$${PATH};	\
					PSQL=`which psql`;				\
					if [ -x "$${PSQL}" ]; then			\
						echo $${PSQL};				\
					else						\
						echo 'echo "ERROR: No executable psql found";';		\
						echo 'echo "HINT:  Add path to psql to your environment PATH";';	\
						echo 'exit 1;';				\
					fi;}

PGDUMP ?=			${shell export PATH=${LOCAL}/pgsql/bin:$${PATH};	\
					PGDUMP=`which pg_dump`;				\
					if [ -x "$${PGDUMP}" ]; then			\
						echo $${PGDUMP};			\
					else						\
						echo 'echo "ERROR: No executable pg_dump found";';			\
						echo 'echo "HINT:  Add path to pg_dump to your environment PATH";';	\
						echo 'exit 1;';				\
					fi;}

# rsync wrappers
RSYNC =				${shell export PATH=${LOCAL}/bin:$${PATH};		\
					RSYNC=`which rsync`;				\
					if [ -x "$${RSYNC}" ]; then			\
						echo $${RSYNC};				\
					else						\
						echo 'echo "ERROR: No executable rsync found";';			\
						echo 'echo "HINT:  Add path to rsync to your environment PATH,";';	\
						echo 'echo "       or install with: make port_install PORT=rsync``";';	\
						echo 'exit 1;';				\
					fi;}

COMPOSITE =				${shell export PATH=${LOCAL}/bin:$${PATH}; which composite}
#CONVERT =				${shell export PATH=${LOCAL}/bin:$${PATH}; which convert}
#ifeq (${CONVERT},)
#${error ERROR: No executable convert found, you need to install ImageMagick first}
#endif
