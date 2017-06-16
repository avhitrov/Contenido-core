##############################################################################
# Перегрузка builtin функций 'warn' и 'die'.
# Использование:
#   use Contenido::Errors qw(die warn);
# При включенной опции STACK_TRACE = YES ($state->{stack_trace} в config.mk
# инсталляции дополняет выводимые сообщения трейсом по компонентам и модулям.
##############################################################################
package Contenido::Errors;

use strict;
use warnings 'all';
use base qw(Exporter);
use vars qw(@EXPORT_OK);

use Contenido::Globals;


@EXPORT_OK = qw(&debug &die &warn);

my %skip_pack = map {$_=>1} qw(
                HTML::Mason::ApacheHandler
                HTML::Mason::Component
                HTML::Mason::Request
                HTML::Mason::Request::ApacheHandler
                );

my %skip_file = map {$_=>1} qw(
                /dev/null
                );

sub debug {
	return unless $DEBUG;
	warn("DEBUG: ".join("\n", @_));
}

sub warn {
	my $msg = (@_ ? join("\n", @_) : 'Warning: something\'s wrong').&native(@_);
	$msg .= &trace if $state->{stack_trace};
	CORE::warn $msg;
}

sub die {
	my $msg = (@_ ? join("\n", @_) : 'Died').&native(@_);
	$msg .= &trace if $state->{stack_trace};
	CORE::die $msg;
}

sub native {
	return '' if ($_[-1]||'')=~/\n$/;
	my @info = caller(1);
	" at ".$info[1]." line ".$info[2].", in PID $$, ".(localtime(time))."\n";
}

sub trace {
	my (@stack, @info, $level);

	while (@info = caller(++$level)) {
		next if $skip_pack{$info[0]} || $skip_file{$info[1]};
		push @stack, sprintf('  line: %6d  file: %s', $info[2], $info[1]);
	}

	@stack ? "Stack trace:\n".join("\n", @stack)."\n" : '';
}

1;
