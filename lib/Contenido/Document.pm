package Contenido::Document;

# ----------------------------------------------------------------------------
# Класс Документ
# ----------------------------------------------------------------------------

use strict;
use warnings;
use locale;

use base 'Contenido::Object';

use Utils;
use Contenido::Globals;
use Data::Dumper;

sub class_name {
	return 'Документ';
}

sub class_description {
	return 'Документ по умолчанию';
}

# клас реализации таблицы 
sub class_table {
	return 'SQL::DocumentTable';
}

# ----------------------------------------------------------------------------
# Конструктор. Создает новый объект для работы с документами в среде базы
#  данных PostgreSQL.
#
# Формат использования:
#  Contenido::Document->new()
#  Contenido::Document->new($keeper)
#  Contenido::Document->new($keeper, $id)
#
# Возвращает либо истинное значение, если все получилось, либо ложь.
# ----------------------------------------------------------------------------
sub new {
	my ($proto, $keeper, $id) = @_;
	my $class = ref($proto) || $proto;
	my $self;

	if (defined($id) && ($id>0) && defined($keeper)) {
		$self=$keeper->get_document_by_id($id, class=>$class);
	} else {
		$self = {};
		bless($self, $class);
		$self->init();
		$self->class($class);
		$self->keeper($keeper)    if (ref $keeper);
	}
	return $self;
}

# Возвращает главную секцию (первую)...
# вот такой вот загадочный код ;)) 
# искренне надеюсь что он работает и причем так как надо 
sub section {
	shift @{[shift->sections()]};
}


####
# Шаблонный метод для определения полей, по которым можно искать.
# Переопределяется в документах, возвращает массив названий полей.
##################################################################
sub search_fields {
	return ('name');
}

####
# Шаблонный метод для описания полей в документах других классов,
# связанных с данным документом связью многие-к-одному от поля
# field документа класса class к id (или source_field) данного документа
#
# Пример:
#	{
#		name	=> 'Описание связи',
#		class	=> 'project::Class',
#		filter	=> 'filter_name that will be set to "get_documents" request'
#		field	=> 'table_field which is linked to the current table'
#		source_field	=> 'field (except id) to which target table is linked to'
#		auto	=> { source_field1 => target_field1, source_field2 => target_field2 ... }
#	}
#
##################################################################
sub table_links {
	return undef;
}


####
# Шаблонный конфигуратор Jevix
##################################################################
sub jevix_conf
{
	my $jevix_conf = {
		isHTML		=> 1,		# Работать в режиме гипертекста (в режиме простого текста работает быстрее)
		lineBreaks	=> 0,		# Расставлять переносы строк <br />
		paragraphs	=> 0,		# Размечать параграфы <p>
		dashes		=> 1,		# Тире
		dots		=> 1,		# Многоточия
		edgeSpaces	=> 1,		# Убирать пробельные символы в начале и конце строки
		tagSpaces	=> 1,		# Убирать пробелы между тегами (</td>  <td>)
		multiSpaces	=> 1,		# Превращать множественные пробелы в одинарные
		redundantSpaces	=> 1,		# Убирать пробелы там, где их не должно быть
		compositeWords	=> 0,		# Заключать составные слова в тег <nobr>
		compositeWordsLength => 10,	# Максимальная длина составного слова, заключаемого в тег <nobr>
		nbsp		=> 0,		# Расставлять неразрывные пробелы
		quotes		=> 1,		# Верстать кавычки
		qaType		=> 0,		# Тип внешних кавычек (см. настройки отладочного интерфейса на http://jevix.ru/)
		qbType		=> 1,		# Тип вложенных кавычек
		misc		=> 1,		# Всякое разное (&copy, дроби и прочее)
		codeMode	=> 2,		# Способ кодировки спец. символов (0: ANSI <...>, 1: HTML-код <&#133;>, 2: HTML-сужности <&hellip;>)
		tagsDenyAll	=> 0,		# По умолчанию отвергать все теги
		tagsDeny	=> 'script',	# Список запрещённых тегов
		tagsAllow	=> '',		# Список разрешённых тегов (исключает их, когда устанавлен запрет всех)
		tagCloseSingle	=> 0,		# Закрывать одинарные теги, когда они не закрыты
		tagNamesToLower	=> 0,		# Приводить имена тегов к нижнему регистру
		tagNamesToUpper	=> 0,		# Приводить имена тегов к верхнему регистру
		tagAttributesToLower => 0,	# Приводить имена атрибутов тегов к нижнему регистру
		tagAttributesToUpper => 0,	# Приводить имена атрибутов тегов к верхнему регистру
		tagQuoteValues	=> 0,		# Помещать в кавычки значения атрибутов тегов
		tagUnQuoteValues => 0,		# Убирать кавычки вокруг значений атрибутов тегов
		simpleXSS	=> 1,		# Удаление возможных XSS-атак в коде документа
		checkHTML	=> 0,		# Проверять целостность HTML
		logErrors	=> 0		# Вести журнал ошибок
	};
	return $jevix_conf;
}


1;

