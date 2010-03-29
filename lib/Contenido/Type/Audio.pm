package Contenido::Type::Audio;
#-------------------------------------------------------------------------------
# Тип данных - Аудио Файл
#-------------------------------------------------------------------------------
# НАДО:
# 1. Добавить частоту дисткретизации для wma файлов
#-------------------------------------------------------------------------------
use strict;
use warnings;
use Contenido::Globals;
use Contenido::File;
use Data::Dumper qw/Dumper/;
use base qw/Contenido::Type::File/;
use MP3::Info;
use Audio::WMA;
#-------------------------------------------------------------------------------
# Дополнительные данные
# Возвращаем:
# - длительность аудиофайла (duration)
# - битрейт (bitrate)
# - частоту дискретизации (freq)
sub more_info {
    my ($self) = @_;
    return undef unless $self && ref $self && $self->{'ext'};
    if ($self->{'ext'} eq 'mp3') {
        my $info = get_mp3info($self->{'file_local'}) || return undef;
        $self->{'duration'} = int($info->{'SECS'});
        $self->{'bitrate'} = $info->{'BITRATE'};
        $self->{'freq'} = $info->{'FREQUENCY'};
    } elsif ($self->{'ext'} eq 'wma') {
        my $wma  = Audio::WMA->new($self->{'file_local'});
        my $info = $wma->info() || return undef;
        $self->{'duration'} = int($info->{'playtime_seconds'});
        $self->{'bitrate'} = int($info->{'bitrate'}/1024);
    }
    warn (Dumper $self) if $state->development;
    return 1;
}
#-------------------------------------------------------------------------------
# WMA -> MP3
sub wma2mp3 {
    my ($self, %param) = @_;
    return undef if $self->{'ext'} ne 'wma';
    my $out_file = $param{'out_file'} || $self->{'file_local'};
    $out_file =~s /wma$/mp3/g;
    my $tmp_file = $state->{'tmp_dir'}.'/tmp_'.int(rand(100000)).'_'.time.'.wav';
    my $command = 'mplayer -vo null -vc dummy -ao pcm:file='.$tmp_file.' '.$self->{'file_local'}.' && lame -m s -S '.$tmp_file.' -o '.$out_file;
    system($command);
    return undef unless -e $out_file;
    unlink $self->{'file_local'} unless $param{'no_delete'};
    unlink $tmp_file;
    $self->{'file_local'} = $out_file;
    $self->{'ext'} = 'mp3';
    $self->file_info;
    return 1;
}
#-------------------------------------------------------------------------------
# Change FREQUENCY  8, 12 => 11.025, 16, 24 => 22.05, 32, 48 => 44.1
sub change_frequency {
    my ($self, %param) = @_;
    my %freq_change = (
                        8   => 11.025,
                        12  => 11.025,
                        16  => 22.05,
                        24  => 22.05,
                        32  => 44.1,
                        48  => 44.1
                        );
    return undef if $self->{'ext'} ne 'mp3';
    return 2 unless $freq_change{$self->{'freq'}};
    my $out_file = $param{'out_file'} || $self->{'file_local'};
    $out_file =~s /\.mp3$/0\.mp3/i;
    my $command = 'lame -b '.$self->{'bitrate'}.' -m s -S --resample '.$freq_change{$self->{'freq'}}.' '.$self->{'file_local'}.' -o '.$out_file;
    system($command);
    return undef unless -e $out_file;
    unlink $self->{'file_local'};
    $self->{'file_local'} = $out_file;
    $self->file_info;
    return 1;
}
1;