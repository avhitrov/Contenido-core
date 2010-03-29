##############################################################################
# $HeadURL: svn://cvs1.rambler.ru/Contenido/trunk/ports/all/expat/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

PORTVERSION =		2.6.26
CONFIGURE_POSTARGS =	--without-python --without-threads

ifeq (${shell uname},FreeBSD)
CONFIGURE_POSTARGS +=	--with-iconv=/usr/local
endif


include ../../etc/ports.mk
