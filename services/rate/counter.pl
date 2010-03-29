#!/usr/bin/perl

use strict;
BEGIN { require '../libs.pl' };

use vars qw($DEBUG);
$DEBUG = 0;

use Data::Dumper;

use Contenido::Init;
use Rate::Main;

&check_pid();

Contenido::Init::init();

$Contenido::Keeper::DEBUG = $DEBUG;
$Contenido::Project::DEBUG = $DEBUG;
$Contenido::State::DEBUG = $DEBUG;
$PhoenixDBI::DEBUG = $DEBUG;

$Data::Dumper::Indent = 0 unless ($DEBUG);

# Подключаемся к базе данных для тестирования и проверки...
my $keeper = Contenido::Keeper->new($state);
$keeper->{TSQLStable} = 1;

warn Data::Dumper::Dumper($state->rate()) if ($DEBUG);

my $set={};
foreach my $serial (($state->rate->days-2..0),undef) {
	Rate::Main->parse_single_file($set,$serial);
}
warn Data::Dumper::Dumper($set) if ($DEBUG);

my $id_hash=();
while (my ($client,$votes)=each(%$set)) {
	while (my ($id,$vote)= each(%$votes)) {
		$id_hash->{$id}->{$vote}++;
		$id_hash->{$id}->{votes}++;
		$id_hash->{$id}->{total}+=$vote;
	}
}

warn Data::Dumper::Dumper($id_hash) if ($DEBUG);

my $time=time();

while (my ($id,$votes)=each(%$id_hash)) {
	my $document=undef;

	foreach (@{$state->rate->allowed_classes}) {
		$document = $keeper->get_document_by_id($id,class=>$_);
		last if $document;
	}

	unless ($document) {
		warn "wrong document id: '$id'";
		next;
	}

	my $document_votes=$document->get_image('rating');
	$document_votes->{LAST}=$votes;
	$document_votes->{LAST}->{mtime}=$time;

	foreach (qw(1 2 3 4 5 votes total mtime)) {
		$document_votes->{OLD}->{$_}||=0;
		$document_votes->{LAST}->{$_}||=0;
		$document_votes->{TOTAL}->{$_}=$document_votes->{OLD}->{$_}+$document_votes->{LAST}->{$_};
	}

	my $raw_rating = Data::Dumper::Dumper($document_votes);

	#rating changed!!!
	#comparing Data::Dumper results is cheap hack but no fast and easy way compare two data structure
	if ($raw_rating ne $document->rating) {
		$document->rating($raw_rating);
		$document->store();
	}
}
