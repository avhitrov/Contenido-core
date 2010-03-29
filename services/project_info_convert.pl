#!/usr/bin/perl -w

use strict;
use warnings "all";

use FindBin;
BEGIN { require "$FindBin::RealBin/../lib/Modules.pm" }

use Contenido::Globals;
use Contenido::Init;

my $config_file = shift or die "Usage: ".$FindBin::RealScript." /path/to/project.info\n";

die "File '$config_file' doesnt exists or not readable" unless -e $config_file and -r $config_file;

Contenido::Init->init();

$keeper = Contenido::Keeper->new($state);

my $rows = $keeper->{SQL}->selectrow_array("SELECT count(*) FROM options");

unless ($rows) {
    $keeper->{SQL}->do(qq(CREATE TABLE options (id INTEGER NOT NULL PRIMARY KEY DEFAULT NEXTVAL('public.documents_id_seq'::text), pid INTEGER, name TEXT, VALUE text, "type" TEXT NOT NULL)));

    $keeper->t_connect() || do { $keeper->error(); return undef; };
    $keeper->{TSQL}->do("DELETE FROM options");

    my $insert = $keeper->{TSQL}->prepare("INSERT INTO options (pid, name, value, type) VALUES (?, ?, ?, ?)");

    my $config = do $config_file;
    die "$config_file has invalid format" unless ref $config eq "HASH";

    store(undef, undef, $config, $insert, $keeper);

    $keeper->t_finish();
} else {
    die "Table 'options' already exists and not empty";
}

sub store {
    my $pid = shift;
    my $key = shift;
    my $data = shift;
    my $insert = shift;
    my $keeper = shift;

    my $new_pid;

    if (ref $data eq "HASH") {
        if (defined $key) {
            $insert->execute($pid, $key, undef, "HASH");
            $new_pid = $keeper->{TSQL}->selectrow_array("SELECT currval('documents_id_seq')");
        }

        foreach my $new_key (keys %$data) {
            store($new_pid, $new_key, $data->{$new_key}, $insert, $keeper);
        }
    } elsif (ref $data eq "ARRAY") {
        if (defined $key) {
            $insert->execute($pid, $key, undef, "ARRAY");
            $new_pid = $keeper->{TSQL}->selectrow_array("SELECT currval('documents_id_seq')");
        }

        foreach my $new_key (0 .. $#$data) {
            store($new_pid, $new_key, $data->[$new_key], $insert, $keeper);
        }
    } else {
        $insert->execute($pid, $key, $data, "SCALAR") || return $keeper->t_abort();
    }
}
