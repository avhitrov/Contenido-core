package Contenido::MVC::Controller;

use strict;
use Contenido::Globals;
use Data::Dumper;
use HTTP::Status;

sub init {
        my $proto = shift;
        my $class = ref($proto) || $proto;
        my $self = {
            comp => undef,
            mason_args => {},
            action => undef,
            result => undef
            
        };
        return bless $self, $class;
}

# get path actions in format: [ { sub =>  sub_name, path => location }, .. ]
sub get_path_actions {
        return [];
}

# get regex actions in format: [ { sub => sub_name, regex => regex, sorder => undef or integer (0 - max priority) ], .. ]
sub get_regex_actions {
        return [];
}


sub comp {
        my $self = shift;
        my $comp = shift;
        my %mason_args = @_;

        $self->{comp} = $comp;
        if (%mason_args) {
            foreach (keys %mason_args) {
                next unless defined $_;
                $self->{mason_args}->{$_} = $mason_args{$_};
            }
        }

        return $self->{comp};
}

# установка хэша параметров, которые будут доступны в ARGS вызываемой компоненты
sub set_mason_args {
        my $self = shift;

        return undef unless $self->{mason_args} && ref($self->{mason_args}) eq 'HASH';

        my $apr = $self->get_r();

        foreach ( keys %{ $self->{mason_args} } ) {
                $request->{'_mason_request_args_'}{$_} = $self->{mason_args}->{$_};
        }

        return 1;
}

# вернуть текущее значение args
sub mason_args {
        my $self = shift;
        return $self->{mason_args};
}

# вернуть $r - объект Apache
sub get_r {
        my $self = shift;
        return $self->{r};
}

# Подготовка начала запроса
sub prepare_request {
        my $self = shift;

        $self->{r}		= shift;
        $self->{comp}		= undef;
        $self->{mason_args}	= {};
        $self->{action}		= undef;
        $self->{_result}	= undef;
}

# установка action
sub set_action {
        my $self = shift;
        $self->{action} = shift;
}

# вернуть текущий action
sub get_action {
        my $self = shift;
        return $self->{action};
}


# функция, которая будет вызвана в начале обработки любого action
sub begin {
        return undef;
}

# функция, которая будет вызвана в конце обработки любого action
sub end {
        return undef;
}


sub get_response {
    my $self = shift;
    return $self->{_result} ? $self->{_result} : undef;
}

sub is_response {
    my $self = shift;
    return defined $self->{_result} ? 1 : undef;
}

sub set_response {
    my $self = shift;
    my $status = shift;

    $self->set_mason_args();
    
    if ($status && HTTP::Status::status_message($status)) {
        $self->{_result} = $status;
    } else {
        $self->{_result} = 0;
    }

    return undef;
}


# Редирект средствами контроллера
sub redirect {
    my $self = shift;
    my $url = shift;
    
    my $r = $self->get_r();
    $r->header_out("Location", $url);
    $r->status(302);

    return $self->set_response(302);
}


1;

