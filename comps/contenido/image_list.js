// This list may be created by a server logic page PHP/ASP/ASPX/JSP in some backend system.
// There images will be displayed as a dropdown in all image dialogs if the "external_link_image_url"
// option is defined in TinyMCE init.

var tinyMCEImageList = new Array(
	// Name, URL
<% join(',', @imgstr) %>
);
<%args>

	$class	=> undef
	$id	=> undef

</%args>
<%init>

  return	unless $class && $id;
  my $document = $keeper->get_document_by_id ( $id, class => $class );
  return	unless ref $document;
  
  my @images;
  my @props = grep { $_->{type} eq 'images' || $_->{type} eq 'image' } $document->structure;
  foreach my $prop ( @props ) {
	if ( $prop->{type} eq 'images' ) {
		my $images = $document->get_image($prop->{attr});
		if ( ref $images && exists $images->{maxnumber} && $images->{maxnumber} ) {
			for ( 1..$images->{maxnumber} ) {
				my $image = $images->{"image_$_"};
				if ( ref $image && exists $image->{filename} ) {
					my $img_path = ($state->{images_dir} =~ /^http:/ ? $state->{images_dir} : '').($image->{filename} =~ /^\// ? '' : '/').$image->{filename};
					my $name = $image->{alt} || $prop->{attr}.": image_$_";
					$name =~ s/"/\\"/g;
					push @images, { url => $img_path, name => $name, mini => (exists $image->{mini} ? $image->{mini} : undef) };
				}
			}
		}
	} else {
		my $image = $document->get_image($prop->{attr});
		if ( ref $image && exists $image->{filename} ) {
			my $img_path = ($state->{images_dir} =~ /^http:/ ? $state->{images_dir} : '').($image->{filename} =~ /^\// ? '' : '/').$image->{filename};
			my $name = $image->{alt} || $document->name.' ('.$prop->{attr}.')';
			$name =~ s/"/\\"/g;
			push @images, { url => $img_path, name => $name, mini => (exists $image->{mini} ? $image->{mini} : undef) };
		}
	}
  }
  return	unless @images;
  my $comma = 0;
  my @imgstr;
  foreach my $img ( @images ) {
	push @imgstr, '["'.$img->{name}.'","'.$img->{url}.'"]';
	if ( exists $img->{mini} && ref $img->{mini} eq 'HASH' ) {
		while ( my ($dim, $mini) = each %{$img->{mini}} ) {
			next	unless ref $mini eq 'HASH' && exists $mini->{filename};
			push @imgstr, '["'.$img->{name}.'. Mini: '.$dim.'","'.$mini->{filename}.'"]';
		}
	}
  }

</%init>