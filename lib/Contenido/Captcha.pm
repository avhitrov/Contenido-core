package Contenido::Captcha;

use strict;
use warnings 'all';

use Authen::Captcha;
use Digest::MD5 qw(md5_hex);


sub new {
	my ($class, $keeper, %captcha_args) = @_;

	my $self  = {
		captcha => Authen::Captcha->new(%captcha_args),
		memd    => $keeper->MEMD,
	};
	bless $self, $class;
}

sub create_code {
	my ($self, %opts) = @_;

	my $code = $$self{captcha}->generate_random_string($opts{length}||4);
	my $md5 = md5_hex($code.int 10**10*rand);

	$$self{memd}->set("captcha:".$md5, $code, $opts{expire}||600);

	$md5;
}

sub create_image {
	my ($self, $md5) = @_;

	my $code = $$self{memd}->get("captcha:".$md5||'');
	return unless $code;

	$$self{captcha}->create_image_file($code);
}

sub check_code {
	my ($self, $md5, $code) = @_;

	return 0 unless $code;

	my $real = $$self{memd}->get("captcha:".$md5||'');
	return 0 unless $real && $real eq $code;

	$$self{memd}->delete("captcha:".$md5||'');

	1;
}

sub width {
	my $self = shift;
	$$self{captcha}->width;
}

sub height {
	my $self = shift;
	$$self{captcha}->height;
}

1;
