##############################################################################
# $HeadURL: svn+ssh://svn@vcs.dev.rambler.ru/Contenido/trunk/ports/all/XML-Parser-encodings/GNUmakefile $
# $Id: GNUmakefile 1654 2012-04-17 14:56:57Z abavykin $
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
		PATH=/usr/local/bin:${PREFIX}/bin make_encmap $${ENC_NAME} $${ENC_NAME}.txt |						\
		${PERL} -pi -e "s/(?<=^<encmap name='$${ENC_NAME}')()(?=>)/ expat='yes'/;" > ${WRKSRC}/$${ENC_NAME}.xml;\
		PATH=/usr/local/bin:${PREFIX}/bin compile_encoding -o ${WRKSRC}/$${ENC_NAME}.enc ${WRKSRC}/$${ENC_NAME}.xml;		\
	done

do-install:
	@mkdir -p ${PREFIX}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/XML/Parser/Encodings/
	@cp ${WRKSRC}/*.enc ${PREFIX}/lib/perl5/site_perl/${PERL_VER}/${PERL_ARCH}/XML/Parser/Encodings/

include ../../etc/ports.mk
