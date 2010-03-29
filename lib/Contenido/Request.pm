package Contenido::Request;

# ----------------------------------------------------------------------------
# Contenido::Request - класс, который будет создаваться для каждого 
#  запроса и незримо присутствовать. В него мы инкапсулируем все данные 
#  о текущем запросе (в том числе и результаты выполнения URI mapping, 
#  то есть названия конкретных компонент, которые должны обрабатывать 
#  этот запрос). Объект этого типа будет создаваться для каждого 
#  запроса до того, как HTML::Mason получит управление.
# ----------------------------------------------------------------------------

use strict;
use warnings;
use locale;

use vars qw($VERSION $AUTOLOAD);
$VERSION = '1.0';

use Data::Dumper;
use Contenido::Globals;

sub new
{
    my ($proto,$state) = @_;
    $log->error("Неправильный вызов конструктора объекта проекта. В параметрах нет объекта класса Contenido::State")  unless ref $state;

    my $class = ref($proto) || $proto;
    my $self = {};
    bless($self, $class);

    # Запомним то, что нас интересует...
    $self->{data} = {};
    $self->{_cache_} = {};
    $self->{timer_start} = time();

    foreach my $a ( qw(timer_start timer_finish) )
    {
        $self->{attributes}->{ $a } = 'SCALAR';
    }

    return $self;
}


sub set_properties
{
    my ($self, %P) = @_;
    foreach my $p (keys(%P))
    {
        $self->{data}->{$p} = $P{$p};
        $self->{attributes}->{ $p } = 'DATA';
    };

    return 1;
}

sub get_args {
    my $self = shift;

    if (exists $self->{request_args}) {
        return wantarray ? %{$self->{request_args}} : $self->{request_args};
    }
    

    my $apr = $self->r();
    my $args = {};
    if ($apr) {
        foreach my $key ( $apr->param ) {
            my @values = $apr->param($key);
            $args->{$key} = @values == 1 ? $values[0] : \@values;
        }
    }

    $self->{request_args} = $args;
    return wantarray ? %{ $self->{request_args} } : $self->{request_args};
}


sub is_post {
	my $self = shift;
	return $self->r()->method() =~ /^post/i ? 1 : undef;
}


# ----------------------------------------------------------------------------
# Это умный AUTOLOAD. Ловит методов для установки/чтения полей...
# Версия 0.2/Модифицированная версия
# ----------------------------------------------------------------------------

sub AUTOLOAD
{
    my $self = shift;
    my $attribute = $AUTOLOAD;

    $attribute =~ s/.*:://;
    return undef unless $attribute =~ /[^A-Z]/; # Отключаем методы типа DESTROY

    unless ( exists $self->{attributes}->{$attribute} ) {
        $log->error("Вызов метода, для которого не существует обрабатываемого свойства: ->$attribute()");
        return undef;
    }

    if ($self->{attributes}->{$attribute} eq 'DATA')
    {
        $self->{data}->{ $attribute } = shift @_    if (scalar(@_) > 0);
        return $self->{data}->{ $attribute };
    } else {
        $self->{ $attribute } = shift @_    if (scalar(@_) > 0);
        return $self->{ $attribute };
    }
}


1;
