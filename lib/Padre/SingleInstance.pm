package Padre::SingleInstance;

# core modules
use strict;
use warnings;
use Carp;
use IO::File;
use IO::Socket;
use threads;

# constants
use constant REMOTE_HOST => '127.0.0.1';
use constant SERVER_PORT => 9999;

#
# constructor
#
sub new {
    my ($class,%options) = @_;
    
    if(! defined $options{on_file_request}) {
        croak "on_file_request is not defined";
    }
    if(! defined $options{on_focus_request}) {
        croak "on_focus_request is not defined";
    }
    my $self = bless \%options, $class;
    return $self;
}

#
# checks whether another instance is running or not
#
sub is_running {
    my $self = shift;
    
    my $socket = IO::Socket::INET->new(PeerAddr => REMOTE_HOST,
                                    PeerPort => SERVER_PORT,
                                    Proto    => "tcp",
                                    Type     => SOCK_STREAM);

    if($socket) {    
        print "It is alive\n";
        if($#ARGV >= 0) {
            foreach my $argnum (0 .. $#ARGV) {
               my $arg = $ARGV[$argnum];
               print $socket "open $ARGV[$argnum]\n";
            }
            close $socket
                or croak "Cant close socket\n";
        } else {
            print $socket "restore_focus";
        }
        die "Sent it my work.... bye bye\n";
    }
    
    return $socket ? 1 : 0;
}

#
# start TCP server socket thread
#
sub start_server {
    my $self = shift;
    $self->{server_thread} = threads->create(sub { $self->_run; } );
    return $self->{server_thread};
}

#
# Main thread that services TCP clients
#
sub _run {
    my $self = shift;
    
    print "Try to run server on " . SERVER_PORT ."\n";
    my $server = IO::Socket::INET->new(LocalPort => SERVER_PORT,
                                    Type      => SOCK_STREAM,
                                    Reuse     => 1,
                                    Listen    => 10 )
        or croak "Couldn't be a tcp server on port " . SERVER_PORT .  ": $@\n";
    LOOP: while (my $client = $server->accept()) {
        # $client is the new connection
        while(my $line = <$client>) {
            if($line =~ /^open\s+(.+)$/) {
                #XXX- I should open filename... 
                my $filename = $1;
                eval {
                    $self->{on_file_request}($filename);
                    1;
                };
                Carp::confess($@) if $@;
            } elsif($line =~ /^restore_focus$/) {
                eval {
                    $self->{on_focus_request}();
                    1;
                };
                Carp::confess($@) if $@;
            }
        }
    }
}    

1;