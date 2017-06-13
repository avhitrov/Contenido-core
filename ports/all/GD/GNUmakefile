##############################################################################
# $HeadURL: svn://cvs1.rambler.ru/Contenido/trunk/ports/all/MIME-Base64/GNUmakefile $
# $Id: GNUmakefile 175 2006-06-16 12:50:03Z lonerr $
###############################################################################

include ../../etc/perl.mk


PORTVERSION =		2.53
PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	GD
PORT_DEPENDS =		libgd
CONFIGURE_POSTARGS =	-options "GIF,JPEG,PNG" -lib_gd_path ${PREFIX} -lib_jpeg_path ${PREFIX} -lib_png_path ${PREFIX}


include ../../etc/ports.mk
