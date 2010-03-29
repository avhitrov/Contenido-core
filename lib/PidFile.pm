package PidFile;

use strict;
use warnings 'all';

use Contenido::DateTime;
use PidFile::Database;
use PidFile::DatabaseCompat;
use PidFile::File;


my $singleton;

sub new {
	$singleton ||= _new(@_);
}

#XXX: compat.
sub start {
	__PACKAGE__->new(@_);
}

sub _new {
	my ($class, $storage, %opts) = @_;

	select((select(STDERR), $|=1)[0]);
	select((select(STDOUT), $|=1)[0]);

	my $now = time;

	my $self = {
		lclass  => 'PidFile::'.(ref $storage ? 'Database'.($opts{compat} ? 'Compat' : '') : 'File'),
		started => $now,
		verbose => $opts{verbose},
	};

	$opts{host} = (`hostname`=~/(.*)/)[0];
	if ($opts{host_only} && $opts{host_only} ne $opts{host}) {
		print "This script executes only at $opts{host_only}, exit\n" if $opts{verbose};
		exit;
	}

	printf "\nPID $$ started at ".localtime($now)."\n" if $self->{verbose};
	$self->{lock} = $self->{lclass}->new($storage, %opts);
	$self->{lock}->block($now);

	bless $self, $class;
}

sub DESTROY {
	my $self = shift;

	my $now = time;
	my $delay = $self->{lock}->release($now);
	print "PID $$ finished at ".localtime($now)." (elapsed ".($now - $self->{started})." seconds".($delay ? " in execute and $delay seconds in sleep" : "").")\n" if $self->{verbose};
}

sub END {
	undef $singleton;
}

1;
