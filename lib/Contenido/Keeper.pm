
package Contenido::Keeper;

# ----------------------------------------------------------------------------
# Класс базы данных
# ----------------------------------------------------------------------------
use strict;
use warnings;
use locale;

use vars qw($VERSION $AUTOLOAD);
$VERSION = '5.0';

use base qw(Contenido::DB::PostgreSQL);

use Data::Dumper;
use Time::HiRes;

use Contenido::Globals;
use Contenido::Msg;

# TODO
# побить на 2-4 модуля вменяемого размера....!  

use constant DATA_SOURCE_LOCAL      => 10;
use constant DATA_SOURCE_MEMCACHED  => 20;
use constant DATA_SOURCE_DATABASE   => 30;

# # ------------------------------------------------------------------------------------------------
# Конструктор объекта базы данных.
#  Обязательный параметр - объект класса Contenido::State из которого
#  конструктор возьмет необходимые параметры для доступа к БД и т.д.
#
# Формат вызова:
#  Contenido::Keeper->new($state)
# ------------------------------------------------------------------------------------------------
sub new {
    my ($proto, $local_state) = @_;

    unless ( ref $local_state ) {
        $log->error("Неправильный вызов конструктора объекта базы данных. В параметрах нет объекта класса Contenido::State");
        die;
    }

    my $class = ref($proto) || $proto;
    my $self = {};
    bless($self, $class);


    # Заполним собственные свойства конкретными данными...
    $self->{db_host} = $local_state->db_host();
    $self->{db_name} = $local_state->db_name();
    $self->{db_user} = $local_state->db_user();
    $self->{db_password} = $local_state->db_password();
    $self->{db_port} = $local_state->db_port();
    # AUTOLOAD method, can не работает
    $self->{db_client_encoding} = $local_state->{attributes}{db_client_encoding} ? $local_state->db_client_encoding() : '';
    $self->{db_enable_utf8}	= $local_state->{attributes}{db_enable_utf8} ? $local_state->db_enable_utf8() : 0;

    $self->{serialize_with} = $local_state->{serialize_with};

    $self->{data_dir} = $self->{data_directory} = $local_state->data_directory();
    $self->{images_dir} = $self->{images_directory} = $local_state->images_directory();
    $self->{binary_dir} = $self->{binary_directory} = $local_state->binary_directory();
    $self->{preview} = $local_state->preview();
    $self->{convert_binary} = $local_state->can('convert_binary') ? $local_state->convert_binary : undef;
    
    $self->{debug} = $local_state->debug();
    $self->{store_method} = $local_state->store_method();
    $self->{cascade} = $local_state->cascade();

    $self->{default_status} = [
        [0, 'Скрытый'],
        [1, 'Активный'],
        [2, 'Принято'],
        [3, 'Отложено'],
    ];

    $self->{state} = $local_state;
    $self->_init_();

    # соединяемся с базой если используется постоянное соединение
    $self->db_connect() if $local_state->db_type ne 'none' && $local_state->db_keepalive();
    # соединяемся с memcached
    $self->MEMD()       if $local_state->memcached_enable();

    return $self;
}

# ----------------------------------------------------------------------------
# Инициализация.
#  - Создает внутри объекта хэш с типами полей - это нужно для быстрой
#   работы метода AUTOLOAD...
# ----------------------------------------------------------------------------
sub _init_ {
    my $self = shift;

    foreach my $attribute ( qw(
            db_host db_name db_user db_password db_port
            serialize_with

            data_directory data_dir
            images_directory images_dir
            binary_directory binary_dir

            store_method cascade

            default_status

            debug
            state
            )    )
    {
        $self->{attributes}->{ $attribute } = 'SCALAR';
    }
}

sub get_items {
    my ($self, $proto, %opts) = @_;

    $log->info("get_items($proto) called with opts: ".Data::Dumper::Dumper(\%opts)) if $DEBUG;

    #установка доп опций
    $opts{all_childs} = $self->_all_childs($opts{s}) if ($opts{dive} and $opts{s});

    # -------------------------------------------------------------------------------------------
    # выставляем режим возвращаемых данных (array|array_ref|hash|hash_ref|count)
    # default array for compatibility reasons
    # hash/hash_ref хешируют по умолчанию по полю id...
    # hash_by параметр может установить произвольное поле обьекта для построения хеша
    # return_mode => 'count' эквивалентно count=>1
    # return_mode имеет более высокий приоритет чем count

    if ($opts{count} and $opts{return_mode} and ($opts{return_mode} ne 'count')) {
        $log->warning("get_items($proto) have count=>1 and return_mode=>$opts{return_mode} set... using $opts{return_mode} mode"); delete $opts{count};
    } elsif ($opts{count}) {
        $opts{return_mode} = 'count';
    } elsif (defined($opts{return_mode}) and $opts{return_mode} eq 'count') {
        $opts{count} = 1;
    }

    # выставляем совместимое значение return_mode если не указанно обратного
    my $mode = $opts{return_mode} || 'array';
    # ----------------------------------------------------------------------------------------

        #-----------------------------------------------------------------------------------------
        # убираем возможную сортировку если указано in_id_sort
        # и проставляем sort_list если он не стоит
        #-----------------------------------------------------------------------------------------
        if ($opts{in_id_sort} && $opts{in_id}) {
        $opts{sort_list} = $opts{in_id};
    }

    #-----------------------------------------------------------------------------------------
    # если есть sort_list и return_mode не array или array_ref ругаемся и сбрасываем sort_list
    #-----------------------------------------------------------------------------------------
    if ($opts{sort_list} and ($mode ne 'array') and ($mode ne 'array_ref')) {
        delete $opts{sort_list};
        $log->warning("sort_list set with incompatible return_mode: '$mode'");
    }

    # -----------------------------------------------------------------------------------------
    # убираем все order_by если у нас hash или hash_ref return_mode или стоит in_id_sort
    # тоесть режим возвращаемых данных не предполагает сортировки базой чего либо
    # можно руками выставить если очень хочется в opts
    # todo добавить некий warns если при этот order или order_by в параметрах есть
    # ----------------------------------------------------------------------------------------
    if ( (($mode eq 'hash' or $mode eq 'hash_ref') && !(exists $opts{limit} || exists $opts{offset})) or ($mode eq 'count') or $opts{sort_list}) {
        $opts{no_order} = 1;
        if ($opts{order} or $opts{order_by}) {
            my $mason_comp = ref($HTML::Mason::Commands::m) ? $HTML::Mason::Commands::m->current_comp() : undef;
            my $mason_file = ref($mason_comp) ? $mason_comp->path : undef;
            $log->warning("Указание сортировки проигнорировано так как указан несовместимый режим. ".($mason_file ? "called from $mason_file" : ''));
            delete $opts{order};
            delete $opts{order_by};
        }
    }

    # ----------------------------------------------------------------------------------------
    # Формируем запрос
    # ToDo: добавить механизм кеширования полученных запросов
    #-----------------------------------------------------------------------------------------
    my ($query, $binds) = $proto->_get_sql(%opts);
    return unless ($query);


    my $start = Time::HiRes::time() if ($DEBUG);
    # ---------------------------------------------------------------------------------------
    # Подготавливаем запрос и кешируем полученные prepared запросы (см докуметацию DBI на счет prepare_cached)
    # действительно работает на pgsql 8.0+ и новых версиях DBD (и помогает!)
    # ----------------------------------------------------------------------------------------
    my $sth;
    if ($opts{no_prepare_cached}) {
        unless ($sth = $self->SQL->prepare($$query)) {
           $self->error;
           $log->error("DBI prepare error on $$query\ncalled with opts: ".Data::Dumper::Dumper(\%opts));
           return;
        }
    } else {
        unless ($sth = $self->SQL->prepare_cached($$query, {}, 1)) {
           $self->error;
           $log->error("DBI prepare error on $$query\ncalled with opts: ".Data::Dumper::Dumper(\%opts));
           return;
        }
    }

    # ----------------------------------------------------------------------------------------
    # Выполняем
    # ----------------------------------------------------------------------------------------
    unless ($sth->execute(@$binds)) {
       $self->error;
       $log->error("DBI execute error on $$query\n".Data::Dumper::Dumper($binds)."\ncalled with opts:\n".Data::Dumper::Dumper(\%opts));
       return;
    }
    my $finish1 = Time::HiRes::time() if ($DEBUG);

    #-----------------------------------------------------------------------------------------
    # подготавливаем результаты в нужном формате
    #-----------------------------------------------------------------------------------------
    my ($res, $total);
    ($res, $total) = $self->_prepare_array_results($sth, \%opts) if ($mode eq 'array' or $mode eq 'array_ref');
    ($res, $total) = $self->_prepare_hash_results($sth,  \%opts) if ($mode eq 'hash'  or $mode eq 'hash_ref');
    ($res, $total) = $self->_prepare_count_results($sth, \%opts) if ($mode eq 'count');
    $sth->finish();
    my $finish2 = Time::HiRes::time() if ($DEBUG);

    if ($DEBUG) {
        my $mason_comp = ref($HTML::Mason::Commands::m) ? $HTML::Mason::Commands::m->current_comp() : undef;
        my $mason_file = ref($mason_comp) ? $mason_comp->path : undef;
        my $db_time    = int(10000*($finish1-$start))/10;
        my $core_time  = int(10000*($finish2-$finish1))/10;
        my $total_time = int(10000*($finish2-$start))/10;

        $Contenido::Globals::DB_TIME   += $finish1-$start;
        $Contenido::Globals::CORE_TIME += $finish2-$finish1;
        $Contenido::Globals::DB_COUNT++;

        $log->info("get_items($proto) ".($mason_file ? "called from $mason_file" : '')." SQL: '$$query' with binds: '".join("', '", @$binds)."' fetched: $total records (total work time: $total_time ms, database time $db_time ms, core time $core_time ms)");
    }

    #выдает предупреждение если полученно более 500 обьектов но не выставлен no_limit
    if ($total>999 and !($opts{no_limit} or $opts{limit})) {
        my $mason_comp = ref($HTML::Mason::Commands::m) ? $HTML::Mason::Commands::m->current_comp() : undef;
        my $mason_file = ref($mason_comp) ? $mason_comp->path : undef;
        $log->error("get_items($proto) ".($mason_file ? "called from $mason_file" : '')." SQL: '$$query' with binds: '".join("', '", @$binds)."' fetched 1000 records... гарантированно часть записей не получена из базы... или добавьте no_limit=>1 или разберитесь почему так много данных получаете");
    } elsif ($total>500 and !($opts{no_limit} or $opts{limit})) {
        my $mason_comp = ref($HTML::Mason::Commands::m) ? $HTML::Mason::Commands::m->current_comp() : undef;
        my $mason_file = ref($mason_comp) ? $mason_comp->path : undef;
        $log->warning("get_items($proto) ".($mason_file ? "called from $mason_file" : '')." SQL: '$$query' with binds: '".join("', '", @$binds)."' fetched over 500 ($total) records... или добавьте no_limit=>1 или разберитесь почему так много данных получаете");
    }

    # -----------------------------------------------------------------------------------------
    # возвращаем разные результаты в зависимости от того какой return_mode просят
    # -----------------------------------------------------------------------------------------
    if ($mode eq 'array') {
        return @$res;
    } elsif ($mode eq 'array_ref') {
        return $res;
    } elsif ($mode eq 'hash') {
        return %$res;
    } elsif ($mode eq 'hash_ref') {
        return $res;
    } elsif ($mode eq 'count') {
        return $res;
    } else {
        $log->error("get_items($proto) unsupported return_mode called with opts: ".Data::Dumper::Dumper(\%opts));
        return;
    }
}

#internal only method
sub _prepare_count_results {
    my ($self, $sth, $opts) = @_;
    my ($count) = $sth->fetchrow_array();
    return ($count, 1);
}

#internal only method
sub _prepare_hash_results {
    my ($self, $sth, $opts) = @_;

    #To Do вывод warnings при использование ключей несовместимых с hash режимами... как то: in_id_sort 
    #To Do доделать hash mode для $opts{names} и для $opts{ids}

    # выставляем умолчательное значение hash_by
    my $hash_by = $opts->{hash_by} || 'id';
        # выставляем умолчательное значение hash_index
        my $hash_index = $opts->{hash_index} || 0;

    my %items;
    my $total = 0;

    if ($opts->{names}) {
        while (my $row = $sth->fetch) {
            $items{$row->[0]} = $row->[1];
        }
    } elsif ($opts->{ids} || $opts->{field}) {
        if (ref($opts->{field})) {
                        #hashing by first field by default
                        while (my $row = $sth->fetch) {
                                $items{$row->[$hash_index]} = [@$row]; 
                        }
        } else {
            while (my $row = $sth->fetch) {
                $items{$row->[0]} = 1;
            }
        }
    } else {
        my $item;
        while (my $row = $sth->fetch) {
            eval { $item=$row->[0]->init_from_db($row, $self, $opts->{light}); };
            if ($@) {
                $log->error("Сannot init item from database for $row->[0] because '$@'");
            } else {
                $item->post_init($opts);
                $self->set_object_to_cache($item, 30, $opts) if ($opts->{with_cache});
                $total++;
		if ( exists $item->{$hash_by} && defined $item->{$hash_by} ) {
	                $items{$item->{$hash_by}} = $item;
		} else {
                        $log->warning( "Can not HASH BY parameter [$hash_by]. It doesn't exists in row or the field is empty");
		}
            }
        }
    }
    return (\%items, $total);
}

#internal only method
sub _prepare_array_results {
    my ($self, $sth, $opts) = @_;

    my @items;

    if ($opts->{names} || (ref($opts->{field}) eq 'ARRAY')) {
        @items = @{$sth->fetchall_arrayref()};
    } elsif ($opts->{ids} || $opts->{field}) {
        while (my $row = $sth->fetch) {
            push @items, $row->[0];
        }
    } else {
        my $item;
        while (my $row = $sth->fetch) {
            eval { $item=$row->[0]->init_from_db($row, $self, $opts->{light}); };
            if ($@) {
                $log->error("Cannot init item from database for $row->[0] because '$@'");
            } else {
                $item->post_init($opts);
                $self->set_object_to_cache($item, 30, $opts) if ($opts->{with_cache});
                push @items, $item;
            }
        }
    }

    return (\@items, scalar(@items));
}

#понять бы зачем этот метод нужен
sub get_objects {
    return shift->get_items('Contenido::Object', @_);
}

# ------------------------------------------------------------------------------------------------
# Получение документов, подходящих под условия отбора:
#   @documents = $keeper->get_documents( %search_options )
#
# Параметры отбора:
#   s - номер секции (если задан параметр dive, то s может содержать только один номер секции, в противном случае s
#   может содержать ссылку на массив номеров секций);
#   sfilter - секция-фильтр. В конечную выборку включаются только документы, попадающие в sfilter (если та задана).
#   Может быть задан массив секций (с помощью ссылки на массив);
#   dive - если установлен в истину, то отбор будет производиться по все ее детям;
#   intersect - флаг "пересечение секций". Если установлен, то будут отобраны документы, привязанные ко всем
#   перечисленным в s секциям, если не установлен - к любой из перечисленных секций.
#   include_parent - если этот параметр задан, то отбор будет происходить и из самой секции. По умолчанию - задан;
#   date_equal - точное соответствие даты (YYYY-MM-DD);
#   date - ссылка на массив с двумя датами (началом и концом интервала);
#   previous_days - запрос за ... последних дней;
#   datetime    - custom dtime filters допустимые значения 'future','past','today' 
#
#   use_mtime   - использовать во всех выборках по времени mtime вместо dtime (!)
#   use_ctime   - использовать во всех выборках по времени ctime вместо dtime (!)
#
#   status - заданный идентификатор статуса (или ссылка на массив со статусами);
#   class - заданный класс объекта (--"--);
#   order - порядок выборки:
#   ['date','direct'] - по дате в прямом порядке;
#   ['date','reverse'] - по дате в обратном порядке;
#   ['name','direct'/'reverse'] - по имени в прямом или обратном порядке;
#   [] - без сортировки
#
#   in_id [id,id,id,...] - выборка по идентификаторам (по целой пачке - ссылка на массив идентификаторов)
#   name - поиск по названию;
#   excludes - ссылка на массив всех идентификаторов, которые надо исключить из отбора
#   class_excludes - ссылка на массив классов, исключенных для выборки
#   count - если задан в единицу, то вернет число - количество элементов
#   ids - если задан в единицу, то вернет только идентификаторы объектов...
#   names - если задан в единицу, то вернет набор пар [идентификатор, имя]
#   offset - возможность задать оффсет для выборки документов...
#
#   like - выборка с помощью like (должно быть задано name)
#   ilike - выборка с помощью ilike (должно быть задано name)
#
#   light - если установить в 1, то вернет объекты без выполнения restore()
#   limit - ограничение на количество возвращаемых элементов
#
#   Три параметра, которые требуются для построения join-запросов. Рекомендуется использовать их
#   для выборок документов связанных с каким-то конкретным документом какой-то конкретной связью:
#   lclass - класс связи
#   ldest - идентификатор dest_id
#   lsource - идентификатор source_id
#   lstatus - статус в таблице связей
#   id - выборка 1 документа по id
# ------------------------------------------------------------------------------------------------
sub get_documents {
    return shift->get_items('Contenido::Document', @_);
}



# ------------------------------------------------------------------------------------------------
# Получение связей, подходящих под условия отбора:
#   @links = $keeper->get_links( %search_options )
#
# Параметры отбора:
#   status - заданный идентификатор статуса (или ссылка на массив идентификаторов);
#   class - заданный класс объекта (--"--);
#
#   dest_id - идентификатор (или ссылка на массив идентификаторов)
#   source_id - идентификатор (или ссылка на массив идентификаторов)
#
#   excludes - ссылка на массив всех идентификаторов, которые надо исключить из отбора
#   class_excludes - ссылка на массив классов, исключенных для выборки
#
#   count - если задан в единицу, то вернет число - количество элементов
#   ids - если задан в единицу, то вернет только идентификаторы связей...
#
#   offset - возможность задать оффсет для выборки документов...
#
#   light - если установить в 1, то вернет объекты без выполнения restore()
#   limit - ограничение на количество возвращаемых элементов
# ------------------------------------------------------------------------------------------------
sub get_links {
    return shift->get_items('Contenido::Link', @_);
}



# ------------------------------------------------------------------------------------------------
# Получение секций, подходящих под условия отбора:
#   @sections = $keeper->get_sections( %search_options )
#
# Параметры отбора:
#   s - номер родительской;
#
#   status - заданный идентификатор статуса (или ссылка на массив);
#   class - заданный класс секции (--"--);
#   order - порядок выборки:
#   ['name','direct'/'reverse'] - по имени в прямом или обратном порядке;
#   [] - без сортировки
#   name - поиск по названию;
#
#   in_id [id,id,id,...] - выборка по идентификаторам (по целой пачке)
#   ids - если задан в единицу, то вернет только идентификаторы секций...
#   names - если задан в единицу, то вернет набор пар [идентификатор, имя]
#
#   light - если установить в 1, то вернет объекты без выполнения restore()
#   limit - ограничение на размер выборки
# ------------------------------------------------------------------------------------------------
sub get_sections {
    return shift->get_items('Contenido::Section', @_);
}

# ----------------------------------------------------------------------------
# Метод для получения списка пользователей системы
#   @users = $keeper->_get_users( %search_options )
#
# Параметры отбора:
#   s - номер секции (s может содержать ссылку на массив номеров секций);
#   intersect - флаг "пересечение секций". Если установлен, то будут отобраны документы, привязанные ко всем
#   перечисленным в s секциям, если не установлен - к любой из перечисленных секций.
#   class - заданный класс объекта (--"--);
# ----------------------------------------------------------------------------
sub _get_users {
    return shift->get_items('Contenido::User', @_);
}
# XXX Не использовать - будет удалена в следующих версиях. Использовать _get_users()
sub get_users {
    return shift->_get_users(@_);
}


# -------------------------------------------------------------------------------------------------
# Получение деревца...
# Параметры:
#   light => облегченная версия
#   root => корень дерева (по умолчанию - 1)
# -------------------------------------------------------------------------------------------------
sub get_tree {
	my $self = shift;
    return Contenido::Section->new($self)->get_tree(@_);
}

sub get_section_tree {
    my $self = shift;
    my ( %opts ) = @_;

    delete $opts{return_mode}		if exists $opts{return_mode};
    delete $opts{order_by}		if exists $opts{order_by};
    delete $opts{no_limit}		if exists $opts{no_limit};
    my $root_id = delete $opts{root_id};
    my $sections = $self->get_sections (
		%opts,
		return_mode	=> 'array_ref',
		order_by	=> 'sorder',
		no_limit	=> 1,
		light		=> exists $opts{light} ? $opts{light} : 1,
	);
    my %section_hash = map { $_->id => $_ } @$sections	if ref $sections eq 'ARRAY';
    my %tree;
    if ( ref $sections eq 'ARRAY' ) {
	foreach my $sect ( @$sections ) {
		if ( !$sect->pid || $sect->id == 1 ) {
			$tree{0} = $sect;
		} else {
			if ( exists $tree{$sect->pid} ) {
				if ( exists $tree{$sect->pid}{children} ) {
					push @{ $tree{$sect->pid}{children} }, $sect;
				} else {
					$tree{$sect->pid}{children} = [$sect];
				}
			} elsif ( exists $section_hash{$sect->pid} ) {
				$tree{$sect->pid} = $section_hash{$sect->pid};
				$tree{$sect->pid}{children} = [$sect];
			}
			if ( $root_id && $sect->id == $root_id ) {
				$tree{root} = $sect;
			}
		}
	}
	if ( (!$root_id || !exists $tree{root}) && exists $tree{0} ) {
		$tree{root} = $tree{0};
	}
    }
    return \%tree;
}

# -------------------------------------------------------------------------------------------------
# Получаем объект по идентификатору. А зачем вообще нужен этот метод? А! Потому что мы
#  еще не знаем имени класса.
#
# Этот метод получает тип того, что мы извлекаем (секция, документ, связь)
# -------------------------------------------------------------------------------------------------
sub __get_by_id__ {
    my ($self, $proto, %opts) = @_;
    return unless ($opts{id});
    #на всякий случай устанавливаем возврат только 1 значения из базы
    $opts{limit} = 1;
    #отключаем сортировку как бессмысленную
    $opts{no_order} = 1;
    my ($item)=$self->get_items($proto, %opts);
    return $item;
}

sub get_document_by_id {
    my ($self, $id, %opts) = @_;
    return unless $id;
    $opts{id} = $id;
    return $self->__get_by_id__('Contenido::Document', %opts);
}

sub get_section_by_id {
    my ($self, $id, %opts) = @_;
    return unless $id;
    $opts{id} = $id;
    return $self->__get_by_id__('Contenido::Section', %opts);
}

sub get_link_by_id {
    my ($self, $id, %opts) = @_;
    return unless $id;
    $opts{id}=$id;
    return $self->__get_by_id__('Contenido::Link', %opts);
}

sub get_user_by_id {
    my ($self, $id, %opts) = @_;
    return unless $id;
    $opts{id}=$id;
    return $self->__get_by_id__('Contenido::User', %opts);
}


# -------------------------------------------------------------------
# Умный метод. Сначала ищет объект в $request->{_cache_},
# потом в memcached (если включена поддержка, конечно), и только потом уже идёт в базу.
# Полученные из базы данные складывает в $request и в memcached.
# $level это с кеша какого уровня мы все это достали (10 уровень локальный кеш, 20 уровень memcached, 30 база)
sub get_object_by_id {
    my ($self, $id, %opts) = @_;

    my ($object, $level) = $self->get_object_from_cache($id, \%opts) unless ($opts{expire});

    #не нашли в кешах идем в базу
    unless ($object) {
        $object = $self->__get_by_id__($opts{proto}||'Contenido::Document', %opts, id=>$id);
        $level = DATA_SOURCE_DATABASE;
    }
    
    #ну не шмогла я нешмогла... aka нет такого на белом свете объекта
    unless ($object) {
        return;
    }

    #если с 10 уровня достали то ничего более кешировать всеравно нет смысла
    $self->set_object_to_cache($object, $level, \%opts, $state->{memcached_set_mode})
        if $level > DATA_SOURCE_LOCAL;

    return $object;
}

# -------------------------------------------------------------------
# Тоже умный метод. Зачастую в таблицах id является суррогатным ключом,
# а некоторое символическое имя - настоящим, например, login в таблицах
# users. Данная функция кеширует соответствие уникального символического
# имени объекта и его id, позволяя не обращаться к базе всякий раз при
# получении данных таким образом.
# -------------------------------------------------------------------
sub get_object_by_unique_key {
    my ($self, $unique, %opts) = @_;

    return undef unless defined $unique;

    my ($id, $level) = (undef, DATA_SOURCE_DATABASE);
    my %key_list = ();

    my $class = $opts{class};
    return undef unless defined $class;

    my $key = $class->get_object_unique_key($unique);
    return undef unless $key;

    my $object = undef;

    unless ($opts{expire}) {
        if (exists $request->{_cache_}->{$key}) {
            ($id, $level) = $request->{_cache_}->{$key};
            $level = DATA_SOURCE_LOCAL;
        } elsif (($self->{state}->{memcached_enable}) &&
                 (defined ($id = $self->MEMD->get($key)))) {
            $level = DATA_SOURCE_MEMCACHED;
        }

        # Соответствие в кеше имеется, ищем объект по id
        if (defined $id) {
            $object = $self->get_object_by_id($id, %opts);
            # Если какая-то скотина умудрилась грохнуть объект в обход зависимостей
            unless (defined $object) {
                $self->MEMD->delete($key);
            }
        }
    }

    # Соответствие не найдено или найдено неверное.
    unless (defined $object) {
        my $attr = $class->class_table->unique_attr;
        ($object) =
            $self->get_items(
                $class,
                'limit' => 1,
                'no_order' => 1,
                $attr => $unique,
                'class' => $class
            );
    }

    # Объект с таким уникальным ключем не найден.
    return undef unless defined $object;

    $self->set_object_unique_key_to_cache($object, $level, \%opts)
        if $level > DATA_SOURCE_LOCAL;

    return $object;
}

sub set_object_unique_key_to_cache {
    my ($self, $object, $level, $opts) = @_;

    my $key = $object->get_object_unique_key;

    if (defined $key) {
        if ($level > DATA_SOURCE_LOCAL) {
            $request->{_cache_}->{$key} = $object->id;
        }
        if (($level > DATA_SOURCE_MEMCACHED) and ($self->state->{memcached_enable})) {
            my $expire =
                exists $opts->{'expire_in'}
                    ? $opts->{'expire_in'}
                    : $object->memcached_expire;
            if ($self->state->{memcached_delayed}) {
                $request->{_to_memcache}{$key} = [$object->id, $expire, 'set'];
            } else {
                $self->MEMD->set($key, $object->id, $expire);
            }
        }
    }

    return $object;
}

#достает обьект из кеша по его id
sub get_object_from_cache {
    my ($self, $id, $opts) = @_;

    my $object;
    my %key_list = ();

    #определяем по какому классу работаем (надо для определения ключа кеширования)
    my @classes;
    if (ref($opts->{class}) eq 'ARRAY') {
            foreach my $class (@{$opts->{class}}) {
                    $key_list{$class->get_object_key($id, $opts)} = $class;
            }
    } elsif ($opts->{class}) {
        $key_list{$opts->{class}->get_object_key($id, $opts)} = $opts->{class};
    } elsif ($opts->{table}) {
        $key_list{$opts->{table}->_get_object_key(undef, $id, $opts)} = $opts->{table};
    } else {
        my $class = $opts->{proto} || 'Contenido::Document';
        $key_list{$class->get_object_key($id, $opts)} = $class;
    }

    while (my ($object_key, $class) = each(%key_list)) {
        if (defined($request->{_cache_}->{$object_key})) {
            return ($request->{_cache_}->{$object_key}, DATA_SOURCE_LOCAL);
        } elsif ($self->MEMD) {
            if ($object = $self->MEMD->get($object_key)) {
                $object->recover_from_cache($self, $opts) if $object->can('recover_from_cache');
                return ($object, DATA_SOURCE_MEMCACHED);
            } else {
                return;
            }
        }
    }
    return;
}

#может кешировать любой обьект поддерживающий метод set_to_cache (не обязательно производное Contenido::Object)
#$level это с кеша какого уровня мы все это достали (10 уровень локальный кеш, 20 уровень memcached, 30 база)
#$mode => set|add (default set)
sub set_object_to_cache {
    my ($self, $object, $level, $opts, $mode) = @_;

    #выставляем ключ по обьекту
    my $object_key = $object->can('get_object_key') ? $object->get_object_key($opts) : ref($object).'|'.$object->id();

    if ($level > DATA_SOURCE_LOCAL) {
        $request->{_cache_}->{$object_key} = $object;
    }
    if ($level > DATA_SOURCE_MEMCACHED and $self->state->{memcached_enable}) {
        my $value = $object->can('prepare_for_cache') ? $object->prepare_for_cache($opts) : $object;
        my $expire = exists $opts->{'expire_in'} ? $opts->{'expire_in'} : $object->memcached_expire;
        if ($self->state->{memcached_delayed}) {
            $request->{_to_memcache}{$object_key} = [$value, $expire, $mode];
        } else {
            if ($mode && $mode eq 'add') {
                $self->MEMD->add($object_key, $value, $expire);
            } else {
                $self->MEMD->set($object_key, $value, $expire);
            }
        }
    }
    return $object;
}

sub get_user_by_login {
    my ($self, $login, %opts) = @_;
    return unless $login;
    $opts{login}=$login;
    my ($item)=$self->get_items('Contenido::User', %opts);
    return $item;
}

############################## DIFFERENT TRASH CODE #######################################################################
# ----------------------------------------------------------------------------
# Обработчик ошибки. Очень важная функция, именно в ней мы будем
#  хранить все возможные коды ошибок и так далее...
# надо ли это вообще вот в чем вопрос
# ----------------------------------------------------------------------------
sub error {
    my $self = shift;

    $self->{last_error} = shift || $self->SQL->errstr();
    chomp($self->{last_error});

    my $mason_comp = ref($HTML::Mason::Commands::m) ? $HTML::Mason::Commands::m->current_comp() : undef;
    my $mason_file = ref($mason_comp) ? $mason_comp->path : undef;

    $log->error(($mason_file ? "Called from $mason_file" : '')."$self->{last_error}");
}


sub minimize_image {
    my $self = shift;
    my $IMAGE = shift;
    my $PREVIEW = shift;

    my $SLINE = $self->{convert_binary};
    my $PREVIEWLINE = " -geometry '".($PREVIEW || $self->{preview})."' -quality 80";
    my $SFILE = $IMAGE->{filename};
    my $DFILE = $SFILE;
    $DFILE =~ s/\.([^\.]*)$/\.mini\.$1/;
    $SLINE = $SLINE.' '.$PREVIEWLINE.' '.$self->{state}->{images_directory}.'/'.$SFILE.' '.$self->{state}->{images_directory}.'/'.$DFILE;

    my $RESULT = `$SLINE`;
    if (length($RESULT) > 0)
    {
        $log->error("При вызове '$SLINE' произошла ошибка '$RESULT' ($@)");
        return undef;
    }
    
    $IMAGE->{mini}->{filename} = $DFILE;
    ($IMAGE->{mini}->{width}, $IMAGE->{mini}->{height}) = Image::Size::imgsize($self->{state}->{images_directory}.'/'.$DFILE);

    return $IMAGE;
}

sub get_sorted_documents {
    my ($self, %opts) = @_;
    unless ($opts{s}) {
        my $mason_comp = ref($HTML::Mason::Commands::m) ? $HTML::Mason::Commands::m->current_comp() : undef;
        my $mason_file = ref($mason_comp) ? $mason_comp->path : undef;
        $log->warning("Method $keeper->get_sorted_documents(...) called without required param s=>".($mason_file ? "called from $mason_file":"")."\ncalled with opts:\n".Data::Dumper::Dumper(\%opts));
        return;
    }
    my $section = $self->get_section_by_id($opts{s});
    if ($section->{_sorted}) {
        $opts{sort_list} = [split(',', $section->_sorted_order())];
    } else {
        $log->warning("Method $keeper->get_sorted_documents(...) called with s=>$opts{s} but section have _sorted disabled\n");
    }
    return $self->get_documents(%opts);
}

sub _all_childs {
    my ($self, $s)=@_;
    return [] unless $s;
    # Получаем всех детишек от данной секции и вглубь...
    my $section = $self->get_section_by_id($s, light=>1);
    return [] unless (ref($section));
    my @all_childs = $section->childs(100);
    return \@all_childs;
}

# -------------------------------------------------------------------
# Инициализирует $keeper->{MEMD}
#--------------------------------------------------------------------
sub MEMD {
    my $self = shift;

    return undef unless $self->{state}->{memcached_enable};

    unless ($self->{MEMD} && ref($self->{MEMD}) && $self->{MEMD}->{servers}) {
        my $implementation = $self->state()->memcached_backend();
        $self->{MEMD} = $implementation->new({
            servers => $self->state()->memcached_servers(),
            debug => $DEBUG,
            compress_threshold => 10_000,
            namespace => $self->state()->memcached_namespace,
            enable_compress => $self->state()->memcached_enable_compress(),
            connect_timeout => 0.1,
            select_timeout => $self->state()->memcached_select_timeout(),
            check_args => 'skip'
        });
    }
    return $self->{MEMD};
}

# ----------------------------------------------------------------------------
# Это умный AUTOLOAD. Ловит методов для установки/чтения полей...
# Версия 0.2
# ----------------------------------------------------------------------------
sub AUTOLOAD {
    my $self = shift;
    my $attribute = $AUTOLOAD;

    $attribute =~ s/.*:://;
    return undef    unless  $attribute =~ /[^A-Z]/;     # Отключаем методы типа DESTROY

    unless (ref $self) { 
        $log->error("Прямой вызов неизвестной функции $AUTOLOAD()");
        return undef;
    } elsif (! exists($self->{attributes}->{$attribute})) {
        $log->error("Вызов метода, для которого не существует обрабатываемого свойства: ->$attribute()");
        return undef;
    }

    $self->{ $attribute } = shift @_  if scalar @_ > 0;
    return $self->{ $attribute };
}


1;

