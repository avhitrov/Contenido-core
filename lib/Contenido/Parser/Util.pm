package Contenido::Parser::Util;

use strict;

sub clean_invalid_chars { # http://www.w3.org/TR/REC-xml/#NT-Char
    my ($cont_ref) = shift;
    $$cont_ref =~ s/[\x0-\x8|\xB\xC|\xE-\x1F|\x{d800}-\x{dfff}|\x{fffe}\x{ffff}]//sgi;
}

sub text_cleanup {
    my $text = shift;
    my $delim = shift || "\n\n";

    $text =~ s/^\s+//; $text =~ s/\s+$//;
    $text =~ s/\r\n/\n/g;

    my @paragfs = $text =~ /\n{2,}/ ? # is paragraphs detected?
	split /\n{2,}/, $text :       # - by paragraphs only
	split /\n+/, $text;           # - by any newline

    for (@paragfs) {
        s/^\s+//mg; s/\s+$//mg; # trim whitespace
        s/[[:blank:]]+/ /g;     # collapse spaces
    }

    return join "\n\n", grep length $_, @paragfs;
}

sub strip_html {
    my $text = shift;

    if ( ref $text ) {
        $$text =~  s/<\/?[^>]+>//sgi;
    } else {
        $text =~   s/<\/?[^>]+>//sgi;
        return $text;
    }
}

1;
