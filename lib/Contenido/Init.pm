package Contenido::Init;

# ----------------------------------------------------------------------------
# Здесь будут храниться все инициализирующие методы Contenido...
# Это НЕ объект, это просто пакет с процедурами...
# ----------------------------------------------------------------------------

use strict;
use warnings;
use locale;

use vars qw($VERSION);
$VERSION = '4.1';

# Подключение модулей... общих...
use Utils;
use IO::File;
use Image::Size;
use Data::Dumper;
use Convert::Cyrillic;
use POSIX qw(:locale_h);


# Подключение модулей Contenido...
use Contenido::Globals;
use Contenido::Logger;
use Contenido::User;
use Contenido::Project;
use Contenido::Request;
use Contenido::State;
use Contenido::Document;
use Contenido::Link;
use Contenido::Section;
use Contenido::Keeper;
use Contenido::Image;
# Типы данных
use Contenido::Type::File;

# Процедура возвращает модульную структуру Contenido/ElTexto/Arte
# По идее именно она должна патчиться, если нужно просканировать дополнительные директории.
sub module_structure {
    return (
        ['documents', 'модули документов', 'Contenido::Document'],
        ['sections', 'модули секций', 'Contenido::Section'],
        ['users', 'модули пользователей', 'Contenido::User'],
        ['links', 'модули связей', 'Contenido::Link'],
    );
}


sub init {
    warn "Contenido Init: Инициализация Contenido\n" if $DEBUG;

    my $R = contenido_init();

    if ($state->locale) {
        setlocale(LC_COLLATE, $state->locale);
        setlocale(LC_CTYPE,   $state->locale);
    }

    $keeper = Contenido::Keeper->new($state);
    # если не стоит keepalive имеет смысл соединиться с базой, если она используется проектом
    unless ($state->db_type eq 'none') {
        $keeper->db_connect unless $keeper->is_connected;
    }

        $log->info("Создание объекта Contenido::Project") if $DEBUG;
        $project = Contenido::Project->new($state);

    $R += plugins_load();
    $R += modules_load();
    utils_load();

    init_classes();
    clear_not_available();

    # PREAMBLE_HANDLER stuff - load and initialize
    #
	if ( $state->{preamble_handler} ) {
		my $module = $state->{preamble_handler};      # main preamble hanler
		my $path   = $state->{preamble_handler_path}; # extra preamble handlers relative path
		eval "use $module";
		if ( $@ ) {
            $R++; $log->error("Cannot load module $module because of '$@'");
		}
		$state->{preamble_handler_obj} = $module->new( $path ? (load_modules => $path) : () );
    }

    unless ($state->db_type eq 'none') {
        $keeper->shutdown;
    }

    if ($R) {
        $log->error("При инициализации Contenido произошли ошибки (количество - $R)") if $DEBUG;
    } else {
        $log->info("Инициализация Contenido прошла успешно") if $DEBUG;
    }

    return ($R ? 1 : 0);
}

sub init_classes {
    foreach (&module_structure, ['locals', 'проектные модули', $keeper->state()->project() ]) {
        my $tag = $_->[0];
        $state->{'available_'.$tag} ||= [];
        if (ref($state->{'available_'.$tag}) eq 'ARRAY') {
            foreach my $class (@{$state->{'available_'.$tag}}) {
                $class->class_init;
            }
        } else {
            $log->error("Wrong structure in \$state->{available_$tag} (".$state->{'available_'.$tag}."), must be ARRAY REF");
            die;
        }
    }
}

sub clear_not_available {
    foreach (&module_structure, ['locals', 'проектные модули', $keeper->state()->project() ]) {
        my $tag = $_->[0];
        next unless ref $state->{'available_'.$tag} eq 'ARRAY';
        for (my $i = 0; $i <= $#{$state->{'available_'.$tag}} ; $i++) {
            my $class = $state->{'available_'.$tag}->[$i];
            unless ($class->contenido_is_available) {
                splice(@{$state->{'available_'.$tag}}, $i--, 1);
                $log->debug('Удален класс ' . $class . ' из $state->{available_' . $tag . '}') if $DEBUG;
            }
        }
    }
}

sub load_classes {
    shift;
    for (@_) {
        eval "use $_";
        #зачем делать eval если не проверять потом $@ ?
        $log->error("Cannot load class $_ because of $@") if ($@);
        if ($_->can('class_init')) {
            eval {$_->class_init};
            $log->error("Error on class_init for class $_ because of $@") if ($@);
        }
        $log->info("Загружен класс $_") if $DEBUG;
    }
}

sub plugins_load {
    my $LR = 0;

    # ----------------------------------------------------------------------------
    # Теперь нам надо подключить все сторонние модули...
    for my $plugin ($state->project, split(/\s+/, $state->plugins)) {
        my $class = $plugin.'::Init';
        eval ("use $class");
        $log->error("Ошибка при загрузке модуля.\n$@!") if $@;

        {
            package HTML::Mason::Commands;
            eval ("use $class");
        }

        
        if ( $@ ) {
            $log->error("Не могу подключить плагин $plugin (инициализатор $class) по причине '$@'");
            $LR++;
        } else {
            $log->info("Загружен класс $class для плагина $plugin") if $DEBUG;
            eval {
                $LR += $class->init( $keeper );
            };
            if ( $@ ) {
                $log->error("Не могу выполнить инициализацию плагина $plugin (инициализатор $class) по причине '$@'");
                $LR++;
            }
        }
    }

    return $LR;
}

sub utils_load {
    Utils::load_modules( ['Utils::HTML'] );
}


sub modules_load {
    my $path = __FILE__;
    $path =~ s|/[^/]*$||;
    $path =~ s|/Contenido$||;

    my $LR = 0;

    my @ms = ();

    # Добавляем проверку локальных модулей...
    push (@ms, ['locals', 'проектные модули', $keeper->state()->project() ] );


    foreach my $ms (@ms) {
        $log->info("Подключаем ".$ms->[1]) if $DEBUG;

        my $pathlib = $path.'/'.$ms->[2];
        $pathlib =~ s|::|/|gi;
        if (! -s $pathlib) {
            $log->warning("Директории ${pathlib} не существует. Непорядок!");
        } else {
            opendir(DIR, $pathlib) || do { $log->error("Не могу открыть директорию ${pathlib} для подключения модулей"); die };
            my @modules = grep {/\.pm$/} readdir(DIR);
            closedir(DIR);

            foreach my $module (@modules) {
                $module =~ s/\.pm$//;

                my $class = $ms->[2]."::".$module;

                eval("
                    package TestPackage::$class;
                    use $class;
                    1;
                ");

                if ( $@ ) {
                    $log->error("Не могу подключить модуль $module (класс $class) по причине '$@'");
                    $LR++;
                } else {
                    $log->info("Загружен класс $class") if $DEBUG;
                    next unless $class->isa('Contenido::Object');
                    foreach (&module_structure()) {
                        my ($tag, $name, $proto) = @$_;
                        if ($class->isa($proto)) {
                            push (@{ $state->{'available_'.$tag} }, $class);
                            $log->info("Класс $class типа $name '".$class->class_name()."' (прототип $proto)") if $DEBUG;
                        }
                    }
                }
            }
        }
    }

    # Еще загрузим специально ряд модулей - Contenido::User, Contenido::Section... Вернее добавим их в список возможностей
    push (@{ $state->{'available_sections'} }, 'Contenido::Section');
    push (@{ $state->{'available_users'} }, 'Contenido::User');
    push (@{ $state->{'available_links'} }, 'Contenido::Link');

    return $LR;
}

# Создание объектов Contenido...
sub contenido_init {
    warn "Contenido Init: Создание объекта Contenido::State\n" if $DEBUG;
    $state = Contenido::State->new();
    $log = Contenido::Logger->new(
        log_format  => $state->{__debug_format__}      || '%d %C:%L (%P) [%l]: "%m"%n',
        max_level   => $state->{__debug_max_level__}   || 'emergency',
        min_level   => $state->{__debug_min_level__}   || 'debug',
        stack_trace => $state->{__debug_stack_trace__} || 0,
    );

    return 1 unless ref $state && ref $log;
    $log->info("Создан объект Contenido::Logger") if $DEBUG;

    $state->debug($DEBUG);
    $state->info() if $DEBUG;

    return 0;
}

1;

