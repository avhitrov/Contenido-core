package SQL::AutoTable;

use strict;
use SQL::Common;
use Contenido::Globals;

my %typemap = (
    'smallint'            => 'integer',
    'integer'            => 'integer',
    'integer[]'            => 'string',
    'varchar'            => 'string',
    'character varying'        => 'string',
    'char'                => 'string',
    'text'                => 'text',
    'boolean'            => 'checkbox',
    'timestamp with time zone'    => 'datetime',
    'timestamp without time zone'    => 'datetime',
);

#некоторые умолчательные свойства некоторых документов
my $default_props = {
class =>    {
            'hidden'    => 1,
            'readonly'    => 1,
            'column'    => 3,
            'rusname'    => 'Класс документа',
        },
name =>        {
            'column'    => 2,
            'rusname'    => 'Название',
            'type'        => 'string',
        },
ctime =>    {
            'readonly'    => 1,
            'auto'        => 1,
            'hidden'    => 1,
            'default'    => 'CURRENT_TIMESTAMP',
            'rusname'    => 'Время создания документа',
        },
mtime =>    {
            'auto'        => 1,
            'hidden'    => 1,
            'default'    => 'CURRENT_TIMESTAMP',
            'rusname'    => 'Время изменения документа',
        },
dtime =>    {
            'rusname'    => 'Дата и время документа<sup style="color:#888;">&nbsp;1)</sup>',
            'default'    => 'CURRENT_TIMESTAMP',
            'column'    => 1,
        },
sections =>    {
            'type'        => 'sections_list',
            'rusname'    => 'Секции',
            'hidden'    => 1,
        },
status =>    {
            'rusname'    => 'Статус',
            'type'        => 'status'
        },
};

sub modificators {
    return {};
}

sub auto_init {
    my $self = shift;
    my $class = shift;

    my $filter_set = {};
    my @rp = (
        {
            'attr'        => 'id',
            'type'        => 'integer',
            'hidden'    => 1,
            'auto'        => 1,
            'readonly'    => 1,
            'db_field'    => 'id',
            'db_type'    => 'integer',
        }
    );

    my $modificators = $class->modificators();

    my $sth = $keeper->SQL->column_info(undef, undef, $class->db_table, undef) || die "no connection to DB!";
    while (my $row = $sth->fetchrow_arrayref) {
        my ($field_name, $field_type, $default) = ($row->[3], $row->[5], $row->[12]);
        $field_name =~ s/^"(.*)"$/$1/;

        #skip data field for tables with _extra and skip id
        next if (($field_name eq 'id') or (($field_name eq 'data') and $class->have_extra));

        my $field = {
                attr    =>    $field_name,
                db_field=>    $field_name,
                db_type    =>    $field_type,
                type    =>    ($typemap{$field_type} || $field_type),
                default    =>    $default,
                rusname    =>    $field_name,
                %{$default_props->{$field_name} || {}},
                %{$modificators->{$field_name}    || {}}
        };
        push @rp, $field;
    }

    # Создаем фильтры для каждого поля
    $class->_register_filter($filter_set, $_) foreach @rp;

    {
        no strict 'refs';
        ${$class.'::_rp'}    = \@rp;
        ${$class.'::filters'}    = $filter_set;
        ${$class.'::_init_ok'}    = 1;
        warn "$class table descriptor loaded ok!\n" if ($DEBUG);
    }

    return 1;
}

sub _register_filter {
    my ($self, $filter_set, $field) = @_;
    my $class = ref($self) || $self;
    return if ($field->{no_filter} or !$field->{db_type});

    my $name = 'd.'.$field->{attr};

    # Специальныe случаи
    if ($field->{attr} eq 'sections') {
        # Игнорируем значение и передаем весь %opts
        $filter_set->{s}            = sub { return $class->_s_filter( %{$_[1]} ); };
    } elsif ($field->{attr} eq 'id') {
        $filter_set->{in_id}            = sub { return (SQL::Common::_generic_int_filter($name, shift, 1, shift)); };
    }
    #todo возможно еще несколько фильтров для совместимости умолчательной сделать

    #name всегда специальный образом работает
    if ($field->{attr} eq 'name') {
        $filter_set->{$field->{attr}}           = sub { return (SQL::Common::_generic_name_filter($name, shift, 0, shift)); };
        $filter_set->{'not_'.$field->{attr}}    = sub { return (SQL::Common::_generic_name_filter($name, shift, 1, shift)); };
    } elsif ($field->{db_type} eq 'integer' or $field->{db_type} eq 'smallint') {
        $filter_set->{$field->{attr}}           = sub { return (SQL::Common::_generic_int_filter($name, shift, 0, shift)); };
        $filter_set->{'not_'.$field->{attr}}    = sub { return (SQL::Common::_generic_int_filter($name, shift, 1, shift)); };
    } elsif ($field->{db_type} eq 'float' or $field->{db_type} eq 'real' or $field->{db_type} eq 'double precision') {
        $filter_set->{$field->{attr}}           = sub { return (SQL::Common::_generic_float_filter($name, shift, 0, shift)); };
        $filter_set->{'not_'.$field->{attr}}    = sub { return (SQL::Common::_generic_float_filter($name, shift, 1, shift)); };
       } elsif ($field->{db_type} eq 'text' or $field->{db_type} eq 'char' or $field->{db_type} eq 'character varying' or $field->{db_type} eq 'character') {
        $filter_set->{$field->{attr}}           = sub { return (SQL::Common::_generic_text_filter($name, shift, 0, shift)); };
        $filter_set->{'not_'.$field->{attr}}    = sub { return (SQL::Common::_generic_text_filter($name, shift, 1, shift)); };
    } elsif ($field->{db_type} eq 'integer[]') {
        $filter_set->{$field->{attr}}           = sub { return (SQL::Common::_generic_intarray_filter($name, shift, 0, shift)); };
        $filter_set->{'not_'.$field->{attr}}    = sub { return (SQL::Common::_generic_intarray_filter($name, shift, 1, shift)); };
    } elsif ($field->{db_type} eq 'boolean') {
        $filter_set->{$field->{attr}}           = sub { return (SQL::Common::_generic_boolean_filter($name, shift, 0, shift)); };
        $filter_set->{'not_'.$field->{attr}}    = sub { return (SQL::Common::_generic_boolean_filter($name, shift, 1, shift)); };
    } elsif ($field->{db_type} eq 'date' or $field->{db_type} eq 'timestamp without time zone' or $field->{db_type} eq 'timestamp with time zone') {
        $filter_set->{$field->{attr}}           = sub { return (SQL::Common::_generic_date_filter($name, shift, 0, shift)); };
        $filter_set->{'not_'.$field->{attr}}    = sub { return (SQL::Common::_generic_date_filter($name, shift, 1, shift)); };
    } elsif ($field->{db_type} eq 'time' or $field->{db_type} eq 'time without time zone') {
        $filter_set->{$field->{attr}}           = sub { return (SQL::Common::_generic_time_filter($name, shift, 0, shift)); };
        $filter_set->{'not_'.$field->{attr}}    = sub { return (SQL::Common::_generic_time_filter($name, shift, 1, shift)); };
    } else {
        warn "$class have field $field->{db_field} with type $field->{db_type} unsupported in autofilter just now sorry";
    }
}

1;

