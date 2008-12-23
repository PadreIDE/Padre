
package Padre::Task::Examples::WxEvent;
use strict;
use warnings;

our $VERSION = '0.22';

use base 'Padre::Task';

# set up a new event type
our $SAY_HELLO_EVENT : shared = Wx::NewEventType();

sub prepare {
	my $self = shift;

	# Set up the event handler
	my $main = Padre->ide->wx->main_window;
	Wx::Event::EVT_COMMAND($main, -1, $SAY_HELLO_EVENT, \&on_say_hello);
	return();
}

# the event handler
sub on_say_hello {
	my ($main, $event) = @_; @_=(); # hack to avoid "Scalars leaked"
	
	# write a message to the beginning of the document
	my $cur = Padre::Documents->current->editor;
	return if not defined $cur;
	$cur->InsertText(0, $event->GetData());
}

sub run {
	my $self = shift;
	
	# post two events for fun
	$self->post_event($SAY_HELLO_EVENT, "Hello from thread!\n");
	sleep 1;
	$self->post_event($SAY_HELLO_EVENT, "Hello again!\n");
	return 1;
}

1;

__END__

# Copyright 2008 Gabor Szabo.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
