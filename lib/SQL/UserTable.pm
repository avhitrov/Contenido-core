package SQL::UserTable;

use strict;
use base 'SQL::ProtoTable';
use vars qw($available_filters @required_properties);

sub db_table
{
	return 'users';
}

$available_filters = [qw(	
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

					_groups_filter
					_login_filter
			)];

sub available_filters {
	return $available_filters;
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
@required_properties = (
		{						       # Идентификатор документа, сквозной по всем типам...
			'attr'	  => 'id',
			'type'	  => 'integer',
			'rusname'       => 'Идентификатор документа',
			'hidden'	=> 1,
			'auto'		=> 1,
			'readonly'      => 1,
			'db_field'      => 'id',
			'db_type'       => 'integer',
		},
		{							# Идентификатор документа, сквозной по всем типам...
			'attr'		=> 'login',
			'type'		=> 'string',
			'rusname'	=> 'Логин',
			'db_field'	=> 'login',
			'db_type'	=> 'varchar(255)',
		},
		{							# Класс документа...
			'attr'		=> 'class',
			'type'		=> 'string',
			'rusname'	=> 'Класс документа',
			'hidden' 	=> 1,
			'readonly'      => 1,
			'db_field'	=> 'class',
			'db_type'       => 'varchar(48)',
		},
		{							# Имя документа...
			'attr'		=> 'name',
			'type'		=> 'string',
			'rusname'	=> 'ФИО',
			'db_field'	=> 'name',
			'db_type'       => 'varchar(255)',
		},
		{							# Время создания документа, служебное поле...
			'attr'    	=> 'ctime',
			'type'    	=> 'datetime',
			'rusname' 	=> 'Время создания',
			'hidden'   	=> 1,
			'auto'		=> 1,
			'readonly'      => 1,
			'db_field'	=> 'ctime',
			'db_type'       => 'timestamp',
			'default' 	=> 'CURRENT_TIMESTAMP',
		},
		{							# Время модификации документа, служебное поле...
			'attr'    	=> 'mtime',
			'type'    	=> 'datetime',
			'rusname' 	=> 'Время модификации',
			'hidden'   	=> 1,
			'auto'		=> 1,
			'db_field'	=> 'mtime',
			'db_type'       => 'timestamp',
			'default' 	=> 'CURRENT_TIMESTAMP',
		},
		{							# Одно поле статуса является встроенным...
			'attr'		=> 'status',
			'type'		=> 'status',
			'rusname'	=> 'Статус',
			'db_field'	=> 'status',
			'db_type'       => 'integer',
		},
		{						       # Пароль
			'attr'		=> 'passwd',
			'type'		=> 'string',
			'rusname'	=> 'Пароль',
			'db_field'	=> 'passwd',
			'db_type'       => 'varchar(255)',
		},
		{						       # Группы
			'attr'		=> 'groups',
			'type'		=> 'array of integer',
			'rusname'	=> 'Группы',
			'hidden' 	=> 1,
			'db_field'	=> 'groups',
			'db_type'       => 'integer[]',
		}
);

sub required_properties {
	return @required_properties;
}

########### FILTERS DESCRIPTION ####################################################################################
sub _login_filter {
	my ($self,%opts)=@_;
	return undef unless ( exists($opts{login}) );
	return &SQL::Common::_generic_text_filter('d.login', $opts{login});
}

sub _groups_filter {
	my ($self,%opts)=@_;
	return undef unless ( exists($opts{s}) );
	return &SQL::Common::_generic_intarray_filter('d.groups', $opts{s});
}

1;
