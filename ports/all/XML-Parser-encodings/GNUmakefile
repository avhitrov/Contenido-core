##############################################################################
# $HeadURL: http://svn.dev.rambler.ru/Contenido/branches/utf8/ports/all/XML-Parser-encodings/GNUmakefile $
# $Id: GNUmakefile 661 2007-01-29 12:03:09Z abavykin $
###############################################################################

PORTVERSION =		0.01
PERL_MAKEMAKER =	yes
PORT_DEPENDS =		XML-Encoding

WRKSRC =		${WRKDIR}/${PORTNAME}-${PORTVERSION}

do-fetch: ;
do-extract: ;
	@mkdir -p ${WRKSRC}

do-configure: ;
do-build:
	@export ${BUILD_ENV}; for ENC in *.txt; do									\
		ENC_NAME=`echo $${ENC} | perl -pe 's/\.txt$$//'`;							\
		${PREFIX}/bin/make_encmap $${ENC_NAME} $${ENC_NAME}.txt |						\
		${PERL} -pi -e "s/(?<=^<encmap name='$${ENC_NAME}')()(?=>)/ expat='yes'/;" > ${WRKSRC}/$${ENC_NAME}.xml;\
		${PREFIX}/bin/compile_encoding -o ${WRKSRC}/$${ENC_NAME}.enc ${WRKSRC}/$${ENC_NAME}.xml;		\
	done

do-install:
	@mkdir -p ${PREFIX}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/XML/Parser/Encodings/
	@cp ${WRKSRC}/*.enc ${PREFIX}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/XML/Parser/Encodings/

include ../../etc/ports.mk
