package Contenido::Type::Image;
#-------------------------------------------------------------------------------
# Тип данных - Файл
#-------------------------------------------------------------------------------
use strict;
use warnings;
use Contenido::Globals;
use Contenido::File;
use Image::Size;
use base qw/Contenido::Type::File/;
#-------------------------------------------------------------------------------
#
sub new {
    my ($prototype, $properties) = @_;
    warn 'Неправильно переданы свойства изображения: #0001' unless $properties || ref $properties;
    $properties = {
                    properties  => $properties,
                    width       => undef,
                    height      => undef,
                    alt         => undef,
                    mini        => {},
                   };
    my $self = SUPER::new($prototype, $properties)
    return $self;
}
#-------------------------------------------------------------------------------
# Перепроверяем текущие параметры - не готово
sub restrict_properties {
    my ($self, $properties) = @_;
    warn 'Неправильно переданы свойства изображения: #0002' unless $properties || ref $properties;
    foreach my $key (keys %{$properties}) {
        
    }
    return $self;
}
#-------------------------------------------------------------------------------
# Дополнительные данные
sub more_info {
    my ($self) = @_;
    ($self->{'width'}, $self->{'height'}) = Image::Size::imgsize($self->{'file_local'}) || return undef;
    return 1;
}
#-------------------------------------------------------------------------------
sub create_preview {
    my ($self, $filename) = @_;
    $filename ||= '/images/'.$self->filename_default;
# Удаляем старые превьюшки
    foreach my $key (keys {$self->{'mini'}}) {
        next if $key eq 'filename' || $key eq 'width' || $key eq 'height' || $key eq 'alt';
        Contenido::File::remove($self->{'mini'}->{$key}->{'filename'});
        delete $self->{'mini'}->{$key};
    }
    $self->{'mini'} = {};
# Формируем новые превьюшки
    my @preview = $self->{'properties'}->{'preview'} && ref $self->{'properties'}->{'preview'} && ref $self->{'properties'}->{'preview'} eq 'ARRAY' ?
                    @{$self->{'properties'}->{'preview'}} : ($self->{'properties'}->{'preview'} || $keeper->{'preview'});
    foreach my $preview (@preview) {
        substr (my $file_preview = $self->{'file_local'}, (- 1 - (length $self->{'ext'})), 0 , '.'.$preview);
        my $command = $state->{'convert_binary'}.' -geometry \''.$preview.'\' -quality 80 '.$self->{'file_local'}.' '.$file_preview;
        my $result = `$command`;
        substr (my $filename_preview = $filename, (- 1 - (length $self->{'ext'})), 0 , $preview);
        if (Contenido::File::store($filename_preview, $file_preview)) {
            $self->{'mini'}->{$key}->{'filename'} = $storage.'.'.$self->{'ext'};
            $self->{'mini'}->{$key}->{'size'} = (stat $file_preview)[7];
            $self->{'mini'}->{$key}->{'ext'} = $self->{'ext'};
            unlink $file_preview;
            ($self->{'mini'}->{$key}->{'width'}, $self->{'mini'}->{$key}->{'height'}) = Image::Size::imgsize($self->{'file_local'}) || return undef;
        }
    }
    @{%{$self->{'mini'}}}{'filename', 'width', 'height', 'size', 'ext', 'alt'} = @{%{$self->{'mini'}{$preview[0]}}}{'filename', 'width', 'height', 'size', 'ext', 'alt'};
    return 1;
}
#-------------------------------------------------------------------------------
sub store {
    my ($self, $filename) = @_;
    $self->create_preview($filename);
    return $self->SUPER::store;
}
#-------------------------------------------------------------------------------
sub remove {
    my ($self) = @_;
    return $self->SUPER::remove;
}
1;