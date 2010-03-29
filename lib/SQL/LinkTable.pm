package SQL::LinkTable;

use strict;
use base 'SQL::ProtoTable';

sub db_table
{
	return 'links';
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
		
					_dest_id_filter
					_source_id_filter
					_source_class_filter
					_dest_class_filter
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
			'db_field'	=> 'id',
			'readonly'	=> 1,
			'db_type'	=> 'integer',
		},
		{							# Класс документа...
			'attr'		=> 'class',
			'type'		=> 'string',
			'rusname'	=> 'Класс документа',
			'hidden'	=> 1,
			'db_field'	=> 'class',
			'readonly'	=> 1,
			'db_type'	=> 'varchar(48)',
		},
		{						       # Имя документа...
			'attr'		=> 'source_id',
			'type'		=> 'string',
			'rusname'	=> 'ID Источника',
			'db_field'	=> 'source_id',
			'db_type'	=> 'integer',
		},
		{						       # Имя документа...
			'attr'		=> 'source_class',
			'type'		=> 'string',
			'rusname'	=> 'Класс источника',
			'db_field'	=> 'source_class',
			'db_type'	=> 'varchar(48)',
		},
		{						       # Имя документа...
			'attr'		=> 'dest_id',
			'type'		=> 'string',
			'rusname'	=> 'ID цели',
			'db_field'	=> 'dest_id',
			'db_type'	=> 'integer',
		},
		{							# Имя документа...
			'attr'		=> 'dest_class',
			'type'		=> 'string',
			'rusname'	=> 'Класс цели',
			'db_field'	=> 'dest_class',
			'db_type'	=> 'varchar(48)',
		},
		{							# Время создания документа, служебное поле...
			'attr'		=> 'ctime',
			'type'		=> 'datetime',
			'rusname'	=> 'Время создания',
			'hidden'	=> 1,
			'auto'		=> 1,
			'db_field'	=> 'ctime',
			'readonly'	=> 1,
			'default'	=> 'CURRENT_TIMESTAMP',
			'db_type'	=> 'timestamp',
		},
		{							# Время модификации документа, служебное поле...
			'attr'		=> 'mtime',
			'type'		=> 'datetime',
			'rusname'	=> 'Время модификации',
			'hidden'	=> 1,
			'auto'		=> 1,
			'db_field'	=> 'mtime',
			'default'	=> 'CURRENT_TIMESTAMP',
			'db_type'	=> 'timestamp',
		},
		{							# Одно поле статуса является встроенным...
			'attr'		=> 'status',
			'type'		=> 'status',
			'rusname'	=> 'Статус',
			'db_field'	=> 'status',
			'db_type'	=> 'integer',
		},
	);
}


########### FILTERS DESCRIPTION ####################################################################################
sub _dest_id_filter {
	my ($self,%opts)=@_;
	return undef unless ( exists($opts{dest_id}) );
	return &SQL::Common::_generic_int_filter('d.dest_id', $opts{dest_id});
}

sub _source_id_filter {
	my ($self,%opts)=@_;
	return undef unless ( exists($opts{source_id}) );
	return &SQL::Common::_generic_int_filter('d.source_id', $opts{source_id});
}

sub _source_class_filter {
        my ($self, %opts)=@_;
        return undef unless ( exists($opts{source_class}) );
        return &SQL::Common::_generic_text_filter('d.source_class', $opts{source_class});
}

sub _dest_class_filter {
        my ($self, %opts)=@_;
        return undef unless ( exists($opts{dest_class}) );
        return &SQL::Common::_generic_text_filter('d.dest_class', $opts{dest_class});
}

1;

