##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/File-Cache/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

include ../../etc/perl.mk

PORTVERSION =		0.16
PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	File

ifeq (${shell perl -e 'print 1 if ${PERL_LEVEL}<500800'},1)
PORT_DEPENDS =		Digest-MD5		\
			Storable
endif


include ../../etc/ports.mk
