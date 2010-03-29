use strict;

# если нагрузка больше максимально допустимой
# не запускаем сервис
sub activity {
	my $MAXIMUM_ACTIVITY = 10;
	my $TOPS = `uptime`;
	if ($TOPS =~ /load averages: ([\d\.]+), ([\d\.]+), ([\d\.]+)/)
	{
		my $CA = $2;
		$CA = $1 if ($CA < $1);
		if (($CA) > $MAXIMUM_ACTIVITY)
		{
			return 0;
		}
	}
	return 1;
}

# сохранение pid'а процесса
sub save_pid {
	my $FILE = shift;
	open F, ">".$FILE.".pid" || die "Не могу открыть pid файл ".$FILE.".pid \n";
	print F $$;
	close F || die "Не могу закрыть pid файл ".$FILE.".pid \n";
}


# проверка запущенного экземпляра программы
# на фик нам второй
sub check_pid {
	my $FILE = shift || __FILE__;
	if (-s $FILE.".pid") {
		open F, "<".$FILE.".pid" || die "Не могу открыть pid файл ".$FILE.".pid \n";
		my $pid = (<F>)[0];
		chomp $pid;
		close F || die "Не могу закрыть pid файл ".$FILE.".pid \n";
		if (kill 0 => $pid) {
			warn "Программа уже запущена -> выход\n";
			exit;
		} else {
			&save_pid($FILE);
		}
	} else {
		&save_pid($FILE);
	}
}

1;
