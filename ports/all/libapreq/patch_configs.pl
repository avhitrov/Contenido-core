#!/usr/bin/perl

use strict;

my $start_dir = $ARGV[0] || die "Root dir needed\n";
$start_dir =~ s/\/$//;
die "Wrong path\n"	unless -e $start_dir;

print "Start patching Makefiles from [$start_dir]...\n";

my @dirs = ( $start_dir );
my @FILES;

while ( @dirs ) {
   my $dir = shift @dirs;
   opendir(DIR,  $dir);
   my @files =  grep { /[^\.]+/ && ( -d $dir.'/'.$_ || $_ eq 'Makefile' ) } readdir(DIR);
   closedir DIR;

   foreach my $file ( @files ) {
	if ( $file eq 'Makefile' ) {
		push @FILES, $dir.'/'.$file;
	} else {
		push @dirs, $dir.'/'.$file;
	}
   }
}

foreach my $file ( @FILES ) {
    print $file."\n";
    my $dir = $file;
    $dir =~ s/\/\w+$//;
    open FILE, $file;
    my $buffer = '';
    while ( <FILE> ) {
	my $str = $_;
	if ( $str =~ /^OPTIMIZE\s*=\s+(.*?)\n/ ) {
		$str = "OPTIMIZE = $1 -fgnu89-inline\n";
	}
	$buffer .= $str;
    }
    close FILE;
    my $out = $dir.'/Makefile.patch';
    open OUT, "> $out";
    print OUT $buffer;
    close OUT;
    rename $file, $file.'.orig';
    rename $out, $file;
}

print "Files patched\n";