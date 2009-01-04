package Padre::Locale;

=pod

=head1 NAME

Padre::Locale - Locale support for Padre

=head1 DESCRIPTION

B<Padre::Locale> is a utility library that implements locale and encoding
support for the L<Padre> editor, and serves as an integration point between
the various identifier systems (Wx identifiers, ISO639, RFC3066, RFC4646)

The module implements a collection of public functions that can be called
by various parts of the editor to get locale and encoding information.

None of the functions in B<Padre::Locale> are exported. Because the need
for encoding and locale functionality is very high in a user-facing
application like Padre, the resulting quantity of exports would be very
very high.

Forcing all calls to the functions to be fully referenced assists in
reducing the complexity of the Perl symbol table (saving a small amount of
memory) and serves to improve maintainability, as there can always be
certainty about where a particular function is being called from.

=head1 FUNCTIONS

TO BE COMPLETED

=cut

use 5.008;
use strict;
use warnings;

# NOTE: Normally, namespace convention is that modules outside of Padre::Wx
# should not implement anything using Wx modules.
# We make an exception in this case, because we're only using the locale
# logic in Wx, which isn't related to widgets anyway.
use Padre::Util ();
use Padre::Wx   ();

our $VERSION = '0.23';





#####################################################################
# Locale 2.0 Tables

use constant RFC4646_DEFAULT => 'en-gb';

# The RFC4646 table is the primary language data table and contains
# mappings from a Padre-supported language to all the relevant data
# about that language.
# According to the RFC all identifiers are case-insensitive, but for
# simplicity (for now) we list them all as lower-case.
my %RFC4646 = (
	# The default language for Padre is "United Kingdom English"
	# The most common English dialect, used not only in the UK,
	# but also other Commonwealth countries such as Australia,
	# New Zealand, India, and Canada (sort of...)
	# The following entry for it is heavily commented for
	# documentation purposes.
	'en-gb' => {
		# REQUIRED: The gettext msgid for the language.
		gettext   => 'English (British)',

		# REQUIRED: Mapping to ISO 639 language tag.
		# Used by Padre's first-generation locale support
		# This should be lowercase.
		iso639    => 'en',

		# OPTIONAL: Mapping to the ISO 3166 country code.
		# This should be uppercase.
		iso3166   => 'GB',

		# REQUIRED: The wxWidgets language (integer) identifier.
		# http://docs.wxwidgets.org/stable/wx_languagecodes.html#languagecodes
		wxid      => Wx::wxLANGUAGE_ENGLISH_UK,

		# OPTIONAL: The wxWidgets catalog file to use.
		# Having this as an explicit file name simplified the
		# transition from the old to the new style.
		wxcatalog => 'en.mo',

		# OPTIONAL: Recommended language fallback sequence.
		# This is an ordered list of alternative languages
		# that Padre should try to use if no first-class
		# support is available for this language.
		# This is mainly used to allow closest-dialect support.
		# For example, if full support for "Portugese Portugese"
		# is not available, we first attempt to use
		# "Brazillian Portugese" first, before falling back on
		# "American English" and only then the default.
		# Entries in the fallback list express intent, and
		# they do not need to have an entry in %RFC4646.
		fallback  => [ ],
	},

	# Example entry for an language which is not supported directly,
	# but which Padre is aware of.
	'en-au' => {
		gettext  => 'English (Australian)',
		iso639   => 'en',
		iso3166  => 'AU',
		wxid     => Wx::wxLANGUAGE_ENGLISH_AUSTRALIA,
		# Even though en-gb is the default language, in this
		# specific case there is a clearly expressed desire for
		# this fallback path.
		# If we are ever forced for technical reasons to move to
		# using en-us as a default, this group would explicitly
		# wish to retain the final fallback to en-gb.
		fallback => [ 'en-nz', 'en-gb' ],
	},





	# The official languages are listed sorted by identifier.
	# NOTE: Please do not populate entries into this list unless
	# you are a native speaker of a particular language and are
	# fully aware of any 

	'en-nz' => {
		gettext  => 'English (New Zealand)',
		iso639   => 'en',
		iso3166  => 'NZ',
		wxid     => Wx::wxLANGUAGE_ENGLISH_NEW_ZEALAND,
		fallback => [ 'en-au', 'en-gb' ], # The en-au is debatable
	},

	'en-us' => {
		gettext  => 'English (US)',
		iso639   => 'en',
		iso3166  => 'US',
		wxid     => Wx::wxLANGUAGE_ENGLISH_US,
	},





	# RFC4646 supports the interesting idea of comedy languages.
	# We'll put these at the end :)
	# Mostly what these do is uncover issues that might arise when
	# a language is not supported by various older standards.
	'i-klingon' => {
		gettext  => 'Klingon',
		iso639   => undef,
		iso3166  => undef,
		wxid     => undef,
	},
);





#####################################################################
# Locale 1.0 Support

use constant DEFAULT_LOCALE => 'en';

my %SHORTNAME = (
	Wx::wxLANGUAGE_ARABIC()        => 'ar',
	Wx::wxLANGUAGE_GERMAN()        => 'de',

	# This should be addressed by the fallback system
	Wx::wxLANGUAGE_ENGLISH_US()    => 'en',

	Wx::wxLANGUAGE_FRENCH()        => 'fr',
	Wx::wxLANGUAGE_HEBREW()        => 'he',
	Wx::wxLANGUAGE_HUNGARIAN()     => 'hu',
	Wx::wxLANGUAGE_ITALIAN()       => 'it',
	Wx::wxLANGUAGE_KOREAN()        => 'ko',
	Wx::wxLANGUAGE_RUSSIAN()       => 'ru',
	Wx::wxLANGUAGE_DUTCH()         => 'nl',

	# Probably should be a separate 'pt_br'
	# (With apologies to the Portugese)
	Wx::wxLANGUAGE_PORTUGUESE()    => 'pt',

	Wx::wxLANGUAGE_SPANISH()       => 'es',
);

my %NUMBER = reverse %SHORTNAME;

# The list of languages that should be shown in the language menu
# and the strings that should be used to label them.
sub menu_view_languages {
	ar => Wx::gettext('Arabic'),
	de => Wx::gettext('German'),
	en => Wx::gettext('English'),
	fr => Wx::gettext('French'),
	he => Wx::gettext('Hebrew'),
	hu => Wx::gettext('Hungarian'),
	ko => Wx::gettext('Korean'),
	it => Wx::gettext('Italian'),
	ru => Wx::gettext('Russian'),
	nl => Wx::gettext('Dutch'),
	pt => Wx::gettext('Portuguese'), # Actually brazilian, which is a bug
	es => Wx::gettext('Spanish'),
}

sub shortname {
	my $config    = Padre->ide->config;
	my $shortname = $config->{host}->{locale};
	unless ( $shortname ) {
		$shortname = $SHORTNAME{ Wx::Locale::GetSystemLanguage };
	}
	unless ( $shortname ) {
		$shortname = DEFAULT_LOCALE;
	}
	return $shortname;
}

sub object {
	my $shortname = shortname();
	my $lang      = $NUMBER{$shortname};
	my $locale    = Wx::Locale->new($lang);
	$locale->AddCatalogLookupPathPrefix(
		Padre::Util::sharedir('locale')
	);
	unless ( $locale->IsLoaded($shortname) ) {
		my $filename = Padre::Util::sharefile( 'locale', $shortname ) . '.mo';
		$locale->AddCatalog($shortname) if -f $filename;
	}
	return $locale;
}





#####################################################################
# Encoding Support

sub encoding_system_default {
	my $encoding;
	if ( Padre::Util::MAC ) {
		# In mac system Wx::locale::GetSystemEncodingName() couldn't
		# return the name of encoding directly.
		# Use LC_CTYPE to guess system default encoding.
		require POSIX;
		my $loc = POSIX::setlocale(POSIX::LC_CTYPE());
		if ( $loc =~ m/^(C|POSIX)/i ) {
			$encoding = 'ascii';
		}
		elsif ( $loc =~ /\./ ) {
			my ($language, $codeset) = split /\./, $loc;
			$encoding = $codeset;
		}
	}
	elsif ( Padre::Util::WIN32 ) {
		# In windows system Wx::locale::GetSystemEncodingName() returns
		# like ``windows-1257'' and it matches as ``cp1257''
		# refer to src/common/intl.cpp
		$encoding = Wx::Locale::GetSystemEncodingName();
		$encoding =~ s/^windows-/cp/i;
	}
	elsif ( Padre::Util::LINUX ) {
		$encoding = Wx::Locale::GetSystemEncodingName();
		if (!$encoding) {
			# this is not a usual case, but...
			require POSIX;
			my $loc = POSIX::setlocale(POSIX::LC_CTYPE());
			if ($loc =~ m/^(C|POSIX)/i) {
				$encoding = 'ascii';
			}
			elsif ($loc =~ /\./) {
				my ($language, $codeset) = split /\./, $loc;
				$encoding = $codeset;
			}
		}
	}
	else {
		$encoding = Wx::Locale::GetSystemEncodingName();
	}

	if (!$encoding) {
		# fail to get system default encoding
		warn "Could not find system($^O) default encoding. "
			. "Please check it manually and report your environment to the Padre development team.";
		return;
	}

	return $encoding;
}

sub encoding_from_string {
	my ($content) = @_;

	#
	# FIXME
	# This is a just heuristic approach. Maybe there is a better way. :)
	# Japanese and Chinese have to be tested. Only Korean is tested.
	#
	# If locale of config is one of CJK, then we could guess more correctly.
	# Any type of locale which is supported by Encode::Guess could be added.
	# Or, we'll use system default encode setting
	# If we cannot get system default, then forced it to set 'utf-8'
	#
	my $default  = '';
	my @guess    = ();
	my $encoding = '';
	my $lang_shortname = shortname();
	if ($lang_shortname eq 'ko') {      # Korean
		@guess = qw/utf-8 euc-kr/;
	} elsif ($lang_shortname eq 'ja') { # Japan (not yet tested)
		@guess = qw/utf-8 iso8859-1 euc-jp shiftjis 7bit-jis/;
	} elsif ($lang_shortname eq 'cn') { # Chinese (not yet tested)
		@guess = qw/utf-8 iso8859-1 euc-cn/;
	} else {
		$default ||= encoding_system_default();
		@guess = ( $default ) if $default;
	}

	require Encode::Guess;
	my $guess = Encode::Guess::guess_encoding($content, @guess);
	unless ( defined $guess ) {
		$guess = ''; # to avoid warnings
	}

	# Wow, nice!
	if ( ref($guess) and ref($guess) =~ m/^Encode::/ ) {
		$encoding = $guess->name;

	# utf-8 is in suggestion
	} elsif ($guess =~ m/utf8/) {
		$encoding = 'utf-8';

	# Choose from suggestion
	} elsif ($guess =~ m/or/) {
		my @suggest_encodings = split /\sor\s/, "$guess";
		$encoding = $suggest_encodings[0];

	# Use system default
	} else {
		$default ||= encoding_system_default();
		$encoding = $default;
	}

	unless ( $encoding ) {
		# Failed to guess encoding from contents
		warn "Could not find encoding. Defaulting to 'utf-8'. "
			. "Please check it manually and report to the Padre development team.";
		$encoding = 'utf-8';
	}

	return $encoding;
}

1;
