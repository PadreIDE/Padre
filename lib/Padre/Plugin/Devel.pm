package Padre::Plugin::Devel;

use 5.008;
use strict;
use warnings;
use Padre::Wx      ();
use Padre::Plugin  ();
use Padre::Current ();

our $VERSION = '0.24';
our @ISA     = 'Padre::Plugin';





#####################################################################
# Padre::Plugin Methods

sub padre_interfaces {
	'Padre::Plugin'         => 0.24,
	'Padre::Wx::MainWindow' => 0.24,
}

sub plugin_name {
	'Padre Developer Tools';
}

# Load our non-core dependencies when we are enabled
sub plugin_enable {
	require Devel::Dumpvar;
}

sub menu_plugins_simple {
	my $self = shift;
	return $self->plugin_name => [
		'Dump Current Document'          => sub { $self->dump_document },
		'Eval Current Document in Padre' => sub { $self->eval_document },
		'---'                            => undef,
		'About'                          => sub { $self->show_about    },
	];
}





#####################################################################
# Plugin Methods

sub dump_document {
	my $self     = shift;
	my $document = Padre::Current->document;
	unless ( $document ) {
		Padre::Current->_main->message( 'No file is open', 'Info' );
		return;
	}
	return $self->_dump_eval( $document );
}

sub eval_document {
	my $self     = shift;
	my $document = Padre::Current->document or return;
	my $code     = $document->text_get;
	return $self->_dump_eval( $code );
}

sub show_about {
	my $self  = shift;
	my $about = Wx::AboutDialogInfo->new;
	$about->SetName('Padre::Plugin::Devel');
	$about->SetDescription(
		"A set of unrelated tools used by the Padre developers\n"
	);
	Wx::AboutBox( $about );
	return;
}

# Takes a string, which it evals and then dumps to Output
sub _dump_eval {
	my $self = shift;
	my $code = shift;
	my $main = Padre::Current->_main;

	# Evecute the code and handle errors
	warn $code . "\n";
	my @rv = eval $code; ## no critic
	if ( $@ ) {
		$main->error( sprintf(Wx::gettext("Error: %s"), $@) );
		return;
	}

	# Dump the results to the output window
	my $dumper = Devel::Dumpvar->new( to => 'return' );
	my $string = $dumper->dump( @rv );
	$main->show_output(1);
	$main->output->clear;
	$main->output->AppendText($string);

	return;
}

1;

__END__

=pod

=head1 NAME

Padre::Plugin::Devel - tools used by the Padre developers

=head1 DESCRIPTION

=head2 Run in Padre

Executes and evaluates the contents of the current (saved or unsaved)
document within the current Padre process, and then dumps the result
of the evaluation to Output.

=head2 Show %INC

Dumps the %INC hash to Output

=head2 Info

=head2 About

=head1 AUTHOR

Gabor Szabo

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
