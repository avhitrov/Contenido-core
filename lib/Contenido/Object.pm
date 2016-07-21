package Contenido::Object;

# ----------------------------------------------------------------------------
# Класс Объект.
# Родительский класс для всех типов. Раз уж мы используем ООП, то давайте
#  действительно его использовать.
#
# От него мы будем наследовать механизмы работы с директорией данных, 
#  механизмы работы с бинарными файлами и так далее...
# ----------------------------------------------------------------------------

use strict;
use warnings;
use locale;

use vars qw($VERSION $AUTOLOAD);
$VERSION = '4.1';

use Utils;
use Contenido::Globals;
use Contenido::File;
use Data::Dumper;
use Data::Recursive::Encode;
use JSON::XS;

use DBD::Pg;
use Encode;

use SQL::ProtoTable;

our $json_n = JSON::XS->new->utf8(0);
our $json_u = JSON::XS->new->utf8(1);

# required properties теперь берутся из свойств таблицы
sub required_properties {
    my $self=shift;
    my $class = ref($self) || $self;
    if ($class->can('class_table')) {
        return $self->class_table->required_properties();
    } else {
        $log->error("$class cannot method class_table");
        return ();
    }
}

sub extra_properties {
    return ();
}

sub post_init {
    return;
}

sub pre_store {
    return 1;
}

sub post_store {
    return 1;
}

sub post_finish_store {
    return 1;
}

sub pre_delete {
    return 1;
}

sub post_delete {
    return 1;
}

sub pre_abort {
    return 1;
}

sub t_abort {
    my $self = shift;
    $self->pre_abort();
    return $self->keeper->t_abort();
}

sub new {
    $log->error("Method 'new' cannot be called for class Contenido::Object");
    die;
}

sub class_table {
    $log->error("Method 'class_table' cannot be called for Contenido::Object");
    die;
}              

#обьявляем пустой DESTROY чтобы эта зараза в AUTOLOAD не попадала
sub DESTROY {}

#получение ключа в кеше по $object или по $class/$id
#can be overloaded in class
sub get_object_key {
    my $self = shift;
    return $self->class_table->_get_object_key($self, @_);
}

#получение ключа в кеше по $object или по $class/$unique
#can be overloaded in class
sub get_object_unique_key {
    my $self = shift;
    return $self->class_table->_get_object_unique_key($self, @_);
}

#скорость тут совершенно не критична... исполняется 1 раз на каждый класс
#??? возможно лучше сделать методы доступа к свойствам на этом этапе
sub class_init {
    my $self = shift;
    my $class = ref($self) || $self; 

    {
        no strict 'refs';
        return 1 if (${$class.'::class_init_done'});
        use strict;
    }

    #инициализируем описатель таблицы
    if ($class->can('class_table')) {
        eval { SQL::ProtoTable->table_init($class->class_table) };
        do { $log->error("Cannot initialise class $class!"); die } if ($@);
    }

    #валидация корректности класса (todo)
    #$self->class_validate();

    my $funct;

    #начало текста функции инициализатора класса из базы
    my $funct_begin = "
    my (\$class, \$row, \$keeper, \$light) = \@_;
";

    my $funct_start_obj ='  return bless({';
    my $funct_end_obj = "}, '$class');
";
    my $funct_begin_if_light = '
    if ($light) {';
    my $funct_elsif_light = '
    } else {';
    my $funct_endif_light = '
    }';

    my $func_start_encode = '';
    my $func_end_encode = '';

    if ($state->db_encode_data) {
        $func_start_encode = 'Encode::encode("'.$state->db_encode_data.'", ';
        $func_end_encode = ', Encode::FB_HTMLCREF)';
    }
    
    my @funct_default_fields = ("class=>'$class'", "keeper=>\$keeper", "__light=>\$light");
    my @funct_exra_fields = ();

    #те вещи которые надо заранее подсчитать при инициализации класса
    my (%props, %attributes, @extra_fields, %virtual_fields, @structure);

    my $pos = 0;
    #последовательность reload: required_properties может быть перекрытым через add_properties который может быть далее перекрыт через extra_properties

    foreach my $prop ($self->required_properties()) {
        my $attr = $prop->{attr};
        unless ($attr) {
            $log->error("$class have wrong data in required_properties (no attr for field)");
            next;
        }
        unless ($prop->{db_type} || $prop->{virtual}) {
            $log->warning("$class with class table: ".$self->class_table()." property '$attr' missing db_type in table descriptor... can be incompatible with future versions!");
        }

        $props{$attr} = $prop;

        push @structure, $prop;

        #вообще с классом надо подумать... есть идея что для части таблиц класс поле не нужно... только место ест
        next if ($attr eq 'class');

        #поля которые идут в DB могут быть обьявлены ТОЛЬКО в required_properties
        if (exists($prop->{db_field}) and $prop->{db_field}) {
            $pos++;
            #$DBD::Pg versions since 2.0.0 do it automatically
            if ($DBD::Pg::VERSION=~/^1\./ and $prop->{db_type} and (($prop->{db_type} eq 'integer[]') or ($prop->{db_type} eq 'integer_ref[]'))) { 
                push @funct_default_fields, "$attr=>[(\$row->[$pos] and \$row->[$pos]=~/^{(\\d+(?:,\\d+)*)}\$/) ? split(/,/, \$1) : ()]";
            } else {
                push @funct_default_fields, "$attr=>$func_start_encode\$row->[$pos]$func_end_encode";
            }
        }

        if ($prop->{db_type} and ($prop->{db_type} eq 'integer[]')) {
            $attributes{$attr} = 'ARRAY';
        } elsif($prop->{db_type} and ($prop->{db_type} eq 'integer_ref[]')) {
            $attributes{$attr} = 'ARRAY_REF';                                
        } else {
            $attributes{$attr} = 'SCALAR';
        }
    }
    push @funct_default_fields, "attributes=>\$${class}::attributes";

    my $have_extra = $self->class_table->have_extra;
    if ($have_extra) {
        my @ap = $self->add_properties()    if $self->can('add_properties');
        #последовательность reload: required_properties может быть перекрытым через add_properties который может быть далее перекрыт через extra_properties
        foreach my $prop (@ap, $self->extra_properties()) {
            my $attr = $prop->{attr};
            if (exists($props{$attr})) {
                #reload code
                $log->info("Reloaded property $attr for class $class") if ($DEBUG);
                while ( my ($field, $value) = each(%$prop)) {
                    $props{$attr}->{$field} = $value;
                }
            } else {
                $props{$attr} = $prop;
                #если это был не overload то это новое extra поле
                push @extra_fields, $attr; 
                push @structure, $prop;
                $attributes{$attr} = 'SCALAR';
                if ($prop->{virtual}) {
                    #выставляем что это вообще виртуальный атрибут
                    $virtual_fields{$attr} = 1;
                } else {
                    #инициализируем из dump все кроме виртуальных свойств
                    push @funct_exra_fields, "$attr=>(\$keeper->serialize_with eq 'json' ? (ref \$dump->{$attr} ? Data::Recursive::Encode->encode_utf8(\$dump->{$attr}) : Encode::encode('utf-8', \$dump->{$attr}, Encode::FB_HTMLCREF) ) : $func_start_encode\$dump->{$attr}$func_end_encode)";
                }
            }
        }
    }

    $attributes{class}  = 'SCALAR';

    #если у обьекта есть extra_attributes надо бы вызвать restore_extras если не указан light
    #наличие have_extra у таблицы не ведет к обязательному наличию extra_fields
    if (@extra_fields) {
        # --------------------------------------------------------------------------------------------
        # Чтение из одного дампа в базе данных
        # --------------------------------------------------------------------------------------------
        my $funct_eval_dump .= '
            my $dump = $keeper->serialize_with eq \'json\' ? (Contenido::Object::eval_json(\\$row->[-1]) || {}) : Contenido::Object::eval_dump(\\$row->[-1]);
';
        $funct = $funct_begin.$funct_begin_if_light.$funct_start_obj.join(', ', @funct_default_fields).$funct_end_obj.$funct_elsif_light.$funct_eval_dump.$funct_start_obj.join(', ', (@funct_default_fields, @funct_exra_fields)).$funct_end_obj.$funct_endif_light;
    } else {
        $funct = $funct_begin.$funct_start_obj.join(', ', @funct_default_fields).$funct_end_obj;
    }
#    warn "Restore function: [$funct]\n";

    create_method($class, 'init_from_db', $funct);

    {
        no strict 'refs';
        ${$class.'::structure'}     = \@structure;
        ${$class.'::attributes'}    = \%attributes;
        ${$class.'::extra_fields'}  = \@extra_fields;
        ${$class.'::virtual_fields'}    = \%virtual_fields;
        ${$class.'::class_init_done'}   = 1;
    }
    return 1;
}

# -------------------------------------------------------------------------------------------
# Сохраняет внешние свойства объекта в зависимости от выбранного способа...
# -------------------------------------------------------------------------------------------
sub store_extras {
    my $self = shift;
    my %opts = @_;
    do {$log->error("Метод store_extras() можно вызывать только у объектов, но не классов\n"); die } unless ref($self);

    do { $log->error("В объекте не определена ссылка на базу данных"); die } unless ref($self->keeper);
    do { $log->error("Не задан режим сохранения данных (insert/update)"); die } if (($opts{mode} ne 'insert') && ($opts{mode} ne 'update'));
    do { $log->error("Не задан идентификатор объекта (а должен быть задан в обязательном порядке)"); die }  unless($self->id());

    if ($self->keeper->store_method() eq 'sqldump') {
        my $extra_table=$self->class_table->extra_table;
        do { $log->error("No extra table for class $self->{class}"); die } unless ($extra_table);
        if ($opts{mode} eq 'insert') {
            $self->keeper->TSQL->do("INSERT INTO $extra_table (id, data) VALUES (?, ?)", {}, $self->id(), $self->_create_extra_dump()) || $self->t_abort();
        } else {
            $self->keeper->TSQL->do("UPDATE $extra_table SET data=? WHERE id=?", {}, $self->_create_extra_dump(), $self->id()) || $self->t_abort();
        }

    } elsif ($self->keeper->store_method() eq 'toast') {
        my $table = $self->class_table->db_table;
        do { $log->error("There no db_table for class $self->{class}"); die } unless ($table);
        $self->keeper->TSQL->do("UPDATE $table SET data=? WHERE id=?", {}, $self->_create_extra_dump(), $self->id()) || $self->t_abort();

    } else {
        $log->error("Метод сохранения объектов задан неверно! Возможные значения - TOAST, SQLDUMP");
        die;
    }

    return 1;
}


sub _create_extra_dump {
    my $self = shift;

    do { $log->error("Метод _create_extra_dump можно вызывать только у объектов, но не классов"); die }   unless ref($self);

    my $class_table = $self->class_table; 
    return undef unless ($class_table and $class_table->have_extra);

    my $extra_fields = [];
    my $virtual_fields = {};

    if ( $self->keeper->serialize_with eq 'json' ) {
        no strict 'refs';
        #пропускаем virtual attributes
        #да я знаю что так писать нельзя но блин крута как смотрится
        $extra_fields = ${$self->{class}.'::extra_fields'};
        $virtual_fields = ${$self->{class}.'::virtual_fields'};
        #надо использовать все extra поля кроме тех что находятся в virtual_fields списке
        if ($state->db_encode_data) {
            return Encode::decode('utf-8', $json_n->encode ({map { $_=> Encode::decode($state->db_encode_data, $self->{$_}, Encode::FB_HTMLCREF) } grep { !$virtual_fields->{$_} && (defined $self->{$_}) } @$extra_fields}));
        } else {
            my $content = Encode::decode('utf-8', $json_n->encode ({map { $_=>$self->{$_} } grep { !$virtual_fields->{$_} && (defined $self->{$_}) } @$extra_fields}));
            return $content;
        }
    } else {
        no strict 'refs';
        #пропускаем virtual attributes
        #да я знаю что так писать нельзя но блин крута как смотрится
        $extra_fields = ${$self->{class}.'::extra_fields'};
        $virtual_fields = ${$self->{class}.'::virtual_fields'};
        #надо использовать все extra поля кроме тех что находятся в virtual_fields списке
        local $Data::Dumper::Indent = 0;
        if ($state->db_encode_data) {
            return Data::Dumper::Dumper({map { $_=> Encode::decode($state->db_encode_data, $self->{$_}, Encode::FB_HTMLCREF) } grep { !$virtual_fields->{$_} && (defined $self->{$_}) } @$extra_fields});
        } else {
            return Data::Dumper::Dumper({map { $_=>$self->{$_} } grep { !$virtual_fields->{$_} && (defined $self->{$_}) } @$extra_fields});
        }
    }
}

# -------------------------------------------------------------------------------------------
# Считывает внешние свойства объекта в зависимости от выбранного способа...
# -------------------------------------------------------------------------------------------
sub restore_extras {
    my ($self, $row) = @_;

    do { $log->error("Метод restore_extras() можно вызывать только у объектов, но не классов"); die } unless ref($self);

    my $extra_fields;
    {
        no strict 'refs';
        $extra_fields = ${$self->{class}.'::extra_fields'};
    }

    if (@$extra_fields) {
        if (($Contenido::Globals::store_method eq 'toast') or ($Contenido::Globals::store_method eq 'sqldump')) {
            # --------------------------------------------------------------------------------------------
            # Чтение из одного дампа в базе данных
            # --------------------------------------------------------------------------------------------
            my $dump_ = $self->keeper->serialize_with eq 'json' ? eval_json(\$row->[-1]) : eval_dump(\$row->[-1]);
            if ($dump_) {
                foreach (@$extra_fields) {
                    $self->{$_} = $dump_->{$_};
                }
            }
        } else {
            $log->error("Метод сохранения объектов задан неверно! Возможные значения - TOAST, SQLDUMP, SINGLE, DUMP");
            die;
        }
    }
}

sub _serialize {
    my $self = shift;
    my $data = shift;
    if ( $self->keeper->serialize_with eq 'json' ) {
	return $json_n->encode(ref $data ? $data : {});
    } else {
	local $Data::Dumper::Indent = 0;
	return Data::Dumper::Dumper($data);
    }
}

# ----------------------------------------------------------------------------
# Выбирает хеш из перл-дампа по атрибуту
# Пример:
# my $pics_hashe = $doc->get_data('images');
# ----------------------------------------------------------------------------
sub get_data {
    my $self = shift;
    my $attr = shift;
    my $encode = shift;
    my $data  = $self->keeper->serialize_with eq 'json' ? ( $encode ? Data::Recursive::Encode->encode_utf8(eval_json(\$self->{$attr})) : eval_json(\$self->{$attr}) ) : eval_dump(\$self->{$attr});
    return ($data || {});
}

# ----------------------------------------------------------------------------
# Выбирает картинку из обьекта по ее атрибуту
# Возвращает обьект типа Contenido::Image
#
# Пример:
# my $pic = $doc->get_pic('top_image');
#
# ----------------------------------------------------------------------------
sub get_pic {
    my $self = shift;
    my $attr = shift;

    Contenido::Image->new (
        img => $self->get_data($attr, 'encode'),
        attr    => $attr,
    );
}

# ----------------------------------------------------------------------------
# Выбирает картинки из обьекта по атрибуту их хранилища
# Возвращает массив обьектов типа Contenido::Image
#
# Пример:
# my @pics = $doc->get_pics('images', {
#   order   => 'reverse',   # порядок сортировки по ключам ('reverse' ,'asis', по умолчанию - 'direct')
#   keys    => [3..12, 1..2],   # диапазон ключей
#   });
#
# ----------------------------------------------------------------------------
sub get_pics {
    my $self = shift;
    my $attr = shift;
    my %args = ref $_[0] ? %{$_[0]} : @_;
    my $pics = $self->get_data($attr, 'encode');

    # Дефолты
    $args{order} ||= 'direct';

    # выясняем ключики нужных нам картинок...
    my @keys = ref $args{keys} ne 'ARRAY' ? grep {s/\D+//, /^\d+$/} keys %{$pics} : @{$args{keys}};

    my $prefix = 'image_'; # а надо бы, чтоб так: my $prefix = $attr.'_';

    map { Contenido::Image->new (
        img => $pics->{$prefix.$_},
        attr    => $prefix.$_,
        group   => $attr,
        key => $_,
    )} sort { $args{order} eq 'asis' ? 1 : $args{order} ne 'reverse' ? $a <=> $b : $b <=> $a } @keys;
}

sub _get_sql {
    my ($self,%opts)=@_;

    #детект класса таблицы по которой работаем
    my $table  = $self->_get_table(%opts);
    unless ($table) {
        $log->error("Не могу получить таблицу запроса");
        return;
    }

    my ($query, $binds) = $table->generate_sql(%opts);
    my @binds = ();

    if ($state->db_encode_data) {
        foreach my $i (0..$#{$binds}) {
            if ( ref $binds->[$i] ) {
                $binds->[$i] = Data::Recursive::Encode->decode($state->db_encode_data, $binds->[$i], Encode::FB_HTMLCREF);
            } else {
                $binds->[$i] = Encode::decode($state->db_encode_data, $binds->[$i], Encode::FB_HTMLCREF);
            }
        }
    } elsif ( $DBD::Pg::VERSION >= '3' ) {
        foreach my $i (0..$#{$binds}) {
            if ( ref $binds->[$i] ) {
                $binds->[$i] = Data::Recursive::Encode->decode_utf8($binds->[$i]);
            } else {
                $binds->[$i] = Encode::decode('utf-8', $binds->[$i], Encode::FB_HTMLCREF);
            }
        }
    }

    return $query, $binds;
}

# Формат использования:
#  $document->store()
#
# Если $id задан то мы считаем, что этот объект в базе есть. Если
#  не задан, то мы считаем, что этого объекта в базе нет и создаем его. 
# ----------------------------------------------------------------------------
sub store {
    my $self = shift;
    do { $log->error("Метод store() можно вызывать только у объектов, но не классов"); die } unless ref($self);

    do { $log->error("В объекте документа не определена ссылка на базу данных"); die } unless ref($self->keeper);

    return undef if ($self->keeper->state->readonly());

    $self->keeper->t_connect() || do { $self->keeper->error(); return undef; };
    $self->{status} ||= 0;                    # Значение статуса по умолчанию = 0

    unless ($self->pre_store()) {
        $log->notice("pre_store call failed!");
        return undef;
    }

    my (@fields, @values, @default_pairs, @default_fields, @default_values, @binary_fields);

    foreach ($self->required_properties()) {

        my $value = $self->{$_->{attr}};
        if ( exists $_->{db_field} && $_->{db_field} ) {
            $value = undef if (defined($value) and $value eq '') and (lc($_->{db_type}) eq 'float' or lc($_->{db_type} eq 'integer'));
            $value = undef if lc $_->{db_type} eq 'integer[]' && ref $value ne 'ARRAY';
            $value = undef if lc $_->{db_type} eq 'integer_ref[]' && ref $value ne 'ARRAY';
        }

        #пропустить readonly если у документа уже есть id
        if ($self->id() and $_->{readonly}) {

        #нет поля в базе у атрибута
        } elsif (!$_->{db_field}) {

        #установка default если оно есть и стоит авто или нет значения у поля
        } elsif (defined($_->{default}) and ($_->{auto} or !defined($value))) {
            push @default_fields, $_->{db_field};
            push @default_values, $_->{default};
            push @default_pairs, "$_->{db_field}=$_->{default}";

        #пропустить auto без default
        } elsif ($_->{auto}) {

        #установка валидных полей
        } elsif (defined($value)) {
            push @fields, $_->{db_field};
            if ($_->{db_type} eq 'integer[]') {
                push @values, '{'.join(',', grep { $_ } @$value).'}';
            } elsif ($_->{db_type} eq 'integer_ref[]') {
                push @values, '{'.join(',', grep { $_ } @$value).'}';     
            } else {
                #some special work for bytea column type
                push @binary_fields, scalar(@fields) if ($_->{db_type} eq 'bytea');
                if ($state->db_encode_data) {
                    push @values, Encode::decode($state->db_encode_data, $value, Encode::FB_HTMLCREF);
                } elsif ($DBD::Pg::VERSION >= '3') {
                    push @values, Encode::decode('utf-8', $value, Encode::FB_HTMLCREF);
                } else {
                    push @values, $value;
                }
            }

        #undef to NULL or empty array
        } else {
            push @default_fields, $_->{db_field};
            push @default_values, 'NULL';
            push @default_pairs, "$_->{db_field}=NULL";
        } 
    }

    #если использется toast то загоняется за 1 sql запрос и extra тоже
    if (($self->keeper->store_method() eq 'toast') and $self->class_table->have_extra and !$self->{__light}) {
        push @fields, 'data';
        push @values, $self->_create_extra_dump();
    }


    my $values_string = '';
    my $mode = 'update';
    if ($self->id()) {
        if (@fields) {
            $values_string = join(' = ?, ', @fields).' = ?';
            $values_string .= ', '.join(', ', @default_pairs) if (@default_pairs); 
        #нет обычных значений работаем только по @default_pairs
        } else {
            $values_string = join(', ', @default_pairs) if (@default_pairs);
        }
        my $sql='UPDATE '.$self->class_table->db_table.' SET '.$values_string." WHERE ".$self->class_table()->id_field()." = ?";

        my $sth=$self->keeper->TSQL->prepare_cached($sql, {}, 1) || return $self->t_abort();
        #settin special escape for bytea column type!!!
        foreach (@binary_fields) {
            $sth->bind_param($_, undef, {pg_type => DBD::Pg::PG_BYTEA});
        }
        unless ($sth->execute(@values, $self->{id})) {
            $log->error("DBI execute error on $sql\n".Data::Dumper::Dumper( $DBD::Pg::VERSION >= '3' ? Data::Recursive::Encode->encode_utf8( \@values ) : \@values ));
            $sth->finish();
            return $self->t_abort();
        }
        $sth->finish();

        if (($self->keeper->store_method() ne 'toast') and $self->class_table->have_extra and !$self->{__light}) {
            $self->store_extras(mode => $mode) || return $self->t_abort();
        }

    } else {
        $mode = 'insert';
        if (@fields) {
            $values_string = '?, 'x(scalar (@fields)-1).'?';
            $values_string .= ', '.join(', ', @default_values) if (@default_values);
        #нет обычных значений работаем только по @default_pairs
        } else {
            $values_string = join(', ', @default_values) if (@default_values);
        }
        my $sql='INSERT INTO '.$self->class_table->db_table.' ('.join(', ', (@fields, @default_fields)).') VALUES ('.$values_string.')';

        my $sth=$self->keeper->TSQL->prepare_cached($sql, {}, 1) || return $self->t_abort();
        #settin special escape for bytea column type!!!
        foreach (@binary_fields) {
            $sth->bind_param($_, undef, {pg_type => DBD::Pg::PG_BYTEA});
        }
        unless ($sth->execute(@values)) {
            $log->error("DBI execute error on $sql\n".Data::Dumper::Dumper( $DBD::Pg::VERSION >= '3' ? Data::Recursive::Encode->encode_utf8( \@values ) : \@values ));
            $sth->finish();
            return $self->t_abort();
        }
        $sth->finish();

        my $id = $self->keeper->TSQL->selectrow_array("SELECT currval('".$self->class_table->db_id_sequence()."')");
        $self->id($id);
        return $self->t_abort("Документу присвоен неверный идентификатор") if (! defined($self->{id}) || ($self->{id} <= 0));

        if (($self->keeper->store_method() ne 'toast') and $self->class_table->have_extra and !$self->{__light}) {
            $self->store_extras(mode => $mode) || return $self->t_abort();
        }

    }

    $self->post_store(mode => $mode);

    $self->keeper->t_finish();

    $self->post_finish_store();

    $self->drop_cache($mode) if ($self->keeper->state()->memcached_enable());

    return 1;
}

# ----------------------------------------------------------------------------
# Метод delete() для удаления объекта из базы данных.
#
# Формат использования:
#  $document->delete()
# ----------------------------------------------------------------------------
sub delete {
    my $self = shift;
    my (%opts) = @_;
    do { $log->error("Метод delete() можно вызывать только у объектов, но не классов"); die } unless ref($self);

    return undef if ($self->keeper->state->readonly());

    unless ($self->pre_delete()) {
        $log->error("pre_delete call failed!");
        return undef;
    }

    my $keeper = $self->keeper;
    do { $log->error("В объекте документа не определена ссылка на базу данных"); die } unless ref($keeper);

    my $delete_attachments = exists $opts{attachments} ? $opts{attachments} : 1;
    if ( $delete_attachments ) {
	my @props = $self->structure();
	if ( @props ) {
		@props = grep { $_->{type} =~ /^(image|images|multimedia_new|multimedia_multi)$/ } @props;
		foreach my $prop ( @props ) {
			my $att = $self->get_image($prop->{attr});
			if ( $prop->{type} eq 'image' ) {
				if ( ref $att && exists $att->{filename} && $att->{filename} ) {
					Contenido::File::remove( $att->{filename} );
				}
				if ( exists $att->{mini} && ref $att->{mini} eq 'HASH' ) {
					Contenido::File::remove( $att->{mini}{filename} )	if exists $att->{mini}{filename};
					foreach my $val ( values %{ $att->{mini} } ) {
						if ( ref $val && exists $val->{filename} && $val->{filename} && ($val->{filename} ne $att->{mini}{filename}) ) {
							Contenido::File::remove( $val->{filename} );
						}
					}
				}
				
			} elsif ( $prop->{type} eq 'images' ) {
				for ( 1..100 ) {
					next	unless exists $att->{"image_$_"};
					my $img = $att->{"image_$_"};
					if ( ref $img && exists $img->{filename} && $img->{filename} ) {
						Contenido::File::remove( $img->{filename} );
					}
					if ( exists $img->{mini} && ref $img->{mini} eq 'HASH' ) {
						Contenido::File::remove( $img->{mini}{filename} )	if exists $img->{mini}{filename};
						foreach my $val ( values %{ $img->{mini} } ) {
							if ( ref $val && exists $val->{filename} && $val->{filename} && ($val->{filename} ne $img->{mini}{filename}) ) {
								Contenido::File::remove( $val->{filename} );
							}
						}
					}
				}
			} elsif ( $prop->{type} eq 'multimedia_new' ) {
				if ( ref $att && exists $att->{filename} && $att->{filename} ) {
					Contenido::File::remove( $att->{filename} );
				}
			} elsif ( $prop->{type} eq 'multimedia_multi' ) {
				for ( 1..100 ) {
					next	unless exists $att->{"file_$_"};
					my $file = $att->{"file_$_"};
					if ( ref $file && exists $file->{filename} && $file->{filename} ) {
						Contenido::File::remove( $file->{filename} );
					}
				}
			}
		}
	}
    }
    do { $log->warning("Вызов метода delete() без указания идентификатора для удаления"); return undef }
						unless ($self->{id});
    $keeper->t_connect() || do { $keeper->error(); return undef; };
    $keeper->TSQL->do("DELETE FROM ".$self->class_table->db_table." WHERE id = ?", {}, $self->id) || return $self->t_abort();

    # Удаление связей этого документа с другими документами...
    my %document_links;
    if ( $keeper->state->{available_links} && ref $keeper->state->{available_links} eq 'ARRAY' ) {
	foreach my $classlink ( @{ $keeper->state->{available_links} } ) {
		my $sources = $classlink->available_sources;
		if ( ref $sources eq 'ARRAY' && @$sources ) {
			$document_links{$classlink->class_table->db_table}{source} = 1		if grep { $self->class eq $_ } @$sources;
		}
		my $dests = $classlink->available_destinations;
		if ( ref $dests eq 'ARRAY' && @$dests ) {
			$document_links{$classlink->class_table->db_table}{dest} = 1		if grep { $self->class eq $_ } @$dests;
		}
	}
	foreach my $tablename ( keys %document_links ) {
		my (@wheres, @values);
		if ( exists $document_links{$tablename}{source} ) {
			push @wheres, "(source_id = ? AND source_class = ?)";
			push @values, ( $self->id, $self->class );
		}
		if ( exists $document_links{$tablename}{dest} ) {
			push @wheres, "(dest_id = ? AND dest_class = ?)";
			push @values, ( $self->id, $self->class );
		}
		my $request = "DELETE FROM $tablename WHERE ".join (' OR ', @wheres);
		warn "DELETE LINKS. Request: [$request]\n"			if $DEBUG;
		warn "Values: [".join(', ', @values)."]\n"			if $DEBUG;
		$keeper->TSQL->do($request, {}, @values) || return $self->t_abort();
	}
    } else {
	$keeper->TSQL->do("DELETE FROM links WHERE source_id = ? AND source_class = ? ", {}, $self->id, $self->class) || return $self->t_abort();
	$keeper->TSQL->do("DELETE FROM links WHERE dest_id = ? AND dest_class = ? ", {}, $self->id, $self->class) || return $self->t_abort();
    }
    $keeper->t_finish();

    $self->post_delete();

    $self->drop_cache('delete') if ($keeper->state()->memcached_enable());

    return 1;
}

# ----------------------------------------------------------------------------
# Метод links() возвращает массив объектов типа Contenido::Link
#
# Формат использования:
#  $document->links([класс])
# ----------------------------------------------------------------------------
sub links {
    my ($self, $lclass, $direction, %opts) = @_;
    do { $log->error("Метод ->links() можно вызывать только у объектов, но не классов"); die }  unless ref($self);

    do { $log->error("В объекте документа не определена ссылка на базу данных"); die } unless ref($self->keeper);

    do { $log->warning("Вызов метода ->links() без указания идентификатора сообщения-источника"); return () } unless ($self->id() > 0);

    my $check = defined $direction ? 'dest_id' : 'source_id';

    $opts{$check} = $self->id();

    if (defined($lclass) && (length($lclass) > 0)) {
	$opts{class} = $lclass;
    }

    my @links = $self->keeper->get_links(%opts);

    $self->{links} = \@links;
    return @links;
}


sub linked_to {
    my ($self, $lclass) = @_;
    $self->links($lclass, 1);
}


# ----------------------------------------------------------------------------
# Установка связи. Должен быть обязательно задан класс...
#  В качестве source_id выступает идентификатор объекта, в качестве $dest_id -
#  заданный.
#
# Формат использования:
#  $document->set_link($lclass, $dest_id)
#
# Проверки не производится - у сообщения может быть несколько одинаковых
#  связей.
# ----------------------------------------------------------------------------
sub set_link {
    my ($self, $lclass, $dest_id, $dest_class, @opts) = @_;
    do { $log->error("Метод ->set_link() вызван с неправильным кол-вом агрументов"); die } if @opts % 2;
    do { $log->error("Метод ->set_link() можно вызывать только у объектов, но не классов"); die } unless ref($self);
    my %opts = @opts;

    return undef if ($self->keeper->state->readonly());

    do { $log->warning("Вызов метода ->set_link() без указания идентификатора сообщения-источника"); return undef } unless ($self->id() > 0);
    do { $log->warning("Вызов метода ->set_link() без указания идентификатора сообщения-цели"); return undef } unless ($dest_id >= 0);
    do { $log->warning("Вызов метода ->set_link() без указания класса связи"); }  unless defined($lclass) && length($lclass);

    # Создаем объект связи...
    my $link = $lclass->new($self->keeper);

    $link->dest_id($dest_id);
    $link->dest_class($dest_class);

    $link->status(1);

    $link->source_id($self->id());
    $link->source_class($self->class());
    
    while (my ($k,$v) = each %opts) {
	$link->{$k} = $v;
    }

    if ($link->store())
    {
	return $link->id;
    } else {
	return undef;
    }
}

# -------------------------------------------------------------------
# Превращает объект в проблессенный хэш.
#
sub prepare_for_cache {
    my $self = shift;

    do { $log->error("Метод ->prepare_for_cache() можно вызывать только у объектов, но не классов"); die } unless ref($self);

    my $hash = {};

    foreach ( $self->structure() ) {
	$hash->{$_->{attr}} = $self->{$_->{attr}} if defined $self->{$_->{attr}};
    }
    bless $hash, $self->class();
    return $hash;
}

# -------------------------------------------------------------------
# Восстанавливает полноценный объект по проблессенному хэшу.
# Хэш при этом превращается в полноценный объект.
# -------------------------------------------------------------------
sub recover_from_cache {
    my $self = shift;
    my $keeper = shift;

    do { $log->error("Метод ->recover_from_cache() можно вызывать только у объектов, но не классов"); die } unless ref($self);
    do { $log->error("В объекте документа не определена ссылка на базу данных"); die } unless ref($keeper);

    #не нужен тут bless очередной... 100% если уж попали в обьектный метод то он явно имеет класс нужный
    $self->init();
    $self->keeper($keeper);

    return 1;
}

# -------------------------------------------------------------------
# Возвращает хэш:
#   {действие1 => [кэш1, кэш2, ...], действие2 => [кэш1, кэш2, ...], ...}
# Т.е. для каждого действия задается список имен ключей в кэше,
# которые надо удалить.
# Дефолтные значени действий: insert, update, delete
# Для более сложной логики работы этот метод должен быть переопределен
# в классе самого объекта
#
sub dependencies {
    my ($self, $mode) = @_;

    my @keys = ($self->get_object_key,);
    my $object_unique_key = $self->get_object_unique_key;
    push @keys, $object_unique_key if defined $object_unique_key;

    return
        ($mode eq 'delete') || ($mode eq 'insert') || ($mode eq 'update')
            ? \@keys
            : [];
}

# -------------------------------------------------------------------
# Удаляет из кэша ключи, заданные при помощи dependencies().
# Пример вызова:
#   $group->drop_cache('update');
#
sub drop_cache {
    my $self = shift;
    my $mode = shift;

    do { $log->error("Метод ->drop_cache() можно вызывать только у объектов, но не классов"); die } unless ref($self);

    my $keeper = $self->keeper;
    do { $log->error("В объекте документа не определена ссылка на базу данных"); die } unless ref($keeper);
    
    my $dependencies = $self->dependencies($mode, @_);

    my @not_deleted = ();
    if ( defined($dependencies) && (ref($dependencies) eq 'ARRAY') ) {
        for (@$dependencies) {
            my $res = $self->keeper->MEMD ? $self->keeper->MEMD->delete($_) : undef;
            push @not_deleted, $_ unless $res;
            $keeper->MEMD->delete($_) if ($keeper->MEMD);
        }
    }
    return @not_deleted;
}


sub keeper {
    my $self = shift;
    my $project_keeper = shift;

    do { $log->error("Метод keeper() можно вызывать только у объектов, но не классов"); die } unless ref($self);

    if ($project_keeper && ref $project_keeper) {
        $self->{keeper} = $project_keeper;
        return $project_keeper;
    }
    return $self->{keeper} && ref $self->{keeper} ? $self->{keeper} : $keeper;
}

#делаем затычку для init_from_db чтобы проинициализировать класс если надо
sub init_from_db {
    my $self = shift;

    my $class = ref($self) || $self;

    #защита от бесконечной рекурсии если class_init не срабатывает
    if (defined($_[-1]) and ($_[-1] eq 'RECURSIVE CALL FLAG!')) {
        do { $log->error("$class cannot be initialized (->class_init dont work) (recursive call) !!!"); die };
    }

    #если клас каким то странным образом все еще не проинициализирован то попробовать проинициализировать
    #только инициализация метода init_from_db допускает не ref на входе
    if ($class and $class->isa('Contenido::Object')) {
        no strict 'refs';
        if (${$class.'::class_init_done'}) {
            do { $log->error("$class already initialized but DONT HAVE init_from_db method!!!"); die };
        } else {
            if ($self->class_init()) {
                return $self->init_from_db(@_, 'RECURSIVE CALL FLAG!');
            } else {
                do { $log->error("$class cannot be initialized (->class_init dont work) !!!"); die };
            }
        }
    } else {
        do { $log->error("$class cannot be initialized (not Contenido::Object child class) !!!"); die };
    }
}

# ----------------------------------------------------------------------------
# Это умный AUTOLOAD. Ловит методов для установки/чтения полей...
# Версия 1.0
# теперь он герерирует необходимый метод доступу если надо
# ----------------------------------------------------------------------------
sub AUTOLOAD {
    my $self = shift;
    my $attribute = $AUTOLOAD;

    $log->info("$self calling AUTOLOAD method: $attribute") if ($DEBUG_CORE);

    $attribute=~s/^.*:://;

    my $class = ref($self);
    unless ($class and $class->isa('Contenido::Object')) {

        my $mason_comp = ref($HTML::Mason::Commands::m) ? $HTML::Mason::Commands::m->current_comp() : undef;
        my $mason_file = ref($mason_comp) ? $mason_comp->path : undef;
        my ($package, $filename, $line) = caller;

        $log->warning("Wrong AUTOLOAD call with self='$self'/class='$class' and method '$attribute' called from '$package/$filename/$line' ".($mason_file ? "called from $mason_file" : '')."\n".Data::Dumper::Dumper($self));
        if (wantarray)  { return (); } else { return undef; }
    }

    #вообщето сюда было бы не плохо засунуть инициализацию класса если уж мы каким то хреном сюда попали для неинициализированного класса
    {
        no strict 'refs';
        unless (${$class.'::class_init_done'}) {
            my ($package, $filename, $line) = caller;
            $log->error("AUTOLOAD called method '$attribute' for not initialised class ($class) from '$package/$filename/$line'");
            if (wantarray)  { return (); } else { return undef; }
        }
    }

    if (! exists($self->{attributes}->{$attribute})) {

        my $mason_comp = ref($HTML::Mason::Commands::m) ? $HTML::Mason::Commands::m->current_comp() : undef;
        my $mason_file = ref($mason_comp) ? $mason_comp->path : undef;
        my ($package, $filename, $line) = caller;

        $log->error(ref($self)."): Вызов метода, для которого не существует обрабатываемого свойства: ->$attribute() called from $package/$filename/$line ".($mason_file ? "called from $mason_file" : '')."\n".Data::Dumper::Dumper($self));
        if (wantarray)  { return (); } else { return undef; }
    #special work with ARRAY types
    } elsif ($self->{attributes}->{$attribute} eq 'ARRAY') {
        my $funct = "
        use Contenido::Globals;
        my \$self = shift;
        unless (ref(\$self->{$attribute}) eq 'ARRAY') {
            my (\$package, \$filename, \$line) = caller;
            \$log->error(\"Wrong structure in field $attribute called from \$package/\$filename/\$line \\n\".Data::Dumper::Dumper(\$self)) if (\$self->{$attribute});;
            \$self->{$attribute} = [];
        }
        \$self->{$attribute} = [\@_] if (\@_);
        return \@{\$self->{$attribute}};";

        if (create_method($class, $attribute, $funct)) {
            return $self->$attribute(@_);
        } else {
            $log->error("Cannot create method $attribute for class $self->{class}");
            #fallback to old autoload method if create method fail
            unless (ref($self->{$attribute}) eq 'ARRAY') {
                my ($package, $filename, $line) = caller;
                $log->error("Wrong structure in field $attribute called from $package/$filename/$line \n".Data::Dumper::Dumper($self));
                $self->{$attribute} = [];
            }
            $self->{$attribute} = [@_] if (@_);
            return @{$self->{$attribute}};
        }
    #todo: добавить работу с images Нормальную когда она будет готова
    } else {
        #todo: валидация формата полей
        my $funct = "
    my \$self = shift;
    \$self->{$attribute} = shift if (\@_);
    return \$self->{$attribute};";

        if (create_method($class, $attribute, $funct)) {
            return $self->$attribute(@_);
        } else {
            $log->error("Cannot create method $attribute for class $self->{class}");
            #fallback to old autoload method if create method fail
            $self->{$attribute} = shift if (@_);
            return $self->{$attribute};
        }
    }
}

sub eval_dump {
    no strict 'vars';
	return {} unless ${$_[0]};
    return eval ${$_[0]};
}

sub eval_json {
    return undef	unless ${$_[0]};
    my $str = ${$_[0]};
    my $chr = substr($str, 0, 1); return $str	unless $chr eq '{' || $chr eq '[';
    my $value = $json_u->decode( $str );
#    map { $_ = Encode::encode(\'utf-8\', $_) unless ref $_; } values %$value;
    return $value;
}

sub create_method {
    my ($class, $sub_name, $code) = @_;

    unless ($class and $sub_name and $code) {
        $log->error("Wrong call create_method $class/$sub_name/$code");
        return 0;
    }

    my $string = "package $class;\n\nsub $sub_name {\n$code\n}\n\n1;";
    eval $string;

    if ($@) {
        $log->error("Cannot create method $sub_name for class $class because $@ (method code:\n$string\n)");
        return 0;
    } else {
        $log->info("Method '$sub_name' for class '$class' (method code:\n$string\n) created ok") if ($DEBUG_CORE);
        return 1;
    }
}

######################################## ONLY FOR INTERNAL USE!!!! #################################################
#todo добавить проверку что если классов список то проверить что у них 1 table а не 5 разных
sub _get_table {
    my ($self, %opts) = @_;

    my $class_table;

    my $table=$opts{table};
    my $class=$opts{class} || ref $self || $self;

    #пришла таблица в %opts
    if ($table and $table->can('new')) {
        $class_table=$table;
    #иначе пробуем по классу
    } elsif ($class and !ref($class)) {
        unless ($class->can('class_table')) {
            $log->error("$class cannot class_table");
            return undef;
        }
        $class_table=$class->class_table();
    #иначе пробуем по первому классу в списке
    } elsif ($class and ref($class) eq 'ARRAY' and @$class) {
        unless ($class->[0]->can('class_table')) {
            $log->error("$class->[0] cannot class_table");
            return undef;
        }
        $class_table=$class->[0]->class_table();
    #иначе умолчательную
    } else {
        $class_table='SQL::DocumentTable';
    }

    if ($class_table->can('new')) {
        return $class_table->new();
    } else {
        $log->error("$class_table cannot new!!!!");
        return undef;
    }
}

#######################################################################################################################
########## OLD CODE FOR COMPATIBILITY #################################################################################
#######################################################################################################################
sub structure {
    my $self = shift;
    my $class = ref($self);
    {
        no strict 'refs';
        return @${$class.'::structure'};
    }
}


# оставлена для обратной совместимости...
sub get_image {
    my $self = shift;
    if ( $self->keeper->serialize_with eq 'json' ) {
	return $self->get_data(shift, 'encode');
    } else {
	return $self->get_data(shift);
    }
}

sub raw_restore {
    my $self = shift;
    do { $log->error("Метод restore() можно вызывать только у объектов, но не классов"); die } unless ref $self;
    do { $log->warning("Вызов метода Contenido\:\:Object\:\:raw_restore() без указания идентификатора для чтения"); return undef } unless $self->id;
    $self->restore_extras();
}

sub init {
     my $self = shift;
     my $class = ref($self) || $self;
     $self->class_init();
     {
          no strict 'refs';
          $self->{attributes} = ${$class.'::attributes'};
     }
     return 1;
}

sub get_file_name {
    my $self = shift;

    do { $log->error("Метод get_file_name можно вызывать только у объектов, но не классов"); die } unless ref $self;

    my @date;
    my $time = time;

    if ($self->{"dtime"} and $self->{"dtime"} =~ /^(\d{4})-(\d{2})-(\d{2})/) {
        @date = ($1, $2, $3);
    } else {
        @date = (localtime $time)[5, 4, 3]; $date[0] += 1900; $date[1] += 1;
    }

    my $component_class = lc((reverse split "::", ref $self)[0]);
    my $component_date = sprintf "%04d/%02d/%02d", @date;
    my $component_time_rand = sprintf "%010d_%05d", $time, int rand 99999;

    return join "/", $component_class, $component_date, $component_time_rand;
}

sub get {
    my ( $self, %opts ) =  @_;
    my $class = ref $self || $self;
    my $local_keeper = (ref($self) and ref($self->keeper)) ? $self->keeper : $keeper;
    delete $opts{class};
    return $keeper->get_documents( class => $class, %opts );
}

sub contenido_is_available {
    return 1;
}

sub contenido_status_style {
    return;
}

sub memcached_expire {
    return $_[0]->keeper->state->memcached_object_expire;
}

# ----------------------------------------------------------------------------
# Метод _store_image() сохраняет графику, привязанную к полю image или images 
#
# Формат использования:
#  $document->_store_image( INPUT, attr => 'fieldname' )
#  $document->_store_image( INPUT, prop => $prophash )
# ----------------------------------------------------------------------------
sub _store_image {
    my $self = shift;
    do { $log->error("Метод delete() можно вызывать только у объектов, но не классов"); die } unless ref($self);

    my $input = shift;
    my (%opts) = @_;

    return Contenido::File::store_image( $input, object => $self, %opts );
}

# ----------------------------------------------------------------------------
# Метод _delete_image() удаляет файлы, связанные с полем image или images.
# Вычищает все мини-копии
#
# Формат использования:
#  $document->_delete_image( $image_attr_structure )
# ----------------------------------------------------------------------------
sub _delete_image {
    my $self = shift;
    my $IMAGE = shift;

    return Contenido::File::remove_image( $IMAGE );
}

# ----------------------------------------------------------------------------
# Метод _store_binary() сохраняет произвольный бинарный файл, привязанную к полю multimedia_multi или multimedia_new 
#
# Формат использования:
#  $document->_store_binary( INPUT, attr => 'fieldname' )
# ----------------------------------------------------------------------------
sub _store_binary {
    my $self = shift;
    do { $log->error("Метод delete() можно вызывать только у объектов, но не классов"); die } unless ref($self);

    my $input = shift;
    my (%opts) = @_;

    return Contenido::File::store_binary( $input, object => $self, attr => $opts{attr} );
}

# ----------------------------------------------------------------------------
# Метод _delete_binary() удаляет файлы, связанные с полем multimedia или multimedia_new.
# Не пытается искать мини-копии
#
# Формат использования:
#  $document->_delete_binary( $binary_attr_structure )
# ----------------------------------------------------------------------------
sub _delete_binary {
    my $self = shift;
    my $BINARY = shift;

    return Contenido::File::remove_binary( $BINARY );
}

1;

