package Padre::Locale;

# Padre::Locale provides a variety of locale and encoding support functions,
# to prevent locale code (which can be fairly complex) from being scattered
# all over the codebase.
#
# Note: Normally, namespace convention is that modules outside of Padre::Wx
# should not implement anything using Wx modules.
# We make an exception in this case, because we're only using the locale
# logic in Wx, which isn't related to widgets anyway.

use 5.008;
use strict;
use warnings;
use Padre::Util ();
use Padre::Wx   ();

our $VERSION = '0.20';





#####################################################################
# Locale Support

use constant DEFAULT_LOCALE => 'en';

# TODO move it to some better place,
# used in Menu.pm
our %languages = (
	de => Wx::gettext('German'),
	en => Wx::gettext('English'),
	fr => Wx::gettext('French'),
	he => Wx::gettext('Hebrew'),
	hu => Wx::gettext('Hungarian'),
	ko => Wx::gettext('Korean'),
	it => Wx::gettext('Italian'),
	ru => Wx::gettext('Russian')
);

my %shortname_of = (
	Wx::wxLANGUAGE_GERMAN()     => 'de',
	Wx::wxLANGUAGE_ENGLISH_US() => 'en',
	Wx::wxLANGUAGE_FRENCH()     => 'fr',
	Wx::wxLANGUAGE_HEBREW()     => 'he',
	Wx::wxLANGUAGE_HUNGARIAN()  => 'hu',
	Wx::wxLANGUAGE_ITALIAN()    => 'it',
	Wx::wxLANGUAGE_KOREAN()     => 'ko',
	Wx::wxLANGUAGE_RUSSIAN()    => 'ru',
);

my %number_of = reverse %shortname_of;

sub shortname {
	my $config    = Padre->ide->config;
	my $shortname = $config->{host}->{locale};
	unless ( $shortname ) {
		$shortname = $shortname_of{ Wx::Locale::GetSystemLanguage };
	}
	unless ( $shortname ) {
		$shortname = DEFAULT_LOCALE ;
	}
	return $shortname;
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
	elsif ( Padre::Util::UNIX ) {
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

	my $encoding;
	my $system_default = ();
	my @guess_list     = ();
	my $lang_shortname = shortname();
	if ($lang_shortname eq 'ko') {      # Korean
		@guess_list = qw/utf-8 euc-kr/;
	} elsif ($lang_shortname eq 'ja') { # Japan (not yet tested)
		@guess_list = qw/utf-8 iso8859-1 euc-jp shiftjis 7bit-jis/;
	} elsif ($lang_shortname eq 'cn') { # Chinese (not yet tested)
		@guess_list = qw/utf-8 iso8859-1 euc-cn/;
	} else {
		$system_default ||= encoding_system_default();
		@guess_list = ( $system_default ) if $system_default;
	}

	require Encode::Guess;
	my $guess = Encode::Guess::guess_encoding($content, @guess_list);
	if (not defined $guess) {
		$guess = ''; # to avoid warnings
	}
	if ( ref($guess) and ref($guess) =~ m/^Encode::/ ) {       # Wow, nice!
		$encoding = $guess->name;
	} elsif ($guess =~ m/utf8/) {            # utf-8 is in suggestion
		$encoding = 'utf-8';
	} elsif ($guess =~ m/or/) {              # choose from suggestion
		my @suggest_encodings = split /\sor\s/, "$guess";
		$encoding = $suggest_encodings[0];
	}
	else {                                 # use system default
		$system_default ||= encoding_system_default();
		$encoding = $system_default;
	}

	if (!$encoding) {
		# fail to guess encoding from contents
		warn "Could not find encoding. Defaulting to 'utf-8'. "
			. "Please check it manually and report to the Padre development team.";
		$encoding = 'utf-8';
	}

	return $encoding;
}

1;
