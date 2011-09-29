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
    my $timeout = delete $opts{timeout} || 10;
    my $encoding = delete $opts{encoding};
    if (not ref $input) {
	no strict "refs";
	my $scheme = uc(scheme($input));
	if ( $scheme eq 'FILE' ) {
		$fh = &{"Contenido::File::Scheme::".uc(scheme($input))."::get_fh"}($input);
	} else {
		my $request = new HTTP::Request GET => $input;
		my $ua = new LWP::UserAgent;
		$ua->timeout($timeout);
		my $res = $ua->request($request);
		if ($res->is_success) {
			$self->{headers} = $res->headers;
			my $content_length = $res->headers->header('content-length');
			my $content_type = $res->headers->header('content-type');
			my $headers_string = $res->headers->as_string;
#			warn $res->content_type_charset."\n\n";
#			warn Dumper($res->headers)		if $DEBUG;
			$self->{content_type} = $content_type;
			if ( $res->content_type_charset ) {
				$encoding = Encode::find_encoding($res->content_type_charset)->name;
			}
			my $base_url = $input =~ /^([a-z]+:\/\/[a-z\.\d]+)/ ? $1 : '';
			$self->{base_url} = $base_url		if $base_url;
			$content = $res->decoded_content( charset => 'none' );
#			warn "Charset: ".$res->content_charset."\n";
		} else {
			warn $res->status_line." \n";
			$self->{success} = 0;
			$self->{reason} = $res->status_line;
			return $self;
		}
	}
    } elsif ( ref $input eq 'Apache::Upload' ) {
	$fh = $input->fh;
    } elsif ((ref $input eq "GLOB") or (ref $input eq 'IO::File')) {
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
	warn "starting content decoding...\n";
	if ( exists $self->{headers} && ref $self->{headers} && ($self->{headers}->content_is_html || $self->{headers}->content_is_xhtml || $self->{headers}->content_is_xml) ) {
		unless ( $encoding ) {
			$encoding = $self->__try_content_encoding( substr($content, 0, 350) );
		}
		if ( $encoding && $encoding ne 'utf-8' && $encoding ne 'utf-8-strict' ) {
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
		} else {
#			Encode::_utf8_off($content);
			if ( exists $self->{headers} ) {
				foreach my $header ( keys %{$self->{headers}} ) {
					if ( ref $self->{headers}{$header} eq 'ARRAY' ) {
						foreach my $val ( @{$self->{headers}{$header}} ) {
							Encode::_utf8_off($val);
						}
					} else {
						warn "Test: ".$self->{headers}{$header}.": check flag: ".Encode::is_utf8($self->{headers}{$header}).". check: ".Encode::is_utf8($self->{headers}{$header},1)."\n";
						if ( Encode::is_utf8($self->{headers}{$header}) && Encode::is_utf8($self->{headers}{$header},1) ) {
							Encode::_utf8_off($self->{headers}{$header});
#							Encode::_utf8_on($self->{headers}{$header});
#							$self->{headers}{$header} = Encode::encode('utf8', $self->{headers}{$header}, Encode::FB_QUIET);
#							Encode::from_to($self->{headers}{$header}, $encoding, 'utf8');
						}
					}
				}
			}
		}
		$self->{encoding} = $encoding;
		warn Dumper($self)		if $DEBUG;
		if ( $self->{headers}->content_is_html ) {
			my $headers;
			if ( $content =~ /<head.*?>(.*?)<\/head>/si ) {
				$headers = $self->__parse_html_header( $1 );
			}
			if ( ref $headers eq 'ARRAY' && @$headers ) {
				foreach my $header ( @$headers ) {
					if ( $header->{tag} eq 'title' ) {
						$self->{headers}{title} = $header->{content};
					} elsif ( $header->{tag} eq 'meta' && (($header->{rel} && $header->{rel} =~ /icon/i) || ($header->{href} && $header->{href} =~ /\.ico$/)) ) {
						$self->{favicon} = $header->{href};
					}
				}
				$self->{html_headers} = $headers;
			}
		}
	}
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

sub __parse_html_header {
    my ($self, $input)= @_;
    my @tags;
    $input =~ s/[\r\n\t]+/\ /sgi;
    if ( $input =~ /<title.*?>(.*?)<\/title.*?>/sgi ) {
	my $title = $1;
	for ( $title ) {
		s/^\s+//;
		s/\s+$//;
	}
	push @tags, { tag => 'title', content => $title };
    }
    while ( $input =~ /<(.*?)\/?>/sgi ) {
	my $tag = $1;
	my $struct = {};
	for ( $tag ) {
		s/\ *=\ */=/g;
		$_ = __encode_quotes($_);
	}
	my @tag = split /\ +/, $tag;
	$struct->{tag} = lc(shift @tag);
	next	unless ($struct->{tag} eq 'link' || $struct->{tag} eq 'meta');
	foreach my $str ( @tag ) {
		if ( $str =~ /^(.*?)=(.*)$/ ) {
			my $attr = $1;
			my $val = $2;
			for ( $val ) {
				s/^"//;
				s/"$//;
				s/&nbsp;/\ /sg;
			}
			$struct->{$attr} = $val;
		}
	}
	push @tags, $struct;
    }
    return \@tags;
}

sub __encode_quotes {
    my $str = shift;
    my @in = split //, $str;
    my $out = '';
    my $quot = '';
    foreach my $ch ( @in ) {
	if ( ($ch eq '"' && $quot eq '"') || ($ch eq "'" && $quot eq "'") ) {
		$quot = '';
	} elsif ( ($ch eq "'" || $ch eq '"' ) && !$quot ) {
		$quot = $ch;
	} elsif ( ($ch eq '"' && $quot eq "'") ) {
		$ch = '&quot;';
	} elsif ( ($ch eq "'" && $quot eq '"') ) {
		$ch = '&amp;';
	} elsif ( ($ch eq ' ' && $quot) ) {
		$ch = '&nbsp;';
	}
	$out .= $ch;
    }
    $out =~ s/'/"/sgi;
    return $out;
}

sub scheme {
    my $uri = shift;
    my $scheme;

    $scheme = URI->new($uri)->scheme() || "file";

    return $scheme;
}


1;