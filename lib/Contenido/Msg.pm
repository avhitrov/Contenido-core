package Contenido::Msg;

use strict;
use warnings;

use Contenido::Globals;

use vars qw (@EXPORT @ISA %HANDLERS);

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(&msg);

#никогда не ставьте вызовы &debug в код log_handlers
%HANDLERS = (
		debug	=> \&default_warn_handler,
		log	=> \&default_warn_handler,
		logging	=> \&default_warn_handler,
		warn	=> \&default_warn_handler,
		warning	=> \&default_warn_handler,
		err	=> \&default_warn_handler,
		error	=> \&default_warn_handler,
		crit	=> \&default_warn_handler,
		sql	=> \&default_sql_handler,
	    );

sub msg {
	my ($msg, $tag) = @_;
	$tag = lc($tag);

	#нет handler на такой тип сообщения или кривой handler стоит
	unless ($tag and exists($HANDLERS{$tag}) and (ref($HANDLERS{$tag}) eq 'CODE')) {
		warn "не известный или некорректный handler для сообщения типа: '$tag'\n";
		return undef;
	}

	my ($package, $filename, $line) = caller();
	my @caller = caller(1);
	my $subroutine;

	if ( $caller[3] =~ /::(\w+)$/ ) {
		$subroutine = $1;
	} else {
		$subroutine = caller[3];
	}

	#формируем строку об ошибке в стандартном формате
	my $string = 'Contenido '.$tag.' ['.scalar(localtime).'] '.$$.': '.$package.'/'.$line.' '.$subroutine.': '.$msg;

	#вызываем handler обработки сообщения
	eval { $HANDLERS{$tag}->($string, $tag) };
	warn "Error $@ in handler $tag\n" if ($@);
}

sub default_warn_handler {
	my ($string, $tag) = @_;
	#пропускаем если тип сообщения debug и отладка выключенна
	warn $string."\n" unless ($tag eq 'debug' and  !$DEBUG);
}

sub default_sql_handler {
	my ($string, $tag) = @_;
	#только для $DEBUG_SQL установленного
	warn $string."\n" if ($DEBUG_SQL);
}

1;

