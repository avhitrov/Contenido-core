package Contenido::MVC::DispatchType::Path;

use strict;
use base 'Contenido::MVC::DispatchType';
use URI;
use Data::Dumper;

sub match {
        my $self = shift;
        my $path = shift || '/';
        
        if (exists $self->{paths}->{$path}) {
                return {
                        'sub' => $self->{paths}->{$path}->{'sub'},
                        'path' => $path,
                        'controller_class' => $self->{paths}->{$path}->{'controller_class'},
                        'snippets' => [],
						(exists $self->{paths}->{$path}->{'begin'} ? ('begin' => $self->{paths}->{$path}->{'begin'}) : ()),
						(exists $self->{paths}->{$path}->{'end'} ? ('end' => $self->{paths}->{$path}->{'end'}) : ()),
                };
        }

        return undef;       
}

sub register {
        my $self	= shift;
        my $action	= shift;
        
        return undef unless $action && ref($action) eq 'HASH';
        
        my $path = $action->{'path'};
        $path = '/' unless length $path;
        $path = URI->new($path)->canonical();

        $self->{paths}->{$path} = { 
                'sub' =>  $action->{'sub'},
                'controller_class' => $action->{'controller_class'},
				(exists $action->{'begin'} ? ('begin' => $action->{'begin'}) : ()),
                (exists $action->{'end'} ? ('end' => $action->{'end'}) : ()),
        };

        return 1;
}

1;