package Contenido::Logger;
use base 'Log::Dispatch';
use strict;
use Log::Dispatch::Screen;
use Carp;

=head1 NAME

Contenido::Logger - Log wrapper for conenido around Log::Dispatch.

=head1 SYNOPSIS

    my $log = Contenido::Logger->new();
    $log->debug('Hello world');
    $log->error('SMX code is wrong');
    $log->emergency('Fuck!'); 

=head1 DESCRIPTION

Not yet

=head1 METHODS

=head2 new

    Contenido::Logger->new(%options);

=head2 instance

    Contenido::Logger->instance(%options);


=over

Options:

=item *

min_level: minimum level of logging
[debug info notice warning error critical alert emergency].

=item *

max_level: maximum level of logging

=item *

callback: custom callback when logging (instead of default).
CODE reference. See L<Log::Dispatch> for more info.

=item *

log_format: custom log format style. Default to '%d %C:%L(%P) [%l]: %m%n'.

=over

Where:

=item *

%d - date (format [mday/mon/year hour:min:sec])

=item *

%P - current process ID

=item *

%C - name of package caused this log

=item *

%L - code line in %C

=item *

%l - log level

=item *

%m - log text

=item *

%n - "\n"

=back

=item *

stack_trace: enable stack trace on log levels warning, ..., emergency. Boolean.

=back

=cut

our @levels = qw/debug info notice warning error critical alert emergency/;
my $i = 0;
our %levels = map { $_ => $i++ } @levels;
$levels{emerg} = $levels{emergency};
$levels{err}   = $levels{error};
$levels{crit}  = $levels{critical};
my $instance;

sub new {
    my ($this, %opts) = @_;
    $this = ref $this if ref $this;

    my $log_format = $opts{log_format} || "%d %C:%L(%P) [%l]: %m%n";
    my %subst_hash = (
        P => $$,
        n => "\n",
    );
    $log_format =~ s#%(.)#exists $subst_hash{$1} ? $subst_hash{$1} : '%'.$1#ge;
    my $stack_trace = $opts{stack_trace};
    my $custom_callback = $opts{callback};

    my $callback = sub {
        my %p = @_;
        $p{message} .= 
            "\n  >>>>>>>>>> StackTrace\n".
            Carp::longmess('Begin StackTrace').
            "  <<<<<<<<<< /StackTrace"
         if $stack_trace and $levels{$p{level}} >= $levels{warning};
        return $custom_callback->(%p) if $custom_callback;

        my ($sec, $min, $hour, $mday, $mon, $year) = localtime;
        $subst_hash{d} = sprintf(
            '[%02d/%02d/%02d %02d:%02d:%02d]',
            $mday, $mon+1, $year-100, $hour, $min, $sec,
        );

        $subst_hash{m} = $p{message};
        $subst_hash{l} = $p{level};

        #Who's calling?
        my @caller = caller(4 - ($p{_direct} || 0));
        $subst_hash{C} = $caller[0];
        $subst_hash{L} = $caller[2];

        my $final_msg = $log_format;
        $final_msg =~ s#%(.)#exists $subst_hash{$1} ? $subst_hash{$1} : '%'.$1#ge;
        return $final_msg;
    };

    my $self = $this->SUPER::new(callbacks => $callback);

    my $minlevel = $opts{min_level} || 'debug';
    $self->add(
        Log::Dispatch::Screen->new(
            name      => 'genlog',
            min_level => $minlevel,
            max_level => $opts{max_level} || 'emergency',
            stderr    => 1,
        )
    );
    $self->cut_min_level($minlevel);
    $instance = $self;
    $self;
}

sub instance { $instance || shift->new( @_ ) }

sub cut_min_level {
    my (undef, $minlevel) = @_;
    my $num = $levels{$minlevel} or return;
    my @to_cut = grep {$levels{$_} < $num} keys %levels;
    no strict 'refs';
    no warnings;
    *$_ = sub {} for @to_cut;
    *log = sub {
        my $self = shift;
        my %p = @_;
        return if $levels{$p{level}} < $num;
        $self->SUPER::log(@_, caller !~ /^Log::Dispatch/ ? (_direct => 1) : ());
    };
    return;
}

sub log { shift->SUPER::log(@_, caller !~ /^Log::Dispatch/ ? (_direct => 1) : ()) }

1;
