package Contenido::MVC::Dispatcher;

use strict;
use Utils;
use Data::Dumper;

# типы диспетчеров (сравнение пути, регексп пути)
my @DISPATCH_TYPES = qw(Path Regex);

sub init {
        my $proto = shift;
        my %opts = @_;
        my $class = ref($proto) || $proto;
        
        my $self = {};
        bless $self, $class;

        $self->load_dispatch_types( %opts );
        $self->load_actions( %opts );

        return $self;
}

# список доступных диспетчеров
sub get_dispatch_types {
        return @DISPATCH_TYPES;
}

# загрузка типов диспетчеров
sub load_dispatch_types {
        my $self = shift;

        foreach my $typename ( $self->get_dispatch_types() ) {

                my $class = 'Contenido::MVC::DispatchType::'.$typename;
                Utils::load_modules( [ $class ] );
                $self->{dispatch_types}->{ $typename } = new $class;

        }

}

# загрузка actions контроллера
sub load_actions {
        my $self = shift;
        my %opts = @_;

        my $controller_class = $opts{controller_class};
        $controller_class = [ $controller_class ] unless ref($opts{controller_class}) eq 'ARRAY';

        Utils::load_modules( $controller_class );

        foreach my $class (@$controller_class) {

                # добавление контроллера
                my $controller = $class->init();
                $self->register_controller( $controller );

                foreach my $typename ( $self->get_dispatch_types() ) {

                        my $dispatch_type = $self->{dispatch_types}->{ $typename };

                        my $method = 'get_'.lc($typename).'_actions';
                        my $actions = $controller->$method;
                
                        next unless $actions && ref($actions) eq 'ARRAY';
                
                        foreach my $action (@$actions) {
                                next unless $action && ref($action) eq 'HASH';

                                # запоминаем какому из контроллеров принадлежит данный action
                                $action->{'controller_class'} = $class;

                                # проверка на то, может ли быть выполнен метод
                                next unless $controller->can( $action->{'sub'} );

                                # регистрация метода
                                $dispatch_type->register( $action );
                        }
                
                }
        }

        # пост обработка (сейчас пригодилась для сортировки массива с регекспами)
        # к примеру: один из запросов выполняется чаще второго в 10 раз,
        # для этого в необязательном параметре sorder можно вручную поставить приоритет
        # исполнения, начиная с 0 - максимальный

        foreach my $typename ( $self->get_dispatch_types() ) {
                my $dispatch_type = $self->{dispatch_types}->{ $typename };
                $dispatch_type->after_register();
        }

        return 1;
}

# регистрация контроллера
sub register_controller {
        my $self = shift;
        my $controller = shift;

        my $class = ref($controller);
        $self->{controllers}->{$class} = $controller;
}

# получение контроллера в зависимости от action
sub get_controller {
        my $self = shift;
        my $action = shift;

        my $controller = $self->{controllers}->{ $action->{'controller_class'} };
        $controller->set_action( $action );
        return $controller;
}


# получение главного контролера
sub get_main_controller {
        my $self = shift;
        return $self->{controllers}->{'main'};
}

# установка главного контроллера
sub set_main_controller {
        my $self = shift;
        my %opts = @_;
        my $controller = $opts{controller_class}->init();
        $self->{controllers}->{'main'} = $controller;
}

# подготовка action
sub get_action {
        my $self = shift;
        my $r	= shift;

        my $path = $r->uri();
        $path =~ s/\/+/\//;
        $path =~ s/index\.\w+$//i;

        my $action = undef;

        # проходим по всем типам диспетчеров
        DP: foreach my $typename ( $self->get_dispatch_types() ) {

                my $dispatch_type = $self->{dispatch_types}->{ $typename };
                if ($action = $dispatch_type->match( $path )) {
                        last DP;
                }
        }
        return $action; 
}

1;

