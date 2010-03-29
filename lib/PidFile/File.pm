package PidFile::File;

use strict;
use warnings 'all';

use Fcntl qw(:flock);
use FindBin;


sub new {
	my ($class, $pid_dir, %opts) = @_;

	die "PID directory required\n" unless $pid_dir && -d $pid_dir;
	$pid_dir =~ s#/+$##;

	my $self = {
		file    => "$pid_dir/".($opts{pid_name}||"$FindBin::RealScript.pid"),
		host    => $opts{host},
		verbose => $opts{verbose},
	};

	bless $self, $class;
}

sub block {
	my ($self, $now) = @_;

	if (-f $self->{file}) {
		warn "Found existing PID file, check for alive process...\n" if $self->{verbose};
		open PID, "<$self->{file}" or die "Can't read existing PID file - $!\n";
		chomp(local $_ = <PID>);
		warn "Found previous PID: $_\n" if $self->{verbose};
		unless (flock PID, LOCK_EX|LOCK_NB) {
			if ($self->{verbose}) {
				die "Found alive process, exit\n";
			} else {
				print "Found alive process, exit\n";
				exit;
			}
		}
		close PID;
		warn "No alive process were found\n" if $self->{verbose};
	}

	open PID, ">$self->{file}" or die "Can't create PID file - $!\n";
	flock PID, LOCK_EX or die "Can't lock PID files - $!\n";
	select((select(PID), $|=1)[0]);
	print PID $$;
	$self->{handle} = *PID;

	print "Created PID file (PID: $$) at ".localtime($now)."\n" if $self->{verbose};
}

sub release {
	my ($self, $now) = @_;

	return unless $self->{handle};

	flock $self->{handle}, LOCK_UN;
	close $self->{handle};
	unlink $self->{file} or die "Can't unlink self PID file - $!\n";

	print "Removed PID file (PID: $$) at ".localtime($now)."\n" if $self->{verbose};

	return 0;
}

1;
