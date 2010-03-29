#!/usr/bin/perl

use strict;
BEGIN { require 'libs.pl' };

$DEBUG = 0;
$Contenido::Keeper::DEBUG = $DEBUG;
$Contenido::Project::DEBUG = $DEBUG;
$Contenido::State::DEBUG = $DEBUG;
$PhoenixDBI::DEBUG = $DEBUG;

# Подключаемся к базе данных для тестирования и проверки...
my $keeper = Contenido::Keeper->new($state);

$keeper->{SQL}->do("VACUUM FULL ANALYZE");

$keeper->shutdown();
