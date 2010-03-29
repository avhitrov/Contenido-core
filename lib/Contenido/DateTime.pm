package Contenido::DateTime;

use strict;
use warnings;

use Contenido::Errors;
use DateTime;
use DateTime::Locale;
use DateTime::Format::Pg;
use DateTime::Format::Strptime;
use Data::Dumper;

{
    BEGIN {
		$^W = 0;

		DateTime::Locale->register(
			id          => 'ru_RU',
			en_language => 'Russian',
			replace     => 1,
		);
	}

    no warnings 'redefine';
    *DateTime::Format::Pg::format_datetime = \&DateTime::Format::Pg::format_timestamp;
}

sub new {
    shift if $_[0] and $_[0] eq __PACKAGE__;

    my ($key, $value) = @_;
    my ($dt, $no_timezone, $no_locale, $no_formatter);
    my $formatter = DateTime::Format::Pg->new();

    if ($key) {
        return unless $value;
        for ($key) {
            /postgres/ && do {
                last unless ref $value eq "";
                eval { $dt = $formatter->parse_datetime($value) };
                last;
            };
            /epoch/ && do {
                last unless ref $value eq "";
                eval { $dt = DateTime->from_epoch(epoch => $value) };
                last;
            };
            /strptime/ && do {
                last unless ref $value eq "HASH";
                $no_timezone  = 1 if $value->{"time_zone"};
                $no_locale    = 1 if $value->{"locale"};

                my $strptime = DateTime::Format::Strptime->new(
                    pattern   => $value->{"format"},
                    locale    => $value->{"locale"} || "ru_RU_KOI8_R",
                    time_zone => $value->{"time_zone"} || "Europe/Moscow",
                    diagnostic => 0,
                );

                eval { $dt = $strptime->parse_datetime($value->{"datetime"}) };
                last;
            };
            /datetime/ && do {
                last unless ref $value eq "HASH";
                $no_formatter = 1 if $value->{"formatter"};
                $no_timezone  = 1 if $value->{"time_zone"};
                $no_locale    = 1 if $value->{"locale"};
                eval { $dt = DateTime->new(%{$value}) };
                last;
            };
        }

        return unless $dt;
    } else {
        $dt = DateTime->now();
    }

    $dt->set_locale("ru_RU") unless $no_locale;
    $dt->set_time_zone("Europe/Moscow") unless $no_timezone;
    $dt->set_formatter($formatter) unless $no_formatter;

    return $dt;
}

1;
