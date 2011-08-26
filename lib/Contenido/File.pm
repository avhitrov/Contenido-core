package Contenido::File;

use strict;
use warnings;

use Contenido::Globals;
use URI;
use Data::Dumper;
use IO::File;
use IO::Scalar;
use Contenido::File::Scheme::HTTP;
use Contenido::File::Scheme::FILE;
use Contenido::DateTime;

our $IgnoreErrors = 1;

my %translit = (
	'а' => 'a', 'б' => 'b', 'в' => 'v', 'г' => 'g', 'д' => 'd', 'е' => 'e', 'ё' => 'e', 'ж' => 'zh', 'з' => 'z', 'и' => 'i', 'й' => 'y',
	'к' => 'k', 'л' => 'l', 'м' => 'm', 'н' => 'n', 'о' => 'o', 'п' => 'p', 'р' => 'r', 'с' => 's', 'т' => 't', 'у' => 'u', 'ф' => 'f', 'х' => 'h',
	'ц' => 'ts', 'ч' => '4', 'ш' => 'sh', 'щ' => 'sch', 'ъ' => 'y', 'ы' => 'i', 'ь' => 'y', 'э' => 'e', 'ю' => 'u', 'я' => 'a', 'А' => 'A',
	'Б' => 'B', 'В' => 'V', 'Г' => 'G', 'Д' => 'D', 'Е' => 'E', 'Ё' => 'E', 'Ж' => 'ZH', 'З' => 'Z', 'И' => 'I', 'Й' => 'Y', 'К' => 'K', 'Л' => 'L',
	'М' => 'M', 'Н' => 'N', 'О' => 'O', 'П' => 'P', 'Р' => 'R', 'С' => 'S', 'Т' => 'T', 'У' => 'U', 'Ф' => 'F', 'Х' => 'H', 'Ц' => 'TS', 'Ч' => '4',
	'Ш' => 'SH', 'Щ' => 'SCH', 'Ъ' => 'Y', 'Ы' => 'I', 'Ь' => 'Y', 'Э' => 'E', 'Ю' => 'U', 'Я' => 'YA',
);


sub fetch {
    my $filename = shift || return;
    my $fh;

    foreach my $dir (@{$state->{"files_dir"}}) {
        my $path = $dir . '/' . $filename;

        no strict "refs";
        $fh = &{"Contenido::File::Scheme::".uc(scheme($path))."::fetch"}($path);
        return $fh if $fh;
    }
}

sub store {
    my $filename = shift   || return;
    my $fh = get_fh(shift) || return;

    my $dt = Contenido::DateTime->new()->set_locale('en')->set_time_zone("UTC");

    my @successful;

    #убираем сдвоенные и более /
    $filename =~ s#/+#/#g;
    #убираем начальный /
    $filename =~ s#^/##;

    foreach my $dir (@{$state->{"files_dir"}}) {
        seek $fh, 0, 0;
        my $path = $dir . '/' . $filename;

        no strict "refs";
        my $return = &{"Contenido::File::Scheme::".uc(scheme($path))."::store"}($path, $fh, $dt);
        push @successful, $path if $return;
    }

    if (
        !@successful or 
        (
            (scalar @successful != scalar @{$state->{"files_dir"}}) and 
            !$IgnoreErrors
        )
    ) {
        foreach my $path (@successful) {
            no strict "refs";
            &{"Contenido::File::Scheme::".uc(scheme($path))."::remove"}($path);
        }
        return;
    }
    1;
}

sub size {
    my $filename = shift;
    my %args = @_;

    my $size;

    #убираем сдвоенные и более /
    $filename =~ s#/+#/#g;
    #убираем начальный /
    $filename =~ s#^/##;

    foreach my $dir (@{$state->{"files_dir"}}) {
        no strict "refs";
        my $response = &{"Contenido::File::Scheme::".uc(scheme($dir))."::size"}($dir."/".$filename, %args);
        return unless defined $response;
        return if defined $size and $size != $response;

        $size = $response;
        #TODO
        last;
    }
    return $size;
}

sub remove {
    my $filename = shift || return;

    #убираем сдвоенные и более /
    $filename =~ s#/+#/#g;
    #убираем начальный /
    $filename =~ s#^/##;

    foreach my $dir (@{$state->{"files_dir"}}) {
        no strict "refs";
        &{"Contenido::File::Scheme::".uc(scheme($dir))."::remove"}($dir."/".$filename);
    }

    1;
}

sub get_fh {
    my $input = shift;
    my $fh;

    if (not ref $input) {
        no strict "refs";
        $fh = &{"Contenido::File::Scheme::".uc(scheme($input))."::get_fh"}($input);
    } elsif ( ref $input eq 'Apache::Upload' ) {
        $fh = $input->fh;
    } elsif ((ref $input eq "GLOB") or (ref $input eq 'IO::File')) {
        $fh = $input;
    } elsif (ref $input eq "SCALAR") {
        $fh = IO::Scalar->new($input);
    } else {
        $log->warning("Path, scalar ref or fh needed");
        return;
    }

    return $fh
}

sub scheme {
    my $uri = shift;
    my $scheme;

    $scheme = URI->new($uri)->scheme() || "file";

    return $scheme;
}

# sub files_dir {
#     return unless $_[0];
#     my $dir;

#     for (scheme($_[0])) {
#         /http/ && do {
#             $dir = URI->new($_[0])->canonical();
#             $dir =~ s|/*$|/|;
#             last;
#         };
#         /file/ && do {
#             $dir = URI->new($_[0])->path();
#             $dir =~ s|/*$|/|;
#             last;
#         };
#     }

#     return $dir;
# }

sub store_image {
    my $input = shift;
    my (%opts) = @_;
    my $object = delete $opts{object} || return;
    my $attr = delete $opts{attr}  || return;

    my ($prop) = grep { $_->{attr} eq $attr } $object->structure;
    return	unless ref $prop;
    my @preview = exists $prop->{'preview'} && ref $prop->{'preview'} eq 'ARRAY' ? @{$prop->{'preview'}} : exists $prop->{'preview'} && $prop->{'preview'} ? ($prop->{'preview'}) : ();
    my @crops = exists $prop->{'crop'} && ref $prop->{'crop'} eq 'ARRAY' ? @{$prop->{'crop'}} : exists $prop->{'crop'} && $prop->{'crop'} ? ($prop->{'crop'}) : ();
    my @shrinks = exists $prop->{'shrink'} && ref $prop->{'shrink'} eq 'ARRAY' ? @{$prop->{'shrink'}} : exists $prop->{'shrink'} && $prop->{'shrink'} ? ($prop->{'shrink'}) : ();

    my $filename = '/images/'.$object->get_file_name() || return;
    my $filename_tmp = $state->{'tmp_dir'}.'/'.join('_', split('/', $filename));

    my $fh = get_fh($input);
    return	unless ref $fh;

    my $ext;
    my $size = 1073741824;
    if ( not ref $input ) {
	$ext = $input =~ /(jpe?g|gif|png)$/i ? lc $1 : 'bin';
	if ( scheme($input) eq 'file' ) {
		$size = (stat $fh)[7];
	}
    } elsif ( ref $input eq 'Apache::Upload' ) {
	$ext = $input->filename() =~ /(jpe?g|gif|png)$/i ? lc $1 : 'bin';
	$size = (stat $fh)[7];
    } elsif ( $opts{filename} ) {
	$ext = $opts{filename} =~ /(jpe?g|gif|png)$/i ? lc $1 : 'bin';
    }
    if ( ref $fh eq 'IO::Scalar' ) {
	$size = length("$fh");
    }
    $ext ||= 'bin';

    my $fh_tmp = IO::File->new('>'.$filename_tmp.'.'.$ext) || return;
    my $buffer;

    $size = sysread $fh, $buffer, $size;
    syswrite $fh_tmp, $buffer, $size;

    undef $fh_tmp;

    my $IMAGE;
    if ( store($filename.'.'.$ext, $filename_tmp.'.'.$ext) ) {
	$IMAGE = {};
	# hashref slice assigning - жжесть
	@{$IMAGE}{'filename', 'width', 'height'} = (
		$filename.'.'.$ext,
		Image::Size::imgsize($filename_tmp.'.'.$ext),
	);

	foreach my $suffix (@preview) {
		my $c_line = $state->{'convert_binary'}.' -geometry \''.$suffix.'\' -quality 80 '.$filename_tmp.'.'.$ext.' '.$filename_tmp.'.'.$suffix.'.'.$ext;
		my $result = `$c_line`;

		if (length $result > 0) {
			warn 'Contenido Error: При вызове "'.$c_line.'" произошла ошибка "'.$result.'" ('.$@.")\n";
			return undef;
		}
		@{$IMAGE->{'mini'}{$suffix}}{'filename', 'width', 'height'} = (
			$filename.'.'.$suffix.'.'.$ext,
			Image::Size::imgsize($filename_tmp.'.'.$suffix.'.'.$ext),
		);
		%{$IMAGE->{'resize'}{$suffix}} = %{$IMAGE->{'mini'}{$suffix}};
		store($filename.'.'.$suffix.'.'.$ext, $filename_tmp.'.'.$suffix.'.'.$ext);
		unlink $filename_tmp.'.'.$suffix.'.'.$ext	if -e $filename_tmp.'.'.$suffix.'.'.$ext;
	}
	if ( @preview ) {
		@{$IMAGE->{'mini'}}{'filename', 'width', 'height'} = @{$IMAGE->{'mini'}{$preview[0]}}{'filename', 'width', 'height'};
		@{$IMAGE->{'resize'}}{'filename', 'width', 'height'} = @{$IMAGE->{'mini'}{$preview[0]}}{'filename', 'width', 'height'};
	}

	########## CROPS
	foreach my $suffix (@crops) {

		my $shave_string;
		my ($nwidth, $nheight) = $suffix =~ /(\d+)x(\d+)/i ? ($1, $2) : (0, 0);
		if ( ($IMAGE->{width} / $IMAGE->{height}) > ($nwidth / $nheight) ) {
			my $shave_pixels = (($IMAGE->{width} / $IMAGE->{height}) - ($nwidth / $nheight)) * $IMAGE->{height};
			$shave_string = ' -shave '.int($shave_pixels / 2).'x0';
		} elsif ( ($IMAGE->{height} / $IMAGE->{width}) > ($nheight / $nwidth) ) {
			my $shave_pixels = (($IMAGE->{height} / $IMAGE->{width}) - ($nheight / $nwidth)) * $IMAGE->{width};
			$shave_string = ' -shave 0x'.int($shave_pixels / 2);
		}
		if ( $shave_string ) {
			my $c_line = $state->{"convert_binary"}." $shave_string $filename_tmp.$ext $filename_tmp.shaved.$ext";
			my $result = `$c_line`;
			if (length $result  > 0) {
				print "Contenido Error: При вызове '$c_line' произошла ошибка '$result' ($@)\n";
			}
		} else {
			my $c_line = "cp $filename_tmp.$ext $filename_tmp.shaved.$ext";
			my $result = `$c_line`;
			if (length $result  > 0) {
				print "Contenido Error: При вызове '$c_line' произошла ошибка '$result' ($@)\n";
			}
		}

		my $c_line = $state->{'convert_binary'}.' -geometry \''.$suffix.'!\' -quality 80 '.$filename_tmp.'.shaved.'.$ext.' '.$filename_tmp.'.'.$suffix.'.'.$ext;
		my $result = `$c_line`;

		if (length $result > 0) {
			warn 'Contenido Error: При вызове "'.$c_line.'" произошла ошибка "'.$result.'" ('.$@.")\n";
			return undef;
		}
		@{$IMAGE->{'mini'}{$suffix}}{'filename', 'width', 'height'} = (
			$filename.'.'.$suffix.'.'.$ext,
			Image::Size::imgsize($filename_tmp.'.'.$suffix.'.'.$ext),
		);
		%{$IMAGE->{'crop'}{$suffix}} = %{$IMAGE->{'mini'}{$suffix}};
		store($filename.'.'.$suffix.'.'.$ext, $filename_tmp.'.'.$suffix.'.'.$ext);
		unlink $filename_tmp.'.shaved.'.$ext      if -e $filename_tmp.'.shaved.'.$ext;
		unlink $filename_tmp.'.'.$suffix.'.'.$ext if -e $filename_tmp.'.'.$suffix.'.'.$ext;
	}
	if ( @crops ) {
		if ( !exists $IMAGE->{'mini'}{'filename'} ) {
			@{$IMAGE->{'mini'}}{'filename', 'width', 'height'} = @{$IMAGE->{'mini'}{$crops[0]}}{'filename', 'width', 'height'};
		}
		@{$IMAGE->{'crop'}}{'filename', 'width', 'height'} = @{$IMAGE->{'crop'}{$crops[0]}}{'filename', 'width', 'height'};
	}


	########## SHRINKS
	foreach my $suffix (@shrinks) {

		my $c_line = $state->{'convert_binary'}.' -geometry \''.$suffix.'!\' -quality 80 '.$filename_tmp.'.'.$ext.' '.$filename_tmp.'.'.$suffix.'.'.$ext;
		my $result = `$c_line`;

		if (length $result > 0) {
			warn 'Contenido Error: При вызове "'.$c_line.'" произошла ошибка "'.$result.'" ('.$@.")\n";
			return undef;
		}
		@{$IMAGE->{'mini'}{$suffix}}{'filename', 'width', 'height'} = (
			$filename.'.'.$suffix.'.'.$ext,
			Image::Size::imgsize($filename_tmp.'.'.$suffix.'.'.$ext),
		);
		%{$IMAGE->{'shrink'}{$suffix}} = %{$IMAGE->{'mini'}{$suffix}};
		store($filename.'.'.$suffix.'.'.$ext, $filename_tmp.'.'.$suffix.'.'.$ext);
		unlink $filename_tmp.'.'.$suffix.'.'.$ext if -e $filename_tmp.'.'.$suffix.'.'.$ext;
	}
	if ( @shrinks && !exists $IMAGE->{'mini'}{'filename'} ) {
		if ( !exists $IMAGE->{'mini'}{'filename'} ) {
			@{$IMAGE->{'mini'}}{'filename', 'width', 'height'} = @{$IMAGE->{'mini'}{$shrinks[0]}}{'filename', 'width', 'height'};
		}
		@{$IMAGE->{'shrink'}}{'filename', 'width', 'height'} = @{$IMAGE->{'shrink'}{$shrinks[0]}}{'filename', 'width', 'height'};
	}

	unlink $filename_tmp.'.'.$ext if -e $filename_tmp.'.'.$ext;
    }

    return $IMAGE;
}

sub remove_image {
    my $IMAGE = shift;

    if ( ref $IMAGE eq 'HASH' && exists $IMAGE->{filename} ) {
	remove($IMAGE->{'filename'}) || return;
    }
    if ( ref $IMAGE && exists $IMAGE->{mini} && ref $IMAGE->{mini} eq 'HASH' ) {
	foreach my $val ( values %{$IMAGE->{mini}} ) {
		if ( ref $val && exists $val->{filename} && $val->{filename} ) {
			remove($val->{'filename'}) || return;
		}
	}
    }
    1;
}


sub store_binary {
    my $input = shift;
    my (%opts) = @_;
    my $object = delete $opts{object} || return;
    my $attr = delete $opts{attr}  || return;

    my ($prop) = grep { $_->{attr} eq $attr } $object->structure;
    return	unless ref $prop;

    my $filename = '/binary/'.$object->get_file_name() || return;
    if ( $prop->{softrename} ) {
	my $oid = $object->id || int(rand(10000));
	my $orig_name = '';
	if ( ref $input eq 'Apache::Upload' ) {
		$orig_name = $input->filename();
	} elsif ( !ref $input ) {
		$orig_name = $input;
	}
	if ( $orig_name ) {
		if ( $orig_name =~ /\\([^\\]+)$/ ) {
			$orig_name = $1;
		} elsif ( $orig_name =~ /\/([^\/]+)$/ ) {
			$orig_name = $1;
		}
		$orig_name =~ s/[\ \t]/_/g;
		$orig_name = $oid.'_'.$orig_name;
		$filename =~ s/\/([^\/]+)$//;
		my $fname = $1;
		unless ( $orig_name =~ /^[a-zA-Z_\d\.\-\,]+$/ ) {
			$orig_name = translit( $orig_name );
		}
		warn "\n\n\n\n\nNew Name: [$orig_name]\n\n\n\n\n"		if $DEBUG;
		unless ( $orig_name =~ /^[a-zA-Z_\d\.\-\,]+$/ ) {
			$orig_name = $fname;
		}
		$filename .= '/'.$orig_name;
		$filename =~ s/\.([^\.]+)$//;
	}
    }

    my $filename_tmp = $state->{'tmp_dir'}.'/'.join('_', split('/', $filename));

    my $fh = get_fh($input);
    return	unless ref $fh;

    my $ext;
    my $size = 1073741824;
    if ( not ref $input ) {
	$ext = $input =~ /\.([^\.]+)$/ ? lc($1) : 'bin';
	if ( scheme($input) eq 'file' ) {
		$size = (stat $fh)[7];
	}
    } elsif ( ref $input eq 'Apache::Upload' ) {
	$ext = $input->filename() =~ /\.([^\.]+)$/ ? lc($1) : 'bin';
	$size = (stat $fh)[7];
    } elsif ( $opts{filename} ) {
	$ext = $opts{filename} =~ /\.([^\.]+)$/ ? lc($1) : 'bin';
    }
    if ( ref $fh eq 'IO::Scalar' ) {
	$size = length("$fh");
    }
    $ext ||= 'bin';

    my $fh_tmp = IO::File->new('>'.$filename_tmp.'.'.$ext) || return;
    my $buffer;

    $size = sysread $fh, $buffer, $size;
    syswrite $fh_tmp, $buffer, $size;

    undef $fh_tmp;

    my $BINARY;
    if ( store($filename.'.'.$ext, $filename_tmp.'.'.$ext) ) {
	@{$BINARY}{"filename", "ext", "size"} = (
		$filename.".".$ext, $ext, $size
	);

	unlink $filename_tmp.'.'.$ext if -e $filename_tmp.'.'.$ext;

	if ( $ext =~ /(rar|7z|zip|arc|lha|arj|cab)/ ) {
		$BINARY->{type} = 'archive';
	} elsif ( $ext =~ /(doc|rtf)/ ) {
		$BINARY->{type} = 'doc';
	} elsif ( $ext eq 'xls' ) {
		$BINARY->{type} = 'xls';
	} elsif ( $ext =~ /(mdb|ppt)/ ) {
		$BINARY->{type} = 'msoffice';
	} elsif ( $ext =~ /(pdf)/ ) {
		$BINARY->{type} = 'ebook';
	} elsif ( $ext eq 'psd' ) {
		$BINARY->{type} = 'psd';
	} elsif ( $ext =~ /(exe|msi|cab)/ ) {
		$BINARY->{type} = 'executable';
	} else {
		$BINARY->{type} = 'unknown';
	}

    }

    return $BINARY;
}

sub remove_binary {
    my $BINARY = shift;

    if ( ref $BINARY eq 'HASH' && exists $BINARY->{filename} ) {
	remove($BINARY->{'filename'}) || return;
    }

    1;
}


sub translit {
    my $str = shift;
    my @str = split (//, $str);
    my $res = '';
    while ( scalar @str ) {
	my $alpha = shift @str;
	if ( exists $translit{$alpha} ) {
		$res .= $translit{$alpha};
	} else {
		$res .= $alpha;
	}
    }
    return $res;
}


1;
