package Contenido::Parser::RSS;

use strict;
use warnings;
use locale;

use base 'Contenido::Parser';

use Contenido::Globals;
use Utils::HTML;
use Time::ParseDate;
#use Date::Parse;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
#use Class::Date;
use Encode;
use utf8;

my @INVALID_TAGS = qw ( A ABBREV ACRONYM ADDRESS APP APPLET AREA AU B BANNER BASE BASEFONT BDO BGSOUND BIG BLINK BLOCKQUOTE
	BODY BQ BR CAPTION CENTER CITE CODE COL COLGROUP CREDIT DD DEL DFN DIR DIV DL DT EM FN FIG FONT FORM FRAME FRAMESET
	H1 H2 H3 H4 H5 H6 HP HR I IMG INPUT INS ISINDEX KBD LANG LH LI LISTING MAP MARQUEE MENU META NEXTID NOBR NOEMBED
	NOFRAMES NOTE OL OPTION OVERLAY P PARAM PERSON PLAINTEXT PRE Q S SAMP SELECT SMALL SPAN STRIKE STRONG SUB SUP TAB
	TABLE TBODY TD TEXTAREA TFOOT TH THEAD TR TT U UL VAR WBR XMP EMBED
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
	$content = delete $opts{content};
	delete $self->{content};
    } elsif ( $self->{success} || $self->{content} ) {
	$content = delete $self->{content};
    } else {
	$self->{success} = 0;
	return $self;
    }
    my $base_url   = delete $self->{base_url} || delete $opts{base_url};
    my $allow_global_fulltext = delete $opts{allow_fulltext} || 0;
    my $content_global_type = delete $opts{content_type} || 1;
    my $debug = $DEBUG;
    my $gui = delete $opts{gui};
    my $description_as_fulltext = delete $opts{description_as_fulltext};
    warn "Parser Rools: [".$opts{parser_rss}."]\n"				if $debug && $opts{parser_rss};

    my $rss_rools =     $self->__parse_rools (delete $opts{parser_rss});

    warn "RSS Rools: ".Dumper ($rss_rools)					if $debug && $rss_rools;

    my @items;
    my $feed = $self->__parse_content(\$content);

    if ( ref $feed eq 'ARRAY' ) {
        foreach my $item ( @$feed ) {
            my $fulltext_field;
            my $content_type = $content_global_type;
            my $allow_fulltext = $allow_global_fulltext;
            $self->__check_rewrite ( item => $item, rools => $rss_rools );
            my $date = $self->__parse_date($item->{pubdate});
            my $pubdate = Contenido::DateTime->new( epoch => $date );
#            $pubdate = $pubdate->ymd('-').' '.$pubdate->hms;
            next	if ref $item->{title};
            next	if ref $item->{description};
            $self->__check_ignore ( item => $item, rools => $rss_rools );
            $self->__check_only ( item => $item, rools => $rss_rools );
            $item->{title} = $self->__field_prepare ($item->{title});
            $self->__check_filter ( gui => $gui, field => 'title', item => $item, rools => $rss_rools );
            my $title = $item->{title};
            my $link;
            if ( ref $item->{link} eq 'HASH' ) {
                if ( ( (exists $item->{link}{type} && $item->{link}{type} eq 'text/html') || !exists $item->{link}{type} ) && exists $item->{link}{href} ) {
                    $link = $item->{link}{href};
                }
            } elsif ( ref $item->{link} eq 'ARRAY' ) {
                foreach my $lnk ( @{ $item->{link} } ) {
                    if ( ref $lnk ) {
                        if ( ( (exists $lnk->{type} && $lnk->{type} eq 'text/html') || !exists $lnk->{type} ) && exists $lnk->{href} ) {
                            $link = $lnk->{href};
                        }
                    } else {
                        $link = $lnk;
			last;
                    }
                }
            } else {
                $link = $item->{'link'} || (ref $item->{'url'} eq 'ARRAY' ? $item->{'url'}->[0] : $item->{'url'});
            }
            $link = $self->__field_prepare ($link);
            $link = $base_url.($link =~ m|^/| ? '' : '/' ).$link		if $base_url && ($link !~ /^http:/);
            $item->{description} = encode('utf-8', $self->__field_prepare (decode('utf-8', $item->{description})));
            $self->__check_filter ( gui => $gui, field => 'description', item => $item, rools => $rss_rools );
            my %image_href;
            my $description = $item->{description};
            if ( exists $item->{'rambler:fulltext'} && $item->{'rambler:fulltext'} ) {
                $allow_fulltext = 1;
            }
            my $fulltext;
            if ( $description_as_fulltext ) {
                $fulltext = $description;
                $fulltext_field = 'description'
            } else {
                if ( $gui ) {
                    foreach my $field ( qw( rambler:fulltext rambler:full-text yandex:full-text mailru:full-text content:encoded full-text fulltext text ) ) {
                        if ( exists $item->{$field} && $item->{$field} ) {
                            $fulltext_field = $field;
                            $fulltext = $item->{$field};
                            last;
                        }
                    }
                } else {
                    $fulltext =
                        $item->{'rambler:fulltext'}     ||
                        $item->{'rambler:full-text'}    ||
                        $item->{'yandex:full-text'}     ||
                        $item->{'mailru:full-text'}     ||
                        $item->{'content:encoded'}      ||
                        $item->{'full-text'}            ||
                        $item->{'fulltext'}             ||
                        $item->{'text'};
                }
                if ( ref $fulltext eq 'HASH') {
                    my @values = values %$fulltext;
                    if ( scalar @values == 1 ) {
                        $fulltext = $values[0];
                    }
                }
                if ( ref $fulltext eq 'ARRAY' ) {
                    $fulltext = join "\n", @$fulltext;
                }
                $self->__check_filter ( gui => $gui, field => 'fulltext', item => $item, text => \$fulltext, rools => $rss_rools );
                $fulltext = $self->__field_prepare ($fulltext);
            }
            if ( $fulltext && !$description ) {
                $item->{description} = Utils::HTML::limit_words ( $fulltext, 150, 300 );
                $self->__check_filter ( gui => $gui, field => 'description', item => $item, rools => $rss_rools );
                $description = $item->{description};
            }
            $allow_fulltext = 0		unless $fulltext;
            my $author;
            if ( exists $item->{author} && $item->{author} ) {
                if ( ref $item->{author} eq 'HASH' && exists $item->{author}{name} ) {
                    $author = $item->{author}{name};
                } elsif ( !ref $item->{author} ) {
                    $author = $item->{author};
                }
            }
            my $category = [];
            if ( exists $item->{category} && ref $item->{category} eq 'ARRAY' ) {
                $category = $item->{category};
            } elsif ( exists $item->{category} ) {
                $category = [$item->{category}];
            }
            my @images;
            if ( exists $item->{image} || exists $item->{enclosure} ) {
                my @src = ref $item->{image} eq 'ARRAY' ? @{ $item->{image} } : ( $item->{image} )			if exists $item->{image};
                my @att = ref $item->{enclosure} eq 'ARRAY' ? @{ $item->{enclosure} } : ( $item->{enclosure} )	if exists $item->{enclosure};
                @att = grep { ref $_ eq 'HASH' && $_->{type} =~ /image/ } @att;
                @images = map {
                        my $img = $_;
                        $img->{src} = $base_url.($img->{src} =~ m|^/| ? '' : '/').$img->{src}   unless $img->{src} =~ /^http:/; $img;
                    } map { {src => $_->{url}, $_->{width} ? (width => $_->{width}) : (), $_->{height} ? (height => $_->{height}) : (), $_->{title} ? (title => $_->{title}) : ()} } grep { ref $_ eq 'HASH' && exists $_->{url} } @src, @att;
            }
            my @videos;
            if ( exists $item->{video} || exists $item->{enclosure} ) {
                my @src = ref $item->{video} eq 'ARRAY' ? @{ $item->{video} } : ( $item->{video} )			if exists $item->{video};
                my @att = ref $item->{enclosure} eq 'ARRAY' ? @{ $item->{enclosure} } : ( $item->{enclosure} )	if exists $item->{enclosure};
                @att = grep { ref $_ eq 'HASH' && $_->{type} =~ /video/ } @att;
                @videos = map { {src => $_->{url}, $_->{type} ? (type => $_->{type}) : (), $_->{title} ? (title => $_->{title}) : (), $_->{width} ? (width => $_->{width}) : (), $_->{height} ? (height => $_->{height}) : ()} } grep { ref $_ eq 'HASH' && exists $_->{url} } @src, @att;
            }
            my @audios;
            if ( exists $item->{audio} || exists $item->{enclosure} ) {
                my @src = ref $item->{audio} eq 'ARRAY' ? @{ $item->{audio} } : ( $item->{audio} )			if exists $item->{audio};
                my @att = ref $item->{enclosure} eq 'ARRAY' ? @{ $item->{enclosure} } : ( $item->{enclosure} )	if exists $item->{enclosure};
                @att = grep { ref $_ eq 'HASH' && $_->{type} =~ /audio/ } @att;
                @audios = map { {src => $_->{url},  $_->{type} ? (type => $_->{type}) : (), $_->{title} ? (title => $_->{title}) : ()} } grep { ref $_ eq 'HASH' && exists $_->{url} } @src, @att;
            }
            my ($video_url, $audio_url);
            if ( $content_type == 2 || @videos || exists $item->{'videourl'} || exists $item->{'video_url'} ) {
                $video_url = exists $item->{video} && ref $item->{video} eq 'HASH' && exists $item->{video}{url} ?
                    $item->{video}{url} :
                        $item->{'videourl'}					||
                        $item->{'video_url'}					||
                        ($item->{'guid'} && $item->{'guid'} =~ /^http:/ ? $item->{'guid'} : undef)	||
                        (exists $item->{'link'} && ref $item->{'link'} eq 'HASH' ? $item->{'link'}{'href'} || $item->{'link'}{'url'} : $item->{'link'} );
                $content_type = 2;
            }
            if ( @audios || exists $item->{'audiourl'} || exists $item->{'audio_url'} ) {
                $audio_url = exists $item->{audio} && ref $item->{audio} eq 'HASH' && exists $item->{audio}{url} ?
                        $item->{audio}{url} :
                        $item->{'audiourl'} || $item->{'audio_url'};
                $content_type = 2;
            }
            my $related = [];
            if ( exists $item->{'rambler:related'} && $item->{'rambler:related'} ) {
                if ( ref $item->{'rambler:related'} eq 'ARRAY' ) {
                    foreach my $relitem ( @{ $item->{'rambler:related'} } ) {
                        my $rel = $self->__parse_related ( $relitem );
                        push @$related, $rel		if ref $rel;
                    }
                } elsif ( ref $item->{'rambler:related'} eq 'HASH' ) {
                    my $rel = $self->__parse_related ( $item->{'rambler:related'} );
                    push @$related, $rel	if ref $rel;
                }
            }
            @videos = grep { exists $_->{type} && lc($_->{type}) eq 'video/x-flv' && $_->{src} =~ /\.flv$/i } @videos;
            my @inlined_images;
            for ( $description, $fulltext ) {
		next	unless $_;
                my $field = $_;
                while ( $field =~ /<img ([^>]+)>/sgi ) {
                    my $image = $self->__parse_params( $1 );
                    push @inlined_images, $image	if ref $image && exists $image->{src} && $image->{src};
                }
                while ( $field =~ /<a ([^>]+)>/sgi ) {
                    my $anchor = $self->__parse_params( $1 );
                    if ( $anchor->{href} && $anchor->{href} =~ /\.(jpe?g|gif|png)$/ ) {
                        push @inlined_images, { src => $anchor->{href} };
                    }
                }
            }
            if ( @inlined_images ) {
		my %images = map { $_->{src} => $_ } @images, @inlined_images;
		@images = values %images;
            }
            push @items, {
                'checksum'		=> md5_hex(encode_utf8(($title || '').($description || ''))),
                'ignore'		=> $item->{ignore}	|| 0,
                'title'		=> $title		|| '',
                'title_gui'		=> $item->{title_gui}	|| $title || '',
                'description'	=> $description		|| '',
                'description_gui'	=> $item->{description_gui} || $description || '',
                'desc_length'	=> length( $description || '' ),
                'link'		=> $link		|| '',
                'pubdate'		=> $pubdate				|| '',
                'fulltext'		=> $fulltext				|| '',
                'fulltext_gui'		=> $item->{fulltext_gui}		|| '',
                'fulltext_field'	=> $fulltext_field			|| '',
                'image'			=> @images ? $images[0] : undef,
                'images'		=> @images ? \@images : undef,
                'video'			=> @videos ? $videos[0] : undef,
                'videos'		=> @videos ? \@videos : undef,
                'categories'		=> $category,
                'video_url'		=> $video_url		|| '',
                'audio_url'		=> $audio_url		|| '',
                'author'		=> $author		|| '',
                'related'		=> $related,
                'content_type'		=> $content_type,
                'allow_fulltext'	=> $allow_fulltext,
            };
        }
    } else {
        warn ($@ || 'Something wrong while parsing content');
        return $self->is_success(0);
    }

    $self->{items} = \@items;
    return $self->is_success(1);
}


sub __check_rewrite {
    my ($self, %opts) = @_;
    my $item = $opts{item};
    return      unless ref $item;
    return      unless ref $opts{rools} eq 'ARRAY';
    my @rools = grep { $_->{action} eq 'rewrite' } @{ $opts{rools} };
    return      unless @rools;
    foreach my $rool ( @rools ) {
        my $field = $rool->{target};
        my $value = $rool->{condition};
        if ( $value eq 'CURRENT_DATETIME' ) {
            my $dt = DateTime->now( time_zone => "Europe/Moscow" );
            $value = $dt->ymd('-').'T'.$dt->hms.' MSK';
        }
        $item->{$field} = $value	if exists $item->{$field};
    }
}


sub __check_filter {
    my ($self, %opts) = @_;
    my $field = $opts{field};
    my $gui = $opts{gui};
    my $item = $opts{item};
    my $text = exists $opts{text} ? $opts{text} : undef;
    return	unless ref $item;
    return	unless exists $opts{text} || exists $item->{$field};
    return	unless ref $opts{rools} eq 'ARRAY';
    my @rools = grep { $_->{action} eq 'filter' && $_->{target} eq $field } @{ $opts{rools} };
    return	unless @rools;
    foreach my $rool ( @rools ) {
        if ( $rool->{command} eq 'cut' ) {
            my $condition = $rool->{condition};
            if ( $rool->{subcommand} eq 'off' ) {
                if ( $opts{gui} ) {
                    my $field_gui = $item->{$field."_gui"} || (exists $opts{text} ? $$text : $item->{$field});
                    $field_gui =~ s/($condition)/<b style="color:red">$1<\/b>/sgi;
                    $item->{$field."_gui"} = $field_gui;
                }
                if ( exists $opts{text} ) {
                    $$text =~ s/$condition//sgi;
                } else {
                    $item->{$field} =~ s/$condition//sgi;
                }
            } elsif ( $rool->{subcommand} eq 'from' ) {
                if ( $gui ) {
                    my $cut_text = '';
                    my $field_gui = $item->{$field."_gui"} || (exists $opts{text} ? $$text : $item->{$field});
                    my $pos = index $field_gui, $condition;
                    if ( $pos >= 0 ) {
                        $cut_text = substr $field_gui, $pos, -1;
                        $field_gui = substr $field_gui, 0, $pos;
                    }
#                    $field_gui =~ s/($condition)(.*)$/<b style="color:red">$1$2<\/b>/si;
                    $item->{$field."_gui"} = $field_gui.'<b style="color:red">'.$cut_text.'</b>';
                }
                if ( exists $opts{text} ) {
                    my $pos = index $$text, $condition;
                    if ( $pos >= 0 ) {
                        $$text = substr $$text, 0, $pos;
                    }
                } else {
                    my $pos = index $item->{$field}, $condition;
                    if ( $pos >= 0 ) {
                        $item->{$field} = substr $item->{$field}, 0, $pos;
                    }
                }
            } elsif ( $rool->{subcommand} eq 'till' ) {
                if ( $opts{gui} ) {
                    my $field_gui = $item->{$field."_gui"} || (exists $opts{text} ? $$text : $item->{$field});
                    $field_gui =~ s/^(.*?)($condition)/<b style="color:red">$1$2<\/b>/si;
                    $item->{$field."_gui"} = $field_gui;
                }
                if ( exists $opts{text} ) {
                    $$text =~ s/^(.*?)($condition)//si;
                } else {
                    $item->{$field} =~ s/^(.*?)($condition)//si;
                }
            } elsif ( $rool->{subcommand} eq 'untill' ) {
                if ( $opts{gui} ) {
                    my $field_gui = $item->{$field."_gui"} || (exists $opts{text} ? $$text : $item->{$field});
                    $field_gui =~ s/^(.*?)($condition)/<b style="color:red">$1<\/b>$2/si;
                    $item->{$field."_gui"} = $field_gui;
                }
                if ( exists $opts{text} ) {
                    $$text =~ s/^(.*?)($condition)/$2/si;
                } else {
                    $item->{$field} =~ s/^(.*?)($condition)/$2/si;
                }
            } elsif ( $rool->{subcommand} eq 'regex' ) {
                if ( $opts{gui} ) {
                    my $field_gui = $item->{$field."_gui"} || (exists $opts{text} ? $$text : $item->{$field});
                    if ( substr($condition,0,1) eq '^' ) {
                        my $cond = reverse($condition);
                        chop($cond);
                        $cond = reverse($cond);
                        $field_gui =~ s/^($cond)/<b style="color:red">$1<\/b>/si;
                    } elsif ( substr($condition,-1,1) eq '$' ) {
                        my $cond = $condition;
                        chop($cond);
                        $field_gui =~ s/($cond)$/<b style="color:red">$1<\/b>/si;
                    } else {
                        $field_gui =~ s/($condition)/<b style="color:red">$1<\/b>/sgi;
                    }
                    $item->{$field."_gui"} = $field_gui;
                }
                if ( exists $opts{text} ) {
                    $$text =~ s/$condition//sgi;
                } else {
                    $item->{$field} =~ s/$condition//sgi;
                }
            }
        } elsif ( $rool->{command} eq 'regex' ) {
            my $from = $rool->{condition}{from};
            my $to = $rool->{condition}{to};
            if ( exists $opts{text} ) {
                eval ("\$\$text =~ s/$from/$to/sgi");
            } else {
                eval ("\$item->{\$field} =~ s/$from/$to/sgi");
            }
        }
    }
}


sub __check_ignore {
    my ($self, %opts) = @_;
    my $item = $opts{item};
    return	unless ref $item;
    return	unless ref $opts{rools} eq 'ARRAY';
    my @rools = grep { $_->{action} eq 'ignore' } @{ $opts{rools} };
    return	unless @rools;
    foreach my $rool ( @rools ) {
	my $target = $rool->{target};
        if ( $rool->{command} =~ /^contain/ ) {
            $item->{ignore} = 1		if index (lc($item->{$target}), lc($rool->{condition})) >= 0;
        }
        if ( $rool->{command} eq '=' ) {
            $item->{ignore} = 1		if lc($item->{$target}) eq lc($rool->{condition});
        }
        if ( $rool->{command} eq 'regex' ) {
            my $regex = $rool->{condition};
            $item->{ignore} = 1		if $item->{$target} =~ /$regex/sgi;
        }
    }
}


sub __check_only {
    my ($self, %opts) = @_;
    my $item = $opts{item};
    return	unless ref $item;
    return	unless ref $opts{rools} eq 'ARRAY';
    my @rools = grep { $_->{action} eq 'only' } @{ $opts{rools} };
    return	unless @rools;
    foreach my $rool ( @rools ) {
	my $target = $rool->{target};
        if ( $rool->{command} =~ /^contain/ ) {
            $item->{ignore} = 1		unless index (lc($item->{$target}), lc($rool->{condition})) >= 0;
        }
        if ( $rool->{command} eq '=' ) {
            $item->{ignore} = 1		unless lc($item->{$target}) eq lc($rool->{condition});
        }
        if ( $rool->{command} eq 'regex' ) {
            my $regex = $rool->{condition};
            $item->{ignore} = 1		unless $item->{$target} =~ /$regex/sgi;
        }
    }
}


sub __feed_type {
    my ($self, $contref) = @_;

    my $type;
    if ( $$contref =~ /<rss([^>]*)>/ ) {
        $type = 'RSS';
    } elsif ( $$contref =~ /<feed\s+([^>]*)>/ ) {
        my $feed_params = $1;
        my $params = $self->__parse_params ($feed_params);
        if ( exists $params->{xmlns} && $params->{xmlns} =~ /purl.org\/atom/ ) {
            $type = 'ATOM';
        } elsif ( exists $params->{xmlns} && $params->{xmlns} =~ /www.w3.org\/2005\/Atom/ ) {
            $type = 'ATOM';
	}
    } elsif ( $$contref =~ /<rdf([^>]*)>/ ) {
        $type = 'RDF';
    }
    return $type;
}


sub __parse_content {
    my ($self, $contref) = @_;

    my $feed_type = $self->__feed_type($contref);
#    warn "FEED Type = [$feed_type]\n";
    return undef unless $feed_type;

    $$contref =~ s/>\s+</></sgi;
    $$contref =~ s/<items(.*?)>(.*?)<\/items([^>]*?)>//sgi;
    $$contref =~ s/<\/?br(.*?)>/\n/sgi;
    $$contref =~ s/<\/?nobr(.*?)>//sgi;
    #$$contref =~ s/<p>/\n\n/sgi;
    #$$contref =~ s/<p\s(.*?)>/\n\n/sgi;
    $$contref =~ s/<\/?strong\s(.*?)>//sgi;
    $$contref =~ s/<\/?s>//sgi;
    $$contref =~ s/<\/?i>//sgi;
    $$contref =~ s/<\/?b>//sgi;
    $$contref =~ s/<\/?strong>//sgi;
    #$$contref =~ s/<\/p>//sgi;
    #$$contref =~ s/<\/p\s(.*?)>//sgi;
    my @items;

    if ( $feed_type eq 'RSS' ) {
        while ( $$contref =~ /<item(.*?)>(.*?)<\/item([^>]*?)>/sgi ) {
            my $item_params = $1;
            my $item_body = $2;
#            warn "BODY: [$item_body]\n\n";
            my $params = $self->__parse_params ($item_params);
            my $item = $self->__parse_item_RSS ($item_body) || {};
            if ( ref $params eq 'HASH' ) {
                foreach my $key ( %$params ) {
                    if ( exists $item->{$key} && ref $item->{$key} eq 'ARRAY' ) {
                        push @{ $item->{$key} }, $params->{$key};
                    } elsif ( exists $item->{$key} ) {
                        my @arr = ( $item->{$key}, $params->{$key} );
                        $item->{$key} = \@arr;
                    } else {
                        $item->{$key} = $params->{$key};
                    }
                }
            }
            if ( ref $item eq 'HASH' && scalar keys %$item ) {
		if ( exists $item->{'feedburner:origlink'} ) {
                    $item->{link} = ref $item->{'feedburner:origlink'} eq 'ARRAY' ? $item->{'feedburner:origlink'}->[0] : $item->{'feedburner:origlink'};
		} elsif ( !exists $item->{link} ) {
                    foreach my $key ( qw( guid ) ) {
			if ( exists $item->{$key} ) {
                            $item->{link} = $item->{$key};
                            last;
                        }
                    }
                }
                push @items, $item;
            }
#            warn Dumper($item);
        }
    }
    if ( $feed_type eq 'RDF' ) {
        while ( $$contref =~ /<item(.*?)>(.*?)<\/item([^>]*?)>/sgi ) {
            my $item_params = $1;
            my $item_body = $2;
#            warn "BODY: [$item_body]\n\n";
            my $params = $self->__parse_params ($item_params);
            my $item = $self->__parse_item_RSS ($item_body) || {};
            if ( ref $params eq 'HASH' ) {
                foreach my $key ( %$params ) {
                    if ( exists $item->{$key} && ref $item->{$key} eq 'ARRAY' ) {
                        push @{ $item->{$key} }, $params->{$key};
                    } elsif ( exists $item->{$key} ) {
                        my @arr = ( $item->{$key}, $params->{$key} );
                        $item->{$key} = \@arr;
                    } else {
                        $item->{$key} = $params->{$key};
                    }
                }
            }
#            warn Dumper($item);
            if ( ref $item eq 'HASH' && scalar keys %$item ) {
                if ( !exists $item->{pubdate} ) {
                    foreach my $key ( 'prism:publicationdate', 'dc:date' ) {
			if ( exists $item->{$key} ) {
                            $item->{pubdate} = $item->{$key};
                            last;
                        }
                    }
                }
                push @items, $item;
            }
        }
    }
    if ( $feed_type eq 'ATOM' ) {
        while ( $$contref =~ /<entry(.*?)>(.*?)<\/entry([^>]*?)>/sgi ) {
            my $item_params = $1;
            my $item_body = $2;
            my $item = $self->__parse_item_ATOM ($item_body) || {};
#            warn Dumper($item);
            if ( ref $item eq 'HASH' && scalar keys %$item ) {
                if ( !exists $item->{pubdate} ) {
                    foreach my $key ( 'published', 'updated' ) {
			if ( exists $item->{$key} ) {
                            $item->{pubdate} = $item->{$key};
                            last;
                        }
                    }
                }
                push @items, $item;
            }
        }
    }
    return ( scalar @items ? \@items : undef );
}


sub __parse_params {
    my ($self, $params) = @_;
    return undef	unless $params;

    my %params;
    while ( $params =~ /([\w\:]+)(\s*?)=(\s*?)["'](.*?)["']/sgi ) {
        my $name = $1;
        my $value = $4;
        if ( $name && $value ) {
            $params{$name} = $value;
        }
    }
    return ( scalar(keys %params) ? \%params : undef );
}


sub __parse_item_RSS {
    my ($self, $item_body, $debug) = @_;
    return undef	unless $item_body;

    my %item;
#    my $embedded = $self->__item_cut_rss_embedded(\$item_body);
#    if ( ref $embedded ) {
#	%item = %$embedded;
#    }
#    my $content = $self->__item_cut_rss_description(\$item_body);
#    $item{description} = $content	if $content;
#    my $one_string_elements = $self->__item_cut_single_elements (\$item_body);
#    if ( ref $one_string_elements eq 'ARRAY' && @$one_string_elements ) {
#        foreach my $elem ( @$one_string_elements ) {
#            my ($elem_name) = keys %$elem	if ref $elem eq 'HASH';
#            if ( exists $item{$elem_name} && ref $item{$elem_name} eq 'ARRAY' ) {
#                push @{ $item{$elem_name} }, $elem->{$elem_name};
#            } elsif ( exists $item{$elem_name} ) {
#                $item{$elem_name} = [$item{$elem_name}, $elem->{$elem_name}];
#            } else {
#                $item{$elem_name} = $elem->{$elem_name};
#            }
#        }
#    }
    my $parsed = $self->__make_tree (\$item_body, $debug);
#    warn Dumper($parsed);
    if ( ref $parsed && exists $parsed->{1} && exists $parsed->{1}{children} && ref $parsed->{1}{children} eq 'ARRAY' ) {
        foreach my $tag ( @{ $parsed->{1}{children} } ) {
            if ( ref $tag->{children} eq 'ARRAY' && scalar @{ $tag->{children} } ) {
                my %params;
                foreach my $it ( @{ $tag->{children} } ) {
                    next	unless $it->{text};
                    if ( exists $params{$it->{type}} && ref $params{$it->{type}} eq 'ARRAY' ) {
                        push @{ $params{$it->{type}} }, $it->{text};
                    } elsif ( exists $params{$it->{type}} ) {
                        my @arr = ( $params{$it->{type}}, $it->{text} );
                        $params{$it->{type}} = \@arr;
                    } else {
                        $params{$it->{type}} = $it->{text};
                    }
                }
                if ( exists $item{$tag->{type}} && ref $item{$tag->{type}} eq 'ARRAY' ) {
                    push @{ $item{$tag->{type}} }, \%params;
                } elsif ( exists $item{$tag->{type}} ) {
                    my @arr = ( $item{$tag->{type}}, \%params );
                    $item{$tag->{type}} = \@arr;
                } else {
                    $item{$tag->{type}} = \%params;
                }
            } else {
                my $body = $tag->{text} || $tag->{params};
                if ( exists $item{$tag->{type}} && ref $item{$tag->{type}} eq 'ARRAY' ) {
                    push @{ $item{$tag->{type}} }, $body;
                } elsif ( exists $item{$tag->{type}} ) {
                    my @arr = ( $item{$tag->{type}}, $body );
                    $item{$tag->{type}} = \@arr;
                } else {
                    $item{$tag->{type}} = $body;
                }
            }
        }
    }
#    warn Dumper(\%item);
    return \%item;
}


sub __parse_item_ATOM {
    my ($self, $item_body, $debug) = @_;
    return undef	unless $item_body;

    my %item;
    my $embedded = $self->__item_cut_rss_embedded(\$item_body);
    if ( ref $embedded ) {
	%item = %$embedded;
    }
    if ( exists $item{summary} ) {
        $item{description} = delete $item{summary};
    } else {
        my $summary = $self->__item_cut_atom_summary(\$item_body);
        $item{description} = $summary	if $summary;
    }
    my $content = $self->__item_cut_atom_content(\$item_body);
    if ( $content && $item{description} ) {
        $item{fulltext} = $content;
    } elsif ( $content ) {
        $item{description} = $content;
    }
    my $one_string_elements = $self->__item_cut_single_elements (\$item_body);
#    warn Dumper ($one_string_elements);
    if ( ref $one_string_elements eq 'ARRAY' && @$one_string_elements ) {
        foreach my $elem ( @$one_string_elements ) {
            my ($elem_name) = keys %$elem	if ref $elem eq 'HASH';
            if ( exists $item{$elem_name} && ref $item{$elem_name} eq 'ARRAY' ) {
                push @{$item{$elem_name}}, $elem->{$elem_name};
            } elsif ( exists $item{$elem_name} ) {
                my @arr = ($item{$elem_name}, $elem->{$elem_name});
                $item{$elem_name} = \@arr;
            } else {
                $item{$elem_name} = $elem->{$elem_name};
            }
            if ( $elem->{$elem_name}{type} =~ /^image/ ) {
                my $enclosure = { url => $elem->{$elem_name}{href} || $elem->{$elem_name}{url}, type => $elem->{$elem_name}{type} };
                if ( exists $item{enclosure} && ref $item{enclosure} eq 'ARRAY' ) {
                    push @{ $item{enclosure} }, $enclosure;
                } elsif ( exists $item{enclosure} ) {
                    my @arr = ($item{enclosure}, $enclosure);
                    $item{enclosure} = \@arr;
                } else {
                    $item{enclosure} = $enclosure;
                }
            }
            if ( $elem->{$elem_name}{type} =~ /^video/ ) {
                my $enclosure = { url => $elem->{$elem_name}{href} || $elem->{$elem_name}{url}, type => $elem->{$elem_name}{type} };
                if ( exists $item{enclosure} && ref $item{enclosure} eq 'ARRAY' ) {
                    push @{ $item{enclosure} }, $enclosure;
                } elsif ( exists $item{enclosure} ) {
                    my @arr = ($item{enclosure}, $enclosure);
                    $item{enclosure} = \@arr;
                } else {
                    $item{enclosure} = $enclosure;
                }
            }
        }
    }
    my $parsed = $self->__make_tree (\$item_body, $debug);
#    warn Dumper($parsed);
    if ( ref $parsed && exists $parsed->{1} && exists $parsed->{1}{children} && ref $parsed->{1}{children} eq 'ARRAY' ) {
        foreach my $tag ( @{ $parsed->{1}{children} } ) {
            if ( ref $tag->{children} eq 'ARRAY' && scalar @{ $tag->{children} } ) {
                my %params;
                foreach my $it ( @{ $tag->{children} } ) {
                    next	unless $it->{text};
                    if ( exists $params{$it->{type}} && ref $params{$it->{type}} eq 'ARRAY' ) {
                        push @{ $params{$it->{type}} }, $it->{text};
                    } elsif ( exists $params{$it->{type}} ) {
                        my @arr = ( $params{$it->{type}}, $it->{text} );
                        $params{$it->{type}} = \@arr;
                    } else {
                        $params{$it->{type}} = $it->{text};
                    }
                }
		if ( exists $tag->{params} && ref $tag->{params} eq 'HASH' ) {
                    while ( my ($param, $value) = each %{ $tag->{params} } ) {
                        if ( exists $params{$param} && ref $params{$param} eq 'ARRAY' ) {
                            push @{ $params{$param} }, $value;
                        } elsif ( exists $params{$param} ) {
                            my @arr = ( $params{$param}, $value );
                            $params{$param} = \@arr;
                        } else {
                            $params{$param} = $value;
                        }
                    }
		}
                if ( exists $item{$tag->{type}} && ref $item{$tag->{type}} eq 'ARRAY' ) {
                    push @{ $item{$tag->{type}} }, \%params;
                } elsif ( exists $item{$tag->{type}} ) {
                    my @arr = ( $item{$tag->{type}}, \%params );
                    $item{$tag->{type}} = \@arr;
                } else {
                    $item{$tag->{type}} = \%params;
                }
            } else {
                my $body = $tag->{text} || $tag->{params};
                if ( exists $item{$tag->{type}} && ref $item{$tag->{type}} eq 'ARRAY' ) {
                    push @{ $item{$tag->{type}} }, $body;
                } elsif ( exists $item{$tag->{type}} ) {
                    my @arr = ( $item{$tag->{type}}, $body );
                    $item{$tag->{type}} = \@arr;
                } else {
                    $item{$tag->{type}} = $body;
                }
            }
        }
        my $pubDate = exists $item{issued} ? $item{issued} : exists $item{modified} ? $item{modified} : undef;
        $item{pubdate} = $pubDate		if $pubDate;
    }

#    warn Dumper(\%item);
    return \%item;
}


sub __make_tree {
    my ($self, $content, $debug) = @_;

    my @elems = split (//,$$content);
#    warn "CONTENT: [$$content]\n\n";
    my $id = 1;
    my $level = 0;
    my @stack;
    my %tree = (
                root => {
                        id      => $id++,
                        text    => '',
                        type    => 'root',
                        children=> [],
                        parent  => undef,
                        level   => $level,
                },
        );
    my %elem_hash = ( 1 => $tree{root} );
    my $current = $tree{root};

    while ( @elems ) {
        if ( $elems[0] eq '<' && $elems[1] =~ /[\!a-zA-Z]/ ) {
            my $tag = $self->__try_tag (\@elems);
            if ( ref $tag && $tag->{type} eq 'text' ) {
                $current->{text} .= $tag->{content};
                splice @elems, 0, $tag->{count};
#		warn "Tag: [".$current->{type}."]\n Text added:[".$tag->{content}."]\n";
            } elsif ( ref $tag && exists $tag->{closed} && $tag->{closed} ) {
                $tag->{id} = $id++;
                $tag->{parent} = $current;
                $tag->{level} = $level+1;
                $elem_hash{$tag->{id}} = $tag;
                push @{$current->{children}}, $tag;
                splice @elems, 0, $tag->{count};
#		warn "Tag: [".$current->{type}."]\n Text added:[".$tag->{content}."]\n";
            } elsif ( ref $tag ) {
                $tag->{id} = $id++;
                $tag->{children} = [];
                $tag->{parent} = $current;
                $tag->{level} = ++$level;
                $elem_hash{$tag->{id}} = $tag;
                push @{$current->{children}}, $tag;
                push @stack, $current;
                $current = $tag;
                splice @elems, 0, $tag->{count};
#		warn "Tag: [".$current->{type}."]\n Text added:[".$tag->{content}."]\n";
            } else {
#		warn "!!!! Error: RSS analyse. Job on item broken... !!!!\n" if $debug;
                return undef;
            }
        } elsif ( $elems[0] eq '<' && $elems[1] =~ /\// ) {
            my $tag = $self->__try_end (\@elems);
            if ( ref $tag && $tag->{type} eq 'text' ) {
                $current->{text} .= $tag->{content};
                $current->{count} += $tag->{count};
                splice @elems, 0, $tag->{count};
            } elsif ( ref $tag ) {
                if ( $current->{type} ne $tag->{type} ) {
#                    warn "!!!!Wrong tag type for closing. It's [$tag->{type}]. It must be [$current->{type}]!!!!\n" if $debug;
                    return undef;
                } else {
                    $current = pop @stack;
                    $level = $current->{level};
#                    warn "Text place: [".substr($current->{text}, 0, 20)."]\n"         if exists $current->{text};
#                    warn "Close type: /$tag->{type}. Level: $level. Stack depth: ".scalar(@stack)."\n";
                }
                splice @elems, 0, $tag->{count};
            } else {
#                warn "!!!! Error: HTML analyse. Job broken... !!!!\n" if $debug;
                return undef;
            }
        } else {
            $current->{text} .= shift @elems;
            $current->{count}++;
        }
    }
    return (\%elem_hash);
}



sub __try_tag {
    my ($self, $content) = @_;

    my $i = 1;
    my %tag;
    my $tag = $content->[0];
    if ( $content->[$i] eq '!' ) {
#        warn "What? Think it's CDATA\n";
        my $try_cdata = join '', @$content[1..8];
        if ( $try_cdata eq '![CDATA[' ) {
            $tag = '';
            $i = 9;
            while ( !($content->[$i-1] eq '>' && $content->[$i-2] eq ']' && $content->[$i-3] eq ']') && $i < scalar @$content ) {
                $tag .= $content->[$i];
                $i++;
            }
            chop $tag; chop $tag; chop $tag;
        }
#        warn "CDATA Found: [$tag]";
        return {
            type        => 'text',
            content     => $tag,
            count       => $i,
        };
    }
    while ( $content->[$i] ne '<' && $content->[$i] ne '>' && $i < scalar @$content ) {
        $tag .= $content->[$i];
        $i++;
    }
    if ( $content->[$i] eq '<' || $i >= scalar @$content ) {
        return {
            type        => 'text',
            content     => $tag,
            count       => $i,
        };
    } else {
        if ( $tag =~ /^<([\w:-]+)\s*(.*)/si ) {
            my $elem_name = $1;
            my $elem_body = $2;
            unless ( $self->__is_valid_tag ($elem_name) ) {
                return {
                    type        => 'text',
                    content     => $tag,
                    count       => $i,
                };
            } else {
                my $params = $self->__parse_params ($elem_body)	if $elem_body;
                if ( $content->[$i] eq '>' && $content->[$i-1] eq '/' ) {
                    $tag{closed} = 1;
                }
                $tag{type} = lc($elem_name);
                $tag{count} = $i+1;
                $tag{params} = $params				if ref $params;
                return \%tag;
            }
        } else {
            return {
                type        => 'text',
                content     => $tag,
                count       => $i,
            };
        }
    }
}


sub __try_end {
    my ($self, $content) = @_;

    my $i = 2;
    my %tag;
    my $tag = $content->[0].$content->[1];
    while ( $content->[$i] ne '<' && $content->[$i] ne '>' && $i < scalar @$content ) {
        $tag .= $content->[$i];
        $i++;
    }
    if ( $content->[$i] eq '<' || $i >= scalar @$content ) {
        return {
            type        => 'text',
            content     => $tag,
            count       => $i,
        };
    } else {
        if ( $tag =~ /^<\/([\w:-]+)/i ) {
            my $elem_name = $1;
            unless ( $self->__is_valid_tag ($elem_name) ) {
                return {
                    type    => 'text',
                    content => $tag,
                    count   => $i,
                };
            } else {
                $tag{type} = lc($elem_name);
                $tag{count} = $i+1;
                return \%tag;
            }
        } else {
            return {
                type    => 'text',
                content => $tag,
                count   => $i,
            };
        }
    }
}


sub __is_valid_tag {
    my ($self, $tag) = @_;
    foreach my $invtag ( @INVALID_TAGS ) {
        return 0	if lc($invtag) eq lc($tag);
    }
    return 1;
}


sub __item_cut_atom_content {
    my ($self, $item_body) = @_;

    my %elem;
    if ( $$item_body =~ /<content([^>]*?)>(.*?)<\/content([^>]*)>/si ) {
        my $content_params = $1;
        my $content_body = $2;
        my $params = $self->__parse_params ($content_params)	if $content_params;
        $$item_body =~ s/<content([^>]*?)>(.*?)<\/content([^>]*)>//si;
        return $content_body;
    }
}


sub __item_cut_atom_summary {
    my ($self, $item_body) = @_;

    my %elem;
    if ( $$item_body =~ /<summary([^>]*)>(.*?)<\/summary([^>]*)>/si ) {
        my $content_params = $1;
        my $content_body = $2;
        my $params = $self->__parse_params ($content_params)	if $content_params;
        $$item_body =~ s/<summary([^>]*)>(.*?)<\/summary([^>]*)>//si;
        return $content_body;
    }
}


sub __item_cut_rss_description {
    my ($self, $item_body) = @_;

    my %elem;
    if ( $$item_body =~ /<description([^>]*?)>(.*?)<\/description([^>]*)>/si ) {
        my $content_params = $1;
        my $content_body = $2;
        my $params = $self->__parse_params ($content_params)	if $content_params;
        $$item_body =~ s/<description([^>]*?)>(.*?)<\/description([^>]*)>//si;
        return $content_body;
    }
}


sub __item_cut_rss_embedded {
    my ($self, $item_body) = @_;

    my %elem;
    while ( $$item_body =~ /<([^>]*?)>\s*<!\[CDATA\[(.*?)\]\]>\s*<\/([^>]*)>/sgi ) {
        my $tag = $3;
        my $content_body = $2;
        my $content_params = $1;
	if ( $content_params =~ /([\w:-]+)\s+(.*)/ ) {
		$tag = 1;
		$content_params = $2;
	}
        my $params = $self->__parse_params ($content_params)	if $content_params;
        $elem{$tag} = $content_body;
        $$item_body =~ s/<$tag([^>]*?)>(.*?)<\/$tag([^>]*)>//si;
    }
    return scalar keys %elem ? \%elem : undef;
}



sub __item_cut_single_elements {
    my ($self, $item_body) = @_;

    my @elems;
    while ( $$item_body =~ /<([\w\:\-]+)\s*([^>]*?)\/>/sgi ) {
        my $elem_name = $1;
        my $elem_body = $2;
        my $params = $self->__parse_params ($elem_body)		if $elem_body;
        if ( $elem_name && ref $params ) {
            push @elems, { $elem_name => $params }
        }
    }
    $$item_body =~ s/<(\w+)\s*([^>]*?)\/>//sgi;
    return ( @elems ? \@elems : undef );
}


sub __field_prepare {
    my ($self, $text) = @_;
    return	unless $text;

    $text =~ s/^[\n\r\ \t]+//;
    $text =~ s/[\n\r\ \t]+$//;
    $self->__cdata (\$text);
    $self->__extchar (\$text);
#    $text = HTML::Entities::decode_entities($text);

    # Remove linebreaks inside incorrectly breaked paragraphs
    if (length($text) > 100) {
        my $pcount = 0;
        while ($text =~ /<p>(.+?)(?=<\/?p>|$)/sgi) {
            my $p = $1;
            if (length $p > 50) {
                my ($dcount, $ndcount) = (0,0);
                # Count sentences normally ended vs breaked
                $dcount++ while $p =~ /(\.|\?|\!)['"]?\s*[\r\n]+/g;
                $ndcount++ while $p =~ /([^\.\?\!\s])\s*[\r\n]+/g;
                # Found broken paragraph
                last if $ndcount > $dcount and ++$pcount > 1;
            }
        }
        if ($pcount > 0) {
            $text =~ s/[\n\r]+/ /sg;
        }
    }
    $text =~ s/<br[^>]*>/\n/sgi;
    $text =~ s/<p\s*>/\n\n/sgi;
    $text =~ s/<\/p\s*>//sgi;
#    $text = Contenido::Parser::Util::strip_html($text);
#    $text = Contenido::Parser::Util::text_cleanup($text);
    return $text;
}


sub __extchar {
    my ($self, $textref) = @_;

    for ( $$textref ) {
        s/&#38;/\&/sg;
        s/\&amp;/\&/sgi;
        s/\&amp;/\&/sgi;
        s/\&lt;/</sgi;
        s/\&gt;/>/sgi;
        s/\&quot;/"/sgi;
        s/\&#171;/«/sg;
        s/\&#187;/»/sg;
        s/\&#163;/£/sg;
        s/\&#150;/&ndash;/sg;
        s/\&#151;/&mdash;/sg;
        s/\&#132;/"/sg;
        s/\&#147;/"/sg;
        s/\&#148;/"/sg;
        s/\&#180;/'/sg;
        s/\&#133;/\.\.\./sg;
        s/\&#13;/\n/sg;
        s/\&#34;/"/sg;
    }
#    $$textref =~ s/&#(\d+);/{'&#'.__normalise($1).';'}/eg;
#    $$textref =~ s/&laquo;/«/sgi;
#    $$textref =~ s/&raquo;/»/sgi;
#    $$textref =~ s/&copy;/©/sgi;
#    $$textref =~ s/&ndash;/–/sgi;
#    $$textref =~ s/&mdash;/—/sgi;
#    $$textref =~ s/&deg;/º/sgi;
#    $$textref =~ s/&nbsp;/\x20/sgi;
}

sub __normalise {
    my $chr = shift;
    return sprintf("%04d",$chr);
}

sub __cdata {
    my ($self, $textref) = @_;
    if ( $$textref =~ /^<\!\[CDATA\[/ ) {
        $$textref =~ s/<\!\[CDATA\[//sgi;
        $$textref =~ s/\]\]>//sgi;
    }
}


sub __parse_rools {
    my ($self, $rools) = @_;
    return      unless $rools;
    $rools =~ s/\r//sgi;
    my @rools = split /\n/, $rools;
    return      unless @rools;

    my @parsed;
    foreach my $rool ( @rools ) {
        my %pr;
        next    if $rool =~ /^#/;
        $rool =~ s/[\x20\t]+$//;
        $rool =~ s/^[\x20\t]+//;
        if ( $rool =~ /^([\w']+)\s+(.*)$/ || $rool =~ /^(\w+)(.*)$/ ) {
            $pr{action} = lc($1);
            my $params = $2;
            if ( $pr{action} eq 'use' && $params =~ /^(current)\s+(date)$/ ) {
                $pr{action} = 'rewrite';
                $pr{target} = 'pubdate';
                $pr{command} = 'set';
                $pr{condition} = 'CURRENT_DATETIME';
                push @parsed, \%pr;
            } elsif ( $params =~ /^(\w+)\s+(.*)$/ ) {
                $pr{target} = lc($1);
                $params = $2;
                if ( $params =~ /^([\w=]+)\s+(.*)$/ ) {
                    $pr{command} = lc($1);
                    $params = $2;
                    if ( $pr{action} eq 'filter' && $pr{command} eq 'cut' && $params =~ /^(\w+)\s+(.*)$/ ) {
                        $pr{subcommand} = lc($1); $params = $2;
                        next    unless $pr{subcommand} =~ /^(untill|till|from|off|regex)$/;
                        $params =~ s|([*+?/\\\|])|\\$1|sg		unless $pr{subcommand} eq 'regex';
                        $pr{condition} = $params;
                    } elsif ( $pr{action} eq 'filter' && $pr{command} eq 'regex' && substr($params,0,1) eq substr($params,-1,1) && substr($params,0,1) =~ /([\/\#\|])/ ) {
                        my $delim = $1;
                        $params = substr($params,1,length($params)-2);
                        my @params = split(//,$params);
                        my ($from, $to) = ('','');
                        my $prev = '';
                        while ( @params ) {
                            my $ch = shift @params;
                            if ( $ch eq $delim && $prev ne '\\' ) {
                                last;
                            } else {
                                $prev = $ch;
                                $from .= $ch;
                            }
                        }
                        $to = join ('', @params);
                        $pr{condition} = { from => $from, to => $to };
                    } elsif ( ($pr{action} eq 'ignore' || $pr{action} eq 'only') && $pr{command} =~ /^(regex|=|contain|contains)$/ ) {
                        $params =~ s|([*+?/\\\|])|\\$1|sg		unless $pr{subcommand} eq 'regex';
                        $pr{condition} = $params;
                    } else {
                        next;
                    }
                    push @parsed, \%pr;
                }
            }
        }
    }
    return ( scalar @parsed ? \@parsed : undef );
}


sub __parse_related {
    my ($self, $related) = @_;
    return      unless ref $related eq 'HASH';
    return      unless exists $related->{url} && $related->{url} =~ /^http:\/\//i;
    return      unless exists $related->{rel} && $related->{rel} =~ /(news|discussion|teaser)/;
    my $result = { url => $related->{url}, rel => $related->{rel} };
    $result->{type} = $related->{type}						if exists $related->{type};
    $result->{title} = $self->__field_prepare($related->{title})		if exists $related->{title} && $related->{title};

    $result->{author} = $self->__field_prepare($related->{author})		if exists $related->{author} && $related->{author};
    $result->{description} = $self->__field_prepare($related->{description})	if exists $related->{description} && $related->{description};

    if ( exists $related->{pubdate} && $related->{pubdate} ) {
        my $pubdate = Class::Date::localdate(Date::Parse::str2time($related->{pubdate}));
        $result->{pubdate} = $pubdate		if $pubdate;
    }
    if ( $related->{rel} =~ /(news|teaser)/ ) {
        return undef		unless $result->{title} && $result->{pubdate};
    } else {
        $result->{title} ||= 'Обсудить';
    }

    if ( exists $related->{image} && $related->{image} ) {
        if ( ref $related->{image} eq 'HASH' && (exists $related->{image}{url} || exists $related->{image}{href}) ) {
            my $img = rchannel::Image->new( { src => ($related->{image}{url} || $related->{image}{href}) } );
            $result->{image} = $img		if ref $img;
        } elsif ( !ref $related->{image} ) {
            my $img = rchannel::Image->new( { src => $related->{image} } );
            $result->{image} = $img		if ref $img;
        }
    }

    return $result;
}


sub __parse_date {
    my $self = shift;
    my $str = shift;

    if ($str=~/(\d{2})(\d{2})(\d{4})T(\d{2})(\d{2})(\d{2})/){
	return parsedate ("$3-$2-$1 $4:$5:$6");
    } elsif ($str=~/(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2}:\d{2})/){
	return parsedate ("$1 $2");
    } else {
	return parsedate($str);
    }
}



# TODO IMAGES:
# enclosure
# media:content
# media:thumbnail
# image
# img

# FOUDNED:
# author
# category
# comments
# content
# content:encoded
# content:format
# dc:creator
# dc:date
# dc:rights
# dc:subject
# description
# enclosure
# feedburner:awareness
# feedburner:origLink
# full-text
# fulltext
# guid
# guide
# habrahabr:ballsCount
# habrahabr:commentsCount
# id
# image
# img
# link
# media:content
# media:thumbnail
# pdalink
# pubDate
# pubdate
# pubid
# published
# rambler:full-text
# rambler:fulltext
# region
# section
# sections
# source
# sport
# summary
# text
# title
# updated
# wfw:commentRSS
# wfw:commentRss
# wmj:fulltext
# yandex:full-text

1;
