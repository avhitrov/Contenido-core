##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/IPC-ShareLite/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

PORTVERSION =		0.09
PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	IPC
CONFIGURE_PRECMD =	${MAKE_RECURSIVE} pre-configure

pre-configure:

	@cd ${WRKSRC}							\
	&& sed -e 's%/Configure%/Configure -de%'			\
		< Makefile.PL > Makefile.PL.new				\
        && mv Makefile.PL.new Makefile.PL


include ../../etc/ports.mk
