package Contenido::MVC::MasonHandler;

use strict;
use base 'HTML::Mason::ApacheHandler';
use Contenido::Globals;
use Data::Dumper;

use Contenido::MVC::Dispatcher;
use HTTP::Status;
use Apache::Request;

sub new {
	my $proto = shift;
	my %opts = @_;
	my $class = ref($proto) || $proto;

	my $dispatcher_class		= $opts{controller_dispatcher_class} || 'Contenido::MVC::Dispatcher';
	my $controller_class		= $opts{controller_class} || 'Contenido::MVC::Controller';
	my $controller_main_class 	= $opts{controller_main_class} || 'Contenido::MVC::Controller';

	# удаление опций контроллера
	foreach (keys %opts) {
		delete $opts{$_} if $_ =~ /^controller/i;
	}

	my $self = $proto->SUPER::new( %opts );

	$self->set_dispatcher( $dispatcher_class->init( controller_class => $controller_class ) );
	$self->get_dispatcher()->set_main_controller( controller_class => $controller_main_class );

	return $self;
}


sub request_args {
    my $self = shift;

	my %args = $request->get_args();

    if ($request->{'_mason_request_args_'} && ref $request->{'_mason_request_args_'} eq 'HASH') {
        map { $args{ $_ } = $request->{'_mason_request_args_'}{$_} } keys %{ $request->{'_mason_request_args_'} };
    }

    return (\%args, $request->r(), undef);
}
    

sub get_dispatcher {
        my $self = shift;
        return $self->{dispatcher};
}

sub set_dispatcher {
        my $self = shift;
        $self->{dispatcher} = shift;
}

# исполнение запроса
sub handle_request {
        my $self	= shift;
        my $r		= shift;
        
        my $apr = $request->r();
		my ($comp, $response);

        # определяем action
        my $action = $self->get_dispatcher()->get_action( $apr );

		# TODO: Почему-то эта строчка выглядела так -
		# $self->get_dispatcher()->get_main_controller()->prepare_request( $apr ) if $apr->is_initial_req();
		# что вызывало появление 504 ошибки при обращении к http://planeta.rambler.ru/ 
		# при вызове index.html напрямую ошибка не появлялась...
        $self->get_dispatcher()->get_main_controller()->prepare_request( $apr );
        
        # исполнение begin
        $self->get_dispatcher()->get_main_controller()->begin( $action );

        if ($self->get_dispatcher()->get_main_controller()->is_response()) {
        		$comp		= $self->get_dispatcher()->get_main_controller()->{comp};
        		$response	= $self->get_dispatcher()->get_main_controller()->get_response();

                return $self->mason_handle_request( $apr, $response, $comp );
        }

        if ($action) {
            # установка request
            $self->get_dispatcher()->get_controller( $action )->prepare_request( $apr );

            # исполнение
            $self->execute($action);

            # установка mason %ARGS
            $self->get_dispatcher()->get_controller( $action )->set_mason_args();
            
            $comp = $self->get_dispatcher()->get_controller( $action )->{comp};
            $response   = $self->get_dispatcher()->get_controller( $action )->get_response();

        }

        # исполнение end
        $self->get_dispatcher()->get_main_controller()->end( $action );
        if ($self->get_dispatcher()->get_main_controller()->is_response()) {
        		$comp		= $self->get_dispatcher()->get_main_controller()->{comp};
        		$response	= $self->get_dispatcher()->get_main_controller()->get_response();

                return $self->mason_handle_request( $apr , $response, $comp );
        }

        if ($action && $self->get_dispatcher()->get_controller( $action )->is_response()) {
				$comp		= $self->get_dispatcher()->get_controller( $action )->{comp};
				$response	= $self->get_dispatcher()->get_controller( $action )->get_response();
                return $self->mason_handle_request( $apr , $response, $comp );
        }


        return $self->mason_handle_request( $apr, $response, $comp );
}

# mason handle_request
sub mason_handle_request {
	my $self	= shift;
	my $apr		= shift;
	my $status	= shift;
	my $comp	= shift;

	if (defined $status) {
		return $status;
	}

	# Установка необходимой компоненты
	if ($comp) {
		my $interp = $self->interp;
		foreach (map $_->[1], $interp->comp_root_array) {
			if (-e $_.$comp) {
				$apr->filename($_.$comp);
				last;
			}
		}
	}

	return $self->SUPER::handle_request( $apr );
}

# исполнение процедуры контроллера, отвечающего за данный путь
sub execute {
        my $self	= shift;
        my $action	= shift;

        return undef unless $action && ref($action) && $action->{'sub'};
        my $method = $action->{'sub'};
        my $begin_method = exists $action->{'begin'} ? $action->{'begin'} : 'begin';
        my $end_method = exists $action->{'end'} ? $action->{'end'} : 'end';

		if ($begin_method) {
	        $self->get_dispatcher()->get_controller( $action )->$begin_method( $action );
        }

        if ($self->get_dispatcher()->get_controller( $action )->is_response()) {
            return undef;
        }

        $self->get_dispatcher()->get_controller( $action )->$method( $action );

		if ($end_method) {
	        $self->get_dispatcher()->get_controller( $action )->$end_method( $action );
        }

        return undef;
}


1;