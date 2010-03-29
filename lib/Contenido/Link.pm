package Contenido::Link;

# ----------------------------------------------------------------------------
# Класс Связь
# Очень похож на документ за тем исключением, что не 
#  наследники этого класса не могут иметь дополнительных полей.
# ----------------------------------------------------------------------------

use strict;
use warnings;
use locale;

use base 'Contenido::Object';

use Contenido::Globals;

# ----------------------------------------------------------------------------
# Метод class_name() - возвращает имя класса
# ----------------------------------------------------------------------------
sub class_name
{
	return 'Связь';
}

sub class_description
{
	return 'Связь по умолчанию';
}

# клас реализации таблицы
sub class_table
{
	return 'SQL::LinkTable';
}

# ----------------------------------------------------------------------------
# Конструктор. Создает новый объект связи... 
#
# Формат использования:
#  Contenido::Link->new()
#  Contenido::Link->new($keeper)
#  Contenido::Link->new($keeper,$id)
# ----------------------------------------------------------------------------
sub new
{
	my ($proto, $keeper, $id) = @_;
	my $class = ref($proto) || $proto;
	my $self;

	if (defined($id) && ($id>0) && defined($keeper)) {
	        $self=$keeper->get_link_by_id($id, class=>$class);
	} else {
	        $self = {};
	        bless($self, $class);
	        $self->init();
	        $self->class($class);

	        $self->keeper($keeper)          if (ref $keeper);
	}
	return $self;
}

#базовая версия available_sources (возвращает все классы)
sub available_sources {
#	return $state->{available_documents};
	return [];
}

sub available_destinations {
	return [];
}

#sub _get_table {
#       return class_table->new();
#}

1;

