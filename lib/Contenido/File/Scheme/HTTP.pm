package Contenido::File::Scheme::HTTP;

use strict;
use warnings;

use Contenido::Globals;
use Contenido::File;
use IO::Scalar;
use Data::Dumper;
use HTTP::Request;
use HTTP::Headers;
use LWP::UserAgent;
use File::Temp;

my  %LWP_ARGS = (timeout => 5);

sub fetch {
    my $path      = shift || return;

    my $fh = File::Temp->new(
        TEMPLATE => 'tempXXXXX',
        DIR => $keeper->state()->{tmp_dir},
        SUFFIX => '.dat'
    );

    my $ua = LWP::UserAgent->new(%LWP_ARGS);

    my $res = $ua->get(
        $path,
        ':read_size_hint' => 10 * 1024,
        ':content_cb'     => sub {
            $fh->write(shift());
        },
    );

    seek $fh, 0, 0;

    return $res->is_success() ? $fh : undef;
}

sub store {
    my $path = shift || return;
    my $fh = shift || return;
    my $dt = shift;

    local $/ = undef;

    my $content = <$fh>;

    my $ua = LWP::UserAgent->new(%LWP_ARGS);
    my $req = HTTP::Request->new(PUT => $path);
    $req->content_length(length $content);
    $req->content($content);
    $req->header(Date => $dt->strftime('%a %b %d %H:%M:%S %Y')) if $dt and ref $dt eq "DateTime";

    my $res = $ua->request($req);
#    my $res = $ua->request($req, sub { my $buffer; read $fh, $buffer, 10000; return $buffer });

    unless ($res->is_success()) {
        warn $req->headers()->as_string()."\nreturned NOT OK result: ".$res->message()."(".$res->code.") result is: ".$res->as_string."\n";
        return;
    }

    1;
}

sub remove {
    my $path = shift;

    my $ua = LWP::UserAgent->new(%LWP_ARGS);
    my $req = HTTP::Request->new(DELETE => $path);
    my $res = $ua->request($req);

    unless ($res->is_success()) {
        warn $req->headers()->as_string()."\nreturned NOT OK result: ".$res->message()."(".$res->code.") result is: ".$res->as_string."\n";
        return;
    }

    1;
}

sub size {
    my $path = shift;

    my $ua = LWP::UserAgent->new(%LWP_ARGS);
    my $req = HTTP::Request->new(HEAD => $path);
    my $res = $ua->request($req);

    return unless $res->is_success();
    return $res->content_length();
}

sub listing {
    my $path = shift;

    return unless Contenido::File::scheme($path) eq "http";

    my $files = {};
    my $buffer = "";
    my $ua = LWP::UserAgent->new(%LWP_ARGS);

    $ua->get($path,
             ":content_cb" => sub {
                 $buffer .= shift;

                 while ($buffer =~ s/^(.*?)(?:\r?\n)+//) {
                     next unless my $line = $1;
                     $line =~ s/^[ \t]+//;
                     $line =~ s/[ \t]+$//;
                     if ($line =~ /^<.+?>(.+?)<.+?>.+?(\d+)$/) {
                         $files->{$1} = $2;
                     }
                 }
             },
             ":read_size_hint" => 102400,
         );

    return $files;
}

sub get_fh {
    my $path = shift;
	my $fh;

    return unless Contenido::File::scheme($path) eq "http";

    my $ua = LWP::UserAgent->new(%LWP_ARGS);

    my $response = $ua->get($path);

	if ($response->is_success()) {
        $fh = IO::Scalar->new(\($response->content()));
	} else {
		warn  $response->status_line();
	}

	return $fh;
}

1;
