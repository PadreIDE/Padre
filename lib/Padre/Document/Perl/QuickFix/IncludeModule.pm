package Padre::Document::Perl::QuickFix::IncludeModule;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.94';

#
# Constructor.
# No need to override this
#
sub new {
	my ($class) = @_;

	# Create myself :)
	my $self = bless {}, $class;

	return $self;
}

#
# Returns the quick fix list
#
sub apply {
	my ( $self, $doc, $document ) = @_;

	my @items = ();

	my $editor          = $document->editor;
	my $text            = $editor->GetText;
	my $current_line_no = $editor->GetCurrentLine;

	my $includes = $doc->find('PPI::Statement::Include');
	if ($includes) {
		foreach my $include ( @{$includes} ) {
			next if $include->type eq 'no';
			if ( not $include->pragma ) {
				my $module = $include->module;
				eval "require $module";
				if ($@) {
					push @items, {
						text     => "Install $module",
						listener => sub {

							#XXX- implement Install $module
						},
					};
				}

				my $project_dir = $document->project_dir;
				if ($project_dir) {
					my $Build_PL    = File::Spec->catfile( $project_dir, 'Build.PL' );
					my $Makefile_PL = File::Spec->catfile( $project_dir, 'Makefile.PL' );
					if ( -f $Build_PL ) {
						open my $FILE, '<', $Build_PL;
						my $content = do { local $/ = <$FILE> };
						close $FILE;
						if ( $content !~ /^\s*requires\s+["']$module["']/ ) {
							push @items, {
								text     => "Add missing requires '$module' to Build.PL",
								listener => sub {

								},
							};
						}

					} elsif ( -f $Makefile_PL ) {
						open my $FILE, '<', $Makefile_PL;
						my $content = do { local $/ = <$FILE> };
						close $FILE;
						if ( $content !~ /^\s*requires\s+["']$module["']/ ) {
							push @items, {
								text     => "Add missing requires '$module' to Makefile.PL",
								listener => sub {

								},
							};
						}
					}
				}

			}
		}
	}

	return @items;
}

1;

__END__

=head1 NAME

Padre::Document::Perl::QuickFix::IncludeModule - Check for module inclusions

=head1 DESCRIPTION

XXX - Please document

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
