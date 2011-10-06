sub guess_indentation_style {
	if ( $indentation =~ /^m(\d+)/ ) {
		$style = {
			use_tabs    => 1,
			tabwidth    => 8,
			indentwidth => $1,
		};
	}
}

sub guess_filename {
	my $self = shift;

	return;
}

# Abstract methods, each subclass should implement it
# TO DO: Clearly this isn't ACTUALLY abstract (since they exist)

sub get_calltip_keywords {
	return {};
}

sub two_lines
{
	return 1;
}

sub
three_lines
{
	return 1;
}

# This is a false __DATA__ that shouldn't result in a culled document
'__DATA__';

sub after_data {
	return 1;
}
