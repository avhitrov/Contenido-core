##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/trunk/ports/all/Module-Build/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

PORTVERSION =		0.3800
PERL_MODBUILD =		yes
MASTER_CPAN_SUBDIR =	Module

include ../../etc/perl.mk

ifeq (${shell ${PERL} -e 'print 1 if ${PERL_LEVEL}<501000'},1)
PORT_DEPENDS +=		Test-Harness
endif

ifeq (${shell ${PERL} -e 'print 1 if ${PERL_LEVEL}<501001'},1)
PORT_DEPENDS +=		ExtUtils-Install
endif

ifeq (${shell ${PERL} -e 'print 1 if ${PERL_LEVEL}<501200'},1)
PORT_DEPENDS +=		ExtUtils-CBuilder	\
			ExtUtils-ParseXS
endif

ifeq (${shell ${PERL} -e 'print 1 if ${PERL_LEVEL}<501400'},1)
PORT_DEPENDS +=		Module-Metadata		\
			Perl-OSType		\
			version
endif

include ../../etc/ports.mk
