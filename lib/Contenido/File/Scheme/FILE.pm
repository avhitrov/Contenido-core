package Contenido::File::Scheme::FILE;

use strict;
use warnings;

use Contenido::Globals;
use Data::Dumper;

sub store {
    my $path = shift || return;
    my $fh = shift || return;

    local $/ = undef;

    my $content = <$fh>;

    make_dir_recursive($path);

    unless (open FILE, ">$path") {
        warn $!;
        return;
    }

    print FILE $content;
    close FILE;

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
