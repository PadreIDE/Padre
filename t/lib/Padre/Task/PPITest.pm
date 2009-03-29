package Padre::Task::PPITest;
use strict;
use warnings;
require Test::More;
use base 'Padre::Task::PPI';

sub prepare {
	my $self = shift;
	$self->SUPER::prepare(@_);
	Test::More::isa_ok( $self, "Padre::Task" );
	Test::More::isa_ok( $self, "Padre::Task::PPI" );
	Test::More::isa_ok( $self, $main::TestClass );
	$self->{msg} = "query";
}

sub process_ppi {
	my $self = shift;
	my $ppi  = shift;
	Test::More::isa_ok( $self, "Padre::Task" );
	Test::More::isa_ok( $self, "Padre::Task::PPI" );
	Test::More::isa_ok( $self, $main::TestClass );
	Test::More::is( $self->{msg}, "query", "message received in worker" );
	Test::More::ok( !exists $self->{_process_class}, "_process_class was cleaned" );
	Test::More::isa_ok($ppi, 'PPI::Document');
	$self->{answer} = 'succeed';
}

sub finish {
	my $self = shift;
	$self->SUPER::finish(@_);
	Test::More::isa_ok( $self, "Padre::Task" );
	Test::More::isa_ok( $self, "Padre::Task::PPI" );
	Test::More::isa_ok( $self, $main::TestClass );
	Test::More::is( $self->{msg}, "query", "message survived worker" );
	Test::More::is( $self->{answer}, "succeed", "message from worker" );
	Test::More::ok( !exists $self->{_process_class}, "_process_class was cleaned" );
}

1;

