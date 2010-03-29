package Contenido::User;

# ----------------------------------------------------------------------------
# Пользователь
# ----------------------------------------------------------------------------

use strict;
use warnings;
use locale;

use base 'Contenido::Object';

use Contenido::Section;
use Contenido::Globals;

# клас реализации таблицы
sub class_table
{
    return 'SQL::UserTable';
}

sub class_name
{
    return 'Пользователь';
}

sub class_description
{
    return 'Пользователь';
}


sub extra_properties
{
    return (
        { 'attr' => 'status',	'type' => 'status',
            'cases' => [
                    [0, 'Не активен'],
                    [1, 'Активен'],
                   ],
        },
	{ 'attr' => 'passwd',	'type' => 'password',	'rusname' => 'Пароль (<font color="red">Не отображается. Указывать при создании и для изменения</font>)' },
    )
}

# ----------------------------------------------------------------------------
# Конструктор. Создает новый объект пользователя... 
#
# Формат использования:
#  Contenido::User->new()
#  Contenido::User->new($keeper)
#  Contenido::User->new($keeper,$login)
# ----------------------------------------------------------------------------
sub new
{
    my ($proto, $keeper, %args) = @_;
    my $class = ref($proto) || $proto;
    my $login = $args{login};
    my $id    = $args{id};
    my $self;
    if (defined($login) && (length($login)>0) && defined($keeper)) {
        $self=$keeper->get_user_by_login($login, class=>$class);
    } elsif (defined($login) && ($id>0) and defined($keeper)) {
        $self=$keeper->get_user_by_id($login, class=>$class);
    } else {
        $self = {};
        bless($self, $class);
        $self->init();
        $self->keeper($keeper)      if (defined($keeper));
        $self->{class} = $class;
        $self->login($login)        if (defined($login) && (length $login > 0));
    }

    return $self;        
}

#пользователи Contenido работают ПО 1 таблице специальной
sub _get_table {
    return class_table()->new();
}

sub pre_store
{
  my $self = shift;

  if ( $self->id ) {
	unless ( $self->passwd ) {
		my $up = $keeper->get_document_by_id ( $self->id,
			class   => ref $self,
		);

		unless (ref $up && $up->passwd) { return 0 }
		$self->passwd($up->passwd);
	}
  }
  return 1;
}


# ----------------------------------------------------------------------------
# Возвращает 1, если этот пользователь входит в заданную группу.
#
# Начиная с версии Contenido 4.0
#  А на самом деле - если пользователь имеет ПРЯМОЙ доступ к секции с заданным идентификатором.
#  Прямой доступ - это доступ НЕ через потомка.
# ----------------------------------------------------------------------------
sub check_group {
    my ($self, $group) = @_;

    my @groups = $self->groups();
    my %G = map { $_ => 1 } @groups;

    return exists($G{$group});
}


# ----------------------------------------------------------------------------
# Возвращает уровень доступа к указанной секции:
# 0 - нет доступа ни к данной секции ни к её потомкам
# 1 - есть доступ к потомкам данной секции но к самой секции доступа нет
# 2 - есть доступ непосредтственно к данной секции или её родителю на каком-либо уровне
# Аргумент - идентификатор секции
# ----------------------------------------------------------------------------
sub get_section_access
{
    my $self = shift;
    my $sectionid = shift;
    do { $log->error("Метод get_section_access() можно вызывать только у объектов, но не классов"); die } unless ref($self);

    # Для неизвестных секций разрешаем доступ
    my $section = ref $sectionid ? $sectionid : $self->keeper()->get_section_by_id($sectionid);
    do { $log->error("Метод ->get_section_access: не найдена секция $sectionid"); return 2 } unless defined $section;
    my $section_id = ref $sectionid ? $sectionid->id : $sectionid;

    # 1. Проверяем, есть ли доступ к непосредственно указанной секции
    my $exact = $self->check_group($section_id);
    return 2 if $exact;

    # 2.Определяем, есть ли доступ к родителям данной секции
    my @ancestors = $section->ancestors(); # предки
    my $ancestor_access = 0;
    # 2.1. Идем в цикле по всем родителям (предкам) на всех уровнях и проверяем доступ
    foreach (@ancestors)
    {
        if ($self->check_group($_))
        {
            $ancestor_access = 1;
            last;
        }
    }
    return 2 if $ancestor_access;

    # 3. Определяем, есть ли доступ к потомкам данной секции
    my @descendants = $section->descendants(); # потомки
    my $descendant_access = 0;
    # 3.1. Идем в цикле по всем секциям-потомкам на всех уровнях и проверяем доступ
    foreach (@descendants)
    {
        if ($self->check_group($_))
        {
            $descendant_access = 1;
            last;
        }
    }
    return 1 if $descendant_access;
    return 0;
}


# ----------------------------------------------------------------------------
# Кэширование запросов на определение доступа пользователя к секции
# ----------------------------------------------------------------------------
sub section_accesses
{
    my $self = shift;
    my ($user, $section) = @_;
    
    #another dirty hack for documents without sections
    return 2 unless ($section);

    my $section_id = ref $section ? $section->id : $section;
    unless (defined $user->{_section_accesses_}->{$section_id})
    {
        $user->{_section_accesses_}->{$section_id} = $user->get_section_access($section);
    }
    return $user->{_section_accesses_}->{$section_id};
}


# ----------------------------------------------------------------------------
# Эта функция возвращает весь хэш $self->{section_acesses}, но заполненный.
# То есть фактически для выполнения этой функции надо получить все дерево, а
#  затем наложить на него права...
# ----------------------------------------------------------------------------
sub get_accesses {
    my $self = shift;
    my $keeper = $self->keeper();

    my $tree = $keeper->get_tree(light => 1);
    # Найдем ссылку на каждый элемент дерева...
    my $trefs = {};
    my @tree_ = ($tree);
    $self->{_section_accesses_} = {};
    for my $to (@tree_) {
        if (ref($to->{childs}) eq 'ARRAY') {
            push (@tree_, @{ $to->{childs} });
        }
        $trefs->{$to->id()} = $to;
        $self->{_section_accesses_}->{ $to->id() } = 0;
    }

    # Пройдемся для каждого идентификатора...
    my @groups = $self->groups();
    for my $g (@groups) {
        next    if (!exists($trefs->{$g}) || !ref($trefs->{$g}) );

        # Все предки
        my @ancestors = ();
		my $pid = $trefs->{$g}->pid() || '';
        push (@ancestors, $trefs->{$pid})  if (
                                        exists($trefs->{$pid}) 
                                        &&
                                        ref($trefs->{$pid})
                                        && ($g != 1)
                                    );
        for my $a (@ancestors) {
            push (@ancestors, $trefs->{ $trefs->{ $a->id() }->pid() })  if (exists($trefs->{ $trefs->{ $a->id() }->pid() }) && ref($trefs->{ $trefs->{ $a->id() }->pid() }) && ($a->id() != 1))
        }
        for my $a (@ancestors) {
            $self->{_section_accesses_}->{$a->id()} = 1 if ($self->{_section_accesses_}->{$a->id()} < 1);
        }

        # Все потомки
        my @descendants = ();
        push (@descendants, @{ $trefs->{$g}->{childs} })    if (
                                        exists($trefs->{$g}->{childs}) 
                                        &&
                                        (ref($trefs->{$g}->{childs}) eq 'ARRAY')
                                    );
        for my $d (@descendants) {
            push (@descendants, @{ $trefs->{$d->id()}->{childs} })  if (exists($trefs->{ $d->id() }->{childs}) && (ref($trefs->{ $d->id() }->{childs}) eq 'ARRAY'));
        }
        for my $d (@descendants) {
            $self->{_section_accesses_}->{$d->id()} = 2;
        }

        $self->{_section_accesses_}->{$g} = 2;
    }
    undef $trefs;
    undef @tree_;
    undef $tree;
    return $self->{_section_accesses_};
}

# ----------------------------------------------------------------------------
# Дефолтный список классов, показываемых юзеру. Это не ограничение доступа!
# Это всего лишь легкий фильтр отображения.
# ----------------------------------------------------------------------------
sub get_available_classes {
    my $self = shift;
    my $class = ref $self || do { $log->error("Метод get_available_classes() можно вызывать только у объектов, но не классов"); die };

    return $state->{available_documents};
}

1;

