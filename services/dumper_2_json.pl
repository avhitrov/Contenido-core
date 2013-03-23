#!/usr/bin/perl

use strict;
use warnings "all";
use locale;

use FindBin;
BEGIN {
	require "$FindBin::RealBin/../lib/Modules.pm";
}

use Contenido::Globals;
use Contenido::Init;
use ErrorTee;
use PidFile;
use Data::Dumper;
use JSON::XS;

# begin
Contenido::Init->init();

my $keeper_module = $state->project.'::Keeper';
$keeper = $keeper_module->new($state);

#PidFile->new($keeper, compat=>1);                # db-based locking (run only on one host)
#PidFile->new($keeper, compat=>1, per_host=>1);   # db-based locking (run on whole cluster)

############################################
# please use:
#     $state->{log_dir} for logging
#     $state->{tmp_dir} for temporary files
###########################################
my $table = $ARGV[0] || 'sections';
my $LIMIT = 10;
my $OFFSET = 0;
my $json = JSON::XS->new;

print "Alter table:\n";
my $res = $keeper->SQL->do("alter table $table add column data__json text");
print "Reading from $table...\n";
my $i = 2;
while ( $i ) {
	my $sql = $keeper->SQL->prepare("select id, data from $table order by id limit $LIMIT offset $OFFSET");
	my $res = $sql->execute;
	if ( $res ne '0E0' ) {
		while ( my $ln = $sql->fetchrow_hashref ) {
			next	unless $ln->{data};
			my $VAR1; eval "$ln->{data}";
			my $STRUCT = $VAR1;
			print Dumper $STRUCT;
			if ( ref $STRUCT eq 'HASH' ) {
				while ( my ($field, $val) = each %$STRUCT ) {
					if ( $val && $val =~ /\$VAR1/ ) {
						my $VAL = eval "$val";
						if ( ref $VAL ) {
							print Dumper $VAL;
							$STRUCT->{$field} = $json->encode($VAL);
						}
					}
				}
			}
			my $DATA = Encode::decode('utf-8', $json->encode( $STRUCT ));
			my $store = $keeper->SQL->prepare("update $table set data__json = ? where id = ?");
			$store->execute( $DATA, $ln->{id} );
		}
	} else {
		print "Stop\n";
		last;
	}
	$OFFSET += $LIMIT;
}
print "Rename column [data] to [data__dumper]\n";
$keeper->SQL->do("alter table $table rename COLUMN data TO data__dumper");
print "Rename column [data__json] to [data]\n";
$keeper->SQL->do("alter table $table rename COLUMN data__json TO data");
