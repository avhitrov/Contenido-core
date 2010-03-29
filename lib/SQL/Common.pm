package SQL::Common;
use base qw(Exporter);

use strict;
use Utils;
use Contenido::DateTime;
use Data::Dumper;

our @EXPORT = qw(&NIL);

sub NIL {
	return '___NEXT___';
}

my %_TEXT_CONDITIONS = ( 
	'!=' => 1, 
	'<>' => 1, 
	'NOT' => 1,
	'LIKE' => 1,
	'ILIKE' => 1,
	'NOT LIKE' => 1, 
	'NOT ILIKE' => 1, 
	'~' => 1,
);
my %_CONDITIONS = (
	'NOT' => 1,
	'!=' => 1,
	'<>' => 1,
	'<' => 1,
	'>' => 1,
	'>=' => 1,
	'<=' => 1,
);
my %_DATE_CONDITIONS = (
	'!=' => 1,
	'<>' => 1,
	'<' => 1,
	'>' => 1,
	'>=' => 1,
	'<=' => 1,
);

sub _generic_int_filter {
	my ($field,$value,$negation)=@_;

	my $mode = $negation ? 'NOT IN':'IN';

	#undef <=> NULL
	if ( !defined($value) ) {
		$mode = $negation ? 'IS NOT' : 'IS';
		return "$field $mode NULL", [];
	} elsif ( (ref($value) eq 'ARRAY') and @$value ) {
		my $values_string = '?, 'x(scalar (@$value)-1).'?';
		return " ($field $mode ($values_string)) ", [@$value];
	} elsif (ref($value) eq 'ARRAY') {
		# skip empty array
		return ($negation ? ' TRUE ' : ' FALSE '), [];
	} elsif ( $value eq 'positive' || $value eq 'negative' || $value eq 'natural' ) {
		$mode = $value eq 'positive' ? '>' : $value eq 'negative' ? '<' : '>=';
		return "$field $mode 0", [];
	} elsif ( $value =~ /^[0-9 ,]+$/ ) {
		my @values = split(/\s*,\s*/, $value);
		my $values_string = '?, 'x(scalar (@values)-1).'?';
		return " ($field $mode ($values_string)) ", \@values;
	} else {
                my $mason_comp = ref($HTML::Mason::Commands::m) ? $HTML::Mason::Commands::m->current_comp() : undef;
                my $mason_file = ref($mason_comp) ? $mason_comp->path : undef;
                my ($package, $filename, $line) = caller;

		warn "WARNING: $$: Неверно задан формат integer фильтра для $field ('$value'). Это может быть либо число, либо ряд чисел через запятую либо ссылка на массив чисел.  called from '$package/$filename/$line' ".($mason_file ? "called from $mason_file" : '')."\n";
		return ' FALSE ', [];
	}
}

sub _generic_composite_filter {
	my ($field, $condition, $value, $mode ) = @_;
	unless ( $condition ) {
		warn "Contenido Warning (_generic_composite_filter): Неверно задан формат!\n";
		return ' FALSE ';
	}
	$condition = uc($condition) if $condition =~ /^[\w\s]+$/;
	if ( $value eq NIL() ) {
		return ' TRUE ';
	} elsif ( defined($value) && !ref($value) ) {
		if ( ( $mode eq 'text' && !$_TEXT_CONDITIONS{$condition} ) || ( $mode ne 'text' && !$_CONDITIONS{$condition} ) ) {
			warn "Contenido Warning (_generic_composite_filter): Неверно задан формат неравенства, недопустимое условие \"$condition\"!\n";
			return ' FALSE ';
		}
		return "$field $condition ?", $value; 
	} elsif ( ref($value) eq 'ARRAY' && scalar(@{ $value }) ) {
		my $in = 'IN (';
		my $i = 0;
		unless ( $condition eq 'NOT' ) {
			warn "Contenido Warning (_generic_composite_filter): Неверно задан формат, недопустимое условие \"$condition\"!\n";
			return ' FALSE ';
		}
		foreach my $v ( @{ $value } ) {
			$in .= '?';
			$in .= ',' if $#{ $value } != $i; 
			$i++;
		}
		$in .= ')';
		return "$field $condition $in", $value;
	} else {
		warn "Contenido Warning (_generic_composite_filter): Неверно задано значение, ожидается скаляр или ссылка на массив!\n ";
		return ' FALSE ';
	}
}

sub _composite_date_filter {
	my ($field, $condition, $value ) = @_;
	unless ( $condition ) {
		warn "Contenido Warning (_composite_date_filter): Неверно задан формат!\n";
		return ' FALSE ';
	}
	if ( $value eq NIL() ) {
		return ' TRUE ';
	} elsif ( defined($value) && !ref($value) ) {
		unless ( $_DATE_CONDITIONS{$condition} ) {
			warn "Contenido Warning (_composite_date_filter): Неверно задан формат неравенства, недопустимое условие \"$condition\"!\n";
			return ' FALSE ';
		}
		if ( $value =~ /^\d+$/ ) {
			my $date = Contenido::DateTime->new(epoch => $value)->strftime('%Y-%m-%d %H:%M:%S');
			return " ($field $condition ?::TIMESTAMP) ", $date;
		} elsif ( $value =~ /^\d{4}-\d{2}-\d{2}$/ || $value =~ /^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}(?:\:\d{2})?$/ ) {
			return " ($field $condition ?::TIMESTAMP) ", $value;
		} else {
			warn "Contenido Warning (_composite_date_filter): Неверно задано значение! Правильный формат строка \"YYYY-MM-DD[ HH24:MI[:SS]]\" или дата в формате unixtime\n";
			return ' FALSE ';
		}
	} else {
		warn "Contenido Warning (_composite_date_filter): Неверно задано значение! Правильный формат строка \"YYYY-MM-DD[ HH24:MI[:SS]]\" или дата в формате unixtime\n";
		return ' FALSE ';
	}	
}

sub _generic_null_filter {
	my ($field, $param )= @_;
	$param = uc($param);
	if ( $param ne 'NULL' && $param ne 'NOT NULL' ) {
		warn "Contenido Warning (_generic_null_filter): Неверно задан значение, ожидается 'NULL' или 'NOT NULL'!\n";
		return ' FALSE ';
	}
	return "$field IS $param";	
}

sub _generic_date_filter {
	my ($field, $param )= @_;
	if ( defined($param) && !ref($param)  ) {
		if ( $param =~ /^\d+$/ ) {
			my $date = Contenido::DateTime->new(epoch => $param)->strftime('%Y-%d-%m %H:%M');
			return " ($field >= ?::TIMESTAMP AND $field < ?::TIMESTAMP+'1 min'::INTERVAL) ", [$date, $date];
		} elsif ( $param =~ /^\d{4}-\d{2}-\d{2}$/ ) {
			return " ($field >= ?::TIMESTAMP AND $field < ?::TIMESTAMP+'1 day'::INTERVAL) ", [$param, $param];
		} elsif ( $param =~ /^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}(?:\:\d{2})?$/ ) {
			return " ($field >= ?::TIMESTAMP AND $field < ?::TIMESTAMP+'1 min'::INTERVAL) ", [$param, $param];
		} else {
			warn "Contenido Warning (_generic_date_filter): Неверно задано значение! Правильный формат строка \"YYYY-MM-DD[ HH24:MI[:SS]]\" или дата в формате unixtime\n";
			return ' FALSE ';
		}
	} elsif ( !defined($param) ) {
		return "$field IS NULL";
	} else {
		warn "Contenido Warning (_generic_date_filter): Неверно задано значение! Правильный формат строка \"YYYY-MM-DD[ HH24:MI[:SS]]\" или дата в формате unixtime\n";
		return ' FALSE ';
	}
}

sub _generic_float_filter {
	my ($field,$value,$negation)=@_;

	my $mode = $negation ? 'NOT IN':'IN';

	#undef <=> NULL
	if ( !defined($value) ) {
		$mode = $negation ? 'IS NOT' : 'IS';
		return "$field $mode NULL", [];
	} elsif (ref($value) eq 'ARRAY' and @$value) {
        my $values_string = '?, 'x(scalar (@$value)-1).'?';
        return " ($field $mode ($values_string)) ", $value;
    } elsif (ref($value) eq 'ARRAY') {
        # skip empty array
        return ($negation ? ' TRUE ' : ' FALSE '), [];
	} else {
		return " ($field $mode (?)) ", [$value];
	}
}

# raw flag for disable placeholders use... (need manual escaping before)... sometime need for partial indexes use with prepared statements
sub _generic_text_filter {
        my ($field,$value,$negation,$raw)=@_;

        my $mode = $negation ? 'NOT IN':'IN';

        #undef <=> NULL
        if ( !defined($value) ) {
                $mode = $negation ? 'IS NOT' : 'IS';
                return "$field $mode NULL", [];
        } elsif (ref($value) eq 'ARRAY') {
                if ($raw) {
                        my $values_string = "'".join ("','",@$value)."'";
                        return " ($field $mode ($values_string)) ", [];
                } else {
                        my $values_string = '?, 'x(scalar (@$value)-1).'?';
                        return " ($field $mode ($values_string)) ", $value;
                }
        } else {
                if ($raw) {
                         return " ($field $mode ('$value')) ", [];
                } else {
                        return " ($field $mode (?)) ", [$value];
                }
        }
}

sub _generic_name_filter {
	my ($field,$value,$negation,$opts)=@_;
	$opts ||= {};

	#like and ilike modes incompatible with [] in $opts{name}
	if ($opts->{like}) {
		my $mode = $negation ? "NOT" : "";
		return " $field $mode LIKE ? ", [$value];
	} elsif ($opts->{ilike}) {
		my $mode = $negation ? "NOT" : "";
		return " $field $mode ILIKE ? ", [$value];
	} else {
		return &SQL::Common::_generic_text_filter($field,$value,$negation,0);
	}
}

sub _generic_intarray_filter {
	my ($field, $value, $opts)=@_;

	#undef <=> FALSE here!!!!
	if (defined($value)) {
		if (ref($value) ne 'ARRAY') {
			if ($value =~ /^[\d ,]+$/) {
				$value = [split(/\s*,\s*/, $value)];
			} else {
				warn "Contenido Warning: В списке для _generic_int_array_filter есть нечисловые элементы ('$value'). Параметр игнорируется.";
				return [' FALSE '], [];
			}
		}

		if (@$value) {
			my $op = (ref($opts) eq 'HASH' and ($opts->{intersect} or $opts->{contains})) ? '@>' : '&&';
#           old versions DBD::Pg is SO STUPID!!!!
#			if ($DBD::Pg::VERSION<1.49) {
#				my $value_string = '{'.join(',',@{$value}).'}';
#				return [" ($field $op ?) "], [$value_string];
#			} else {
#           all versions before 2.0.0 also stupid
            if ($DBD::Pg::VERSION=~/^1\./) {
                my $ph_string = '?, 'x$#{$value}.'?';
				return [" ($field $op ARRAY[$ph_string]::integer[]) "], $value;
			} else {
                return [" ($field $op ?::integer[]) "], [$value];
            }                    
		} else {
			return [' FALSE '], [];
		}
	} else {
		return [' FALSE '], [];
	}
}

sub _get_limit {
	my %opts=@_;
	if (exists($opts{limit})) {
		return ' LIMIT 1000' unless defined $opts{limit};
		if ($opts{limit} !~ /\D/) {
			return ' LIMIT '.$opts{limit};
		} else {
			warn "Contenido Warning: Неверно заданы пределы выборки ($opts{limit})";
			return ' LIMIT 1000';
		}
	} elsif ($opts{no_limit}) {
		return undef;
	} else {
		return ' LIMIT 1000';
	}
}

sub _get_offset {
	my %opts=@_;
	if ( exists($opts{offset})) {
		return undef unless defined $opts{offset};
		if ($opts{offset} !~ /\D/) {
			return ' OFFSET '.$opts{offset};			
		} else {
			my $mason_comp = ref($HTML::Mason::Commands::m) ? $HTML::Mason::Commands::m->current_comp() : undef;
			my $mason_file = ref($mason_comp) ? $mason_comp->path : undef;

			warn "ERROR: $$ ".__PACKAGE__."  ".scalar(localtime())." ".($mason_file ? "called from $mason_file" : '')." Для _get_offset неверно задан параметр offset: '$opts{offset}'\n";
			return undef;
		}
	}
}


1;
