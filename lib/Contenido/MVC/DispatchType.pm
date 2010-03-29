package Contenido::MVC::DispatchType;

use strict;

sub new {
        my $proto = shift;
        my $class = ref($proto) || $proto;
        my $self =  {};
        return bless $self, $class;
}

sub match {
        return undef;
}

sub register {
        return undef;
}                                                      
                                                      
sub after_register {
        return undef;
}

1;
