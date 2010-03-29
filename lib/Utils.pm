package Utils;

use strict;
use vars qw ($VERSION @ISA @EXPORT);
use base 'Utils::HTML';

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(   &eval_config_file
                &dump_config_file
                &_mkdir
                &looks_like_id
                &time_unix_to_timestamp
                &time_timestamp_to_unix
                &abort404 
                &abort403 
                &abort503 
                &http_abort 
            );
$VERSION = '0.1';

use Data::Dumper;
use CGI;
use locale;
use File::Find;
use Time::Local;
use URI::Escape;
use Contenido::Init;
use Convert::Cyrillic;

sub looks_like_id { shift =~ /^\d+$/ ? 1 : 0 }


# ----------------------------------------------------------------------------
# Рекурсивное создание директории
# ----------------------------------------------------------------------------
sub _mkdir
{
	my $directory = shift;

	return	-1	if (! defined($directory));
	
	# Создаем необходимые промежуточные директории
	if (! -d $directory) {
		my $e = `mkdir -p $directory`;
		unless(-d $directory) {
			warn "Contenido Warning: Не могу создать директорию $directory по причине $! ($e)";
			return -1;
		}
	}

	return 1;
}

sub eval_config_file
{
	my $config_file = shift;

	open (FILE, "< $config_file") || do {
		warn "Utils: Не могу прочитать файл $config_file по причине $!\n";
		return undef;
	};
	my @CFILE = <FILE>;
	my $eval_line = join(' ', @CFILE);
	close (FILE);

	my $CONFIG = {};
	{
		local $SIG{'__DIE__'};
		$CONFIG = eval ('use vars qw($VAR1); '. $eval_line);

	};
	if ($@)
	{
		warn "Utils: При обработке файла $config_file произошла ошибка $@\n";
		return undef;
	}

	return $CONFIG;
}





sub dump_config_file
{
	my ($config_file, $data) = @_;
	my $DumpStr = Dumper($data);

	# Осуществляем моментальный dump...

	open (FILE, "> $config_file") || do {
		warn "Utils: Не могу открыть файл $config_file по причине $!\n";
		return -100;
	};
	print FILE $DumpStr;
	close (FILE);

	return 1;
}


sub query_string
{
	my ($args, $newargs, $no_urlencode) = @_;
	return '' unless ($args || $newargs || $no_urlencode);

	my %Args = ref($args) eq 'HASH' ? %$args: @_;		# Возмем аргументы
	%Args = () unless %Args;
	my %no_encode;

	if (ref($args) eq 'HASH')
	{
		@Args{ keys %$newargs } = values %$newargs;	# Наложим на них новые
		%no_encode = map { $_ => 1; } @$no_urlencode if $no_urlencode ;
	}

	my $one_param = sub { my ($k,$v)=@_; "$k=". ($no_encode{$k} ? $v : CGI::escape($v)) };

	my $params = join('&', 
		map { my $k=$_; ref ($Args{$k}) eq 'ARRAY' ? join('&', map { &$one_param($k, $_) } @{$Args{$k}}) : &$one_param($k, $Args{$k}) }
		grep { $Args{$_} =~ /\S/ }
		keys %Args
	);

	$params = '?'.$params if $params;			# Припишем вопросительный знак, если строка непуста
	return $params;
}



# ----------------------------------------------------------------------------
# Вспомогательная процедура. Получает массив в PostgreSQL-формате, а
#  возвращает простой массив
# ----------------------------------------------------------------------------
sub split_array
{
        my $array_string = shift;

        my @R = ();
        if ($array_string =~ /^{([^}]+)}$/)
        {
                my (@S) = split(/,/,$1);
                @R = @S;
        }

        return @R;
}

# Перекодировка параметров запроса из WIN|UTF в KOI8
sub recode_args {
	my $opts = shift;
	my %args = (
		to_charset	=> 'UTF8',
		@_
	);

	return undef unless $opts && ref($opts) eq 'HASH';

	if ( $opts->{'control_charset'} ) {

		my $charset     = undef;
		my $is_escaped  = undef;

		if ( $opts->{'control_charset'} eq 'Контроль' ) {
			$charset = 'UTF8';

		} elsif ( recode_string('WIN', 'UTF8', $opts->{'control_charset'}) eq 'Контроль' ) {
			$charset = 'WIN';

		} elsif ( recode_string('KOI', 'UTF8', $opts->{'control_charset'}) eq 'Контроль' ) {
			$charset = 'KOI';

		} elsif ( url_unescape($opts->{'control_charset'}) eq 'Контроль' ) {
			$charset = 'UTF8';
			$is_escaped = 1;

		} elsif ( recode_string('WIN', 'UTF8', url_unescape($opts->{'control_charset'})) eq 'Контроль' ) {
			$charset = 'WIN';
			$is_escaped = 1;

		} elsif ( recode_string('KOI', 'UTF8', url_unescape($opts->{'control_charset'})) eq 'Контроль' ) {
			$charset = 'KOI';
			$is_escaped = 1;
		}

		if ($charset && ($is_escaped || $charset ne $args{'to_charset'})) {
			while ( my ($key, $val) = each %$opts ) {
				if ( ref($val) eq 'ARRAY' ) {
					foreach ( @{$val} ) {
						$_ = recode_string( $charset, $args{'to_charset'}, $is_escaped ? url_unescape($_) : $_ );
					}
				} else {
					$opts->{$key} = recode_string( $charset, $args{'to_charset'}, $is_escaped ? url_unescape($val) : $val );
				}
			}
		}
	}
	return $opts;
}

# Перекодировка строки
sub recode_string {
	my ($from, $to, $str) = @_;
	return Convert::Cyrillic::cstocs($from, $to, $str);
}
        

# загрузка модулей
sub load_modules {
	my $list = shift;
	unless (ref($list) eq 'ARRAY') {
		return undef;
	}
	foreach my $module (@$list) {
		eval ("use $module");
		if ( $@ ) {
			die __PACKAGE__.": ошибка загрузки модуля $module.\n $@";
		}
		{
			package HTML::Mason::Commands;
			eval ("use $module");
		}
	}
	return 1;
}

# поиск модулей в заданной директории
# абсолютной, относительно установочной директории Contenido
sub find_modules {
	my %opts = @_;

	my $relative_dir = $opts{relative_dir};
	my $recursive_flag = $opts{recursive};
	my $absolute_dir = $opts{absolute_dir};

	$relative_dir .= '/' unless $relative_dir =~ /\/$/;

	my $dir = $absolute_dir.'/'.$relative_dir;

	return undef unless -d $dir;
	
	my @res = ();
	$relative_dir =~ s/\//::/g;

	if ($recursive_flag) {

		my $sub = sub {if (/\.pm$/i) { s/\.pm//i; my $d = $File::Find::dir.'/'; $d =~ s/$dir//; $d =~ s/\//::/g; push @res, $relative_dir.$d.$_; }  };
		File::Find::find({ wanted => $sub, no_chdir => 0}, $dir);

	} else {
		opendir(DIR, $dir) || do { warn __PACKAGE__.": не могу прочесть директорию модулей $dir."; return undef; } ;
		my @modules = grep {/\.pm$/} readdir(DIR);
		closedir(DIR);


		foreach my $module (@modules) {
			$module =~ /(.*)\.pm/;
			push @res, $relative_dir.$1;
		}
	}
	return @res ? \@res : undef;
}
#-------------------------------------------------------------------------------
# Время из unixtime в timestamp
sub time_unix_to_timestamp {
    my ($time) = @_;
    $time ||= time;
    my @localtime = localtime($time);
    my $timestamp = ($localtime[5] + 1900).'-'.(sprintf('%02d', $localtime[4] + 1)).'-'.(sprintf('%02d', $localtime[3])).' '.(sprintf('%02d', $localtime[2])).':'.(sprintf('%02d', $localtime[1])).':'.(sprintf('%02d', $localtime[0]));
    return $timestamp;
}
#-------------------------------------------------------------------------------
# Время из timestamp в unixtime
sub time_timestamp_to_unix {
    my ($time) = @_;
    return undef unless $time;
    my @time = $time =~ /(\d+)/g;
    @time = reverse @time;
    shift @time if $time =~ /\.\d+$/;
    $time[4]--;
    $time = timelocal(@time);
    return $time
}

sub abort404 {
    http_abort(404);
}

sub abort403 {
    http_abort(403);
}

sub abort503 {
    http_abort(503);
}

sub http_abort {
	my $code = shift;
	my $m = $HTML::Mason::Commands::m;
	$m->clear_buffer();
	$m->abort($code);
}

1;
