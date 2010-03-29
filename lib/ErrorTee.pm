# Используется для запуска скриптов из crontab
# в виде: /some/script > /some/log
# Если STDOUT редиректится в файл, то STDERR дублируется в STDOUT.
# Таким образом, все выводы в STDOUT и STDERR всегда попадают в log
# для анализа. Отключение буферизации должно обеспечивать правильный порядок
# сообщений в файле.
# При этом warn и die и ошибки runtime уходят на email владельцу cron.
# То есть имеет смысл использовать print для всех некритичных сообщений
# а warn и die для сообщений, требующих вмешательства и исправления.

package ErrorTee;

use strict;
use warnings 'all';


# buffering off!
select((select(STDERR), $|=1)[0]);
select((select(STDOUT), $|=1)[0]);

# is file-redirected?
if (-p STDOUT || -f STDOUT) {
	$SIG{'__DIE__'} = sub {
		print STDOUT $_[0] if defined($^S) && $^S==0;
	};

	$SIG{'__WARN__'} = sub {
		print STDOUT $_[0] if defined($^S) && $^S==0;
		warn $_[0];
	};
}

1;
