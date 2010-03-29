require 'subs_local.pl';

sub abort404 {
        use vars qw($m);
        $m->clear_buffer();
        $m->abort(404);
};

sub abort403 {
        use vars qw($m);
        $m->clear_buffer();
        $m->abort(403);
};

sub abort503 {
        use vars qw($m);
        $m->clear_buffer();
        $m->abort(503);
};


sub spacer {
        my %opts = @_;
        my $w = $opts{w};
        my $h = $opts{h};

        if (!$w && !$h) {
                return '<spacer type="block" width="1" height="1" border="0">';
        } else {
                return  '<div style="'.($w ? 'width:'.$w.'px;' : '').($h ? 'height:'.$h.'px;' : '').'">'.
                        '<spacer type="block" width="'.($w ? $w : 1).'" height="'.($h ? $h : 1).'" border="0"></div>';
        }
}


sub tlontl {
        my %opts = @_;
        my $link = $opts{link};
        my $param = $opts{param};
        my $object = $opts{object};

        if ($link eq '') {
                return $object;
        } elsif($ENV{REQUEST_URI} eq $link || $ENV{REQUEST_URI} eq $link.'index.html') {
                return $object;
        } else {
                return '<a href="'.$link.'"'.($param ? ' '.$param : '' ).'>'.$object.'</a>';
        }
}

sub easy_get {
	my %opts=@_;
	&abort404() unless ($opts{$id});
	&abort404() unless ($opts{$id}=~/^\d+$/);
	if ($opts{type} eq 'document') {
		my $doc=$keeper->get_document_by_id($opts{id},class=>$opts{class});
		&abort404() unless ($doc);
		return $doc;
	} elsif ($opts{type} eq 'section') {
		my $doc=$keeper->get_section_by_id($opts{id},class=>$opts{class});
		&abort404() unless ($doc);
		return $doc;
	} else {
		&abort404();
	}
}

1;
