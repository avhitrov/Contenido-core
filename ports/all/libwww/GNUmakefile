##############################################################################
#
###############################################################################

#include ../../etc/perl.mk

PORTVERSION =		6.13
DISTFILE =		${PORTNAME}-perl-${PORTVERSION}.tar.gz
PERL_MAKEMAKER =	yes
MASTER_CPAN_SUBDIR =	LWP
PORT_DEPENDS =		Authen-NTLM					\
			Encode-Locale					\
			File-Listing					\
			HTML-Parser					\
			HTTP-Cookies					\
			HTTP-Daemon					\
			HTTP-Date					\
			HTTP-Message					\
			HTTP-Negotiate					\
			LWP-MediaTypes					\
			Net-HTTP					\
			URI						\
			WWW-RobotRules					\
			Crypt-SSLeay					\
			LWP-Protocol-https

#PERL_CHECK_MODULE =	LWP
CONFIGURE_COMMAND =	${PERL} Makefile.PL -n


include ../../etc/ports.mk
