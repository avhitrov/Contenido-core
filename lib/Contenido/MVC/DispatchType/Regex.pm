package Contenido::MVC::DispatchType::Regex;

use strict;
use base 'Contenido::MVC::DispatchType';
use Data::Dumper;

sub match {
        my $self = shift;
        my $path = shift || '/';

        my $compiled = $self->{compiled} || [];

        foreach my $comp (@$compiled) {
                if ( my @snippets = ( $path =~ $comp->{regex} ) ) {
                        return {
                                'sub' => $comp->{'sub'},
                                'path' => $path,
                                'controller_class' => $comp->{'controller_class'},
                                'snippets' => \@snippets,
								(exists $comp->{'begin'} ? ('begin' => $comp->{'begin'}) : ()),
								(exists $comp->{'end'} ? ('end' => $comp->{'end'}) : ()),
						};
                }
        }
        return undef;
}

sub register {
        my $self        = shift;
        my $action      = shift;

        return undef unless $action && ref($action) eq 'HASH';

        push @{ $self->{compiled} }, {
                'regex' => qr#$action->{'path'}#,
                'sub'   => $action->{'sub'},
                'sorder' => defined $action->{'sorder'} ? $action->{'sorder'} : 1000,
                'controller_class' => $action->{'controller_class'},
				(exists $action->{'begin'} ? ('begin' => $action->{'begin'}) : ()),
				(exists $action->{'end'} ? ('end' => $action->{'end'}) : ()),
        };

        return 1;
}

sub after_register {
        my $self = shift;

        my $compiled = $self->{compiled} || [];
        $self->{compiled} = [ sort { $a->{sorder} <=> $b->{sorder} } @$compiled ];

        return 1;
}

1;