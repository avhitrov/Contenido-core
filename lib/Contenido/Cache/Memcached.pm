package Contenido::Cache::Memcached;

use strict;
use warnings 'all';
use base qw(Cache::BaseCache);

use Contenido::Cache::MemcachedBackend;
use Contenido::Errors qw(warn);
use Contenido::Logger;


###########################################
# Cache::BaseCache interface implementation
###########################################

sub new {
	my ($class, $opts) = @_;
	my $self = Cache::BaseCache::_new(@_);
	$self->_set_backend(Contenido::Cache::MemcachedBackend->new($opts));
	$self->_complete_initialization;
	$self;
}

sub Clear {
	my ($self) = @_;
	$self->_not_implemented('Clear');
}

sub Purge {
	my ($self) = @_;
	$self->_not_implemented('Purge');
}

sub Size {
	my ($self) = @_;
	$self->_not_implemented('Size');
}

sub set {
	my $self = shift;
	my ($key, $data, $expires_in) = @_;

	if ($expires_in eq 'never') {
		Contenido::Logger->instance->warning("No 'expires_in' specified, caching impossible for key '$key'");
		$self->SUPER::set($key, $data, 84600);
		return;
	}
	$self->SUPER::set(@_);
} 


###################
# Internal routines
###################

sub _not_implemented {
	my ($self, $meth) = @_;
	warn "WARNING! ".ref($self)."::$meth not implemented\n";
}


1;
