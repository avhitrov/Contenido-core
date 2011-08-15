package Contenido::Parser;

use strict;
use warnings;
use locale;

use Encode;
use URI;
use Data::Dumper;
use Contenido::Globals;
use LWP::UserAgent;
use Contenido::File::Scheme::FILE;
use Contenido::Parser::Util;

sub new {
    my ($proto) = @_;
    my $class = ref($proto) || $proto;
    my $self = {};
    bless $self, $class;

    return $self;
}


sub fetch {
    my ($self, $input, %opts) = @_;

    my ($fh, $content);
    my $encoding = delete $opts{encoding};
    if (not ref $input) {
	no strict "refs";
	my $scheme = uc(scheme($input));
	if ( $scheme eq 'FILE' ) {
		$fh = &{"Contenido::File::Scheme::".uc(scheme($input))."::get_fh"}($input);
	} else {
		my $request = new HTTP::Request GET => $input;
		my $ua = new LWP::UserAgent;
		$ua->timeout(10);
		my $res = $ua->request($request);
		if ($res->is_success) {
			$self->{headers} = $res->headers;
			my $content_length = $res->headers->header('content-length');
			my $content_type = $res->headers->header('content-type');
			$self->{content_type} = $content_type;
			if ( $content_type =~ /charset\s*=\s*([a-z\d\-]+)/i ) {
				$encoding = $1;
			}
			my $base_url = $input =~ /^([a-z]+:\/\/[a-z\.\d]+)/ ? $1 : '';
			$self->{base_url} = $base_url		if $base_url;
			$content = $res->content;
		} else {
			warn $res->status_line." \n";
			$self->{success} = 0;
			$self->{reason} = $res->status_line;
			return $self;
		}
	}
    } elsif ((ref $input eq "GLOB") or (ref $input eq 'Apache::Upload') or (ref $input eq 'IO::File')) {
	$fh = $input;
    } elsif (ref $input eq "SCALAR") {
	$fh = IO::Scalar->new($input);
    } else {
	warn("Path, scalar ref or fh needed");
	$self->{success} = 0;
	$self->{reason} = 'Path, scalar ref or fh needed';
	return $self;
    }

    if ( ref $fh ) {
	$content = <$fh>;
    }
    if ( $content ) {
	unless ( $encoding ) {
		$encoding = $self->__try_content_encoding( substr($content, 0, 350) );
	}
	if ( $encoding && $encoding ne 'utf-8' ) {
		warn "Encoding from $encoding\n..."		if $DEBUG;
		Encode::from_to($content, $encoding, 'utf-8');
		if ( exists $self->{headers} ) {
			foreach my $header ( keys %{$self->{headers}} ) {
				if ( ref $self->{headers}{$header} eq 'ARRAY' ) {
					foreach my $val ( @{$self->{headers}{$header}} ) {
						Encode::from_to($val, $encoding, 'utf-8');
					}
				} else {
					Encode::from_to($self->{headers}{$header}, $encoding, 'utf-8');
				}
			}
		}
	}
	$self->{encoding} = $encoding;
	warn Dumper($self)		if $DEBUG;
	$self->{content} = $content;
	$self->{success} = 1;
    } else {
	$self->{success} = 0;
	$self->{reason} = 'Content is empty';
    }
    return $self;
}

sub is_success {
    my ($self, $val) = @_;

    if ( defined $val ) {
	$self->{success} = $val;
	return $self;
    } else {
	return $self->{success};
    }
}

sub __try_content_encoding {
    my ($self, $input)= @_;
    if ( $input =~ /encoding[\ ]?=[\ ]?[\"\']?([a-z\-\d]+)/i ) {
	return lc($1);
    } elsif ( $input =~ /charset[\ ]?=[\ ]?[\"\']?([a-z\-\d]+)/i ) {
	return lc($1);
    } elsif ( $input =~ /(utf-8|windows-1251|koi8-r)/i ) {
	return lc($1);
    } else {
	return undef;
    }
}

sub scheme {
    my $uri = shift;
    my $scheme;

    $scheme = URI->new($uri)->scheme() || "file";

    return $scheme;
}


1;