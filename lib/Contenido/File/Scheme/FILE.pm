package Contenido::File::Scheme::FILE;

use strict;
use warnings;

use Contenido::Globals;
use Data::Dumper;
use IO::File;

sub store {
    my $path = shift || return;
    my $fh = shift || return;

    local $/ = undef;
    make_dir_recursive($path);

    my $size = (stat $fh)[7];
    if ( $size < 10485760 ) {
	my $content = <$fh>;
	unless (open FILE, "> $path") {
		warn $!;
		return;
	}
	print FILE $content;
	close FILE;
    } else {
	my ($offset, $limit, $buff) = (0, 524288, undef);
	my $dst = new IO::File;
	unless ($dst->open("> $path")) {
		warn $!;
		return;
	}
	while ( $size ) {
		my $len = $size > $limit ? $limit : $size;
		$fh->sysread( $buff, $len, $offset );
		$dst->syswrite( $buff, $len, $offset );
		$offset += $len;
		$size -= $len;
		undef $buff;
	}
	undef $dst;
    }

    return 1;
}

sub remove {
    my $path = shift;

    unlink $path or warn $! and return;
    return 1;
}

sub size {
    my $path = shift;

    return unless -r $path and -f $path;
    return (stat($path))[7];
}

sub listing {
    my $path = shift;
    my $files = {};

    return unless Contenido::File::scheme($path) eq "file";
    return unless -e $path and -d $path;

    opendir my $dir, $path || return; #warn "can't opendir $path: $!";

    foreach my $file (grep { -f "$path/$_" } readdir $dir) {
        $files->{$file} = Contenido::File::Scheme::FILE::size($path."/".$file);
    }

    closedir $dir;

    return $files;
}

sub make_dir_recursive {
    my $path = shift;

    my @parts = grep {$_} split "/", $path;

    for (0 .. $#parts - 1) {
		my $dir = "/".join("/", @parts[0 .. $_]);
		next if -d $dir;
        mkdir $dir or die "Can't create directory $dir: $!";
    }
}

sub get_fh {
    my $path = shift;

    my $fh = IO::File->new($path) or do { warn "can't open file [$path] for reading"; return; };
	return $fh;
}

1;
