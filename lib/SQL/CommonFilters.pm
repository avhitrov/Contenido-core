package SQL::CommonFilters;

use strict;
use SQL::Common;
use Contenido::Globals;

########### FILTERS DESCRIPTION ####################################################################################
sub _status_filter {
	my ($self, %opts)=@_;
	return undef unless ( exists($opts{status}) );
	return &SQL::Common::_generic_int_filter('d.status', $opts{status});
}

sub _class_filter {
	my ($self, %opts)=@_;
	return undef unless ( exists($opts{class}) );
	return &SQL::Common::_generic_text_filter('d.class', $opts{class});
}

sub _in_id_filter {
	my ($self, %opts)=@_;
	return undef unless ( exists($opts{in_id}) );
	return &SQL::Common::_generic_int_filter('d.id', $opts{in_id});
}

sub _id_filter {
	my ($self, %opts)=@_;
	return undef unless ( exists($opts{id}) );
	return &SQL::Common::_generic_int_filter('d.id', $opts{id});
}

sub _sfilter_filter {
	my ($self, %opts)=@_;
	return undef unless ( exists($opts{sfilter}) );
	return &SQL::Common::_generic_intarray_filter('d.sections', $opts{sfilter});
}

sub _name_filter {
	my ($self, %opts)=@_;
	return undef unless ( exists($opts{name}) );
	return &SQL::Common::_generic_name_filter('d.name', $opts{name}, 0, \%opts);
}


sub _datetime_filter {
	my ($self, %opts)=@_;
	return undef unless ( exists($opts{datetime}) );
	if ($opts{datetime} eq 'future') {
		return " ($opts{usedtime} >= CURRENT_TIMESTAMP) ";
	} elsif ($opts{datetime} eq 'past') {
		return " ($opts{usedtime} <= CURRENT_TIMESTAMP) ";
	} elsif ($opts{datetime} eq 'today') {
		return " ($opts{usedtime}>=CURRENT_DATE AND $opts{usedtime}<CURRENT_DATE+'1 day'::INTERVAL) ";
	} elsif (ref $opts{'datetime'} && ref $opts{'datetime'} eq 'HASH') {
		my ($type, $time) = %{$opts{'datetime'}};
		if ($time =~ /^\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}(?:\.\d+)?$/ && $type eq 'after') {
			return " ($opts{usedtime} >= '$time') ";
		} elsif ($time =~ /^\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}(?:\.\d+)?$/ && $type eq 'before') {
			return " ($opts{usedtime} <= '$time') ";
		} else {
			warn "Contenido Warning: Неверно задан фильтр datetime='$opts{datetime}' допустимые значения: 'future','past','today', {['after' || 'before'] => [timestamp]}\n";
			return ' FALSE ';
		}
		return " ($opts{usedtime}>=CURRENT_DATE AND $opts{usedtime}<CURRENT_DATE+'1 day'::INTERVAL) ";
		
	} else {
		warn "Contenido Warning: Неверно задан фильтр datetime='$opts{datetime}' допустимые значения: 'future','past','today', {['after' || 'before'] => [timestamp]}\n";
		return ' FALSE ';
	}
}

sub _date_equal_filter {
	my ($self, %opts)=@_;
	return undef unless ( exists($opts{date_equal}) );

	# - запрос на совпадение даты / YYYY-MM-DD
	if ( $opts{date_equal} =~ /^\d{4}-\d{2}-\d{2}$/) {
		return " ($opts{usedtime}>=?::TIMESTAMP AND $opts{usedtime}<?::TIMESTAMP+'1 day'::INTERVAL) ", [$opts{date_equal},$opts{date_equal}];
	} else {
		warn "Contenido Warning: Неверно задан формат даты '$opts{date_equal}'. Правильный формат - YYYY-MM-DD.";
		return ' FALSE ';
	}
}

sub _date_filter {
	my ($self, %opts)=@_;
	return undef unless ( exists($opts{date}) );
	# - запрос на извлечение документов из интервала дат...
	if ( ref($opts{date}) eq 'ARRAY' and scalar(@{$opts{date}})==2 ) {
		#pure dates
		if ( ($opts{date}->[0] =~ /^\d{4}-\d{2}-\d{2}$/) and ($opts{date}->[1] =~ /^\d{4}-\d{2}-\d{2}$/) ) {
			return " ($opts{usedtime}>=?::TIMESTAMP AND $opts{usedtime}<?::TIMESTAMP+'1 day'::INTERVAL) ", [$opts{date}->[0],$opts{date}->[1]];
		#datetimes
		} elsif ( ($opts{date}->[0] =~ /^\d{4}-\d{2}-\d{2}/) && ($opts{date}->[1] =~ /^\d{4}-\d{2}-\d{2}/) ) {
			return " ($opts{usedtime}>=? AND $opts{usedtime}<=?) ", [$opts{date}->[0],$opts{date}->[1]];
		} else {
			warn "Contenido Warning: Неверно задан формат даты для параметра date. Это должен быть массив с двумя элементами типа YYYY-MM-DD или YYYY-MM-DD HH:MM:SS. ['$opts{date}->[0]', '$opts{date}->[1]']\n";
			return ' FALSE ';
		}
	} else {
		warn "Contenido Warning: Неверно задан формат даты для параметра date. Это должен быть массив с двумя элементами типа YYYY-MM-DD или YYYY-MM-DD HH:MM:SS.";
		return ' FALSE ';
	}
}

sub _class_excludes_filter {
	my ($self, %opts)=@_;
	return undef unless ( exists($opts{class_excludes}) );
	return &SQL::Common::_generic_text_filter('d.class', $opts{class_excludes}, 'NEGATION');
}

sub _s_filter {
	my ($self, %opts) = @_;
	return undef unless ( exists($opts{s}) );

	if ($opts{dive}) {
		my @all_childs = @{$opts{all_childs}};
		# - если задан параметр include_parent, то включим в выборку корень...
		# По умолчанию выключен...
		push (@all_childs, $opts{s}) if ($opts{include_parent});

		return &SQL::Common::_generic_intarray_filter('d.sections', \@all_childs, \%opts);
	} else {
		return &SQL::Common::_generic_intarray_filter('d.sections', $opts{s}, \%opts);
	}
}


sub _previous_days_filter {
	my ($self, %opts)=@_;
	return undef unless ( exists($opts{previous_days}) );
	# - запрос на все данных из заданных последних дней...
	if ($opts{previous_days} =~ /^\d+$/) {
		return " $opts{usedtime} >= (CURRENT_DATE - ?::interval)::TIMESTAMP ", "$opts{previous_days} DAYS";
	} else {
		warn "Contenido Warning: Неверно задан формат дней для параметра previous_days. Это должно быть число дней\n";
		return ' FALSE ';
	}
}

sub _previous_time_filter {
	my ($self, %opts)=@_;
	return undef unless exists $opts{previous_time};
	if ($opts{previous_time} =~ /\D/) {
		warn "Contenido Warning: Неверно задано кол-во для параметра previous_time.\n";
		return ' FALSE ';
	} else {
		return "$opts{usedtime} >= (NOW() - ?::interval)::TIMESTAMP ", ($opts{previous_time} . ' ' . ($opts{previous_time_units} || 'HOURS'));
	}
}

sub _prev_to_filter {
	my ($self, %opts)=@_;
	return undef unless ( exists $opts{prevto} || exists $opts{prev_to} );
	my $prevto = exists $opts{prevto} ? 'prevto' : 'prev_to';
	my ($wheres, $values) = ([],[]);
	my $field = exists $opts{use_id} ? 'id' : exists $opts{use_ctime} ? 'ctime' : exists $opts{use_mtime} ? 'mtime' : 'dtime';
	push @$wheres, " d.$field < ? ";
	if ( ref $opts{$prevto} ) {
		my $ctime = $opts{$prevto};
		push @$values, $ctime->ymd('-').' '.$ctime->hms.'.'.$ctime->nanosecond;
	} else {
		push @$values, $opts{$prevto};
	}
	return ($wheres, $values);
}

sub _next_to_filter {
	my ($self, %opts)=@_;
	return undef unless ( exists $opts{nextto} || exists $opts{next_to} );
	my $nextto = exists $opts{nextto} ? 'nextto' : 'next_to';
	my ($wheres, $values) = ([],[]);
	my $field = exists $opts{use_id} ? 'id' : exists $opts{use_ctime} ? 'ctime' : exists $opts{use_mtime} ? 'mtime' : 'dtime';
	push @$wheres, " d.$field > ? ";
	if ( ref $opts{$nextto} ) {
		my $ctime = $opts{$nextto};
		push @$values, $ctime->ymd('-').' '.$ctime->hms.'.'.$ctime->nanosecond;
	} else {
		push @$values, $opts{$nextto};
	}
	return ($wheres, $values);
}

sub _excludes_filter {
	my ($self,%opts)=@_;
	return undef unless ( exists($opts{excludes}) );
	return &SQL::Common::_generic_int_filter('d.id', $opts{excludes}, 'NEGATION');
}

sub _auto_filter {
	my ( $self, %opts ) = @_;
	my @exclude = qw( order_by limit offset no_limit count ids light hash_by return_mode );
	my $sql;

	my @wheres;
	my @binds;
	my @joins;

	my ( $struct, $query_table );
	
	if ( $opts{join} ) {

		if ( !$opts{join}->can('class_table') || !$opts{join}->class_table()->can('db_table') ) {
			warn "Contenido Warning (_auto_filter): Не могу получить имя таблицы для \"склейки\"!\n";
			return (undef);
		}
		$query_table = $opts{join}->class_table()->db_table();
		$struct =	$opts{join}->class_table()->required_hash();
	
		if ( $opts{field} && !$struct->{ $opts{field} } ) {
			warn "Contenido Warning (_auto_filter): В таблице $query_table нет поля ".$opts{field}."!\n";
			return (undef);
		}

		push @joins, ' join '.$query_table.' on '.$query_table.'.'.( $opts{field} ? $opts{field} : 'id' ).' = '.$opts{__join_table}.'.'.$opts{__join_field}.' ';

	} else {
		$struct = $self->required_hash();
		$query_table = 'd';
	}
	
	foreach my $param ( keys %opts ) {
		next if ( grep { $param eq $_ } @exclude ) || !$struct->{$param} || !exists($opts{$param}) || $struct->{$param}->{_no_autofilter};
		next if $opts{$param} eq SQL::Common::NIL();
		if ( uc($opts{$param}) eq 'NULL' || uc($opts{$param}) eq 'NOT NULL' || !defined($opts{$param}) ) {
			$opts{$param} = 'NULL' unless defined $opts{$param};
			my ($where, $values) = &SQL::Common::_generic_null_filter($query_table.'.'.$param, $opts{$param});
			push (@wheres, $where);
			push (@binds, $values) if (defined $values);
			next;
		} elsif ( $struct->{$param}->{db_type} eq 'integer' or $struct->{$param}->{type} eq 'checkbox') {
			my ($where, $values);
			if ( ref( $opts{$param} ) eq 'HASH') {
				if ( $opts{$param}->{join} ) { 
					my ( $sub_wheres, $sub_binds, $joins ) = $self->_auto_filter( %{ $opts{$param} }, __join_table => $query_table, __join_field => $param );
					push (@wheres, ref($sub_wheres) eq 'ARRAY' ? @{ $sub_wheres } : $sub_wheres ) if defined $sub_wheres;
					push (@binds, ref($sub_binds) eq 'ARRAY' ? @{ $sub_binds } : $sub_binds ) if defined $sub_binds;
					push (@joins, ref($joins) eq 'ARRAY' ? @{ $joins } : $joins ) if defined $joins;
					
				} else {
					foreach my $condition ( keys %{ $opts{$param} } ) { 
						($where, $values) = &SQL::Common::_generic_composite_filter($query_table.'.'.$param, $condition, $opts{$param}->{$condition});
						push (@wheres, $where);
						push (@binds, ref($values) ? @$values : $values) if (defined $values);
					}
				}
			} else {
				if ( !ref($opts{$param}) && $opts{$param} !~ /^\-?\d+$/ ) {
					warn "Contenido Warning (_auto_filter): Неверно задано значение для типа integer! ($opts{$param})\n";
					next;
				}
				($where, $values) = &SQL::Common::_generic_int_filter($query_table.'.'.$param, $opts{$param});
				push (@wheres, $where);
				push (@binds, ref($values) ? @$values : $values) if (defined $values);

			}
		} elsif ( $struct->{$param}->{db_type} eq 'integer[]' ) {
			my ($where, $values) = &SQL::Common::_generic_intarray_filter($query_table.'.'.$param, $opts{$param});
			push (@wheres, ref $where ? @$where : $where);
			push (@binds,	ref($values) ? @$values : $values) if (defined $values);
		} elsif ( $struct->{$param}->{db_type} =~ /char/ || $struct->{$param}->{db_type} eq 'text' ) {
			my ($where, $values);
			if ( ref( $opts{$param} ) eq 'HASH') {
				foreach my $condition ( keys %{ $opts{$param} } ) { 
					($where, $values) = &SQL::Common::_generic_composite_filter($query_table.'.'.$param, $condition, $opts{$param}->{$condition}, 'text');
					push (@wheres, $where);
					push (@binds, ref($values) ? @$values : $values) if (defined $values);
				}
			} elsif ($param eq 'name') {
				# Исключение: для параметра name используем специальный фильтр
				($where, $values) = &SQL::Common::_generic_name_filter($query_table.'.'.$param, $opts{$param}, undef, \%opts);
				push (@wheres, $where);
				push (@binds,	ref($values) ? @$values : $values) if (defined $values);
			} else {
				($where, $values) = &SQL::Common::_generic_text_filter($query_table.'.'.$param, $opts{$param}, $opts{"${param}_negative"});
				push (@wheres, $where);
				push (@binds,	ref($values) ? @$values : $values) if (defined $values);
			}
		} elsif ( $struct->{$param}->{type} eq 'datetime' or $struct->{$param}->{type} eq 'date' ) {
			my ($where, $values);
			if ( ref( $opts{$param} ) eq 'HASH') {
				foreach my $condition ( keys %{ $opts{$param} } ) { 
					($where, $values) = &SQL::Common::_composite_date_filter($query_table.'.'.$param, $condition, $opts{$param}->{$condition});
					push (@wheres, $where);
					push (@binds, ref($values) ? @$values : $values) if (defined $values);
				}
			} elsif ( $opts{$param} && !ref( $opts{$param} ) ) {	
				($where, $values) = &SQL::Common::_generic_date_filter($query_table.'.'.$param, $opts{$param});
				push (@wheres, $where);
				push (@binds,	ref($values) ? @$values : $values) if (defined $values);
			} else {
				warn "Contenido Warning (_auto_filter): Неверно задано значение для поля datetime, ожидается строка в формате 'YYYY-MM-DD[ HH24:MI]', дата в формате unixtime или ссылка на хэш!\n";
				next;
			}
		} elsif ( $struct->{$param}->{db_type} eq 'real' ) {
			my ($where, $values);
			if ( !ref($opts{$param}) && $opts{$param} !~ /^\-?[\d\.]+$/ ) {
				warn "Contenido Warning (_auto_filter): Неверно задано значение для вещественного поля!\n";
				next;
			}
			if ( ref( $opts{$param} ) eq 'HASH') {
				foreach my $condition ( keys %{ $opts{$param} } ) { 
					($where, $values) = &SQL::Common::_generic_composite_filter($query_table.'.'.$param, $condition, $opts{$param}->{$condition});
					push (@wheres, $where);
					push (@binds, ref($values) ? @$values : $values) if (defined $values);
				}
			} else {
				($where, $values) = &SQL::Common::_generic_text_filter($query_table.'.'.$param, $opts{$param});
				push (@wheres, $where);
				push (@binds,	ref($values) ? @$values : $values) if (defined $values);
			}

		}
	}
	return (\@wheres, \@binds, \@joins); 
	
}

sub _link_filter {
	my ($self,%opts)=@_;

	my @wheres=();
	my @binds=();

	# Связь определенного класса
	if (exists($opts{lclass})) {
		my ($where, $values) = SQL::Common::_generic_text_filter('l.class', $opts{lclass});
		push (@wheres, $where);
		push (@binds,	ref($values) ? @$values:$values) if (defined $values);
	}

	my $lclass = $opts{lclass} || 'Contenido::Link';
#	my $link_table = $lclass->class_table->db_table();
	my $link_table = $lclass->_get_table->db_table();

	# Ограничение по статусу связи
	if ( exists $opts{lstatus} ) {
		my ($where, $values) = SQL::Common::_generic_int_filter('l.status', $opts{lstatus});
		push (@wheres, $where);
		push (@binds,	ref($values) ? @$values:$values) if (defined $values);
	}

	# Связь с определенным документ(ом/тами) по цели линка
	if ( exists $opts{ldest} ) {
		my ($where, $values) = SQL::Common::_generic_int_filter('l.dest_id', $opts{ldest});
		push (@wheres, $where);
		push (@binds,	ref($values) ? @$values:$values) if (defined $values);
		if ($self->_single_class) {
			return (\@wheres, \@binds, " join $link_table as l on l.source_id=d.id");
		} else {
			return (\@wheres, \@binds, " join $link_table as l on l.source_id=d.id and l.source_class=d.class");
		}
	}

	# Связь с определенным документ(ом/тами) по источнику линка
	if ( exists $opts{lsource} ) {
		my ($where, $values) = SQL::Common::_generic_int_filter('l.source_id', $opts{lsource});
		push (@wheres, $where);
		push (@binds,	ref($values) ? @$values:$values) if (defined $values);
		if ($self->_single_class) {
			return (\@wheres, \@binds, " join $link_table as l on l.dest_id=d.id");
		} else {
			return (\@wheres, \@binds, " join $link_table as l on l.dest_id=d.id and l.dest_class=d.class");
		}
	}

	return (undef);
}

1;

