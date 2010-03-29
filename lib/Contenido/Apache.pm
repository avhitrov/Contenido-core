package Contenido::Apache;

# ----------------------------------------------------------------------------
# Здесь будут храниться все хэндлеры Apache...
# ----------------------------------------------------------------------------

use strict;
use warnings;
use locale;

use vars qw($VERSION);
$VERSION = '7.0';

use Apache::Constants;
use Apache::Request;

use Contenido::Globals;
use Contenido::Project;
use Contenido::Request;
use Contenido::State;

use Contenido::Keeper;
use Contenido::Object;
use Contenido::User;
use Contenido::Document;
use Contenido::Section;
use Contenido::Link;

use Contenido::Init;
use Contenido::Logger;

# ----------------------------------------------------------------------------
# Хэндлер, который запускается при старте каждого нового дочернего процесса
#  web-сервера.
# ----------------------------------------------------------------------------
sub child_init {
    my $r = shift;

    $log->info("Обрабатываем рождение дочернего процесса Apache") if $DEBUG;

    my $project_keeper_module;
    eval {
        $project_keeper_module=$state->project().'::Keeper';
        $keeper = $project_keeper_module->new($state);
    };
    if ($@) {
        $log->error("Не могу инициализировать $project_keeper_module из-за: $@");
        die;
    }

    for my $plugin ($state->project, split(/\s+/, $state->plugins)) {
        my $class = $plugin.'::Apache';
        eval { $class->child_init($r); };
        if ( $@ ) {
            $log->error("Не могу выполнить метод child_init плагина $plugin ($class) по причине '$@'");
        }
    }

    return OK;
}

# ----------------------------------------------------------------------------
# Хэндлер, который запускается в самом начале обработки запроса пользователя.
# ----------------------------------------------------------------------------
sub request_init {
    my $r = shift;

    $r = ref($r) eq 'Apache::Request' ? $r : Apache::Request->instance($r);

    my $URI = $r->uri;
    my $ARGS = $r->args;

    $log->info("Начало обработки запроса ".$URI.($ARGS ? "?$ARGS":'')) if $DEBUG;

    $state->_refresh_();

    $request = Contenido::Request->new($state);

    if ($DEBUG) {
        $request->{_start} = Time::HiRes::time();
        $Contenido::Globals::DB_TIME   = 0;
        $Contenido::Globals::CORE_TIME = 0;
        $Contenido::Globals::DB_COUNT  = 0;
        $Contenido::Globals::RPC_TIME  = 0;
    }

    if (ref($r)) {

        my %headers = $r->headers_in();
        my $ip = $headers{'X-Real-IP'} ? $headers{'X-Real-IP'} : $r->connection->remote_ip();
        my @ips = split(/\s*,\s*/, $ip);
        $ip = $ips[ $#ips ];

        $request->set_properties (  
                        'uri'   => $URI||'',
                        'query' => $r->args()||'',
                        'ip'    => $ip||'',
                        'user'  => $r->connection->user()||'',
                        'http_host' => $ENV{HTTP_HOST},
                        'r' => $r,
                     )
    }
    $project->restore($keeper);

    for my $plugin ($state->project, split(/\s+/, $state->plugins)) {
        my $class = $plugin.'::Apache';
        eval { $class->request_init($r); };
        if ( $@ ) {
            $log->error("Не могу выполнить метод request_init плагина $plugin ($class) по причине '$@'");
        }
    }

    return OK;
}

sub is_valid_request {
    my $r = shift;
    if ($r->uri =~ /^(?:\/i\/|\/images\/|\/binary\/)/ or ($r->content_type && $r->content_type !~ m#(?:^text/|javascript|json|^httpd/unix-directory)#i)) {
        return 0;            
    } else {
        return 1;
    }
} 
#завершение запроса (отрабатывает ПОСЛЕ отдачи ответа... так что можно буз ущерба интерактивности тут всяие полезности повызывать
sub cleanup {
    my $r = shift;

    #сброс глобальных переменных запроса
    $user    = undef;
    $session = undef;

    return Apache::Constants::DECLINED unless Contenido::Apache::is_valid_request($r);

    #установка отложенных данных в memcached
    if ($state->{memcached_enable} and $request->{_to_memcache}) {
        while ( my ($key, $values) = each(%{$request->{_to_memcache}}) ) {
            my ($value, $expire, $mode) = @$values;
            if (ref($key) or !$key) { 
                $log->warning("bad key value in set ($key)");
                next;
            }
            $mode ||= 'set';
            if ($mode eq 'add') {
                $keeper->{MEMD}->add($key, $value, $expire);
            } elsif ($mode eq 'delete') {
                $keeper->{MEMD}->delete($key);
            #по умолчанию set
            } else {
                $keeper->{MEMD}->set($key, $value, $expire);
            }
        }
    }

        for my $plugin ($state->project, split(/\s+/, $state->plugins)) {
                my $class = $plugin.'::Apache';
        next unless ($class->can('cleanup'));
                eval { $class->cleanup($r); };
                if ( $@ ) {
                        $log->error("Не могу выполнить метод request_init плагина $plugin ($class) по причине '$@'");
                }
        }

        # отсоединяемся от базы проекта и плагинов
        # (если не используются постоянные соденинения)
        # также сбрасываем потенциально зависшие транзакционные соединения
        unless ($state->db_type eq 'none') {
                $keeper->shutdown unless $state->db_keepalive;
                $keeper->{_connect_ok} = 0;
                $keeper->t_shutdown(1);
        }
        for (split /\s+/, $state->plugins) {
                next unless $keeper->{$_};
                next if $state->{$_}->db_type eq 'none';
                $keeper->{$_}->shutdown unless $state->{$_}->db_keepalive;
                $keeper->{$_}->{_connect_ok} = 0;                    
                $keeper->{$_}->t_shutdown(1);
        }

        if ($DEBUG) {
            my $finish = Time::HiRes::time();
            my $time = int(10000*($finish-$request->{_start}))/10;
            my $db_time = int(10000*($Contenido::Globals::DB_TIME)/10);
            my $core_time = int(10000*($Contenido::Globals::CORE_TIME)/10);
            my $rpc_time = int(10000*($Contenido::Globals::RPC_TIME)/10);
            $log->info("DEBUG: $$ ".__PACKAGE__."  ".scalar(localtime())." ".($r->uri || '').($r->args ? '?'.$r->args : '')." worked $time ms, database time $db_time ms, rpc time $rpc_time ms, core time: $core_time ms, db requests count: $Contenido::Globals::DB_COUNT");
        }

        $request = undef;

    return OK;
}

# ----------------------------------------------------------------------------
# Хэндлер, который запускается при окончании работы дочернего процесса
#  web-сервера...
# ----------------------------------------------------------------------------
sub child_exit {
    my $r = shift;

    for my $plugin ($state->project, split(/\s+/, $state->plugins)) {
        my $class = $plugin.'::Apache';
        eval { $class->child_exit($r); };
        if ( $@ ) {
            $log->error("Не могу выполнить метод child_exit плагина $plugin ($class) по причине '$@'");
        }
    }
    unless ($state->db_type eq 'none') {
        $keeper->shutdown;
    }

    $log->info("Обрабатываем смерть дочернего процесса Apache.") if ($DEBUG);

    return OK;
}


# ----------------------------------------------------------------------------
# Хэндлер для аутентификации.
#   - Если это делается для редакторского интерфейса, то группа
#     пользователей должна быть группой 1 (редакторы)
# ----------------------------------------------------------------------------
sub authentication {
    my $r = shift;

    return Apache::Constants::DECLINED unless Contenido::Apache::is_valid_request($r);
    return FORBIDDEN if $state->db_type eq 'none';

    my ($res, $sent_pw) = $r->get_basic_auth_pw();
    return $res if $res != OK;

    my $username = $r->connection->user();

        $keeper->db_connect unless $keeper->is_connected;
    $user = $keeper->get_user_by_login($username);
        $keeper->shutdown   unless $state->db_keepalive;

    if (ref($user) && ($user->login() eq $username) && ($user->passwd() eq $sent_pw) && $user->passwd() && $user->status == 1) {
        return OK;
    } else {
        $log->warning("Попытка авторизации с неверной парой логин/пароль ($username, $sent_pw)");
        $r->note_basic_auth_failure();
        return AUTH_REQUIRED;
    }
}

1;
