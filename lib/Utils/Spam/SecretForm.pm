package Utils::Spam::SecretForm;

use strict;
use Digest::MD5;
use Contenido::Globals;
use Scalar::Util qw(blessed);

# Генерация строки для вставки в hidden-поле формы 
# для подтвеждения действий пользователя.
#   extra - дополнительный параметр для генерации строки 
#   (к примеру, если человек залогинен, можно передавать его логин)
#   Не забыть передавать данный параметр при валидации.
sub generate {
    my %opts = @_;

    my ($start_time, $secret_code) = &get_secret_code(allow_generate_code => 1, memd => $opts{'memd'});
    return unless $start_time && $secret_code;

    my $random = &get_random_string(5);
    # start secret code time | generate time | hash
    return $start_time.'|'.time().'|'.$random.'|'.Digest::MD5::md5_hex($start_time.$secret_code.$random.$opts{'extra'});
}

# Процедура проверки hidden-поля формы
#   secret - код, для проверки
#   ttl - время жизни выданного кода
#   check_count - true означает разрешение на подсчет количества использований
sub validate {
    my %opts = @_;

    my $user_secret = $opts{'secret'};
    my $ttl         = $opts{'ttl'} || 3600;
    my $extra       = $opts{'extra'};
    my $check_count = $opts{'check_count'};
    my $result      = { is_valid => 1, is_expired => 0, count => 1 };
    my $memd        = blessed($opts{'memd'}) ? $opts{'memd'} : $keeper->MEMD();

    return $result unless blessed($memd);

    my ($user_start_time, $user_generate_time, $user_random, $user_hash) = split(/\|/, $user_secret);

    # данные о секретной строке
    my ($start_time, $secret_code) = &get_secret_code(time => $user_start_time, memd => $memd);

    # Если кэш не работает принимаем любые параметры
    return $result if !defined($start_time) && !defined($secret_code);

    if (Digest::MD5::md5_hex($start_time.$secret_code.$user_random.$extra) ne $user_hash) {
        $result->{'is_valid'} = 0;
    }

    if ($result->{'is_valid'} && (($user_generate_time-$start_time > 3600) 
                                    || (time()-$user_generate_time > $ttl))
    ) {
        $result->{'is_expired'} = 1;
    }

    # Если необходима проверка на повторное использование
    # Данные о количестве использования необходимо сохранить в кэше
    if ($result->{'is_valid'} && !$result->{'is_expired'} && $check_count) {

        $result->{'count'} = $memd->incr('usersecret|'.$user_secret, 1) if $memd;

        unless ($result->{'count'}) {
            $memd->add('usersecret|'.$user_secret, 1, $ttl) if $memd;
            $result->{'count'} = 1;
        }
    }

    return $result;
}

# Процедура, которая возвращает true или false в зависимости от валидности, просроченности
#   и количества использований
sub is_valid_secret {
    my %opts = @_;

    my $validate = &validate(%opts);

    if ($validate->{'is_valid'} && !$validate->{'is_expired'} 
        && (!$opts{'check_count'} || ($opts{'check_count'} && $validate->{'count'} == 1)))
    {
        return 1;
    }

    return undef;
}

# Процедура получения и генерации при необходимости
# секретного кода. Сохраняет свою атуальность в течение суток.
#   time - для указанного времени вернет актуальный на тот момент код
#   allow_generate_code - разрешает генерировать код, если он не найден
sub get_secret_code {
    my %opts = @_;

    # Наличие объекта memcached является обязательным 
    # условием работоспособности
    my $memd = blessed($opts{'memd'}) ? $opts{'memd'} : $keeper->MEMD();
    return unless blessed($memd);

    my $time        = abs(int($opts{'time'}));
    my $now_time    = time();

    # Время с округлением до начала часа
    unless ($time) {
        $time = $now_time;
        $time = $time - ($time % 3600);
    }

    my $cache_key = 'secret_code|'.$time;

    my $secret_code = $memd->get($cache_key);
    return ($time, $secret_code) if $secret_code;

    if ($opts{'allow_generate_code'}) {
        $secret_code = &get_random_string(10);
        $memd->set($cache_key, $secret_code);
    }

    return ($time, $secret_code);
}


# Генерация случайной строки
#   length - длина строки
sub get_random_string {
    my $length = shift;
    $length = 10 unless $length && $length =~ /^\d+$/;

    my $random_chars = 'abcdefghijklmnopqrstuvwxyz1234567890';
    my $random_chars_length = length($random_chars);

    my $string = '';
    for (1..$length) {
        $string .= substr($random_chars, int(rand($random_chars_length)), 1);
    }

    return $string;
}


1;
__END__

=head1 NAME

Utils::Spam::SecretForm - утилиты генерации и проверки секретной строки для web-форм

=head1 SYNOPSIS

 Генерация:
 <input type="hidden" name="secret" value="<% Utils::Spam::SecretForm::generate() %>">
  
 Проверка:
 my $validate = Utils::Spam::SecretForm::validate( secret => $ARGS{'secret'}, check_count => 0|1 );
 if ($validate->{'is_valid'} && !$validate->{'is_expired'}) {
    allowed method
 }


=head1 DESCRIPTION

 С помощью javascript существует способ подделки http-запроса get и post методов.
 Некая страница a.html содержит:
 <form method=post action=http://www.rambler.ru/post.html name="b">
 <input type="text" name="text">
 <input name="submit" type="submit" value="submit">
 </form>
 <script>
 document.b.submit.click();
 </script>
 
 Таким образом, человек, зашедщий на страницу a.html, отправит данную форму.
 Для борьбы с данным видом атак следует использовать данный модуль.

 Принцип работы: раз в час генерируется случайная секретная строка, которая хранится в кэше по ключу secret_code|время_генерации.
 Если кэш не работает, валидация проходит успешно для любого рода запросов.
 Пользователь при генерации формы получает некий код в hidden поле, который состоит из трех частей: 
   1) время генерации секретной строки
   2) время выдачи строки пользователю
   3) рандомная строка
   4) md5_hex( время выдачи строки пользователю . рандомная строка . секретная строка)
 При верификации полученного hidden-параметра происходит получение секретной строки из кэша secret_code|время_генерации, сравнение md5_hex(времени . полученной строки) и проверка разницы времени установки поля и текущего времени.
 Таким образом получаем защиту от несанкционированных запросов. Для защиты от повторного использования кода необходимо использовать параметр check_count, в зависимости от которого в результате верификации вернется количество использования кода (после первого использование count = 1).
 Для повышения защиты существует возможность добавления extra параметра для генерации hidden-кода, например для залогиненого пользователя, это может быть логин или сессия. Но необходимо не забывать передавать этот параметр во время валидации.

