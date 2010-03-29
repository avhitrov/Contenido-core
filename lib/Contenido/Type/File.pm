package Contenido::Type::File;
#-------------------------------------------------------------------------------
# Тип данных - Файл
#-------------------------------------------------------------------------------
use strict;
use warnings;
use Contenido::Globals;
use Contenido::File;
use LWP;
use LWP::UserAgent;
use LWP::Simple qw /get/;
use HTTP::Request;
use HTTP::Headers;

sub new {
    my ($proto, $prop) = @_;
    $proto = ref $proto || $proto;
    my $self = $prop && ref $prop && ref $prop eq 'HASH' ?
        {%$prop, ext => undef, filename => undef, size => undef} :
        {ext => undef, filename => undef, size => undef};
    bless $self, $proto;
    return $self;
}
#-------------------------------------------------------------------------------
# Кладем файл локально
# В будущем, можно сдесь же проводить upload
sub put_local {
    my ($self, $filename, $data) = @_;
    return undef if (!$filename || !$data);
    ($self->{'ext'}) = $filename =~ /\.([^\.]+)$/;
    $self->{'ext'} = lc $self->{'ext'};
    $self->{'file_local'} = $state->{'tmp_dir'}.'/'.int(rand(100000)).'_'.time.'.'.$self->{'ext'};
    my $fh = undef;
    if (ref $data eq 'Apache::Upload') {
        my $upload = $data->fh();
        unless (open ($fh, '>', $self->{'file_local'})) {$self->error($!); return undef}
        while (<$upload>) {print $fh $_}
        close $fh;
    } else {
        unless (open ($fh, '>', $self->{'file_local'})) {$self->error($!); return undef}
        print $fh $data;
        close $fh;
    }
    unless ($self->file_info()) {unlink $self->{'file_local'}}
    return 1;
}
#-------------------------------------------------------------------------------
# Берем файл локально
# В будущем, можно сдесь же проводить upload
sub get_local {
    my ($self, $filename) = @_;
    return undef if (!$filename || !-f $filename);
    ($self->{'ext'}) = $filename =~ /\.([^\.\?]+)(?:\?.+$|$)/;
    $self->{'file_local'} = $filename;
    $self->file_info() || return undef;
    return 1;
}
#-------------------------------------------------------------------------------
# Берем файл удаленно, и удаляем если надо
sub get_remote {
    my ($self, %params) = @_;
    ($self->{'ext'}) = $params{'url'} =~ /\.([^\.\?]+)(?:\?.+$|$)/;
    $self->{'ext'} = lc $self->{'ext'};
    $self->{'file_local'} = $state->{'tmp_dir'}.'/'.int(rand(100000)).'_'.time.'.'.$self->{'ext'};
    my $ua = LWP::UserAgent->new();
    my $response = $ua->get($params{'url'}, ':read_size_hint' => 10 * 1024, ':content_file' => $self->{'file_local'});
    return undef unless $response->is_success();
    unless ($self->file_info()) {unlink $self->{'file_local'}; return undef}
    return 1;
}
#-------------------------------------------------------------------------------
# Типа обертка для Contenido::File::store
sub store {
    my ($self, $filename) = @_;
    return undef unless $filename;                                              # Стоит ли делать дефолный путь сохранения?
    $self->remove if $self->{'filename'};                                       # Удаляем предыдущий файл    
    unless (Contenido::File::store($filename, $self->{'file_local'})) {$self->error('Не могу записать файл '.$filename); return undef}
    $self->{'filename'} = $filename;
    return 1;
}
#-------------------------------------------------------------------------------
# Типа обертка для Contenido::File::remove
sub remove {
    my ($self) = @_;
    unless (Contenido::File::remove($self->{'filename'})) {$self->error('Не могу удалить файл '.$self->{'filename'}); return undef}
    return 1;
}
#-------------------------------------------------------------------------------
# Удаляем локальный файл за ненадобностью
sub clean {
    my ($self) = @_;
    unless (unlink $self->{'file_local'}) {$self->error($!); return undef}
    delete $self->{'file_local'};
    delete $self->{'properties'};
    return 1;
}
#-------------------------------------------------------------------------------
# Инфо файла
sub file_info {
    my ($self) = @_;
    $self->{'size'} = (stat($self->{'file_local'}))[7];
    if ($self->can('more_info')) {$self->more_info() || return undef}
    return 1;
}
#-------------------------------------------------------------------------------
# Filename default
sub filename_default {
    my $time = time;
    my @date = (localtime $time)[5, 4, 3]; $date[0] += 1900; $date[1] += 1;
    my $component_date = sprintf "%04d/%02d/%02d", @date;
    my $component_time_rand = sprintf "%010d_%05d", $time, int rand 99999;
    return join "/", $component_date, $component_time_rand;
}
#-------------------------------------------------------------------------------
# DataDumper
sub dumper {
    my $self = shift;
    my $class = ref($self) || die 'objmethod';
    my $struct = undef;
    local $Data::Dumper::Indent = 0;
    $struct = Data::Dumper::Dumper($self);
    return undef unless defined $struct;
    return $struct;
}
#-------------------------------------------------------------------------------
# Куда сваливаем ошибки
sub error {
    my ($self, $error) = @_;
    warn $error;
    return 1;
}
1;
