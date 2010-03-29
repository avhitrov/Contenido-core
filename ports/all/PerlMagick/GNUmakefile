##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/PerlMagick/GNUmakefile $
# $Id: GNUmakefile 185 2006-06-19 14:52:11Z abavykin $
###############################################################################

PORTVERSION =		6.24
PERL_MAKEMAKER =	yes
PERL_CHECK_MODULE =	Image-Magick
MASTER_CPAN_SUBDIR =	Image
PORT_DEPENDS =		ImageMagick

CONFIGURE_PRECMD =	${MAKE_RECURSIVE} pre-configure

pre-configure:
	@cd ${WRKSRC}																					\
	&& perl -pi -e "s|^(\s+'INC'\s+=>\s+)'(.+)'|\$$1'-I${PREFIX}/include \$$2'|" Makefile.PL	\
	&& perl -pi -e "s|^(\s+'LIBS'\s+=>\s+)\['(.+)'\]|\$$1\['-L${PREFIX}/lib \$$2'\]|" Makefile.PL


include ../../etc/ports.mk
