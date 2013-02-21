package Contenido::Section;

# ----------------------------------------------------------------------------
# Класс Секция.
# Теперь это опять же - базовый класс, вводим в него дополнительную 
#   функциональность.
# ----------------------------------------------------------------------------

use strict;
use warnings;
use locale;

use vars qw($VERSION $ROOT);
$VERSION = '6.0';

use base 'Contenido::Object';
use Contenido::Globals;

$ROOT = 1;          # Корневая секция

sub class_name {
    return 'Секция';
}

sub class_description {
    return 'Секция по умолчанию';
}

# DEFAULT клас реализации таблицы
sub class_table {
    return 'SQL::SectionTable';
}

# ----------------------------------------------------------------------------
# Конструктор. Создает новый объект сессии.
#
# Формат использования:
#   Contenido::Section->new()
#   Contenido::Section->new($keeper)
#   Contenido::Section->new($keeper,$id)
#   Contenido::Section->new($keeper,$id,$pid)
# ----------------------------------------------------------------------------
sub new {
    my ($proto, $keeper, $id, $pid) = @_;
    my $class = ref($proto) || $proto;
    my $self;

    if (defined($id) && ($id>0) && defined($keeper)) {
        $self=$keeper->get_section_by_id($id, class=>$class);
    } else {
        $self = {};
        bless($self, $class);
        $self->init();
        $self->keeper($keeper)      if (defined($keeper));
        $self->{class} = $class;
        $self->id($id)          if (defined($id) && ($id > 0));
        $self->pid($pid)        if (defined($pid) && ($pid > 0));
    }

    return $self;
}

sub _get_table {
    class_table()->new();
}

#доработка метода store
sub store {
    my $self=shift;

    #для новосозданных секций ставим новый sorder
    unless ($self->{id}) {
        my ($sorder) = $self->keeper->SQL->selectrow_array("select max(sorder) from ".$self->class_table->db_table(), {});
        $self->{sorder} = $sorder + 1;
    }

    return $self->SUPER::store();
}


## Специальные свойства для секций с встроенной сортировкой документов
sub add_properties {
    return (
        {                           # Признак "секция с сортировкой"
            'attr' => '_sorted',
            'type' => 'checkbox',
            'rusname' => 'Ручная сортировка документов',
        },
        {                           # Порядок документов (список id)
            'attr' => '_sorted_order',
            'type' => 'string',
            'rusname' => 'Порядок документов в секции',
            'hidden' => 1
        },
        {
            'attr' => 'default_document_class',
            'type' => 'string',
            'rusname' => 'Класс документов в секции, показываемый по умолчанию',
        },
        {
            'attr' => 'default_table_class',
            'type' => 'string',
            'rusname' => 'Класс таблицы, документы которой будут показаны по умолчанию',
        },
        {
            'attr' => 'order_by',
            'type' => 'string',
            'rusname' => 'Сортировка документов',
        },
        {
            'attr' => 'no_count',
            'type' => 'checkbox',
            'rusname' => 'Не пересчитывать документы в разделе админки',
        },
        {
            'attr' => 'filters',
            'type' => 'struct',
            'rusname' => 'Дополнительные фильтры выборки',
        },
    );
}

# Конструктор для создания корневной секции
sub root {
    return new(shift, shift, $ROOT);
}


# Заглушка для метода parent
sub parent {
    return shift->pid(@_);
}

# ----------------------------------------------------------------------------
# Удаление секции. Перед удалением происходит проверка - а имеем
#   ли мы право удалять (может есть детишки). Если есть детишки, то секция
#   не удаляется. Проверка на наличие объектов в этой секции не производится,
#   но секция вычитается из всех сообщений.
# ----------------------------------------------------------------------------
sub delete
{
    my $self = shift;
    do { $log->error("Метод ->delete() можно вызывать только у объектов, но не классов"); die } unless ref($self);
    do { $log->warning("Вызов метода ->delete() без указания идентификатора для удаления"); return undef } unless ($self->{id});

    # Проверка наличия детей...
    my ($one_id) = $self->keeper->SQL->selectrow_array('select id from '.$self->class_table->db_table.' where pid = ?', {}, $self->id);
    if (defined($one_id) && ($one_id > 0)) { return "Нельзя удалить секцию, у которой есть вложенные секции\n"; };

    $self->SUPER::delete();

    return 1;
}



# ----------------------------------------------------------------------------
# Метод, возвращающий массив детишек (в порядке sorder для 
#   каждого уровня). В параметре передается глубина.
#
# Формат вызова:
#   $section->childs([глубина]);
# ----------------------------------------------------------------------------
sub childs {
    my ($self, $depth) = @_;
    do { $log->error("Метод ->childs() можно вызывать только у объектов, но не классов"); die } unless ref($self);

    # Глубина по умолчанию - 1
    $depth ||= 1;

    my $SIDS = [];
    my $NEW_SIDS = [$self->id];

    #пока не достигнута нужная глубина и пока нашлись новые дети
    while ($depth>0) {
        $NEW_SIDS = $self->keeper->get_sections(s=>$NEW_SIDS, ids=>1, return_mode=>'array_ref', order_by=>'pid, sorder');
        if (ref($NEW_SIDS) and @$NEW_SIDS) {
            push (@$SIDS, @$NEW_SIDS);
        } else {
            last;
        }
        $depth--;
    }
    return @$SIDS;
}



# ----------------------------------------------------------------------------
# Метод для перемещение секции вверх/вниз по рубрикатору (изменение
#   sorder)...
#
# Формат вызова:
#   $section->move($direction); Направление задается строкой 'up'/'down'
# ----------------------------------------------------------------------------
sub move {
    my ($self, $direction) = @_;
    do { $log->error("Метод ->move() можно вызывать только у объектов, но не классов"); die } unless ref($self);

    return undef if ($self->keeper->state->readonly());

    my $keeper = $self->keeper;
    do { $log->error("В объекте секции не определена ссылка на базу данных"); die } unless ref($keeper);
    do { $log->warning("Вызов метода ->move() без указания идентификатора секции"); return undef }
                                                unless (exists($self->{id}) && ($self->{id} > 0));
    do { $log->warning("Вызов метода ->move() без указания порядка сортировки (sorder)"); return undef }
                                                unless (exists($self->{sorder}) && ($self->{sorder} >= 0));
    do { $log->warning("Вызов метода ->childs() без указания родителя"); return undef }  unless (exists($self->{pid}) && ($self->{pid} >= 0));

    $direction = lc($direction);
    if ( ($direction ne 'up') && ($direction ne 'down') ) { $log->warning("Направление перемещения секции задано неверено"); return undef };


    $keeper->t_connect() || do { $keeper->error(); return undef; };
    $keeper->TSQL->begin_work();


    # Получение соседней секции для обмена...
    my ($id_, $sorder_);
    if ($direction eq 'up')
    {
        ($id_, $sorder_) = $keeper->TSQL->selectrow_array("select id, sorder from ".$self->class_table->db_table." where sorder < ? and pid = ? order by sorder desc limit 1", {}, $self->{sorder}, $self->{pid});
    } else {
        ($id_, $sorder_) = $keeper->TSQL->selectrow_array("select id, sorder from ".$self->class_table->db_table." where sorder > ? and pid = ? order by sorder asc limit 1", {}, $self->{sorder}, $self->{pid});
    }


    # Собственно обмен...
    if ( defined($id_) && ($id_ > 0) && defined($sorder_) && ($sorder_ > 0) )
    {
        $keeper->TSQL->do("update ".$self->class_table->db_table." set sorder = ? where id = ?", {}, $sorder_, $self->{id})
            || return $keeper->t_abort();
        $keeper->TSQL->do("update ".$self->class_table->db_table." set sorder = ? where id = ?", {}, $self->{sorder}, $id_)
            || return $keeper->t_abort(); 
    } else {
        $log->warning("Не могу поменяться с элементом (он неверно оформлен или его нет)"); return 2;
    }

    $keeper->t_finish();
    $self->{sorder} = $sorder_;
    return 1;
}



# ----------------------------------------------------------------------------
# Метод для перемещения документа с id = $doc_id вверх/вниз 
#   по порядку сортировки (в пределах текущей секции)...
#
# Формат вызова:
#   $doc->dmove($doc_id, $direction); Направление задается строкой 'up'/'down'
# ----------------------------------------------------------------------------
sub dmove {
    my ($self, $doc_id, $direction) = @_;
    do { $log->error("Метод ->dmove() можно вызывать только у объектов, но не классов"); die } unless ref($self);

    return undef if ($self->keeper->state->readonly());
    
    my $keeper = $self->keeper;
    do { $log->error("В объекте не определена ссылка на базу данных"); die } unless ref($keeper);
    do { $log->warning("Вызов метода ->dmove() без указания идентификатора секции"); return undef }
                                                unless (exists($self->{id}) && ($self->{id} > 0));

    $direction = lc($direction);
    if ( ($direction ne 'up') && ($direction ne 'down') ) { $log->warning("Направление перемещения документа задано неверно"); return undef };

    my $sorder_;
    if ($self->_sorted()) {
        my @ids = $keeper->get_documents( ids =>1, s => $self->id(), 
			($self->default_document_class ? (class => $self->default_document_class) : $self->default_table_class ? (table => $self->default_table_class) : ()), 
			order => ['date', undef], light => 1
		);
        my %ids = map { $_ => 1 } @ids;
        unless ($self->{_sorted_order}) {
            $self->{_sorted_order} = join ',', @ids;
        }

        my @order = split(/,/, $self->{_sorted_order});
        @order = grep {
            my $res;
            if (exists $ids{$_}) {
                $res = 1;
                delete $ids{$_};
            }
            $res
        } @order;

        push @order, keys %ids;

        foreach my $i (0 .. $#order) {
            if ($order[$i] == $doc_id) {
                my $t;
                if ($direction eq 'up') {
                    last if $i == 0;
                    $t = $order[$i-1];
                    $order[$i-1] = $order[$i];
                    $order[$i] = $t;
                    $sorder_ = $i - 1;
                    last;
                } elsif ($direction eq 'down') {
                    last if $i == $#order;
                    $t = $order[$i+1];
                    $order[$i+1] = $order[$i];
                    $order[$i] = $t;
                    $sorder_ = $i + 1;
                    last;
                }
            }
        }

        $self->{_sorted_order} = join ',', @order;
        $self->store();
    } else {
        $log->warning("dmove called for section without enabled sorted feature... $self->{id}/$self->{class}");
    }

    $self->{sorder} = $sorder_;
    return 1;
}




# ----------------------------------------------------------------------------
# Метод для построения пути между двумя рубриками... Возвращает
#   массив идентификаторов секций от рубрики секции до $root_id снизу
#   вверх. $root_id обязательно должен быть выше по рубрикатору. В результат
#   включаются обе стороны. Если рубрики равны, то возвращается массив из
#   одного элемента, если пути нет - то пустой массив.
#
# Формат вызова:
#   $section->trace($root_id)
# ----------------------------------------------------------------------------
sub trace {
    my ($self, $root_id) = @_;
    do { $log->error("Метод ->trace() можно вызывать только у объектов, но не классов"); die } unless ref($self);

    do { $log->warning("Вызов метода ->trace() без указания идентификатора секции"); return () }
                                                unless (exists($self->{id}) && ($self->{id} > 0));
    $root_id ||= $ROOT;

    my $id_ = $self->{id};
    my @SIDS = ($id_);
    my $sth = $self->keeper->SQL->prepare_cached("select pid from ".$self->class_table->db_table." where id = ?");

    while ($id_ != $root_id)
    {
        $sth->execute($id_);
        ($id_) = $sth->fetchrow_array();
        if (defined($id_) && ($id_ > 0))
        {
            unshift (@SIDS, $id_);
        } else {
            # Мы закочили путешествие вверх по рубрикам, а до корня не дошли...
            $sth->finish;
            return ();          
        }
    }
    $sth->finish;
    return @SIDS;
}


# ----------------------------------------------------------------------------
# Предки 
# Возвращает массив идентификаторов всех предков (родителей на всех уровнях) данной секции
# ----------------------------------------------------------------------------
sub ancestors 
{
    my $self = shift;
    do { $log->error("Метод ->ancestors() можно вызывать только у объектов, но не классов"); die } unless ref($self);

    my $keeper = $self->keeper;
    do { $log->error("В объекте секции не определена ссылка на базу данных"); die } unless ref($keeper);

    do { $log->warning("Вызов метода ->ancestors() без указания идентификатора секции"); return () } unless (exists($self->{id}) && ($self->{id} > 0));

    my @ancestors = ();
    my $sectionid = $self->{id};
    while ($sectionid)
    {
        $sectionid = $keeper->SQL->selectrow_array("select pid from ".$self->class_table->db_table." where id = ?", {}, $sectionid);
        push @ancestors, $sectionid if defined $sectionid && $sectionid;
    }   
    return @ancestors;
}

# ----------------------------------------------------------------------------
# Потомки
# Возвращает массив идентификаторов всех потомков (детей на всех уровнях) данной секции
# ----------------------------------------------------------------------------
sub descendants 
{
    my $self = shift;
    do { $log->error("Метод ->descendants() можно вызывать только у объектов, но не классов"); die } unless ref($self);

    my $keeper = $self->keeper;
    do { $log->error("В объекте секции не определена ссылка на базу данных"); die } unless ref($keeper);

    do { $log->warning("Вызов метода ->descendants() без указания идентификатора секции"); return () } unless (exists($self->{id}) && ($self->{id} > 0));

    my @descendants = ();
    my @ids = ($self->{id});
    while (scalar @ids)
    {
        my $sth = $keeper->SQL->prepare("select id from ".$self->class_table->db_table." where pid in (" . (join ", ", @ids) . ")");
        $sth->execute;
        @ids = ();
        while (my ($id) = $sth->fetchrow_array)
        {
            push @ids, $id;
        }
        $sth->finish();
        push @descendants, @ids;
        last if !$sth->rows;
    }
    return @descendants;
}

# -------------------------------------------------------------------------------------------------
# Получение деревца...
# Параметры:
#   light => облегченная версия
#   root => корень дерева (по умолчанию - 1)
# -------------------------------------------------------------------------------------------------
sub get_tree {
    my ($self, %opts) = @_;
    do { $log->warning("Метод ->get_tree() можно вызывать только у объектов, но не классов"); return undef } unless ref($self);

    my $root = $opts{root} || $ROOT;

    
    # ----------------------------------------------------------------------------------------
    # Выбираем все секции
    $opts{no_limit} = 1;
    delete $opts{root};
    my @sections = $self->keeper->get_sections(%opts);

    my $CACHE = {};
    foreach my $section (@sections) {
        if (ref($section)) {
            $CACHE->{$section->id()} = $section;
        }
    }

    for my $id (sort { $CACHE->{$a}->sorder() <=> $CACHE->{$b}->sorder() } (keys(%{ $CACHE }))) {
        my $pid = $CACHE->{$id}->pid() || '';
        $CACHE->{$pid}->{childs} = []       if (! exists($CACHE->{$pid}->{childs}));
        $CACHE->{$id}->{parent} = $CACHE->{$pid};
        push (@{ $CACHE->{$pid}->{childs} }, $CACHE->{$id} );
    }

    return $CACHE->{$root};
}

1;

