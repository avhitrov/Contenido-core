use warnings;
use strict;

use DateTime::Locale::ru;
use Encode;

my $src_path = $INC{'DateTime/Locale/ru.pm'};
my $dst_path = $INC[0].($INC[0] =~ m|/$| ? '' : '/').'DateTime/Locale/';

system "mkdir -p $dst_path"; $dst_path .= 'ru_RU_KOI8_R.pm';

open my $in,  "<:encoding(utf-8)",  $src_path or die $!;
open my $out, ">:encoding(koi8-r)", $dst_path or die $!;

while (<$in>) {
    next if /^use utf8/;

    s/::ru/::ru_RU_KOI8_R/ if /^package DateTime::Locale::ru;/;

    print $out $_;
}
