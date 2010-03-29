package PidFile::Database;

use strict;
use warnings 'all';

use DBI;
use Digest::MD5 qw(md5);
use FindBin;
use POSIX qw(strftime);


sub new {
	my ($class, $keeper, %opts) = @_;

	my ($crc1, $crc2) = map {abs unpack 'j',$_} grep {$_} split /(.{8})/, md5(($opts{pid_name}||$FindBin::RealScript).($opts{per_host} ? $opts{host} : ''));

	my $self = {
		dbh      => $keeper->SQL,
		delay    => exists $opts{delay} ? $opts{delay} : 30,
		host     => $opts{host},
		mutex    => $crc1^$crc2,
		per_host => $opts{per_host},
		script   => "$FindBin::RealBin/$FindBin::RealScript",
		verbose  => $opts{verbose},
	};

	$self->{dbh}{PrintError} = 0;
	$self->{dbh}{RaiseError} = 1;

	bless $self, $class;
}

sub block {
	my ($self, $now) = @_;

	$self->{started} = $now;

	unless ($self->{dbh}->selectrow_arrayref("SELECT pg_try_advisory_lock(?);", {}, $self->{mutex})->[0]) {
		my $err = "Found alive process, exit\n";
		die $err if $self->{verbose};
		print $err;
		exit;
	}

	$self->{dbh}->do("INSERT INTO pid (pid, mutex, host, script, started) VALUES (?,?,?,?,?)", {}, $$, $self->{mutex}, $self->{host}, $self->{script}, strftime('%Y-%m-%d %H:%M:%S', localtime $now));
	$self->{id} = $self->{dbh}->selectrow_array("SELECT currval('documents_id_seq')");

	print "Created PID record (PID: $$) at ".localtime($now)."\n" if $self->{verbose};
}

sub release {
	my ($self, $now) = @_;

	my $sleep = $self->{delay} ? $self->{delay} - ($now - $self->{started}) : 0;
	$sleep = 0 if $sleep<0;

	if ($sleep) {
		print "Sleeping for $sleep seconds before exit...\n" if $self->{verbose};
		sleep $sleep;
	}

	$self->{dbh}->do("UPDATE pid SET finished=? WHERE id=?", {}, strftime('%Y-%m-%d %H:%M:%S', localtime $now), $self->{id});
	$self->{dbh}->do("SELECT pg_advisory_unlock(?);", {}, $self->{mutex});

	print "Removed PID record (PID: $$) at ".localtime($now)."\n" if $self->{verbose};

	return $sleep;
}

sub DESTROY {
	my $self = shift;

	eval {
		$self->{dbh}->disconnect;
	};
}

1;
