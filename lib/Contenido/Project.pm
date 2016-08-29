package Contenido::Project;

# ----------------------------------------------------------------------------
# Contenido::Project - класс, который будет содержать перечень полей с
#  общей информацией о проекте (ширина, основные цвета, общее название 
#  для title's и так далее). Объект этого класса будет создаваться при 
#  старте Apache-сервера. Данные он будет брать из специального хэша 
#  (который возможно будет редактироваться через редакторский интерфейс)
#  и перечитывать их каждый раз при измении файла на диске.
# ----------------------------------------------------------------------------

use strict;
use warnings;
use locale;

use vars qw($VERSION $AUTOLOAD);
$VERSION = '1.0';


use Utils;
use Contenido::Globals;
use Data::Dumper;

# ----------------------------------------------------------------------------
# Конструктор. Создает объект с описанием проекта.
#
# Формат вызова:
#  Contenido::Project->new();
# ----------------------------------------------------------------------------
sub new
{
    my ($proto, $state, $local_keeper) = @_;
    unless ( ref $state ) {
        $log->error("Неправильный вызов конструктора объекта проекта. В параметрах нет объекта класса Contenido::State.");
        die;
    }

    $local_keeper ||= $keeper;

    my $class = ref($proto) || $proto;
    my $self = {};
    bless($self, $class);
    $self->_init_;

    # Запомним то, что нас интересует...
    $self->{state} = $state;
    $self->{project_name} = $state->project_name();
    $self->{debug} = $state->debug();
#   $self->{mtime} = 0;
    $self->{data} = {};

    $self->restore($local_keeper);
    return $self;
}



# ------------------------------------------------------------------------------------------------
# Инициализация внутренних структур
# ------------------------------------------------------------------------------------------------
sub _init_
{
    my $self = shift;
    $self->{attributes} = {};
    foreach my $a ( qw(project_name mtime debug) )
    {
        $self->{attributes}->{ $a } = 'SCALAR';
    }
    return 1;
}




# ------------------------------------------------------------------------------------------------
# Метод restore() для заполнения объекта Project данными...
#
# Формат использования:
#  $project->restore()
# ------------------------------------------------------------------------------------------------
sub restore
{
    my $self = shift;
    my $local_keeper = shift;
    my $force = shift;
    do { $log->error("Метод restore() можно вызывать только у объектов, но не классов"); die } unless ref $self;
    do { $log->error("Метод restore() require established connection to DB"); die } unless (ref($local_keeper));

    return 1 if (!$force and $self->{"mtime"} and $self->{"mtime"} > time - $state->{"options_expire"});

    #TODO: implement hardcoded project attributes if db_type eq 'none'
    return 1 if $self->{state}->db_type eq 'none';

    delete $self->{"data"};
    delete $self->{"attributes"};

    my $sth = $local_keeper->SQL->prepare_cached("SELECT id, pid, name, value, type FROM options", {}, 1) || do { $log->error("Not connected to DB"); die };
    $sth->execute();

    my $data_ref = $sth->fetchall_arrayref() || [];
    $sth->finish();
    foreach (@$data_ref) {
        $_->[1] = 0 unless ($_->[1]);
    }

    $self->{data} = restore_recursive('HASH',$data_ref, 0);

    foreach my $key (keys %{$self->{"data"}}) {
        $self->{"attributes"}{$key} = "DATA";
    }

    $self->{"mtime"} = time;

    return 1;
}

sub restore_recursive {
    my $type = shift;
    my $data_ref = shift;
    my $pid = shift;

    my $struct_ref;

    if ($type eq 'ARRAY') {
        $struct_ref = [];
        foreach my $item (@$data_ref) {
            my ($id, $local_pid, $local_name, $local_value, $local_type) = @$item;
            next unless ($local_pid == $pid);
            if ($local_type eq 'SCALAR') {
                $struct_ref->[$local_name] = $local_value;
            } else {
                $struct_ref->[$local_name] = restore_recursive($local_type, $data_ref, $id);
            }
        }
    } elsif ($type eq 'HASH') {
        $struct_ref = {};
        foreach my $item (@$data_ref) {
            my ($id, $local_pid, $local_name, $local_value, $local_type) = @$item;
            next unless ($local_pid == $pid);
            if ($local_type eq 'SCALAR') {
                $struct_ref->{$local_name} = $local_value;
            } else {
                $struct_ref->{$local_name} = restore_recursive($local_type, $data_ref, $id);
            }
        }
    } elsif ($type eq 'SCALAR') {
        do { $log->error("Recursive call with scalar value... "); die };
    } else {
        do { $log->error("Wrong type in call '$type'"); die };
    }

    return $struct_ref;
}

# ----------------------------------------------------------------------------
# Метод store() для сохранения объекта Project на диск... то есть в БД
#
# Формат использования:
#  $project->store()
# ----------------------------------------------------------------------------

sub store
{
    my $self = shift;
    my $local_keeper = shift;

    do { $log->error("Метод store() можно вызывать только у объектов, но не классов"); die }    unless ref($self);
    do { $log->error("Метод store() require established connection to DB"); die } unless (ref($keeper) and $keeper->is_connected());

    return 1 if $self->{state}->db_type eq 'none';

    $local_keeper->t_connect() || do { $local_keeper->error(); return undef; };
    my $insert = $keeper->TSQL->prepare("INSERT INTO options (pid, name, value, type) VALUES (?, ?, ?, ?)");
    $local_keeper->TSQL->do("DELETE FROM options");
    store_recursive(undef, undef, $self->{"data"}, $insert, $local_keeper);
    $insert->finish();
    $local_keeper->t_finish();

    undef $self->{"mtime"};

    return 1;
}

# TODO переделать нафиг ужос
sub store_recursive {
    my $pid = shift;
    my $key = shift;
    my $data = shift;
    my $insert = shift;
    my $local_keeper = shift;

    my $new_pid;

    if (ref $data eq "HASH") {
        if (defined $key) {
            $insert->execute($pid, $DBD::Pg::VERSION >= '3' ? Encode::decode( 'utf-8', $key) : $key, undef, "HASH");
            $new_pid = $local_keeper->TSQL->selectrow_array("SELECT currval('documents_id_seq')");
        }

        foreach my $new_key (keys %$data) {
            store_recursive($new_pid, $new_key, $data->{$new_key}, $insert, $local_keeper);
        }
    } elsif (ref $data eq "ARRAY") {
        if (defined $key) {
            $insert->execute($pid, $DBD::Pg::VERSION >= '3' ? Encode::decode( 'utf-8', $key) : $key, undef, "ARRAY");
            $new_pid = $local_keeper->TSQL->selectrow_array("SELECT currval('documents_id_seq')");
        }

        foreach my $new_key (0 .. $#$data) {
            store_recursive($new_pid, $new_key, $data->[$new_key], $insert, $local_keeper);
        }
    } else {
        $insert->execute($pid, 
                $DBD::Pg::VERSION >= '3' ? Encode::decode( 'utf-8', $key) : $key, 
                $DBD::Pg::VERSION >= '3' ? Encode::decode( 'utf-8', $data) : $data, 
                "SCALAR") || return $local_keeper->t_abort();
    }
}

# ----------------------------------------------------------------------------
# Это умный AUTOLOAD. Ловит методов для установки/чтения полей...
# Версия 0.2/Модифицированная версия
# ----------------------------------------------------------------------------

sub AUTOLOAD
{
    my $self = shift;
    my $attribute = $AUTOLOAD;


    $attribute =~ s/.*:://;
    return undef    unless  $attribute =~ /[^A-Z]/;     # Отключаем методы типа DESTROY


    if (! exists($self->{attributes}->{$attribute}))
    {
        $log->error("Вызов метода, для которого не существует обрабатываемого свойства: ->$attribute(). Создаем запись.");
        $self->{attributes}->{$attribute} = 'DATA';
    }

    if ($self->{attributes}->{$attribute} eq 'DATA')
    {
        $self->{data}->{ $attribute } = shift @_    if (scalar(@_) > 0);
        return $self->{data}->{ $attribute };
    } else {
        $self->{ $attribute } = shift @_    if (scalar(@_) > 0);
        return $self->{ $attribute };
    }
}

1;

