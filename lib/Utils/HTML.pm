package Utils::HTML;

# ----------------------------------------------------------------------------
# Здесь хранятся процедуры для удобства верстки
# ----------------------------------------------------------------------------

use strict;
use vars qw($VERSION @ISA @EXPORT $state $HTML $request);
use HTML::TokeParser;
use Contenido::Globals;
use utf8;

use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(   
                &help 
                &spacer 
                &tlontl 
                &word_ending 
                &math_percent 
                &wrap_long_words 
                &break_word 
                &error_catch 
                &top100 
                &top100js
                &top100old 
                &color 
                &server_name 
                &text_trim 
                &limit_words 
                &email 
                &url 
                &banner 
                &banner2
                &js_escape
                &html_escape
                &html_unescape
                &cgiescape
                &url_escape
                &url_unescape
		&format_date
            );

$VERSION = '0.1';

# Всякие удобные функции, которые будут импортированы в HTML::Mason::Commands
# Набор уродиков - для совместимости

sub format_date {
	my ($date, $format) = @_;
	my ($year, $month, $day, $hour, $min, $sec, $msec) = split(/[T\-\.\:\s]+/, $date);
	$year = substr($year, -2) if $format =~ /(^[yY]{2}$|[^yY][yY]{2}$|^[yY]{2}[^yY])/;
	my %formats = (
					d		=> '%3$d',
					D		=> '%3$d',
					h		=> '%4$d',
					H		=> '%4$d',
					m		=> '%5$d',
					M		=> '%2$d',
					dd		=> '%3$02d',
					DD		=> '%3$02d',
					mm		=> '%5$02d',
					MM		=> '%2$02d',
					hh		=> '%4$02d',
					HH		=> '%4$02d',
					ss		=> '%6$02d',
					SS		=> '%6$02d',
					yyyy	=> '%1$04d',
					YYYY	=> '%1$04d',
					);
	$format =~ s/([yYmMdDhHsS]+)/$formats{$1}/gi;
	my $result = sprintf($format, $year, $month, $day, $hour, $min, $sec, $msec);
	return $result;
}

sub spacer {
	my %opts = @_;
	my $w = $opts{w} || 1;
	my $h = $opts{h} || 1;

	return '<div style="width:'.$w.'px; height:'.$h.'px"><!-- --></div>';
}


sub tlontl {
	my %opts		= @_;
	my $src_link	= $opts{link};
	my $param		= $opts{param};
	my $object		= $opts{object};
	my $absolute	= $opts{absolute};
	my $skip_args	= $opts{skip_args};

	my $request_uri = $absolute ? 'http://'.$ENV{SERVER_NAME} : '';
	$request_uri .= $skip_args ? $ENV{SCRIPT_NAME} : $ENV{REQUEST_URI};

	my $link = $src_link;
	if ($skip_args) {
		$link =~ s/\?.*$//;
	}

	if ($link eq '') {
		return $object;
	} elsif($request_uri eq $link || $request_uri eq $link.'index.html') {
		return $object;
	} else {
		return '<a href="'.$src_link.'"'.($param ? ' '.$param : '' ).'>'.$object.'</a>';
	}
}


sub word_ending {
	my %opts = @_;

	my $amount	= $opts{'amount'}; 	# количество
	my $one		= $opts{'one'};		# негрятенок
	my $two		= $opts{'two'};		# негрятенка
	my $ten		= $opts{'ten'};		# негрятят

	my $word				= $ten;
	my $last_num			= $amount;
	my $next_to_last_num	= 0;

	return $word unless defined $amount && $amount =~ /^\d+$/;

	if (length($last_num) >= 2) {
		$last_num =~ s/.*(\d)(\d)$/$2/;
		$next_to_last_num = $1;
	}

	# 10 <= ? < 20
	if ($next_to_last_num == 1) {
		$word = $ten;

	# 1,21,31,...,n1
	} elsif ($last_num == 1) {
		$word = $one;

	# 5,6,7,8,9,10,25,26,.....,n5,n6,n7,n8,n9,n0
	} elsif ($last_num > 4 || $last_num == 0) {
		$word = $ten;

	# other
	} else {
		$word = $two;
	}

	return $word;
}

# Нужен для постоения таблиц, ширина которых задается посредством конфигурационных файлов
# <% math_percent('100%+200%-25%/2') %> результат: 288%
# <% math_percent($project_conf->{left}+$project_conf->{center}) %>
sub math_percent {
    my $exp = shift;
    $exp =~ s/\%//g;
    $exp = eval($exp);
    $exp = sprintf("%.0f", $exp);
    return $exp.'%';
}

# Вставка тега wbr в длинные слова
# Получает ссылку на строку (будьте внимательны - оригинальная строка будет изменена)
sub wrap_long_words {
    my $string = shift;
    my %opts = @_;

    unless ($string && ref($string) eq 'SCALAR' && length($$string)) {
        return;
    }

    my $wordlength = $opts{'wordlength'} || 40;

    if (length($$string) <= $opts{'wordlength'}) {
        return $$string;
    }

    my $newstring = '';

    my $p = HTML::TokeParser->new($string);
    $p->{textify} = {};

    while (my $token = $p->get_token()) {
        my $type = $token->[0];
        if ( $type eq 'S' ) {
            $newstring .= $token->[4];
        } elsif ( $type eq 'E' ) {
            $newstring .= $token->[2];
        } elsif ( $type eq 'T') {
            $token->[1] =~ s/\S{$wordlength,}/break_word($&,$wordlength)/eg;
            $newstring .= $token->[1];
        }
    }
    $$string = $newstring;
    return $$string;
}

# Вставка тега wbr в одно длинное слово
sub break_word {
    my ($word, $wordlength) = @_;
    $word =~ s/((?:[^&\s]|(&\#?\w{1,7};)){$wordlength})\B/$1<wbr \/>/g;
    return $word;
}

# Отлов ошибок
sub error_catch {
    unless ( $state->development ) {
        return <<HTML;
<script type="text/javascript">if(escape('а')!='%u0430') { var cs_i2=new Image; cs_i2.src='http://err.rambler.ru/cs/'; }function globalCsChErr(a,b,c) {var i=new Image; i.src='http://err.rambler.ru/js/?'+escape(a)+','+escape(b)+','+escape(c)+'/'; return true;}window.onerror=globalCsChErr;</script>
HTML
    } else {
        return '<!--// sub &error_catch(); //-->';
    }
}

# Rambler's Top100 
sub top100 {
    my $top100id = shift || $HTML->{top100};
    unless ( $state->development ) {
        return '<!-- top100 --><script type="text/javascript">new Image().src = "http://counter.rambler.ru/top100.scn?'.$top100id.'&amp;rn="+Math.random()+"&amp;rf="+escape(document.referrer);</script><noscript><a href="http://top100.rambler.ru/"><img src="http://counter.rambler.ru/top100.cnt?'.$top100id.'" alt="Rambler\'s Top100 Service" width="1" height="1" border="0"></a></noscript><!-- // top100 -->';
    } else {
        return '<!--// sub &top100('.$top100id.'); (с использованием new Image().src) //-->';
    }
}

sub top100old {
    unless ( $state->development ) {
        return '<!-- top100 --><a href="http://top100.rambler.ru/"><img src="http://counter.rambler.ru/top100.cnt?'.$HTML->{top100}.'" alt="Rambler\'s Top100 Service" width="1" height="1" border="0"></a><!-- // top100 -->';
    } else {
        return '<!--// sub &top100old('.$HTML->{top100}.'); (без использования js) //-->';
    }
}

sub top100js {
    unless ( $state->development ) {
        return '<!-- begin of Top100 code --><script type="text/javascript" src="http://counter.rambler.ru/top100.jcn?'.$HTML->{top100}.'"></script><noscript><img src="http://counter.rambler.ru/top100.cnt?'.$HTML->{top100}.'" alt="Rambler\'s Top100 Service" width="1" height="1" border="0" /></noscript><!-- end of Top100 code -->';
    } else {
        return '<!--// sub &top100js('.$HTML->{top100}.'); (с использованием js) //-->';
    }
}

# Раскрас строк зеброй
sub color { return ++$request->{HTML_color_count} % 2 ? $_[0] : $_[1] }

# универсальная замена $ENV{'SERVER_NAME'}
sub server_name { return $ENV{'HTTP_X_HOST'} || $state->httpd_server() }

# обрезает текст до нужной длины, предварительно удаляя html-теги (бывшая /inc/text_trim.msn)
sub text_trim {
    my %opts = @_;
    my $text = $opts{'text'};
    my $length = $opts{'length'} || 200;
    my $ellipsis = $opts{'ellipsis'} || '&hellip;';
    $text =~ s/<[^>]*>//g;
    if (length($text) > $length) {
        $text = substr($text, 0, $length);
        $text =~ s/\s+\S*$//;
        $text .= $ellipsis;
    }
    return $text;
}
# limit_words('text', { min_words => 70, max_words => 100, ending => '...' })
sub limit_words {
    my $text = shift; my ($t1, $t2) = ();
    my %args = ref($_[0]) ? %{ $_[0] } : @_;

    my @words = split ' ', $text; $args{max_words} ||= 50; $args{min_words} ||= 10;

    return $text if $#words < $args{max_words};
    $t1 = $t2 = join ' ', @words[0 .. $args{max_words}-1];

#   magic !
    s/^(.+\w{3,}[»")]?[.!?]+)\s*[А-ЯA-Z«"].+?$/$1/s and (()=/(\s+)/g)>$args{min_words} and return$_ for $t1;

    $t2 =~ s/[.,:;!?\s—-]+$//;
    $t2.($args{ending} || '');
}

sub email {
    my $email = shift;
    $email =~ s/[<>'"\\]*//g;
    if ($email =~ /\@/) {
        return '<a href="mailto:'.$email.'">'.$email.'</a>';
    } else {
        return $email;
    }
}

sub url {
    my $url = shift;
    $url =~ s/[<>'"\\]*//g;
    $url =~ s/^\s+//;
    $url =~ s/\/$//;
    return unless $url;
    $url =~ s/^((https?|ftp):\/\/)//;
    my $protocol = $1;
    unless ($protocol) {
        $protocol = 'http://';
    }
    return '<a href="'.$protocol.$url.'" target="_blank">'.$url.'</a>';
}

sub banner {
    my %opts = @_;
    my $id = $opts{'id'};
    return '<!-- &banner(id=>'.$id.'); --><!--#include virtual="/ibanOsurg?rip=$remote_addr&place_id='.$id.'&sid=2" --><!-- // banner -->';
}

sub banner2 {
    my %opts = @_;
    my $id = $opts{'id'};
    my $div_class = $opts{'div_class'};
    return '<!-- &banner2(id=>'.$id.'); --><!--#include virtual="/iban1?rip=$remote_addr&pg='.$id.'&ifr=5&wxh=&divclass='.$div_class.'"--><!-- // banner2 -->';
}

sub help() {
    use Data::Dumper;
    my $opt = shift;
    my $data = '';

    if ($opt) {
    
    } else {
      foreach (@EXPORT){
           $data .= '<li>'.$_; 
      }
    }
    return $data;
}

sub js_escape {
    my $string = shift;
    $string =~ s/([\"\'\\])/\\$1/g;
    $string =~ s/\r?\n/\\n/gs;
    $string =~ s/\r//gs;
    return $string;
}

sub html_escape {
    my $string = shift;
    $string =~ s/&/&amp;/g;
    $string =~ s/"/&quot;/g;
	$string =~ s/>/&gt;/g;
	$string =~ s/</&lt;/g;
    return $string;
}

sub html_unescape {
    my $string = shift;
    $string =~ s/&amp;/&/g;
    $string =~ s/&quot;/"/g;
	$string =~ s/&gt;/>/g;
	$string =~ s/&lt;/</g;
    return $string;
}

sub rss_unescape {
    my $string = shift;
    my %opts = @_;

    if ( ref($string) eq 'SCALAR' ) {
	for ( $$string ) {
		s/&raquo;/"/gi;
		s/&laquo;/"/gi;
		s/&rdquo;/"/gi;
		s/&ldquo;/"/gi;
		s/&rsquo;/\'/gi;
		s/&lsquo;/\'/gi;
		s/&nbsp;/\ /gi;
		s/&quot;/"/gi;
		s/&copy;/(c)/gi;
		s/&reg;/(r)/gi;
	}
    } elsif ( length($string) ) {
	for ( $string ) {
		s/&raquo;/"/gi;
		s/&laquo;/"/gi;
		s/&rdquo;/"/gi;
		s/&ldquo;/"/gi;
		s/&rsquo;/\'/gi;
		s/&lsquo;/\'/gi;
		s/&nbsp;/\ /gi;
		s/&quot;/"/gi;
		s/&copy;/(c)/gi;
		s/&reg;/(r)/gi;
	}
	return $string;
    }
}

sub cgiescape {
        my $string = shift;
        $string =~ s/([^a-zA-Z_0-9.-])/sprintf "\%\%\%02x",ord($1)/ge;
        return $string;
}

sub url_escape {
	return URI::Escape::uri_escape(shift);
}

sub url_unescape {
	return URI::Escape::uri_unescape(shift);
}
    
1;