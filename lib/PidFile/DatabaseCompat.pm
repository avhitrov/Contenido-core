package PidFile::DatabaseCompat;

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
		dbh      => $keeper->create_db_t_connect,
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

	# our candidature
	$self->{dbh}->do("INSERT INTO pid (pid, mutex, host, script, started, state) VALUES (?,?,?,?,?,1)", {}, $$, $self->{mutex}, $self->{host}, $self->{script}, strftime('%Y-%m-%d %H:%M:%S', localtime $now));
	$self->{id} = $self->{dbh}->selectrow_array("SELECT currval('documents_id_seq')");
	$self->{dbh}->commit;

	# election now
	eval {
		$self->{cands} = $self->{dbh}->selectall_arrayref("SELECT * FROM pid WHERE mutex=? AND state=1 FOR UPDATE NOWAIT", {Slice=>{}}, $self->{mutex});
	};
	if ($@ && $@=~/could not obtain lock on row/) {
		$@ = "Found alive process, exit\n";
		die $@ if $self->{verbose};
		exit;
	}

	# is real winner?
	unless (grep {$_->{id}==$self->{id}} @{$self->{cands}}) {
		$@ = "Seems like other process overtaked, exit\n";
		die $@ if $self->{verbose};
		exit;
	}

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

	for (@{$self->{cands}}) {
		if ($_->{id}==$self->{id}) {
			$self->{dbh}->do("UPDATE pid SET finished=?, state=2 WHERE id=?", {}, strftime('%Y-%m-%d %H:%M:%S', localtime $now), $self->{id});
		} else {
			$self->{dbh}->do("DELETE FROM pid WHERE id=?", {}, $_->{id});
		}
	}
	$self->{dbh}->commit;

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
