#!/usr/bin/perl

##############################################################################
# $HeadURL: svn://cvs1.rambler.ru/cndinst/trunk/skel/GNUmakefile $
# $Id: GNUmakefile 47 2006-06-08 08:45:46Z lonerr $
###############################################################################

use strict;
use warnings "all";

use FindBin;
BEGIN { require "$FindBin::RealBin/../lib/Modules.pm" }

use locale;
use PidFile;
use Data::Dumper;
use Contenido::Globals;
use Contenido::Init;
use Contenido::File;
use Contenido::File::Scheme::FILE;
use Contenido::File::Scheme::HTTP;

# begin
Contenido::Init->init();
PidFile::start($state->{run_dir}, verbose => 1);
my $keeper = Contenido::Keeper->new($state);

my %files;

foreach my $class (map { @{$state->{"available_".$_}} } qw(documents links sections)) {
    if (my $sub = $class->can("extra_properties")) {
        my @extras = grep { lc($_->{"type"}) eq "image" or lc($_->{"type"}) eq "images" } $sub->();
        my @objects = $keeper->get_documents( class => $class, no_limit => 1 );

        foreach my $object (@objects) {
            foreach my $extra (@extras) {
                my $image = $object->get_image($extra->{"attr"});
                if ($image) {
                    if ($extra->{"type"} eq "images") {
                        foreach (values %$image) {
                            next unless ref $_;
                            if ($_->{"filename"}) {
                                $files{$_->{"filename"}}++;
                            }
                            if ($_->{"mini"}{"filename"}) {
                                $files{$_->{"mini"}{"filename"}}++;
                            }
                        }
                    } else {
                        if ($image->{"filename"}) {
                            $files{$image->{"filename"}}++;
                        }
                       if ($image->{"mini"}{"filename"}) {
                           $files{$image->{"mini"}{"filename"}}++;
                       }
                   }
                }
            }
        }
    }
}

foreach my $dir (@{$state->{"files_dir"}}) {
    no strict "refs";
    my $files = &{"Contenido::File::Scheme::".uc(Contenido::File::scheme($dir))."::listing"}($dir);

    foreach my $file (keys %$files) {
        unless (exists $files{$file}) {
            &{"Contenido::File::Scheme::".uc(Contenido::File::scheme($dir))."::remove"}($dir."/".$file);
        }
    }
}
