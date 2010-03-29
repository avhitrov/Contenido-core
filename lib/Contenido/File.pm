package Contenido::File;

use strict;
use warnings;

use Contenido::Globals;
use URI;
use Data::Dumper;
use IO::File;
use IO::Scalar;
use Contenido::File::Scheme::HTTP;
use Contenido::File::Scheme::FILE;
use Contenido::DateTime;

our $IgnoreErrors = 1;

sub fetch {
    my $filename = shift || return;
    my $fh;

    foreach my $dir (@{$state->{"files_dir"}}) {
        my $path = $dir . '/' . $filename;

        no strict "refs";
        $fh = &{"Contenido::File::Scheme::".uc(scheme($path))."::fetch"}($path);
        return $fh if $fh;
    }
}

sub store {
    my $filename = shift   || return;
    my $fh = get_fh(shift) || return;

    my $dt = Contenido::DateTime->new()->set_locale('en')->set_time_zone("UTC");

    my @successful;

    #убираем сдвоенные и более /
    $filename =~ s#/+#/#g;
    #убираем начальный /
    $filename =~ s#^/##;

    foreach my $dir (@{$state->{"files_dir"}}) {
        seek $fh, 0, 0;
        my $path = $dir . '/' . $filename;

        no strict "refs";
        my $return = &{"Contenido::File::Scheme::".uc(scheme($path))."::store"}($path, $fh, $dt);
        push @successful, $path if $return;
    }

    if (
        !@successful or 
        (
            (scalar @successful != scalar @{$state->{"files_dir"}}) and 
            !$IgnoreErrors
        )
    ) {
        foreach my $path (@successful) {
            no strict "refs";
            &{"Contenido::File::Scheme::".uc(scheme($path))."::remove"}($path);
        }
        return;
    }
    1;
}

sub size {
    my $filename = shift;
    my %args = @_;

    my $size;

    #убираем сдвоенные и более /
    $filename =~ s#/+#/#g;
    #убираем начальный /
    $filename =~ s#^/##;

    foreach my $dir (@{$state->{"files_dir"}}) {
        no strict "refs";
        my $response = &{"Contenido::File::Scheme::".uc(scheme($dir))."::size"}($dir."/".$filename, %args);
        return unless defined $response;
        return if defined $size and $size != $response;

        $size = $response;
        #TODO
        last;
    }
    return $size;
}

sub remove {
    my $filename = shift || return;

    #убираем сдвоенные и более /
    $filename =~ s#/+#/#g;
    #убираем начальный /
    $filename =~ s#^/##;

    foreach my $dir (@{$state->{"files_dir"}}) {
        no strict "refs";
        &{"Contenido::File::Scheme::".uc(scheme($dir))."::remove"}($dir."/".$filename);
    }

    1;
}

sub get_fh {
    my $input = shift;
    my $fh;

    if (not ref $input) {
        no strict "refs";
        $fh = &{"Contenido::File::Scheme::".uc(scheme($input))."::get_fh"}($input);
    } elsif ((ref $input eq "GLOB") or (ref $input eq 'Apache::Upload') or (ref $input eq 'IO::File')) {
        $fh = $input;
    } elsif (ref $input eq "SCALAR") {
        $fh = IO::Scalar->new($input);
    } else {
        $log->warning("Path, scalar ref or fh needed");
        return;
    }

    return $fh
}

sub scheme {
    my $uri = shift;
    my $scheme;

    $scheme = URI->new($uri)->scheme() || "file";

    return $scheme;
}

# sub files_dir {
#     return unless $_[0];
#     my $dir;

#     for (scheme($_[0])) {
#         /http/ && do {
#             $dir = URI->new($_[0])->canonical();
#             $dir =~ s|/*$|/|;
#             last;
#         };
#         /file/ && do {
#             $dir = URI->new($_[0])->path();
#             $dir =~ s|/*$|/|;
#             last;
#         };
#     }

#     return $dir;
# }

1;
