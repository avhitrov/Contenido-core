##############################################################################
# $HeadURL$
# $Id$
###############################################################################

# independent required
CORE_REQUIRED +=		BSD-Resource
CORE_REQUIRED +=		Digest-MD5
CORE_REQUIRED +=		Image-Size
CORE_REQUIRED +=		Image-Info
CORE_REQUIRED +=		String-CRC32
CORE_REQUIRED +=		Time-HiRes
CORE_REQUIRED +=		Time-modules
CORE_REQUIRED +=		cyrillic
CORE_REQUIRED +=		libnet
CORE_REQUIRED +=		URI
CORE_REQUIRED +=		libwww
CORE_REQUIRED +=		MailTools
CORE_REQUIRED +=		DateTime
CORE_REQUIRED +=		HTML-Mason
CORE_REQUIRED +=		apache13
CORE_REQUIRED +=		libapreq
CORE_REQUIRED +=		PerlMagick
CORE_REQUIRED +=		IO-stringy
CORE_REQUIRED +=		DateTime-Format-Pg
CORE_REQUIRED +=		Cache-Memcached
CORE_REQUIRED +=		Data-Recursive-Encode
CORE_REQUIRED +=		JSON-XS
CORE_REQUIRED +=		cronolog
CORE_REQUIRED +=		clogger
CORE_REQUIRED +=		HTML-Parser
CORE_REQUIRED +=		mtt
CORE_REQUIRED +=		SQL-Abstract
CORE_REQUIRED +=		Log-Dispatch
CORE_REQUIRED +=		Text-Wrapper

# depends on DB_TYPE
ifeq (${DB_TYPE},SINGLE)
CORE_REQUIRED +=		postgresql
endif

# depends on DB_TYPE
ifeq (${shell perl -e 'print 1 if "${DB_TYPE}" eq "SINGLE" ||		\
				  "${DB_TYPE}" eq "REMOTE"'},1)
CORE_REQUIRED +=		DBI
CORE_REQUIRED +=		DBD-Pg
endif

# если сильно течет память уменьшить до 1000
MAX_REQUESTS_PER_CHILD ?=	10000

DEVELOPMENT ?=			NO

OPTIONS_EXPIRE ?=		600
