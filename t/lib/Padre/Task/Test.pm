package Padre::Task::Test;

use strict;
use warnings;
use Test::More ();
use base 'Padre::Task';

sub prepare {
	my $self = shift;
	Test::More::isa_ok( $self, "Padre::Task" );
	Test::More::isa_ok( $self, $main::TestClass );
	$self->{msg} = "query";
}

sub run {
	my $self = shift;
	Test::More::isa_ok( $self, "Padre::Task" );
	Test::More::isa_ok( $self, $main::TestClass );
	Test::More::is( $self->{msg}, "query", "message received in worker" );
	Test::More::ok( !exists $self->{_process_class}, "_process_class was cleaned" );
	$self->{answer} = 'succeed';
}

sub finish {
	my $self = shift;
	Test::More::isa_ok( $self, "Padre::Task" );
	Test::More::isa_ok( $self, $main::TestClass );
	Test::More::is( $self->{msg}, "query", "message survived worker" );
	Test::More::is( $self->{answer}, "succeed", "message from worker" );
	Test::More::ok( !exists $self->{_process_class}, "_process_class was cleaned" );
}

1;

