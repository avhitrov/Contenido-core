package Utils::ProxyImage;

use strict;
use Digest::MD5 'md5_hex';

sub get_uri {
    my $url    = shift;
    my $state  = shift;
    my $format = shift;
    
    return '/i/_.gif' unless $format;

    my $secret = $state->proxy_image_secret || 're2anteros';
    
    if ($url =~ /^https?:\/\/(.*)/i) {
        $url = $1; 
    } else {
        return '/i/_.gif';
    }
    
    $url =~ s/\/+/\//g;

    my $hash = md5_hex($url.$secret);
    
    $url = '/'.$format.'/'.$hash.'/'.$url;
    return $state->httpd_root.$state->proxy_image_location.$url;
}
    
1;

__DATA__

Утилита для формирования URI картинки через proxy image

Для начала должен быть сделан соответсвующий location в ngnix, который ссылается на проксирующие сервера картинок
например так:

    location /proxy-image/ {
        proxy_pass            http://imgproxy_upstream/; 
        proxy_set_header      Host i1.rambler.ru;
        proxy_cache           cache;
        proxy_cache_valid     24h;
        proxy_cache_use_stale error timeout;
    }

!!!Важно!!! Не нужно в location запихивать и размер, размер мы определяем параметром $format при вызове метода

в config.mk проекта добалены 2 новые переменные:

PROXY_IMAGE_LOCATION = [собственно наш location]
PROXY_IMAGE_SECRET = [секретное слово для формирования md5]

Вызывает так:

use Utils::ProxyImage;

my $proxy_uri = Utils::ProxyImage::get_uri($url, $state, $format);

где:
$uri - родной uri картинки;
$state - $state Contenido
$format - формат, суффикс. e.q. 'c70x70'