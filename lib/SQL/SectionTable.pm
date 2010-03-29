package SQL::SectionTable;

use strict;
use base 'SQL::ProtoTable';

sub db_table
{
	return 'sections';
}

sub available_filters {
	my @available_filters = qw(	
					_class_filter
					_status_filter
					_in_id_filter
					_id_filter
					_name_filter
					_class_excludes_filter
					_excludes_filter
					_datetime_filter
					_date_equal_filter
					_date_filter
					_previous_days_filter

					_s_filter
					_alias_filter
				);
	return \@available_filters; 
}

# ----------------------------------------------------------------------------
# Свойства храним в массивах, потому что порядок важен!
# Это общие свойства - одинаковые для всех документов.
#
#   attr - обязательный параметр, название атрибута;
#   type - тип аттрибута, требуется для отображдения;
#   rusname - русское название, опять же требуется для отображения;
#   hidden - равен 1, когда 
#   readonly - инициализации при записи только без изменения в дальнейшем
#   db_field - поле в таблице
#   default  - значение по умолчанию (поле всегда имеет это значение)
# ----------------------------------------------------------------------------
sub required_properties
{
	return (
		{							# Идентификатор документа, сквозной по всем типам...
			'attr'		=> 'id',
			'type'		=> 'integer',
			'rusname'	=> 'Идентификатор документа',
			'hidden'	=> 1,
			'auto'		=> 1,
			'readonly'	=> 1,
			'db_field'	=> 'id',
			'db_type'	=> 'integer',
		},
		{						       # Идентификатор родительской секции
			'attr'		=> 'pid',
			'type'		=> 'parent',
			'rusname'	=> 'Идентификатор родителя',
			'db_field'	=> 'pid',
			'db_type'       => 'integer',
		},
		{						       # Порядок сортировки
			'attr'		=> 'sorder',
			'type'		=> 'sorder',
			'rusname'	=> 'Порядок сортировки',
			'hidden'	=> 1,
			'db_field'      => 'sorder',
			'db_type'       => 'integer',
		},
		{							# Класс документа...
			'attr'		=> 'class',
			'type'		=> 'string',
			'rusname'	=> 'Класс документа',
			'hidden'	=> 1,
			'readonly'      => 1,
			'db_field'	=> 'class',
			'db_type'	=> 'varchar(48)',
		},
		{							# Имя документа...
			'attr'		=> 'name',
			'type'		=> 'string',
			'rusname'	=> 'Название',
			'db_field'	=> 'name',
			'db_type'       => 'varchar(255)',
		},
		{						      # Имя документа...
			'attr'		=> 'alias',
			'type'		=> 'string',
			'rusname'       => 'web-alias',
			'db_field'      => 'alias',
			'db_type'       => 'text',
		},
		{							# Время создания документа, служебное поле...
			'attr'     	=> 'ctime',
			'type'     	=> 'datetime',
			'rusname'  	=> 'Время создания',
			'hidden'   	=> 1,
			'readonly'      => 1,
			'auto'		=> 1,
			'db_field'	=> 'ctime',
			'db_type'       => 'timestamp',
			'default'  	=> 'CURRENT_TIMESTAMP',
		},
		{							# Время модификации документа, служебное поле...
			'attr'     	=> 'mtime',
			'type'     	=> 'datetime',
			'rusname'  	=> 'Время модификации',
			'hidden'   	=> 1,
			'auto'		=> 1,
			'db_field'	=> 'mtime',
			'db_type'       => 'timestamp',
			'default'  	=> 'CURRENT_TIMESTAMP',
		},
		{							# Одно поле статуса является встроенным...
			'attr'		=> 'status',
			'type'		=> 'status',
			'rusname'	=> 'Статус',
			'db_field'	=> 'status',
			'db_type'       => 'integer',
		},
	);
}


########### FILTERS DESCRIPTION ####################################################################################
sub _s_filter {
	my ($self,%opts)=@_;
	return undef unless ( exists($opts{s}) );
	if ($opts{dive}) {
		return &SQL::Common::_generic_int_filter('d.pid', $opts{all_childs});
	} else {
		return &SQL::Common::_generic_int_filter('d.pid', $opts{s});
	}
}

sub _alias_filter {
	my ($self,%opts)=@_;
	return undef unless ( exists($opts{alias}) );
	return &SQL::Common::_generic_text_filter('d.alias', $opts{alias});
}

1;

