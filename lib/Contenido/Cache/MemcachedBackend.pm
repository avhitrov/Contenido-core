package Contenido::Cache::MemcachedBackend;

use strict;
use warnings 'all';

use Cache::Memcached::Fast;


#########################################
# Cache::Backend interface implementation
#########################################

my $memd;

sub new {
	my ($class, $opts) = @_;
	my $implementation = $opts->{mc_backend};
	$memd ||= $implementation->new({
			servers   => $$opts{mc_servers},
			namespace => $$opts{mc_namespace},
		});
	bless {memd=>$memd}, $class;
}

sub delete_key {
	my ($self, $nspace, $key) = @_;
	$$self{memd}->delete($self->_make_key($nspace, $key));
}

sub delete_namespace {
	my ($self, $nspace) = @_;
	$self->_not_implemented('delete_namespace');
}

sub get_keys {
	my ($self, $nspace) = @_;
	$self->_not_implemented('get_keys');
}

sub get_namespaces {
	my ($self) = @_;
	$self->_not_implemented('get_namespaces');
}

sub get_size {
	my ($self, $nspace, $key) = @_;
	my $val = $self->restore($nspace, $key);
	defined($val) ? length($val) : undef;
}

sub restore {
	my ($self, $nspace, $key) = @_;
	$$self{memd}->get($self->_make_key($nspace, $key));
}

sub store {
	my ($self, $nspace, $key, $val) = @_;
	$$self{memd}->set($self->_make_key($nspace, $key), $val);
}


###################
# Internal routines
###################

sub _make_key {
	my $self = shift;
	join ':', map {defined($_) ? $_ : ''} @_;
}

sub _not_implemented {
	my ($self, $meth) = @_;
	warn "WARNING! ".ref($self)."::$meth not implemented\n";
}

1;
