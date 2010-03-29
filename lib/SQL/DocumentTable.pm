package SQL::DocumentTable;

use strict;
use base 'SQL::ProtoTable';

sub db_table
{
	return 'documents';
}

sub available_filters {
	my @available_filters = qw(	
					_class_filter
					_status_filter
					_in_id_filter
					_id_filter
					_name_filter
					_class_excludes_filter
					_sfilter_filter
					_datetime_filter
					_date_equal_filter
					_date_filter
				 	_previous_days_filter
					_prev_to_filter
					_next_to_filter
					_s_filter

					_excludes_filter
					_link_filter
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
			'readonly'	=> 1,
			'auto'		=> 1,
			'db_field'	=> 'id',
			'db_type'	=> 'integer',
			'db_opts'	=> "not null default nextval('public.documents_id_seq'::text)", 
		},
		{							# Класс документа...
			'attr'		=> 'class',
			'type'		=> 'string',
			'rusname'	=> 'Класс документа',
			'column'	=> 3,
			'hidden'	=> 1,
			'readonly'	=> 1,
			'db_field'	=> 'class',
			'db_type'	=> 'varchar(48)',
			'db_opts'	=> 'not null',
		},
		{							# Имя документа...
			'attr'		=> 'name',
			'type'		=> 'string',
			'rusname'	=> 'Название',
			'column'	=> 2,
			'db_field'	=> 'name',
			'db_type'	=> 'varchar(255)',
		},
		{							# Время создания документа, служебное поле...
			'attr'		=> 'ctime',
			'type'		=> 'datetime',
			'rusname'	=> 'Время создания',
			'readonly'	=> 1,
			'auto'		=> 1,
			'hidden'	=> 1,
			'db_field'	=> 'ctime',
			'db_type'	=> 'timestamp',
			'db_opts'	=> 'not null default now()',
			'default'	=> 'CURRENT_TIMESTAMP',
		},
		{							# Время модификации документа, служебное поле...
			'attr'		=> 'mtime',
			'type'		=> 'datetime',
			'rusname'	=> 'Время модификации',
			'hidden'	=> 1,
			'auto'		=> 1,
			'db_field'	=> 'mtime',
			'db_type'	=> 'timestamp',
			'db_opts'	=> 'not null default now()',
			'default'	=> 'CURRENT_TIMESTAMP',
		},
		{							# Дата и время документа...
			'attr'		=> 'dtime',
			'type'		=> 'datetime', 
			'rusname'	=> 'Дата и время документа<sup style="color:#888;">&nbsp;1)</sup>',
			'column'	=> 1,
			'db_field'	=> 'dtime',
			'db_type'	=> 'timestamp',
			'db_opts'	=> 'not null default now()',
			'default'	=> 'CURRENT_TIMESTAMP',
		},
		{							# Массив секций, обрабатывается специальным образом...
			'attr'		=> 'sections',
			'type'		=> 'sections_list',
			'rusname'       => 'Секции',
			'hidden'	=> 1,
			'db_field'	=> 'sections',
			'db_type'	=> 'integer[]',
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

1;

