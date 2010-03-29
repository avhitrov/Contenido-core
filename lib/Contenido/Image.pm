package Contenido::Image;

# ----------------------------------------------------------------------------
#
# Класс для завертывания картинки в обьект
#
# ----------------------------------------------------------------------------

use Contenido::Globals;
use strict;

$Contenido::Image::VERSION = '0.5';
$Contenido::Image::DEBUG = 0;

sub new {
    my $class = shift; $class = ref($class) || $class;
    my %args  = ref $_[0] ? %{$_[0]} : @_;

    my $valid_dump;
    $valid_dump = 1 if ( exists($args{img}) and (ref($args{img}) eq 'HASH') and $args{img}->{filename} );
    $log->warning("$class->new(): параметр img не определен") if $Contenido::Image::DEBUG and !$valid_dump;
    return unless $valid_dump;

    return bless {
        key     => $args{key}                       || undef,
        attr    => $args{attr}                      || '',
        name    => $args{img}->{filename}           || '',
        w       => $args{img}->{width}              || undef,
        h       => $args{img}->{height}             || undef,
        alt     => $args{img}->{alt}                || '',
        title   => $args{img}->{title}              || undef,
        source  => $args{img}->{source}             || undef,
        mname   => $args{img}->{mini}->{filename}   || '',
        mw      => $args{img}->{mini}->{width}      || undef,
        mh      => $args{img}->{mini}->{height}     || undef,
        mini    => $args{img}->{mini}               || undef,
        copyright => $args{img}->{copyright}          || undef,
    }, $class;
}

sub get_mini {
    my $self = shift;
    my $size = shift;
    return $size ? $self->{mini}{$size} : $self->{mini};
}

# ----------------------------------------------------------------------------
# Вывод картинки в виде HTML-тега <img>...
# Пример:
# print $pic and $pic->as_html(path => '/imgs/', mini => 1);
# defaults:
#   path => '/images/',
# ----------------------------------------------------------------------------
sub as_html {
    my $self = shift;
    my %args = ref $_[0] ? %{$_[0]} : @_;

    $args{path} ||= '';

    if (exists $args{alt}) {
        $args{alt} =~ s/\"/&quot;/g;
        $self->{alt} = $args{alt};
    }

    my ($name, $w, $h);

    if ( $args{mini} ) {
        if ( length $args{mini} > 1 ) {
            $name = $self->{mini}{$args{mini}}{filename};
            $w = $self->{mini}{$args{mini}}{width};
            $h = $self->{mini}{$args{mini}}{height};
        } else {
            $name = $self->{mname};
            $w = $self->{mw};
            $h = $self->{mh};
        }
    } else {
        $name = $self->{name};
        $w = $self->{w};
        $h = $self->{h};
    }

    my @out = (
        '<img ',
            'src="'.$args{path}.$name.'"',
            ' alt="'.$self->{alt}.'"',
            ' title="'.$self->{alt}.'"',
            ' width="'.$w.'"',
            ' height="'.$h.'"',
            ( $args{misc} ? $args{misc} : '' ),
        '>'
    );
    
    return join '', @out;
}

# ----------------------------------------------------------------------------
# Вывод картинки в виде линка <a>...
# Пример:
# print $pic and $pic->as_href(href => 'http://r0.ru/');
# ----------------------------------------------------------------------------
sub as_href {
    my $self = shift;
    my %args = ref $_[0] ? %{$_[0]} : @_;

    $args{title} =~ s/\"/&quot;/g;

    my @out = (
        '<a',
            ' href="'.$args{href}.'"',
            ' title="'.$args{title}.'"',
            ( $args{a_misc} ? $args{a_misc} : '' ),
        '>',
        $self->as_html(%args),
        '</a>',
    );
    
    return join '', @out;
}

# ----------------------------------------------------------------------------
# Вывод картинки в виде линкованой превьюшки <a><img></a>...
# Пример:
# print $pic and $pic->as_thumbnail(base => '/my_popup.html');
# defaults:
#   base => '/popup.html',
#   mini => 1,
# ----------------------------------------------------------------------------
sub as_thumbnail {
    my $self = shift;
    my %args = ref $_[0] ? %{$_[0]} : @_;

    $args{base} ||= '/popup.html';
    $args{mini} = 1 unless defined $args{mini};
    $args{alt} =~ s/\"/&quot;/g;

    # если ссылка не задана, то линкуем превьюшку на свою большую версию...
    $args{href} ||= join '', (
        $args{base}.
        '?iname='.  $args{path}.$self->{name},
        '&width='.  $self->{w},
        '&height='. $self->{h},
        '&alt='.    $self->{alt},
        '" onclick="openWin(this, \'image',
            $self->{key}.'\', ',
            $self->{w}.', ',
            $self->{h}.', 0); return false" style="text-decoration:none',
    );

    return $self->as_href(%args);
}


sub AUTOLOAD {
    my $dest   = $Contenido::Image::AUTOLOAD =~ /::DESTROY$/ ? 1 : 0;
    my ($attr) = $Contenido::Image::AUTOLOAD =~ /^.*::([^:]+)$/;
    my $self   = $dest ? {} : shift;
    $log->error((ref $self)."->$attr: метод не найден") unless $dest or exists $self->{$attr};
    $self->{$attr} = $_[0] if @_;
    $self->{$attr};
}

1;

