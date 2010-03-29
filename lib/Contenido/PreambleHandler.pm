package Contenido::PreambleHandler;

use strict;

use Contenido::Globals;
use Scalar::Util qw|blessed reftype|;
use Data::Dumper;

sub comps {return{}} # dummy

# ->new( load_modules => 'My_preambles')  
#
sub new {
    my $proto = shift;
    my %args = @_;
    my $class = ref $proto || $proto;
    my $self = {};
    bless $self, $class;

    $self->_init;
    $self->_load_modules( $args{'load_modules'} ) if $args{'load_modules'};

    return $self;
}

sub _init {
    my $self = shift;        
    my $comps = $self->comps || {};
    $self->{comps}{$_} = $comps->{$_} for keys %$comps;
}

sub _load_modules {
    my $self = shift;
    my $class = ref $self || $self;
	my $path = shift || return;

    # (c) Init.pm
    my $root_path = __FILE__;
    $root_path =~ s|/[^/]*$||;
    $root_path =~ s|/Contenido$||;

    my $modules = Utils::find_modules(relative_dir => $state->project.'/'.$path, absolute_dir => $root_path.'/', recursive => 1);
    return unless ref $modules eq 'ARRAY';

    $log->info("Loading Preabmle modules");

    my %modules; map { $modules{$_}++ } @$modules;
    for my $module ( keys %modules ) {
		
		eval "use $module"; $log->error("Cannot load module $module because of '$@'") if $@;
        
        unless ( $module->isa( $class ) ) {
            $log->warning("Class $module is not child of $class - skiped");
            next;
        }
        
        my $obj = $module->new; next unless ref $obj eq $module;
        my $comps = $obj->comps;
        for ( keys %$comps ) {
            $comps->{$_}{obj} = $obj;
            $self->{comps}{$_} = $comps->{$_};
        }
        $log->info("$module loaded");
    }
}

# !!! This code will be executed in every Mason component's preamble.
# Don't make it fat.
#
sub handle {
    my $self = shift;
    my $context = shift;
    my $req_args = shift;

    my $req_args_h = $req_args && reftype $req_args eq 'ARRAY' ? { @$req_args } : {};
    my $comp = $context->current_comp;
    my $action = $self->{comps}{ $comp->path };
    
    return unless $action;
 
    #  1. Action is self cached
    #
    if ( ref $action->{cache} && !$state->development ) {
        
        # create complex cache key - based on component args
        my $key = $action->{cache}{'key'};
        if ( defined $action->{cache}{'key_args'} && reftype $action->{cache}{'key_args'} eq 'ARRAY' ) {
            my $key_args = $action->{cache}{'key_args'};
            $key = join '_', $key || (), map { $_.':'.$req_args_h->{$_} } @$key_args;
        }

        return { _cached => 1 } if $context->cache_self( %{$action->{cache}}, key => $key );
    }

    if ( $action->{'sub'} ) {
        my $ret;
        my $sub = $action->{'sub'};
                
        # 2. Action located in extra module
        #
        if ( ref $action->{obj} ) {
            $ret = $action->{obj}->$sub( $context, $req_args_h );
				
        # 3. Action present in current module
        #
        } else {
            $ret = $self->$sub( $context, $req_args_h );				
        }

        push @$req_args, (%$ret) if reftype $ret eq 'HASH'; # add data to %ARGS

        return $ret;
    }

    return 0;
}


1;

