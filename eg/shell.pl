package main;

use 5.008;
use strict;
use warnings;

# use Demo::App;

my $app = Demo::App->new;
$app->run;

package Shell::App;

use strict;
use warnings;
use base 'Wx::App';

$| = 1;

our $frame;
sub OnInit {
    my ($self) = @_;
    $frame = Shell::App::Frame->new($self);
    $frame->Show( 1 );
}

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    return $self;
}
sub run {
    my ($self) = @_;

    $self->setup;
    $self->MainLoop;
}

sub setup {
}

sub commands {
    my ($self, @commands) = @_;
    $self->{commands}->{$_}++ for @commands;
    return;
}

sub args {
    my ($self) = @_;
    # wantarray?
    return $self->{args};
}

package Shell::App::Frame;

use strict;
use warnings;
use Wx qw(:everything);

use base 'Wx::Frame';


my ($out, $in);

sub new {
    my ($class, $app, $windows) = @_;
    $windows = 1 if not defined $windows;
    die if $windows !~ /^[123]$/;

    my $self = $class->SUPER::new( undef, -1,
                                 'Shell::App',
                                  wxDefaultPosition,  [600, 600],
                                 );
    $self->{_app} = $app;
    $self->{prompt} = '>';
    $self->{windows} = $windows;

    my $main = Wx::SplitterWindow->new(
                $self, -1, wxDefaultPosition, wxDefaultSize,
                wxNO_FULL_REPAINT_ON_RESIZE|wxCLIP_CHILDREN );

    if ($windows == 1) {
        $out = Wx::TextCtrl->new( $main, -1, '', wxDefaultPosition, wxDefaultSize,
            wxTE_MULTILINE|wxNO_FULL_REPAINT_ON_RESIZE
            );
        $in = $out;

    } elsif ($windows == 2) {
    
        $out = Wx::TextCtrl->new( $main, -1, '', wxDefaultPosition, wxDefaultSize,
            wxTE_READONLY|wxTE_MULTILINE|wxNO_FULL_REPAINT_ON_RESIZE
            );
        $in = Wx::TextCtrl->new( $main, -1, '', wxDefaultPosition, wxDefaultSize,
            wxTE_PROCESS_ENTER|wxNO_FULL_REPAINT_ON_RESIZE
            );
        Wx::Event::EVT_TEXT_ENTER($self, $in, \&enter);
        $main->SplitHorizontally( $out, $in, -50 );
    } else {
        die "windows=3 Not implemented yet\n";
    }

    #Wx::Event::EVT_TEXT($in, \&text_changed );  #here is where we can implement command line cleverness?

    $in->SetFocus;
    $out->AppendText($self->{prompt});

    Wx::Event::EVT_CLOSE( $self,  sub {
         my ( $self, $event ) = @_;
         $event->Skip;
    });
    return $self;
}

sub enter {
    my ($self, $event) = @_;
    my $output;
    if ($self->{windows} eq 1) {
       $output = $self->enter_1($event);
    } elsif ($self->{windows} eq 2) {
       $output = $self->enter_2($event);
    } else {
       $output = $self->enter_2($event);
    }

    return $output;
}

sub enter_1 {
    my ($self, $event) = @_;
    my $cmd_line = $in->GetValue;

    print $cmd_line;
}

sub enter_2 {
    my ($self, $event) = @_;

    my $cmd_line = $in->GetValue;
    #process
    $out->AppendText("$cmd_line\n");
    my ($cmd, $args) = split /\s+/, $cmd_line, 2;
    $self->{_app}->{args} = $args;

    if ($self->{_app}->{commands}->{$cmd}) {
        my $output = $self->{_app}->$cmd();
        $out->AppendText($output);
    } else {
        $out->AppendText("No such command '$cmd'\n");
    }
    $out->AppendText($self->{prompt});
    $in->SetValue('');
    #$out

    return;
}

package Demo::App;

use strict;
use warnings;
use base 'Shell::App';

sub setup {
    my ($self) = @_;

    $self->commands(qw(
            ls
            ));

    return;
}

sub ls {
    my ($self) = @_;
    my $dir = $self->args;
    $dir = '.' if not defined $dir;

    #return "running ls\n";
    my $res = '';
    if (opendir my $dh, $dir) {
       my @items = readdir $dh;
       foreach my $thing (@items) {
           $res .= "$thing\n";
       }
    } else {
       $res = "Could not open '$dir': $!";
    }   

    return $res;
}
