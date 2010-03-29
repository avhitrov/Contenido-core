package SQL::ProtoTable;

use strict;
use SQL::Common;
use Contenido::Globals;
#подгружаем общеупотребимые фильтры
#и механизм автофильтров
use base qw(SQL::CommonFilters SQL::AutoTable);

sub new {
	my $class=shift;
	my $self={};
	bless ($self,$class);
	return $self;
}

#most tables have extra table
sub have_extra {
	return 1;
}

#most tables dont use single class mode
sub _single_class {
	return undef;
}

#most tables have _auto disabled
sub _auto {
	return 0;
}

sub available_filters {
	return ();
}

#todo переключить hardcoded 'id' на вызовы id_field там где они использовались
sub id_field {
	return 'id';
}

sub extra_table {
	my $self=shift;
	return $self->db_table().'_extra';
}

sub _get_object_key {
	my ($self,$item,$id) = @_;
	return ref($item) ? ref($item).'|'.$item->id : $item.'|'.$id;
}

# Атрибут с уникальными значениями, однозначно определяющий объект.
# Обычно name, но undef возвращается для снижения нагрузки на memcached -
# в этом случае получение и кеширование таких объектов по этому атрибуту
# считается невозможным.
sub unique_attr {
    return undef;
}

sub _get_object_unique_key {
	my ($self, $item, $value) = @_;
    my $attr = $self->unique_attr;
    return undef unless defined $attr;
	return
        ref($item)
            ? ref($item) . '|' . $attr . '|' . $item->$attr
            : $item . '|' . $attr . '|' . $value;
}

sub required_hash {
	my $self = shift;
	my $class = ref $self || $self;
	return unless scalar $self->required_properties();
	{
		no strict 'refs';
		if ( ref( ${ $class.'_required_hash' } ) eq 'HASH' ) {
			return ${ $class.'::_required_hash' };
		} else {
			my $struct;
			foreach my $field ( $self->required_properties() ) {
				$struct->{$field->{attr}} = $field;
			}
			${ $class.'::_required_hash' } = $struct;
			return $struct;
		}
		use strict;
	}
}

sub _get_fields {
	my $self =shift;
	my @fields;
	foreach ($self->required_properties()) {
		next if ($_->{attr} eq 'class' or $_->{attr} eq 'id');
		next unless ($_->{db_field});
		push @fields, ($_->{no_prefix_db_field} ? '' : 'd.') . $_->{db_field};
	}
	return @fields;
}


sub _get_orders {
	my $self =shift;
	my %opts=@_;

	my $rh = $self->required_hash();

	if (exists($opts{order})) {
		if (ref($opts{order}) eq 'ARRAY' and scalar(@{$opts{order}})==2) {
			my $order = ($opts{order}->[1] eq 'reverse') ? 'ASC' : 'DESC';
			if (lc($opts{order}->[0]) eq 'id') {
				return " ORDER BY d.id $order";
			} elsif (lc($opts{order}->[0]) eq 'date') {
				my $field = $opts{usedtime};
				$field =~ s/^d\.(.*)$/$1/;
				if ($rh->{$field}) {
					return " ORDER BY $opts{usedtime} $order";
				} else {
					warn "Contenido Warning: attempt sort by $opts{usedtime} but no $field field in db...";
					return undef;
				}
			} elsif(lc($opts{order}->[0]) eq 'name') {
				if ($rh->{name}) {
					return " ORDER BY d.name $order";
				} else {
					warn "Contenido Warning: attempt sort by 'name' but no 'name' field in db...";
					return undef;
				}
			} else {
				warn "Contenido Warning: На данный момент сортировка возможна только по полю id или даты или имени.";
			}
		} else {
                	my $mason_comp = ref($HTML::Mason::Commands::m) ? $HTML::Mason::Commands::m->current_comp() : undef;
                	my $mason_file = ref($mason_comp) ? $mason_comp->path : undef;
                	warn "WARNING: $$ ".__PACKAGE__."  ".scalar(localtime()).($mason_file ? " called from $mason_file " : ' ').'Неверный формат задания сортировки. Это должна быть ссылка на массив с двумя полями - названием столбца и направлением сортировки, на входе имеем: '.Data::Dumper::Dumper($opts{order})."\n";
		}
	#custom hand made order
	} elsif ($opts{order_by}) {
		return " ORDER BY $opts{order_by}";
	}
	return "";
}

#возможно 2 типа фильтров... ручные список которых задан в self->available_filters и автоматические которые генерирются на основе структуры таблицы в базе
sub apply_filters {
	my ($self, $opts) = @_;

	unless (exists $opts->{usedtime}) {
		$opts->{usedtime} = 'd.dtime';
		$opts->{usedtime} = 'd.mtime'	if (exists($opts->{use_mtime}) && $opts->{use_mtime}==1);
		$opts->{usedtime} = 'd.ctime'	if (exists($opts->{use_ctime}) && $opts->{use_ctime}==1);
	}

	#начальная инициализация набора фильтров и значений
	#ToDo наверно обьектом его сделать класса SQL::FilterSet
	my $filter_set = {wheres=>[], binds=>[], joins=>[], join_binds=>[]};

	no strict 'refs';

	#main loop on allowed filters
	my $available_filters = $self->available_filters();
	foreach my $filter (@$available_filters) {
		$self->_add_filter_results($filter_set, $self->$filter(%$opts));
	}
	#loop on autofilters
	my $filters = ${(ref($self)||$self).'::filters'} || {};
	foreach my $key (keys %$opts) {
		$self->_add_filter_results($filter_set, &{$filters->{$key}}($opts->{$key}, $opts)) if ($filters->{$key});
	}
	#apply sort_join (в самом конце после все joins предыдущих)
	$self->_add_filter_results($filter_set, $self->_sort_join($opts));

	return $filter_set;
}

#меняет значение в $filter_set
sub _add_filter_results {
	my ($self, $filter_set, $where, $bind, $join, $join_bind) = @_;
        push @{$filter_set->{wheres}},   	$where && ref($where) eq 'ARRAY' ? @$where : $where || ();
        push @{$filter_set->{binds}},    	$bind &&  ref($bind)  eq 'ARRAY' ? @$bind  : $bind  || ();
        push @{$filter_set->{joins}},    	$join &&  ref($join)  eq 'ARRAY' ? @$join  : $join  || ();
        push @{$filter_set->{join_binds}},	$join_bind && ref($join_bind) eq 'ARRAY' ? @$join_bind : $join_bind || ();
}

sub _sort_join {
	my ($self, $opts) = @_;
	return undef unless ($opts->{sort_list} and $opts->{no_order} and (ref($opts->{sort_list}) eq 'ARRAY') and @{$opts->{sort_list}});
	#проставляем флаг что вообще то нам надо будет потом по order_tabl.pos сортировать
	$opts->{_sort_join_used} = 1;
	my $value = $opts->{sort_list};
	my $ph_string = '?, 'x$#{$value}.'?';
        return (undef,undef,[" left outer join (select (ARRAY[$ph_string]::integer[])[pos] as id,pos from generate_series(1,?) as pos) as order_table on d.id=order_table.id "], [@$value, $#{$value}+1]);
}

sub get_fields {
	my ($self, $opts, $joins) = @_;

	my $fields;
	if ($opts->{names}) {
		#possible incompatible with custom tables if not exist 'name' field
		$fields = ['d.id','d.name'];
	} elsif ($opts->{ids}) {
		$fields = ['d.id'];
	} elsif ($opts->{field}) {
		if (ref($opts->{field}) eq 'ARRAY') {
			$fields = [ map {/\./ ? $_:'d.'.$_} @{$opts->{field}} ];
		} else {
			$fields = [ $opts->{field} =~ /\./ ? $opts->{field}:'d.'.$opts->{field} ];
		}
	} elsif ($opts->{count}) {
		$fields = [$opts->{distinct} ? 'COUNT (DISTINCT d.id)':'COUNT(d.id)'];
	} else {
		if ($self->_single_class) {
			$fields = ["'".$self->_single_class."'", 'd.id', $self->_get_fields()];
		} else {
			$fields = ['d.class', 'd.id', $self->_get_fields()];
		}

		if (!$opts->{light} and $self->have_extra()) {
			if ($Contenido::Globals::store_method eq 'sqldump') {
				push @$fields, 'extra.data';
				push @$joins,	' LEFT JOIN '.$self->db_table.'_extra AS extra ON extra.id=d.id ';
			} elsif ($Contenido::Globals::store_method eq 'toast') {
				push @$fields, 'd.data';
			}
		}
	}
	return $fields;
}

#Ура теперь эта функция не занимает 2 страницы кода
sub generate_sql {
	my ($self,%opts)=@_;

	#получаем список фильтров и значений к ним
	my $filter_set = $self->apply_filters(\%opts);

	#возможна модификация $joins тут
	my $fields = $self->get_fields(\%opts, $filter_set->{joins});

	my $query = 'SELECT ';
	$query	.= ' DISTINCT '						if ($opts{distinct} and !$opts{count});
	$query	.= ' '.join(', ', @$fields).' FROM '.$self->db_table.' AS d';
	$query	.= ' '.join(' ', @{$filter_set->{joins}})		if (@{$filter_set->{joins}});
	$query	.= ' WHERE '.join(' AND ', @{$filter_set->{wheres}})	if (@{$filter_set->{wheres}});
	$query	.= ' '.$self->_get_orders(%opts) 			unless ($opts{no_order});
	$query  .= ' ORDER BY order_table.pos '				if ($opts{_sort_join_used}); 
	$query	.= ' '.&SQL::Common::_get_limit (%opts);
	$query	.= ' '.&SQL::Common::_get_offset(%opts);    

	return \$query, [@{$filter_set->{join_binds}}, @{$filter_set->{binds}}];
}

sub required_properties {
	my $self = shift;
	my $class = ref($self) || $self;

	#если не авто мы сюда не должны попадать
	die "$class have no _auto enabled and no required_properties!!!" unless ($class->_auto());

	my $set;
	{
		no strict 'refs';
		SQL::ProtoTable->table_init($class) unless (${$class.'::_init_ok'});
		$set = ${$class.'::_rp'};
	}
	die "$class have wrong internal structure" unless ($set and (ref($set) eq 'ARRAY'));
	return @$set;
}

sub table_init {
	my $self = shift;
	my $class = shift;

	unless ($class) {
        	my ($package, $filename, $line) = caller;
        	die "table_init called for empty class from '$package' '$filename' '$line'\n";
    	}

	unless ($INC{$class}) {
		eval "use $class";
		die "error on require $class: '$@'" if ($@);
		die "class $class can't db_table" unless ($class->can('db_table') and $class->db_table);
		die "class have no required parent" unless ($class->isa('SQL::ProtoTable'));
	}

	{
		no strict 'refs';
		return 1 unless ($class->_auto());
		return 1 if	(${$class.'::_init_ok'});
	}

	#сюда попадаем если автоинициализация таблицы используется
	return $self->auto_init($class);
}

1;

