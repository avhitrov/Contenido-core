package Contenido::DB::PostgreSQL;

# ----------------------------------------------------------------------------
# Класс реализации работы базой данных PostgreSQL 
# ----------------------------------------------------------------------------
use strict;
use warnings;

use DBI;
use DBD::Pg;

use Contenido::Globals;
use Contenido::Msg;

# МЕТОДЫ ДОСТУПА К СОЕДИНЕНИЯМ С БАЗОЙ УМНЫЕ
# получение соединения с базой или установка нового если его не было
sub SQL {
    my $self = shift;
    return ($self->connect_check() ? $self->{SQL} : undef);
}

#получение транзакционного соединения с базой или установка нового если его не было
sub TSQL {
    my $self = shift;
    return ($self->t_connect_check() ? $self->{TSQL} : undef);
}

# -------------------------------------------------------------------------------------------------
# Открываем соединение с базой данных
# -------------------------------------------------------------------------------------------------
sub connect {
    my $self = shift;
    #соединение уже есть
    if ($self->is_connected) {
    } else {
        unless ($self->{SQL} = $self->create_db_connect) {
            $log->error("Не могу соединиться с базой данных");
            die;
        }
        $self->{SQL}->do("SET NAMES '".$self->state->db_client_encoding."'") if ($self->state->db_client_encoding);
    }

    $self->{_connect_ok} = 1;
    return 1;
}

sub t_connect {
    my $self = shift;
    #транзакционный connect уже есть
    if ($self->is_t_connected) {
        $self->{TSQL_level}++;
    } else {
        unless ($self->{TSQL} = $self->create_db_t_connect) {
            $log->error("Не могу соединиться с базой данных");
            die;
        }
        $self->{TSQL}->do("SET NAMES '".$self->state->db_client_encoding."'") if ($self->state->db_client_encoding);
   	    $self->{TSQL_level} = 1;
        #если не проставлено значение то 0
        $self->{TSQLStable} = 0 unless (exists $self->{TSQLStable});
    }
    $self->{_t_connect_ok} = 1;
    $self->{oldSQL} = $self->{SQL} if ($self->{SQL} and (!$self->{oldSQL}));
	$self->{SQL} = $self->{TSQL};

    return 1;
}

#получение соединения с базой (возможно кому то вне keeper надо)
#возвращает $dbh или undef
sub create_db_connect {
    my $self = shift;
    return DBI->connect("dbi:Pg:dbname=$self->{db_name};".( $self->{db_host} ne 'localhost' ? "host=$self->{db_host};" : "" )."port=$self->{db_port}", $self->{db_user}, $self->{db_password}, { 'AutoCommit' => 1, pg_server_prepare => $self->{db_prepare}, 'pg_enable_utf8' => $self->{db_enable_utf8} } );
}

sub create_db_t_connect {
    my $self = shift;
    return DBI->connect("dbi:Pg:dbname=$self->{db_name};".( $self->{db_host} ne 'localhost' ? "host=$self->{db_host};" : "" )."port=$self->{db_port}", $self->{db_user}, $self->{db_password}, { 'AutoCommit' => 0, pg_server_prepare => $self->{db_prepare}, 'pg_enable_utf8' => $self->{db_enable_utf8} } );
}

#физическая проверка состояния соединения с базой 
sub is_connected {
    my $self = shift;
    if (ref($self->{SQL}) and $self->{SQL}->can('ping') and $self->{SQL}->ping()) {
        $self->{_connect_ok} = 1;
        return 1;
    } else {
        $self->{_connect_ok} = 0;
        return 0;               
    }
}

#физическая проверка состояния соединения с базой
sub is_t_connected {
    my $self = shift;
    if (ref($self->{TSQL}) and $self->{TSQL}->can('ping') and $self->{TSQL}->ping()) {
        $self->{_t_connect_ok} = 1;
        return 1;
    } else {
        $self->{_t_connect_ok} = 0;
        return 0;
    }
}

#проверка соединения с базой кеширующая состояние соединения 
sub connect_check {
    my $self = shift;
    return 1 if ($self->{_connect_ok});
    if ($self->is_connected) {
        $self->{_connect_ok} = 1;
        return 1;
    } else {
        if ($self->connect) {
            return 1;
        } else {
            #сюда по логике попадать не должно так как die вылететь должен
            return 0;
        }
    }
}

sub t_connect_check {
    my $self = shift;
    return 1 if ($self->{_t_connect_ok});
    if ($self->is_t_connected) {
        $self->{_t_connect_ok} = 1;
        return 1;
    } else {
        if ($self->t_connect) {
            return 1;
        } else {
            #сюда по логике попадать не должно так как die вылететь должен
            return 0;
        }
    }
}

# -------------------------------------------------------------------------------------------------
# Закрываем соединение с базой данных
# -------------------------------------------------------------------------------------------------
sub shutdown
{
    my $self = shift;
    $self->{SQL} = $self->{oldSQL} if $self->{oldSQL};
    delete $self->{oldSQL};
    $self->{SQL}->disconnect()     if ($self->is_connected);
    delete $self->{SQL};
    $self->{_connect_ok} = 0;
    $log->info("Закрыто соединение с базой данных PostgreSQL на порту ".$self->{db_port}." keepalive=".$self->state->db_keepalive) if $self->{debug};
    return 1;
}

#завершение соединения с поддержкой транзакций
sub t_shutdown {
    my $self = shift;
    my $force = shift; 
    #если не указан stable transaction enabled connect то сносим его
    if ($force or !$self->TSQLStable) {
        $self->{SQL} = $self->{oldSQL} if ($self->{oldSQL});
        $self->{TSQL}->disconnect() if ($self->is_t_connected);
        delete $self->{TSQL};
        $self->{_t_connect_ok} = 0;
    }
    return 1;
}

#rollback+disconnect 2 в 1 флаконе для отката в аварийных ситуациях
#наиболее эффективно что то типа || return $keeper->t_abort("что то сломалось похоже");
sub t_abort {
    my $self=shift;
    if ($self->is_t_connected) {
        $self->{TSQL}->rollback();
        #в случе t_abort не проверяем уровень вложенности транзакции
        $self->t_shutdown();
    }
    return undef;
}

#commit+disconnect 2 в 1 флаконе
sub t_finish {
    my $self=shift;
    if ($self->is_t_connected) {
        $self->{TSQL_level}--;
        #вышли на самый верх наконец то
        #надо реально комитить
        # <0 защита от всевозможных глюков
        if ($self->{TSQL_level}<=0) {
            $self->{TSQL}->commit();
            $self->t_shutdown();
        }
    }
    return 1;
}

#доступ к управлению состоянием TSQLStable (постоянного транзакционного соединения)
sub TSQLStable {
    my $self = shift;
    my $val = shift;
    if (defined $val) {
        $self->{TSQLStable} = $val;
    } else {
        $self->{TSQLStable} ||= 0;
    } 
    return $self->{TSQLStable};
}


#COMPATIBILITY SUBS
sub db_connect {
    return shift->connect;
}

sub t_dis_connect {
    return shift->t_shutdown;
}

1;

