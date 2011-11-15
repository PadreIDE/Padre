package Padre::Wx::Scintilla;

# Basic scintilla integration layer, tracks registration of
# lexers and syntax highlighting.

use 5.008;
use Padre::Config           ();
use Padre::DB               ();
use Padre::MimeTypes        ();
use Wx::Scintilla::Constant ();
use Wx::Scintilla           ();

# Current highlighter for each type
my %HIGHLIGHTER = ();

# Highlighters preferences defined in Padre's configuration system
my %CONFIG = (
	'application/x-perl' => 'lang_perl5_lexer',
);




######################################################################
# Lexer Management





######################################################################
# Highlighter Management

sub load_highlighter_config {
	# Default everything to stc to start
	my $all = Padre::MimeTypes->get_mime_types;
	foreach my $mime ( @$all ) {
		$HIGHLIGHTER{$mime} = 'stc';
	}

	# Overlay database-stored preferences
	my $rows = Padre::DB::SyntaxHighlight->select || [];
	foreach my $row ( @$rows ) {
		my $mime = $row->mime_type;
		next unless $HIGHLIGHTER{$mime};
		$HIGHLIGHTER{$mime} = $row->value;
	}

	# Overlay with settings that have been moved from the database
	# to the Padre::Config system.
	my $config = Padre::Config->read;
	foreach my $type ( keys %CONFIG ) {
		my $method = $CONFIG{$type};
		$MIME{$type}->{current_highlighter} = $config->$method();
	}

	return 1;
}

1;
