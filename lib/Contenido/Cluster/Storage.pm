package Contenido::Cluster::Storage;
use strict;

use Contenido::Globals;

use HTTP::Async;
use HTTP::Request;
use HTTP::Headers;
use LWP::UserAgent;
use String::CRC32;
use Data::Dumper;


sub new {
    my $proto		= shift;
    my $class		= ref($proto) || $proto;
    my %opts		= @_;

    my $self 		= {};
    $self->{sql}	= $opts{sql} || die $log->error("You MUST pass sql object");
    $self->{users}	= $opts{users} || die $log->error("You MUST pass users dir");
    $self->{backend}	= $opts{backend} || die $log->error("You MUST pass backend host");
    $self->{is_async}	= $opts{is_async} ? 1 : 0;
    $self->{login}	= undef;
    $self->{temp}	= $opts{temp};

    bless ($self, $class);

    return $self;
}

sub start {
    my $self 		= shift;
    my %opts		= @_;

    $self->{is_async}	= $opts{is_async} || $self->{is_async} ? 1 : 0;
    $self->{login}	= $opts{login} || die $log->error("You MUST pass user login");
    $self->{result}	= 1;

    if ($self->{is_async} && !$self->{async}) {

        $self->{async} = new HTTP::Async();
        $self->{async}->slots(1000);
        $self->{async}->timeout(900);   
        $self->{async}->max_request_time(1800); 

    }

}

sub stop {
    my $self 		= shift;

    $self->{login}	= undef;

    return $self->_stop_async();
    
}

sub login {
    my $self 	= shift;

    return $self->{login} || die $log->error("You MUST start cluster session before use");
}

sub async {
    my $self 	= shift;

    return $self->{async} || die $log->error("You MUST start cluster session before use");
}

sub cluster {
    my $self 	= shift;

    unless ($request->{cluster}) {
        my $cursor = $self->{sql}->prepare("select bgroup, ip, host, status from backend where status = 0 order by id");
        $cursor->execute();
        while (my ($group, $ip, $host, $status) = $cursor->fetchrow_array()) {
            push(@{$request->{cluster}->{by_group}->[$group]}, [$ip, $host, $status]);
        }
        $cursor->finish();
       
        $cursor = $self->{sql}->prepare("select bgroup, hash from backend_virtual order by id");
        $cursor->execute();
        while (my ($group, $key) = $cursor->fetchrow_array()) {
            my ($from, $to) = map { hex } split("-", $key);
            $to ||= $from;
            foreach my $hash ($from..$to) {
                $request->{cluster}->{by_key}->[$hash] = $group;
                push(@{$request->{cluster}->{by_cluster}->[$group]}, $hash);
            }
        }
        $cursor->finish();

        $cursor = $self->{sql}->prepare("select bgroup, hash from backend_relocate order by id");
        $cursor->execute();
        while (my ($group, $key) = $cursor->fetchrow_array()) {
            my ($from, $to) = map { hex } split("-", $key);
            $to ||= $from;
            foreach my $hash ($from..$to) {
                $request->{cluster}->{by_relocate}->[$hash] = $group;
            }
        }
        $cursor->finish();
    }

    return $request->{cluster};

}

sub get_friend {
    my $self	= shift;
    my $force	= shift || 0;

    my @host	= ();

    if ($self->cluster) {
        my $hash = hex($self->get_full_hash);

        my $group = $self->cluster->{by_group}->[$self->cluster->{by_key}->[$hash]] || return ();
        foreach my $host (@{$group}) {
            if (($self->{backend} ne $host->[1]) || $force) {
                push(@host, $host->[1]);
            }
        }

        if ($self->is_locked) {
            my $group = $self->cluster->{by_group}->[$self->cluster->{by_relocate}->[$hash]];
            foreach my $host (@{$group}) {
                if (($self->{backend} ne $host->[1]) || $force) {
                    push(@host, $host->[1]);
                }
            }
        }
    }

    return @host;
}

sub is_friend {
    my $self	= shift;

    if ($self->cluster) {
        my $group = $self->cluster->{by_group}->[$self->cluster->{by_key}->[hex($self->get_full_hash(shift))]] || return ();

        foreach my $host (@{$group}) {
            if ($self->{backend} eq $host->[1]) {
                return 1;
            }
        }
    }

    return 0;
}

sub is_same_cluster {
    my $self		= shift;
    my $to_login	= shift || return 0;

    return $self->cluster->{by_key}->[hex($self->get_full_hash)] == $self->cluster->{by_key}->[hex($self->get_full_hash($to_login))];

}

sub is_locked {
    my $self	= shift;

    if ($self->cluster) {
        return defined($self->cluster->{by_relocate}->[hex($self->get_full_hash())]) ? 1 : 0;
    }

    return 1;
}

sub put {
    my ($self, $url) = @_; 

    die $log->error("wrong put usage") unless ($url);

    $self->_store_file($url);
}

sub relocate {
    my ($self, $url, $to_login, $to_url) = @_;

    die $log->error("wrong relocate usage") unless ($url || $to_login || $to_url);

    unless ($self->is_friend) {
        $log->error("not home cluster");        
        return 0;
    }

    $self->_store_file($url, $to_login, $to_url);
}

sub relocate_dir {
    my ($self, $url, $to_login, $to_url) = @_;

    die $log->error("wrong relocate_dir usage") unless ($url && $to_login && $to_url);

    unless ($self->is_friend) {
        $log->error("not home cluster");        
        return 0;
    }

    my $dir = join('/', $$self->{users}, $self->get_hash, $url);
    opendir(D, $dir);
    foreach my $file (grep(!/^[\.]+$/, readdir(D))) {
        $self->relocate(join("/", $url, $file), $to_login, join("/", $to_url, $file));
    } 
    closedir(D);
}

sub move {
    my ($self, $url, $to_login, $to_url) = @_;

    die $log->error("wrong move usage") unless ($url || $to_login || $to_url);

    return $self->_transfer_file(1, $url, $to_login, $to_url);

}

sub copy {
    my ($self, $url, $to_login, $to_url) = @_;

    die $log->error("wrong copy usage") unless ($url || $to_login || $to_url);

    return $self->_transfer_file(0, $url, $to_login, $to_url);
}


sub delete {
    my ($self, $url, $recursive) = @_;

    die $log->error("wrong delete usage") unless ($url);

    my $req_file = join('/', "protected", $self->get_hash, $url);

    foreach my $host ($self->get_friend) {

        my $req_url = 'http://'.join('/', $host, $req_file);
        my $req = HTTP::Request->new(
            DELETE => $req_url,
        );
        if ($recursive) {
            $req->header('Depth' => 'infinity');
        }
        $self->_send_request($req, "DELETE $req_url");

    }
}


sub lock {
    my $self	= shift;

    return $self->_lock_request(1);
}


sub unlock {
    my $self	= shift;

    return $self->_lock_request(0);
}


sub acl {
    my ($self, $url, $is_public) = @_;

    die $log->error("wrong acl usage") unless ($url);

    my $req_file = join('/', "protected", $self->get_hash, $url);

    foreach my $host ($self->get_friend) {

        my $req_url = 'http://'.join('/', $host, $req_file);
        my $req = HTTP::Request->new(
            ACL => $req_url,
        );
        $req->header('X-Access' => $is_public ? 775 : 770 );

        $self->_send_request($req, "ACL $req_url");

    }
}

sub _store_file {
    my ($self, $url, $to_login, $to_url) = @_;

    my $file = join('/', $self->{temp} && !$self->is_friend ? $self->{temp} : $self->{users}, $self->get_hash, $url);

    if (open($Contenido::Cluster::Storage::fh, $file)) {
        if (my @host = $self->get_friend) {

            my $req_file = join('/', "public", $to_login && $to_url ? ($self->get_hash($to_login), $to_url) : ($self->get_hash, $url));

            if ($self->{is_async} && $self->async) {

                my $content;
                while (read($Contenido::Cluster::Storage::fh, my $buf, 1024*1024)) {
                    $content .= $buf;
                }

                foreach my $host (@host) {

                    my $req_url = 'http://'.join('/', $host, $req_file);
                    my $req = HTTP::Request->new(
                        PUT	=> $req_url,
                    );
                    $req->content_length((stat($file))[7]);
                    $req->content_ref(\$content);

                    $self->_send_request($req, "PUT $file to $req_url");

                }

            } else {

                foreach my $host (@host) {
                    seek($Contenido::Cluster::Storage::fh, 0, 0);

                    my $req_url = 'http://'.join('/', $host, $req_file);
                    my $req = HTTP::Request->new(
                        PUT	=> $req_url,
                        undef,
                        sub { 
                            read($Contenido::Cluster::Storage::fh, my $buf, 1024*1024);
                            return $buf;
                        }
                    );
                    $req->content_length((stat($file))[7]);

                    $self->_send_request($req, "PUT $file to $req_url");
                }
           }
 
       }
       close($Contenido::Cluster::Storage::fh);
    }
}

sub _send_request {
    my $self	= shift;
    my $req	= shift || die $log->error("no request passed");
    my $msg	= shift || "LWP";

    $log->debug( $msg." ..." );

    if ($self->{is_async}) {

        $self->async->add($req);
        $self->async->poke();

    } else {

        my $res = new LWP::UserAgent->request($req);
        unless ($res->is_success) {
            $log->error( $msg." failed - ".$res->code );
            $self->{result} = 0;
        }

    }
}

sub _lock_request {
    my $self	= shift;
    my $mode	= shift || 0;
    $mode	= $mode ? "LOCK" : "UNLOCK";

    my $req_file = join('/', "protected", $self->login);

    foreach my $host ($self->get_friend(1)) {

        my $req_url = 'http://'.join('/', $host, $req_file);
        my $req = HTTP::Request->new(
            $mode => $req_url,
        );
        $req->header('X-Hash' => $self->get_full_hash);

        $self->_send_request($req, "$mode $req_url");
 
    }

    return $self->_stop_async();
}

sub _transfer_file {
    my $self	= shift;
    my $mode	= shift || 0;
    $mode	= $mode ? "MOVE" : "COPY";

    my ($url, $to_login, $to_url) = @_;

    unless ($self->is_same_cluster($to_login)) {
        $log->error("users not on same cluster");        
        return 0;
    }

    my $req_file	= join('/', "protected", $self->get_hash, $url);
    my $to_req_file	= join('/', "protected", $self->get_hash($to_login), $to_url);

    foreach my $host ($self->get_friend) {

        my $req_url	= 'http://'.join('/', $host, $req_file);
        my $to_req_url	= 'http://'.join('/', $host, $to_req_file);
        my $req = HTTP::Request->new(
            $mode => $req_url,
        );
        $req->header('Destination' => $to_req_url);

        $self->_send_request($req, "$mode $req_url to $to_req_url");

    }
}

sub _stop_async {
    my $self 		= shift;

    if ($self->{is_async}) {
        while ( my $res = $self->{async}->wait_for_next_response ) {
            if (!$res->is_success() && ($res->code ne '405')) {
                $self->{result} = 0;
                $log->error("async failed - ".$res->code);
            }
        }
    }

    return $self->{result};
}

sub get_hash {
    my $self	= shift;
    my $login	= shift || $self->login;

    my $hash = substr(sprintf("%X", crc32($login)), -4, 4);
    return substr($hash, -4, 2).'/'. substr($hash, -2, 2) || '00/00';

}

sub get_full_hash {
    my $self	= shift;
    my $login	= shift || $self->login;

    return substr(sprintf("%X", crc32($login)), -4, 4) || '0000'
}






1;
