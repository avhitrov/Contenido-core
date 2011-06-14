package Contenido::Parser::HTML;

use strict;
use warnings;
use locale;

use base 'Contenido::Parser';

use Contenido::Globals;
use Utils::HTML;
use Data::Dumper;
use utf8;
use Encode;

my @PICNAME = qw ( top menu topmenu home line dot mail razdel button find search srch delivery
 head bar label phone bottom bottommenu ico icon post left right service caption arr arrow cart
 basket main reply title corner address page buy pix pixel spacer fon welcome razd about back
 shapka phones print tel phpBB uho korz korzina raspisanie shop login blank telephone telephones
 dealer diler background bg news rss index none btn cards up footer noimage but link excel price
 mid graphic busket map girl space catalog bann headline hosting contact schedule redir email
);

my @PICHOST = qw ( top.list.ru addweb.ru adland.ru extreme-dm.com top100.rambler.ru
 mypagerank.ru informer.gismeteo.ru lux-bn.com.ua link-txt.com myrating.ljseek.com c.bigmir.net
);

my @PICURL = qw ( rorer counter count ljplus yadro spylog hotlog banner baner ban banners ban
 icq mirabilis adriver advertising ad adv ads adview advert weather imho awaps reklama stat cnt
 ipz design icons promo cycounter captcha foto_hit header random adcycle rssfeed bansrc
);


my @bad_dimensions = (
    { w => 120, h => 60 },
    { w => 468, h => 60 },
    { w => 120, h => 600 },
    { w => 88, h => 31 },
);


sub new {
    my ($proto) = @_;
    my $class = ref($proto) || $proto;
    my $self = {};
    bless $self, $class;

    return $self;
}


sub parse {
    my ($self, %opts) = @_;

    my $content;
    if ( $opts{content} ) {
	$content = decode('utf-8', delete $opts{content});
	delete $self->{content};
    } elsif ( $self->{success} || $self->{content} ) {
	$content = decode('utf-8', delete $self->{content});
    } else {
	$self->{success} = 0;
	return $self;
    }

    my $base_url   = delete $self->{base_url} || delete $opts{base_url};
    my $strip_html = delete $opts{strip_html};
    my $debug = $DEBUG;
    my $gui = delete $opts{gui};
    my $header = decode('utf-8', delete $opts{header});
    warn "Header length: ".length($header)."\n";
    my $description = decode('utf-8', delete $opts{description});
    warn "Description length: ".length($description)."\n";
    my $minimum = delete $opts{min} || length $description;

    my $pre_rools =	$self->__parse_rools (delete $opts{parser_pre});
    warn Dumper ($pre_rools)							if $debug;
    my $parse_rools =	$self->__parse_rools (delete $opts{parser_run});
    warn Dumper ($parse_rools)							if $debug;
    my $post_rools =	$self->__parse_rools (delete $opts{parser_end});
    warn Dumper ($post_rools)							if $debug;

#        warn "Experimental. Debug!!!\n"			if $debug;
        if ( ref $pre_rools eq 'ARRAY' ) {
            my @sets = grep { $_->{command} eq 'set' } @$pre_rools;
            foreach my $set ( @sets ) {
                if ( $set->{condition}{param} eq 'min' || $set->{condition}{param} eq 'minimum' ) {
                    my $value = $set->{condition}{value};
                    unless ( $value =~ /\D/ ) {
                        if ( $set->{subcommand} eq 'limit' ) {
                            $minimum = $minimum && $minimum > int($value) ? int($value) : $minimum ? $minimum : int($value);
                        } else {
                            $minimum = int($value);
                        }
                    }
                }
                if ( $set->{condition}{param} eq 'description' && $set->{condition}{value} eq 'header' ) {
                    $description = $header;
                }
            }
        }
        $minimum ||= 300;

  	warn "Tag cleaning...\n"			if $debug;
	$self->__clean_tags (\$content, $pre_rools);
	$content =~ s/>\s+</></sgi;
	warn "Image cleaning...\n"			if $debug;
	$self->__clean_img (\$content);
	warn "Empty div cleaning...\n"			if $debug;
	while ( $self->__clean_empty_div (\$content) ) {}
	warn "Make tree...\n"				if $debug;
	my ($tree, $shortcuts) = $self->__make_tree (\$content, $parse_rools, $debug);

        $self->__extract_img ($shortcuts, $base_url, $debug);
        $self->__extract_headers ($shortcuts, $header, $debug);
	warn "Getting big texts (min=$minimum)...\n"	if $debug;
        my $chosen = $self->__dig_big_texts (
                structure => $shortcuts,
                min	=> $minimum,
                ref $parse_rools eq 'ARRAY' && @$parse_rools ? (rools => $parse_rools) : (),
                debug	=> $debug );
        unless ( ref $chosen eq 'ARRAY' && @$chosen ) {
                $self->{error_message} = 'Nothing was found at all!!! Check your MINIMUM value';
                return $self->is_success(0)		unless $gui;
        }
        if ( $description ) {
            my @use_rools = grep { $_->{command} eq 'use' && $_->{subcommand} eq 'element' } @$parse_rools		if ref $parse_rools eq 'ARRAY';
            $chosen = $self->__check_description ($chosen, $description, $debug)	unless @use_rools;
        }
        unless ( ref $chosen eq 'ARRAY' && @$chosen ) {
                $self->{error_message} = 'I didn\'t find any valuable text';
                return $self->is_success(0)		unless $gui;
        }
        if ( scalar @$chosen > 1 ) {
            $chosen = $self->__check_headers ($chosen, $header, $debug);
        }
        unless ( ref $chosen eq 'ARRAY' && @$chosen ) {
                $self->{error_message} = 'I didn\'t find any valuable text';
                return $self->is_success(0)		unless $gui;
        }
        $self->__strip_html (
                chosen	=> $chosen,
                header	=> $header,
                ref $post_rools eq 'ARRAY' && @$post_rools ? (rools => $post_rools) : (),
                debug	=> $debug
        );
        if ( ref $parse_rools eq 'ARRAY' ) {
            my ($glue) = grep { $_->{command} eq 'glue' } @$parse_rools;
            $self->__glue ( $chosen, $glue, $debug )	if ref $glue;
        }
        my $images = $self->__get_images (
                structure	=> $shortcuts, 
                chosen		=> $chosen->[0],
                base_url	=> $base_url,
                ref $parse_rools eq 'ARRAY' && @$parse_rools ? (rools => $parse_rools) : (),
                debug => $debug,
        );
        if ( ref $images eq 'ARRAY' && @$images ) {
            $self->{images} = $images;
            $self->{image} = $images->[0];
        }

        if ( $gui ) {
            if ( ref $chosen eq 'ARRAY' ) {
                foreach my $elem ( @$chosen ) {
                    $self->__post_rool ($elem, $post_rools, $description);
                }
            }
            $self->{text} = ref $chosen eq 'ARRAY' ? $chosen->[0] : $chosen;
#            $self->{html} = $content;
#            $self->{tree} = $shortcuts;
            $self->{tree} = $tree;
            $self->{chosen} = $chosen;
        } else {
            $self->__post_rool ($chosen->[0], $post_rools, $description);
            $self->{text} = Contenido::Parser::Util::text_cleanup($chosen->[0]->{text});
            $self->{chosen} = $chosen;
            map { $_->{parent} = undef } @$chosen		if ref $chosen eq 'ARRAY';
            $tree = undef;
            foreach my $key ( keys %$shortcuts ) {
                delete $shortcuts->{$key};
            }
            $shortcuts = undef;
            $content = undef;
        }
        return $self->is_success(1);
}

sub __clean_tags {
    my ($self, $content, $rools) = @_;

    my @cut_rools;
    if ( ref $rools eq 'ARRAY' && @$rools) {
        @cut_rools = grep { $_->{command} eq 'dont' && $_->{subcommand} eq 'cut' } @$rools;
    }
    my @clean_off_rools;
    if ( ref $rools eq 'ARRAY' && @$rools) {
        @clean_off_rools = grep { $_->{command} eq 'clean' && $_->{subcommand} eq 'off' } @$rools;
    }
    $$content =~ s/<!DOCTYPE(.*?)>//sgi;
    $$content =~ s/<!--(.*?)-->//sgi;
    $$content =~ s/<script(.*?)<\/script>//sgi;
    $$content =~ s/<hr(.*?)>//sgi;
    $$content =~ s/<noscript(.*?)<\/noscript>//sgi;
    $$content =~ s/<iframe(.*?)<\/iframe>//sgi;
    unless ( grep { $_->{condition}{param} eq 'tag' && $_->{condition}{value} eq 'noindex' } @cut_rools ) {
        $$content =~ s/<noindex(.*?)<\/noindex>//sgi;
    } else {
        $$content =~ s/<\/?noindex(.*?)>//sgi;
    }
    $$content =~ s/<object(.*?)<\/object>//sgi;
    $$content =~ s/<embed(.*?)<\/embed>//sgi;
    $$content =~ s/<style(.*?)<\/style>//sgi;
    if ( grep { $_->{condition}{param} eq 'tag' && $_->{condition}{value} eq 'form' } @cut_rools ) {
        $$content =~ s/<select(.*?)<\/select([^>]*?)>//sgi;
        $$content =~ s/<textarea(.*?)<\/textarea([^>]*?)>//sgi;
        $$content =~ s/<input([^>]*?)>//sgi;
    } else {
        $$content =~ s/<form(.*?)<\/form>//sgi;
        $$content =~ s/<textarea(.*?)<\/textarea([^>]*?)>//sgi;
        $$content =~ s/<select(.*?)<\/select([^>]*?)>//sgi;
    }
    foreach my $rool ( @clean_off_rools ) {
        next		unless $rool->{condition}{param} eq 'tag';
        my $tag = $rool->{condition}{value};
        $$content =~ s/<$tag(.*?)<\/$tag>//sgi;
    }
    $$content =~ s/<head(.*?)<\/head>//sgi;
    $$content =~ s/\ style="(.*?)"//sgi;

    $$content =~ s/<\/?span(.*?)>//sgi;
    $$content =~ s/<\/?font(.*?)>//sgi;
    $$content =~ s/<br(.*?)>/\n/sgi;
    $$content =~ s/<link(.*?)>//sgi;
    $$content =~ s/<spacer(.*?)>//sgi;
    $$content =~ s/<\!\?(.*?)\?>//sgi;
#    $$content =~ s/<a\s*?(.*?)>/\n/sgi;
    $$content =~ s/<\/p\s*>//sgi;
#    $$content =~ s/<\/a\s*>//sgi;
    $$content =~ s/<p\s*(.*?)>/\n\n/sgi;
    $$content =~ s/onclick="(.*?)"//sgi;
    $$content =~ s/onload="(.*?)"//sgi;

}

sub __clean_img {
    my ($self, $content) = @_;

    my @garbage;
    my $i = 1;

    while ( $$content =~ /(<img.*?>)/sgi ) {
        my $img = $1;
        my $src;
        if ( $img =~ /src=([^\x20|^>]+)/i ) {
            $src = $1;
        }
        my ($w, $h);
        if ( $img =~ /width\s*=\s*["'](\d+)/i || $img =~ /width\s*=\s*(\d+)/i ) {
            $w = $1;
        }
        if ( $img =~ /height\s*=\s*["'](\d+)/i || $img =~ /height\s*=\s*(\d+)/i ) {
            $h = $1;
        }
        my $delim = 0;
        if ( $w && $h ) {
            foreach my $pair ( @bad_dimensions ) {
                if ($w == $pair->{w} && $h == $pair->{h}) {
                    $delim = 10;
                    last;
                }
            }
            $delim = ( $w >= $h ? $w : $h ) / ( $w >= $h ? $h : $w )	unless $delim;
        }
        my $bad_name = __check_img_name ( $src );
	if ( $bad_name || ($w && $w < 80) || ($h && $h < 80) || ( $w && $h && ($delim > 2.5) ) ) {
#            warn "Bad name: [$src]\n";
            push @garbage, $src;
        }
    }

    foreach my $src (@garbage) {
        $src =~ s|([*+?()/\\\$\[\]])|\\$1|sg;
        $$content =~ s/<img([^>]*?)src=$src([^>]+)>//si;
    }
}


sub __check_img_name {
    my $name = shift;
    my $test = $1	if $name =~ /\/([^\/]+)$/;
    if ( $test =~ /\d+[x-]\d+/ || $test =~ /\.gif$/i ) {
        return 1;
    }
    foreach my $word ( @PICNAME ) {
        if ( $test =~ /^$word/si || $test =~ /[^a-z]$word[^a-z]/si ) {
            return 1;
        }
    }
    foreach my $word ( @PICURL ) {
        if ( $name =~ /^$word/si || $name =~ /[^a-z]$word[^a-z]/si ) {
            return 1;
        }
    }
    foreach my $word ( @PICHOST ) {
        if ( index (lc($name), $word) >= 0 ) {
            return 1;
        }
    }
    return 0;
}


sub __clean_empty_div {
    my ($self, $content) = @_;

    my $i = 0;
    while ( $$content =~ s/(<div[^>]*?><\/div\s*>)//sgi ) {
        $i++;
    }

    return $i;
}


sub __make_tree {
    my ($self, $content, $rools, $debug) = @_;

    my @elems = split (//,$$content);
    my @collaborate;
    if ( ref $rools eq 'ARRAY' && @$rools) {
        @collaborate = grep { $_->{command} eq 'collaborate' } @$rools;
    }
    my %hierarchy = ( div => 0, td => 1,  tr => 2,  table => 3, body => 4, html => 5 );
    my $id = 1;
    my $level = 0;
    my %tree = (
		root => {
			id	=> $id++,
			text	=> '',
			type	=> 'root',
			children=> [],
			parent	=> undef,
			level	=> $level,
		},
        );
    my @stack;
    my %elem_hash = ( 1 => $tree{root} );
    my $current = $tree{root};
    my $previous;

    while ( @elems ) {
	if ($elems[0] =~ /[\ \t]/ && !$current){
            shift @elems;
            next;
	}
        if ( $elems[0] eq '<' && $elems[1] =~ /[a-zA-Z]/ ) {
            my $tag = $self->__try_tag (\@elems);
            if ( ref $tag && $tag->{type} eq 'text' ) {
                my $last_text_tag = ref $current->{children} eq 'ARRAY' && @{$current->{children}} && $current->{children}->[-1]->{type} eq 'text' ? $current->{children}->[-1] : undef;
                if ( ref $last_text_tag ) {
                    $last_text_tag->{text} .= $tag->{content};
                    $last_text_tag->{count} += $tag->{count};
                } else {
                    $last_text_tag = $tag;
                    $last_text_tag->{id} = $id++;
                    $last_text_tag->{type} = 'text';
                    $last_text_tag->{parent} = $current;
                    $last_text_tag->{level} = $level+1;
                    $last_text_tag->{text} = $tag->{content};
                    $elem_hash{$last_text_tag->{id}} = $last_text_tag;
                    push @{$current->{children}}, $last_text_tag;
                    $current->{text_count}++;
                }
		$current->{text_value} += $tag->{count};
                splice @elems, 0, $tag->{count};
#		warn "Tag opened. Next text: [".join('',$elems[0..10])."]\n";
            } elsif ( ref $tag ) {
                if ( ($current->{type} eq 'td' || $current->{type} eq 'tr' ) && $tag->{type} eq 'tr' ) {
#                    warn "!!!! Error: HTML validation. ID=[$current->{id}]. Stack rollback till table begin... !!!!\n" if $debug;
                    do {
                        $current = pop @stack;
                        $level = $current->{level};
#                        warn "New current type: /$current->{type}. ID = $current->{id}. Level: $level. Stack depth: ".scalar(@stack)."\n";
                    } while ( ($current->{type} !~ /table|body|html/) && scalar @stack );

                }
                if ( $current->{type} eq 'table' && $tag->{type} eq 'table' ) {
#                    warn "!!!! Error: HTML validation. ID=[$current->{id}]. Stack rollback, previous table(s) will forced to be closed... !!!!\n" if $debug;
                    do {
                        $current = pop @stack;
                        $level = $current->{level};
#                        warn "New current type: /$current->{type}. ID = $current->{id}. Level: $level. Stack depth: ".scalar(@stack)."\n";
                    } while ( ($current->{type} eq "table") && scalar @stack );

                }
                $tag->{id} = $id++;
                $tag->{children} = [];
                $tag->{text_count} = 0;
                $tag->{parent} = $current;
                $tag->{level} = ++$level;
                $elem_hash{$tag->{id}} = $tag;
		push @{$current->{children}}, $tag;
                push @stack, $current;
#                warn "Open type: $tag->{type}. ID=[$tag->{id}]. Name: ".($tag->{params}{name}||'').". Class: ".($tag->{params}{class}||'').". Level: $tag->{level}. Stack depth: ".scalar(@stack)."\n";
                $current = $tag;
                splice @elems, 0, $tag->{count};
            } else {
#                warn "!!!! Error: HTML analyse. Job broken... !!!!\n" if $debug;
                last;
            }
        } elsif ( $elems[0] eq '<' && $elems[1] =~ /\// ) {
            my $tag = $self->__try_end (\@elems);
            if ( ref $tag && $tag->{type} eq 'text' ) {
                my $last_text_tag = ref $current->{children} eq 'ARRAY' && @{$current->{children}} && $current->{children}->[-1]->{type} eq 'text' ? $current->{children}->[-1] : undef;
                if ( ref $last_text_tag ) {
                    $last_text_tag->{text} .= $tag->{content};
                    $last_text_tag->{count} += $tag->{count};
                } else {
                    $last_text_tag = $tag;
                    $last_text_tag->{id} = $id++;
                    $last_text_tag->{type} = 'text';
                    $last_text_tag->{parent} = $current;
                    $last_text_tag->{text} = $tag->{content};
                    $last_text_tag->{level} = $level+1;
                    $elem_hash{$last_text_tag->{id}} = $last_text_tag;
                    push @{$current->{children}}, $last_text_tag;
                    $current->{text_count}++;
                }
		$current->{text_value} += $tag->{count};
                splice @elems, 0, $tag->{count};
            } elsif ( ref $tag ) {
                if ( $current->{type} ne $tag->{type} ) {
#                    warn "!!!!Wrong tag type for closing. It's [$tag->{type}]. It must be [$current->{type}]!!!!\n" if $debug;
#                    warn "Current ID: [$current->{id}]. Text place: [".substr($current->{text}, 0, 20)."]\n";
                    if ( $hierarchy{$tag->{type}} > $hierarchy{$current->{type}} ) {
                        do {
                            $current = pop @stack;
                            $level = $current->{level};
#                            warn "New current type: /$current->{type}. Level: $level. Stack depth: ".scalar(@stack)."\n";
                        } while ( ($current->{type} ne $tag->{type}) && scalar @stack );
                        $current = pop @stack;
                        $level = $current->{level};
#                        warn "Close !the right! type: /$tag->{type}. Level: $level. Stack depth: ".scalar(@stack)."\n" if $debug;
                    }else{
#                        warn "Passing by: /$tag->{type}. Level: $level. Stack depth: ".scalar(@stack)."\n" if $debug;
                    }
                } else {
                    if ( @collaborate ) {
                        if ( defined $previous && (grep { $current->{type} eq $_->{condition} } @collaborate)
                               && $previous->{type} eq $current->{type} && $previous->{level} == $current->{level}
                               && $previous->{text} && $current->{text} ) {
                            $previous->{text} .= ' '.$current->{text};
                            my $parent = $current->{parent};
                            splice @{$parent->{children}}, -1, 1;
                            delete $elem_hash{$current->{id}};
                            $current = undef;
                        } elsif ( !defined $previous && $current->{text} ) {
                            $previous = $current;
                        } else {
                            $previous = undef;
                        }
                    }
                    $current = pop @stack;
                    $level = $current->{level};
#                    warn "Text place: [".substr($current->{text}, 0, 20)."]\n"		if exists $current->{text};
#                    warn "Close type: /$tag->{type}. Level: $level. Stack depth: ".scalar(@stack)."\n";
                }
                splice @elems, 0, $tag->{count};
            } else {
#                warn "!!!! Error: HTML analyse. Job broken... !!!!\n" if $debug;
                last;
            }
        } else {
            my $last_text_tag = ref $current->{children} eq 'ARRAY' && @{$current->{children}} && $current->{children}->[-1]->{type} eq 'text' ? $current->{children}->[-1] : undef;
            if ( ref $last_text_tag ) {
                $last_text_tag->{text} .= shift @elems;
                $last_text_tag->{count}++;
            } else {
                $last_text_tag = {};
                $last_text_tag->{text} = shift @elems;
                $last_text_tag->{count} = 1;
                $last_text_tag->{id} = $id++;
                $last_text_tag->{type} = 'text';
                $last_text_tag->{parent} = $current;
                $last_text_tag->{level} = $level+1;
                $elem_hash{$last_text_tag->{id}} = $last_text_tag;
                push @{$current->{children}}, $last_text_tag;
                $current->{text_count}++;
                $current->{text_value} = 0;
            }
            $current->{text_value}++;
        }
    }
    return (\%tree, \%elem_hash);
}


sub __try_tag {
    my ($self, $content) = @_;

    my $i = 1;
    my %tag;
    my $tag = $content->[0];
    while ( $i < (scalar @$content - 1) && $content->[$i] ne '<' && $content->[$i] ne '>' ) {
        $tag .= $content->[$i];
        $i++;
    }
    if ( $content->[$i] eq '<' || $i >= scalar @$content ) {
        return {
            type	=> 'text',
            content	=> $tag,
            count	=> $i,
        };
    }
    $tag .= $content->[$i++];
#    warn "TAG: [$tag]\n";

    if ( $tag =~ /^<(div|table|tr|td|body|html)\s*(.*)/i ) {
        my $val = $1;
        if ( $tag =~ /^<($val)\s*(.*)/i ) {
            $tag{type} = lc($1);
            my $args = $2;
            $tag{count} = $i;
            my %args;
            while ( $tag =~ /([a-zA-z]+)\x20*?=\x20*?"([^"]+)"/g ) {
                $args{lc($1)} = $2;
            }
            while ( $tag =~ /([a-zA-z]+)\x20*?=\x20*?'([^']+)'/g ) {
                $args{lc($1)} = $2;
            }
            while ( $tag =~ /([a-zA-z]+)=(\w+)/g ) {
                $args{lc($1)} = $2;
            }
            foreach my $arg ( qw( name id class width align ) ) {
                $tag{params}{$arg} = $args{$arg}		if exists $args{$arg};
            }
            return \%tag;
        } else {
            return {
                type	=> 'text',
                content	=> $tag,
                count	=> $i,
            };
        }
    } else {
        return {
            type	=> 'text',
            content	=> $tag,
            count	=> $i,
        };
    }
}

sub __try_end {
    my ($self, $content) = @_;

    my $i = 2;
    my %tag;
    my $tag = $content->[0].$content->[1];
    while ( $content->[$i] ne '<' && $content->[$i] ne '>' && $i < (scalar @$content-1) ) {
        $tag .= $content->[$i];
        $i++;
    }
    if ( $content->[$i] eq '<' || $i >= scalar @$content ) {
        return {
            type	=> 'text',
            content	=> $tag,
            count	=> $i,
        };
    }
    $tag .= $content->[$i++];
#    warn "TAG END: [$tag]\n";
    if ( $tag =~ /^<\/(div|table|tr|td|body|html)/i ) {
            my $val = $1;
            if ( $tag =~ /^<\/($val)[\s>]/i ) {
                $tag{type} = lc($1);
                $tag{count} = $i;
                return \%tag;
            } else {
                return {
                     type	=> 'text',
                     content	=> $tag,
                     count	=> $i,
                };
            }
    } else {
            return {
                type	=> 'text',
                content	=> $tag,
                count	=> $i,
            };
    }
}


sub __extract_img {
    my ($self, $structure, $base_url, $debug) = @_;
    return	unless ref $structure eq 'HASH';

    foreach my $tag ( grep { ref $_ && $_->{type} eq 'text' && $_->{text} } values %$structure ) {
        my $text = $tag->{text};
        while ( $text =~ /<img (.*?)>/sgi  ) {
#            warn "Image for extract_img found [$1]. Tag ID: $tag->{id}\n";
            my $params = $1;
            my $img = {};
            if ( $params =~ /src\x20*?=\x20*?["'](.*?)["']/ || $params =~ /src=([^\x20]+)/ ) {
                $img->{url} = $1;
                $img->{url} =~ s/[\r\t\n\ ]+$//;
                $img->{url} =~ s/^[\r\t\n\ ]+//;
                $img->{url} = $base_url.'/'.$img->{url}		unless $img->{url} =~ /^http:/;
                $img->{url} =~ s/\/+/\//sgi;		
                $img->{url} =~ s/http:\//http:\/\//sgi;		
                $img->{w} = $1			if $params =~ /width[\D]+(\d+)/;
                $img->{h} = $1			if $params =~ /height[\D]+(\d+)/;
                $img->{alt} = $1		if $params =~ /alt\x20*?=\x20*?["'](.*?)["']/;
                $tag->{images} = []		unless ref $tag->{images} eq 'ARRAY';
                push @{ $tag->{images} }, $img;
#                warn "Image for extract_img stored [$img->{url}]. Tag ID: $tag->{id}\n";
            }
        }
        $text =~ s/<img (.*?)>//sgi;
        $tag->{text} = $text;
        $tag->{count} = length ($text);
    }
}


sub __extract_headers {
    my ($self, $structure, $debug) = @_;
    return	unless ref $structure eq 'HASH';

    foreach my $tag ( grep { ref $_ && $_->{type} eq 'text' && $_->{text} } values %$structure ) {
        my $text = $tag->{text};
        while ( $text =~ /<h([\d])[^>]*?>([^<]+)<\/h[\d]>/sgi ) {
            my $header_level = $1;
            my $header_text = $2;
            $tag->{headers} = []		unless ref $tag->{headers} eq 'ARRAY';
            push @{ $tag->{headers} }, { level => $header_level, text => $header_text };
        }
    }

}


sub __dig_big_texts {
    my ($self, %opts) = @_;
    my $structure = exists $opts{structure} ? $opts{structure} : undef;
    my $minimum = exists $opts{min} ? $opts{min} : undef;
    my $debug = exists $opts{debug} ? $opts{debug} : undef;
    my $rools = exists $opts{rools} ? $opts{rools} : undef;
    return	unless ref $structure eq 'HASH';

    my @rools;
    if ( ref $rools eq 'ARRAY' && @$rools) {
        @rools = grep { $_->{command} eq 'use' && $_->{subcommand} eq 'element' } @$rools;
    }
    my @exclude_rools;
    if ( ref $rools eq 'ARRAY' && @$rools) {
        @exclude_rools = grep { $_->{command} eq 'exclude' && $_->{subcommand} eq 'element' } @$rools;
    }

    my @ret;
    foreach my $tag ( sort { $a->{id} <=> $b->{id} } grep { ref $_ && $_->{type} eq 'text' && $_->{text} } values %$structure ) {
        next		if $self->__exclude_rools($tag->{parent}, \@exclude_rools);

        if ( @rools ) {
            my $choose = 0;
            foreach my $rool ( @rools ) {
                my $matched = 1;
                foreach my $cond ( @{$rool->{condition}} ) {
                    unless ( exists $tag->{parent}{params}{$cond->{param}} && $tag->{parent}{params}{$cond->{param}} eq $cond->{value} ) {
                        $matched = 0;
                    }
                }
                $choose ||= $matched; 
            }
            if ( $choose ) {
                for ( $tag->{text} ) {
                    s/^[\t\ \n\r]+//s;
                    s/[\t\ \n\r]+$//s;
                    s/[\t\ ]+/\ /sg;
                    s/\r//sg;
                    s/\n{2,}/\n\n/sg;
                    s/\&\\x(\d+)//sgi;
                }

                my $text = $tag->{text};
                $text =~ s/<a.*?href.*?<\/a[^>]*?>//sgi;
                $text = Contenido::Parser::Util::strip_html($text);
                $tag->{text_weight} = length($text);
                if ( length($text) >= $minimum ) {
                    for ( $tag->{text} ) {
                        s/<a.*?>//sgi;
                        s/<\/a.*?>//sgi;
                    }
                    push @ret, $tag;
                }
            }
        } else {
            for ( $tag->{text} ) {
                s/^[\t\ \n\r]+//s;
                s/[\t\ \n\r]+$//s;
                s/[\t\ ]+/\ /sg;
                s/\r//sg;
                s/\n{2,}/\n\n/sg;
            }
            my $text = $tag->{text};
            $text =~ s/<a.*?href.*?<\/a[^>]*?>//sgi;
            $text = Contenido::Parser::Util::strip_html($text);
            $tag->{text_weight} = length($text);
            if ( length($text) >= $minimum ) {
                for ( $tag->{text} ) {
                    s/<a.*?>//sgi;
                    s/<\/a.*?>//sgi;
                    s/\&\\x(\d+)//sgi;
                }
                push @ret, $tag;
            }
        }
    }
    unless ( @ret ) {
        warn "Nothing was found at all!!! Check your ROOLS or MINIMUM value" if $debug;
    }
    return \@ret;
}



sub __check_headers {
    my ($self, $chosen, $header, $debug) = @_;
    return	unless ref $chosen eq 'ARRAY';

    unless ( grep { exists $_->{headers} } @$chosen ) {
        warn "No headers found\n" if $debug;
        return $chosen;
    } else {
#        @$chosen = grep { exists $_->{headers} } @$chosen;
    }
    my @ret;
    foreach my $unit ( @$chosen ) {
        unless ( exists $unit->{headers} && ref $unit->{headers} eq 'ARRAY' ) {
            $unit->{header_identity} = 0;
            $unit->{header_min_level} = 32768;
            next;
        }
        my @headers = sort { $a->{level} <=> $b->{level} } @{$unit->{headers}};
        my $min_level = $headers[0]->{level};
        $unit->{header_min_level} = $min_level;
        if ( $header ) {
            my $coeff = $self->__str_compare( $header, $headers[0]->{text} );
            $unit->{header_identity} = $coeff;
        }
    }
#    @ret = sort { $a->{header_min_level} <=> $b->{header_min_level} } @$chosen;
#    return \@ret;
    return $chosen;
}



sub __check_description {
    my ($self, $chosen, $desc, $debug) = @_;
    return	unless ref $chosen eq 'ARRAY' && $desc;

    my @ret;
    foreach my $unit ( @$chosen ) {
        if ( $desc ) {
            my $coeff = $self->__str_compare( $unit->{text}, $desc );
            warn "Coeff: [$coeff] to: [$unit->{text}]\n" if $debug;
            $unit->{description_identity} = $coeff;
        }
    }
    @ret = sort { $b->{description_identity} <=> $a->{description_identity} } grep { $_->{description_identity} > -0.9 } @$chosen;
    return \@ret;
}


# wtf, bastards! how come my code's used here? --ra
# damn, it's not 100% your code already
sub __str_compare {
    my ($self, $original, $applicant) = @_;

    my $Al = __freq_list($original);
    return -1	unless defined $Al;
    my $Bl = __freq_list($applicant);
    return -1	unless defined $Bl;
    my $df = 0;

    foreach my $word ( %$Bl ) {
        if ( exists $Al->{$word} ) {
            $df += $Al->{$word} || 0;
        } else {
            $df -= $Bl->{$word} || 0;
        }
    }

    return $df;
}

sub __freq_list {

    my @d = grep { length($_) > 3 } split /\W/, $_[0];
    return undef	unless @d;
    my $z = 1/scalar(@d); my %l = ();
    $l{$_} += $z for @d; \%l;
}



sub __strip_html {
    my ($self, %opts) = @_;
    return	unless ref $opts{chosen} eq 'ARRAY';

    my $chosen = $opts{chosen};
    my $rooles = $opts{rools};
    my $header = $opts{header};

    foreach my $unit ( @$chosen ) {
        my %tags;
        my $headers = $unit->{headers}		if exists $unit->{headers};
        if ( ref $headers && ref $rooles eq 'ARRAY' && grep { $_->{command} eq 'kill' && $_->{condition}{param} eq 'headers' } @$rooles ) {
            if ( grep { $_->{command} eq 'kill' && $_->{condition}{param} eq 'headers' && $_->{condition}{value} eq 'all' } @$rooles ) {
                $unit->{text} =~ s/<h(\d)[^>]*>(.*?)<\/h(\d)[^>]*>/\n/sgi;
                $unit->{text} =~ s/^[\x20\t\r\n]+//si;
            } elsif ( grep { $_->{command} eq 'kill' && $_->{condition}{param} eq 'headers' && $_->{condition}{value} eq 'leading' } @$rooles ) {
                while ( $unit->{text} =~ /^<h(\d)[^>]*>(.*?)<\/h(\d)[^>]*>/si ) {
                    my $hdr = 'h'.$1;
                    $unit->{text} =~ s/^<$hdr[^>]*>(.*?)<\/$hdr[^>]*>//si;
                }
            }
	}
        for ( $unit->{text} ) {
            s/></> </sg;
            s/([\!\?:.])\s*?<\/h(\d+)(.*?)>/$1 /sgi;
            s/<\/h(\d+)(.*?)>/\. /sgi;
            s/<h(\d+)(.*?)>/\n/sgi;
            s/&#38;/\&/sg;
            s/&amp;/\&/sgi;
            s/&#171;/«/sg;
            s/&#187;/»/sg;
            s/&#163;/£/sg;
            s/&#150;/&ndash;/sg;
            s/&#151;/&mdash;/sg;
            s/&#133;/\.\.\./sg;
            s/&#132;/"/sg;
            s/&#147;/"/sg;
            s/&#148;/"/sg;
            s/&#180;/'/sg;
            s/&#13;/\n/sg;
            s/&#34;/"/sg;
            s/&nbsp;/\ /sgi;
        }
#        $unit->{text} = HTML::Entities::decode_entities($unit->{text});
#        $unit->{text} = Contenido::Parser::Util::strip_html($unit->{text});
        for ( $unit->{text} ) {
            s/^[\ \t\r\n]+//si;
            s/^(\d+)\.(\d+)\.(\d+)//si;
            s/^[\ \t\r\n]+//si;
            s/^(\d+):(\d+)//si;
            s/^[\ \t\r\n]+//si;
        }
        if ( lc(substr ($unit->{text}, 0, length($header) )) eq lc($header) ) {
            substr $unit->{text}, 0, length($header), '';
            $unit->{text} =~ s/^[\.\ \t\r\n]+//sgi;
        }
        $unit->{text} =~ s/[\ \t\r\n]+$//sgi;
    }
}



sub __glue {
    my ($self, $chosen, $glue, $debug) = @_;
    return      unless ref $chosen eq 'ARRAY';

    my $i = 0;

    if ( $glue->{subcommand} eq 'first' || $glue->{subcommand} eq 'all' ) {
        my $count = exists $glue->{subcommand} && $glue->{subcommand} eq 'first' ? $glue->{condition} : 32768;
        foreach my $unit ( @$chosen ) {
            next unless $i++;
            if ( $i <= $count ) {
                $chosen->[0]->{text} .= "\n\n".$chosen->[$i-1]->{text};
            }
        }
    } elsif ( $glue->{subcommand} eq 'order' && ref $glue->{condition} eq 'ARRAY' ) {
        my $text = '';
        my $i = 0;
        foreach my $pos ( @{ $glue->{condition} } ) {
            $text .= ($i++ ? "\n\n" : '').$chosen->[$pos-1]->{text};
        }
        $chosen->[0]->{text} = $text;
    }
}


sub __get_images {
    my ($self, %opts) = @_;
    my $structure = exists $opts{structure} ? $opts{structure} : undef;
    my $chosen = exists $opts{chosen} ? $opts{chosen} : undef;
    my $debug = exists $opts{debug} ? $opts{debug} : undef;
    my $rools = exists $opts{rools} ? $opts{rools} : undef;
    my $base_url = delete $opts{base_url};
    return	unless ref $chosen && ref $structure;

    return	if ref $rools eq 'ARRAY' && grep { $_->{command} eq 'image_off' } @$rools;
    my @use_rools;
    my @exclude_rools;
    my $no_validation = 0;
    if ( ref $rools eq 'ARRAY' && @$rools) {
        @use_rools = grep { $_->{command} eq 'use' && $_->{subcommand} eq 'image' } @$rools;
        @exclude_rools = grep { $_->{command} eq 'exclude' && $_->{subcommand} eq 'image' } @$rools;
        $no_validation = grep { $_->{command} eq 'dont' && $_->{subcommand} eq 'validate' && $_->{condition}{param} eq 'image' } @$rools;
    }
    my $image_depth;
    if ( ref $rools eq 'ARRAY' && @$rools) {
        my @rools = grep { $_->{command} eq 'image' && $_->{subcommand} eq 'depth' } @$rools;
        $image_depth = $rools[-1]->{condition}	if @rools;
    }

    my @images;
    foreach my $tag ( values %$structure ) {
        next	unless exists $tag->{images} && ref $tag->{images} eq 'ARRAY';
        next	if $self->__exclude_rools($tag, \@exclude_rools);

        if ( @use_rools ) {
            my $choose = 0;
            foreach my $rool ( @use_rools ) {
                my $matched = 1;
                foreach my $cond ( @{$rool->{condition}} ) {
                    unless ( exists $tag->{params}{$cond->{param}} && $tag->{params}{$cond->{param}} eq $cond->{value} ) {
                        $matched = 0;
                    }
                }
                $matched = 0		if $self->__exclude_rools($tag, \@exclude_rools);
                $choose ||= $matched; 
            }
            if ( $choose ) {
                my @img = grep { $no_validation || $self->__img_is_valid ($_) } map {
                                 my $img = rchannel::Image->new($_);
                                 $img->src($base_url.($img->src =~ m|^/| ? '' : '/').$img->src) unless $img->src =~ /^http:/;
                                 $img;
                              } map { {src => $_->{url}, width => $_->{w}, height => $_->{h}, alt => $_->{alt}, title => $_->{alt}} } @{ $tag->{images} };

                push @images, @img;
            }
        } else {
            next	if ($tag->{level}+1) < $chosen->{parent}{level};
            next	if $image_depth && ( $tag->{level} > ($chosen->{parent}{level} + $image_depth) );

            my $ok = 0;
            my $uphops = $tag->{level} > $chosen->{parent}{level} ? 1 : 2;
            my $hops = $image_depth ? $image_depth : $tag->{level} - $chosen->{parent}{level} + $uphops;
            next	if ($hops - $uphops) > 4;
            my @img_parents = ($tag->{id});
            my $parent = $tag;
            for ( 1..$hops ) {
                $parent = $parent->{parent};
                push @img_parents, $parent->{id};
            }
            $parent = $chosen->{parent}{parent};
            for ( 0..$uphops ) {
                if ( grep { $parent->{id} == $_ } @img_parents ) {
                    $ok = 1;
                    last;
                }
                $parent = $parent->{parent};
            }
            if ( $ok ) {
                my @img = grep { $self->__img_is_valid ($_) } map {
                                 my $img = $_;
                                 $img->{src} = $base_url.($img->{src} =~ m|^/| ? '' : '/').$img->{src}	unless $img->{src} =~ /^http:/;
                                 $img;
                              } map { {src => $_->{url}, width => $_->{w}, height => $_->{h}, alt => $_->{alt}, title => $_->{alt}} } @{ $tag->{images} };

                push @images, @img;
            }
        }
    }
#    warn Dumper (\@images);
    if ( @images ) {
        return \@images;
    } else {
        return undef;
    }
}


sub __img_is_valid {
    my ($self, $img) = @_;

    return 1;
    if ( $img->check_online ) {
        my $delim = 0;
        my $w = $img->width;
        my $h = $img->height;
        if ( $w && $h ) {
            foreach my $pair ( @bad_dimensions ) {
                if ($w == $pair->{w} && $h == $pair->{h}) {
                    return undef;
                }
            }
            $delim = ( $w >= $h ? $w : $h ) / ( $w >= $h ? $h : $w )    unless $delim;
            if ( $w < 80 || $h < 80 || $delim > 2.5 ) {
                return undef;
            }
        }
    } else {
#        warn "Image ".$img->src." not found on server";
	return undef;
    }
    return 1;
}


sub __exclude_rools {
    my ($self, $tag, $rools) = @_;
    return undef	unless ref $rools eq 'ARRAY' && @$rools;

    my $choose = 0;
    foreach my $rool ( @$rools ) {
        my $matched = 1;
        foreach my $cond ( @{$rool->{condition}} ) {
            unless ( exists $tag->{params}{$cond->{param}} && $tag->{params}{$cond->{param}} eq $cond->{value} ) {
                $matched = 0;
            }
        }
        $choose ||= $matched; 
    }
    return $choose;
}


sub __parse_rools {
    my ($self, $rools) = @_;
    return	unless $rools;
    $rools =~ s/\r//sgi;
    my @rools = split /\n/, $rools;
    return	unless @rools;

    my @parsed;
    foreach my $rool ( @rools ) {
        my %pr;
        next	if $rool =~ /^#/;
        $rool =~ s/[\x20\t]+$//;
        $rool =~ s/^[\x20\t]+//;
        if ( $rool =~ /^([\w']+)\s+(.*)$/ || $rool =~ /^(\w+)(.*)$/ ) {
            $pr{command} = lc($1);
            my $params = $2;
           
            if ( $pr{command} eq 'cut' && $params =~ /^(\w+)\s+(.*)$/ ) {
                $pr{subcommand} = lc($1); $params = $2;
                next	unless $pr{subcommand} =~ /^(untill|till|from|off|regex|to)$/;
                $params =~ s|([*+?/\\\|])|\\$1|sg		unless $pr{subcommand} eq 'regex';
                $pr{condition} = $params;
            } elsif ( $pr{command} eq 'glue' ) {
                if ( $params =~ /^(\w+)\s+(.*)$/  ) {
                    $pr{subcommand} = $1; $params = $2;
                    next	unless $pr{subcommand} =~ /^(first|all|order)$/;
                    if ( $pr{subcommand} eq 'order' ) {
                        my @pars = grep { $_ } map { int($_) } split (/\s*,\s*/,$params);
                        $pr{condition} = \@pars;
                    } else {
                        $pr{condition} = int($1);
                    }
                } elsif ( $params =~ /(\d+)/i ) {
                    $pr{subcommand} = 'first';
                    $pr{condition} = int($1);
                } else {
                    $pr{subcommand} = 'all';
                }
            } elsif ( $pr{command} eq 'trim' ) {
                if ( $params =~ /(left|right)/i ) {
                    $pr{subcommand} = lc($1);
                } else {
                    $pr{subcommand} = 'all';
                }
            } elsif ( $pr{command} eq 'collaborate' && $params =~ /^(div|td)/i ) {
                $pr{condition} = $1;
            } elsif ( $pr{command} eq 'image' && $params =~ /^off$/i ) {
                $pr{command} = 'image_off';
            } elsif ( $pr{command} eq 'image' && $params =~ /^(\w+)\s+(.*)$/si ) {
                $pr{subcommand} = lc($1); $params = $2;
                next	unless $pr{subcommand} =~ /^(depth)$/;
                $pr{condition} = $params;
            } elsif ( $pr{command} eq 'set' ) {
                if ( $params =~ /^(limit)\s+(.*)$/si ) {
                    $pr{subcommand} = lc($1);
                    $params = $2;
                }
                if ( $params =~ /^(\w+)\s+(.*)$/ ) {
                    $pr{condition} = { param => $1, value => $2 };
                } else {
                    next;
                }
            } elsif ( $pr{command} eq 'kill' && $params =~ /^(leading|all)\s+(headers)$/ ) {
                $pr{command} = 'kill';
                $pr{condition} = { param => $2, value => $1 };
            } elsif ( $pr{command} eq 'use' && $params =~ /^(title)\s+(as)\s+(description)$/ ) {
                $pr{command} = 'set';
                $pr{condition} = { param => 'description', value => 'header' };
            } elsif ( $pr{command} eq 'use' && $params =~ /^(\w+)\s+(.*)$/ ) {
                $pr{subcommand} = $1; $params = $2;
                next	unless $pr{subcommand} =~ /^(element|elem|image)$/;
                $pr{subcommand} = 'element'	if $pr{subcommand} =~ /^(element|elem)$/;
                my @conditions;
                while ( $params =~ /(class|id|name|align)\x20*=\x20*"([^"]+)"/sgi ) {
                    push @conditions, { param => lc($1), value => $2 }
                }
                $pr{condition} = \@conditions;
            } elsif ( $pr{command} eq 'exclude' && $params =~ /^(\w+)\s+(.*)$/ ) {
                $pr{subcommand} = lc($1); $params = $2;
                next	unless $pr{subcommand} =~ /^(image|elem|element)$/;
                $pr{subcommand} = 'element'	if $pr{subcommand} =~ /^(element|elem)$/;
                my @conditions;
                while ( $params =~ /(class|id|name|align)\x20*=\x20*"([^"]+)"/sgi ) {
                    push @conditions, { param => lc($1), value => $2 }
                }
                $pr{condition} = \@conditions;
            } elsif ( ($pr{command} eq 'dont' || $pr{command} eq "don't") && $params =~ /^(\w+)\s+(.*)$/ ) {
                $pr{command} = 'dont';
                $pr{subcommand} = lc($1); $params = $2;
                next	unless $pr{subcommand} =~ /^(cut|validate)$/;
                my @conditions;
                if ( $params =~ /(tag)\x20*=\x20*"([^"]+)"/sgi ) {
                    $pr{condition} = { param => lc($1), value => $2 };
                } elsif ( $params =~ /(image)/i ) {
                    $pr{condition} = { param => lc($1) };
                } else {
                    next;
                }
            } elsif ( $pr{command} eq 'clean' ) {
                if ( $params =~ /^(off)\s+(.*)$/ ) {
                    $pr{subcommand} = lc($1); $params = $2;
                }
                if ( $params =~ /(tag)\x20*=\x20*"([^"]+)"/sgi ) {
                    $pr{condition} = { param => lc($1), value => $2 };
                } elsif ( $params =~ /(span)/i ) {
                    $pr{condition} = { param => 'tag', value => lc($1) };
                } else {
                    next;
                }
            } else {
                next;
            }
            push @parsed, \%pr;
        }
    }
    return ( scalar @parsed ? \@parsed : undef );
}


sub __post_rool {
    my ($self, $element, $rools, $description) = @_;

    if ( ref $rools eq 'ARRAY' && @$rools ) {
        foreach my $rool ( @$rools ) {
            if ( $rool->{command} eq 'cut' ) {
                my $condition = $rool->{condition};
                if ( $rool->{subcommand} eq 'off' ) {
                    $element->{text} =~ s/$condition//sgi;
                } elsif ( $rool->{subcommand} eq 'from' ) {
                    my $pos = index $element->{text}, $condition;
                    if ( $pos >= 0 ) {
                        $element->{text} = substr $element->{text}, 0, $pos;
                    }
#                    $element->{text} =~ s/$condition(.*)$//si;
                } elsif ( $rool->{subcommand} eq 'to' && $condition eq 'description' && $description ) {
                    my $str = substr $description, 0, 12;
                    my $pos = index $element->{text}, $str;
                    if ( $pos >= 0 ) {
                        $element->{text} = substr $element->{text}, $pos, -1;
                    }
                } elsif ( $rool->{subcommand} eq 'till' ) {
                    $element->{text} =~ s/^(.*?)($condition)//si;
                } elsif ( $rool->{subcommand} eq 'untill' ) {
                    $element->{text} =~ s/^(.*?)($condition)/$2/si;
                } elsif ( $rool->{subcommand} eq 'regex' ) {
                    $element->{text} =~ s/$condition//sgi;
                }
            } elsif ( $rool->{command} eq 'trim' ) {
                if ( $rool->{subcommand} eq 'left' ) {
                    $element->{text} =~ s/^[\x20\xA0\t\n\r]+//sg;
                } elsif ( $rool->{subcommand} eq 'right' ) {
                    $element->{text} =~ s/[\x20\xA0\t\n\r]+$//sg;
                } else {
                    $element->{text} =~ s/^[\x20\xA0\t\n\r]+//sg;
                    $element->{text} =~ s/[\x20\xA0\t\n\r]+$//sg;
                }
            }
        }
    }
}


1;
