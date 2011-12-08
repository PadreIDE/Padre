package Padre::Wx::Scintilla;

# Utility package for integrating Wx::Scintilla with Padre

use 5.008;
use strict;
use warnings;
use Params::Util            ();
use Class::Inspector        ();
use Padre::Config           ();
use Padre::MIME             ();
use Wx::Scintilla::Constant ();
use Padre::Locale::T;

our $VERSION    = '0.93';
our $COMPATIBLE = '0.93';





######################################################################
# Syntax Highlighters

# Supported non-Scintilla colourising modules
my %MODULE = (
	'Padre::Document::Perl::Lexer' => {
		name => _T('PPI Experimental'),
		mime => {
			'application/x-perl' => 1,
		}
	},
	'Padre::Document::Perl::PPILexer' => {
		name => _T('PPI Standard'),
		mime => {
			'application/x-perl' => 1,
		}
	},
);

# Current highlighter for each mime type
my %HIGHLIGHTER = (
	'application/x-perl' => Padre::Config->read->lang_perl5_lexer,
);

sub highlighter {
	my $type = _TYPE($_[1]);
	return $HIGHLIGHTER{$type};
}

sub add_highlighter {
	my $class  = shift;
	my $module = shift;
	my $params = shift;

	# Check the highlighter params
	unless ( Class::Inspector->installed($module) ) {
		die "Missing or invalid highlighter $module";
	}
	if ( $MODULE{$module} ) {
		die "Duplicate highlighter registration $module";
	}
	unless ( Params::Util::_HASH($params) ) {
		die "Missing or invalid highlighter params";
	}
	unless ( defined Params::Util::_STRING($params->{name}) ) {
		die "Missing or invalid highlighter name";
	}
	unless ( Params::Util::_ARRAY($params->{mime}) ) {
		die "Missing or invalid highlighter mime list";
	}

	# Register the highlighter module
	my %mime = map { $_ => 1 } @{$params->{mime}};
	$MODULE{$module} = {
		name => $params->{name},
		mime => \%mime,
	};

	# Bind the mime types to the highlighter
	foreach my $mime ( keys %mime ) {
		$HIGHLIGHTER{$mime} = $module;
	}

	return 1;
}

sub remove_highlighter {
	my $class  = shift;
	my $module = shift;

	# Unregister the highlighter module
	my $deleted = delete $MODULE{$module} or return;

	# Unbind the mime types for the highlighter
	foreach my $mime ( keys %HIGHLIGHTER ) {
		next unless $HIGHLIGHTER{$mime} eq $module;
		delete $HIGHLIGHTER{$mime};
	}

	return 1;
}





######################################################################
# Content Lexers

my %LEXER = (
	'text/x-abc'                => Wx::Scintilla::Constant::SCLEX_NULL,
	'text/x-actionscript'       => Wx::Scintilla::Constant::SCLEX_CPP,
	'text/x-adasrc'             => Wx::Scintilla::Constant::SCLEX_ADA,       # CONFIRMED
	'text/x-asm'                => Wx::Scintilla::Constant::SCLEX_ASM,       # CONFIRMED
	'application/x-bibtex'      => Wx::Scintilla::Constant::SCLEX_NULL,
	'application/x-bml'         => Wx::Scintilla::Constant::SCLEX_NULL,
	'text/x-bat'                => Wx::Scintilla::Constant::SCLEX_BATCH,     # CONFIRMED
	'text/x-csrc'               => Wx::Scintilla::Constant::SCLEX_CPP,       # CONFIRMED
	'text/x-cobol'              => Wx::Scintilla::Constant::SCLEX_COBOL,     # CONFIRMED 
	'text/x-c++src'             => Wx::Scintilla::Constant::SCLEX_CPP,       # CONFIRMED
	'text/css'                  => Wx::Scintilla::Constant::SCLEX_CSS,       # CONFIRMED
	'text/x-eiffel'             => Wx::Scintilla::Constant::SCLEX_EIFFEL,    # CONFIRMED
	'text/x-forth'              => Wx::Scintilla::Constant::SCLEX_FORTH,     # CONFIRMED
	'text/x-fortran'            => Wx::Scintilla::Constant::SCLEX_FORTRAN,   # CONFIRMED
	'text/x-haskell'            => Wx::Scintilla::Constant::SCLEX_HASKELL,   # CONFIRMED
	'text/html'                 => Wx::Scintilla::Constant::SCLEX_HTML,      # CONFIRMED
	'application/javascript'    => Wx::Scintilla::Constant::SCLEX_ESCRIPT,   # CONFIRMED
	'application/json'          => Wx::Scintilla::Constant::SCLEX_ESCRIPT,   # CONFIRMED
	'application/x-latex'       => Wx::Scintilla::Constant::SCLEX_LATEX,     # CONFIRMED
	'application/x-lisp'        => Wx::Scintilla::Constant::SCLEX_LISP,      # CONFIRMED
	'text/x-patch'              => Wx::Scintilla::Constant::SCLEX_DIFF,      # CONFIRMED
	'application/x-shellscript' => Wx::Scintilla::Constant::SCLEX_BASH,
	'text/x-java'               => Wx::Scintilla::Constant::SCLEX_CPP,       # CONFIRMED
	'text/x-lua'                => Wx::Scintilla::Constant::SCLEX_LUA,       # CONFIRMED
	'text/x-makefile'           => Wx::Scintilla::Constant::SCLEX_MAKEFILE,  # CONFIRMED
	'text/x-matlab'             => Wx::Scintilla::Constant::SCLEX_MATLAB,    # CONFIRMED
	'text/x-pascal'             => Wx::Scintilla::Constant::SCLEX_PASCAL,    # CONFIRMED
	'application/x-perl'        => Wx::Scintilla::Constant::SCLEX_PERL,      # CONFIRMED
	'text/x-povray'             => Wx::Scintilla::Constant::SCLEX_POV,
	'application/x-psgi'        => Wx::Scintilla::Constant::SCLEX_PERL,      # CONFIRMED
	'text/x-python'             => Wx::Scintilla::Constant::SCLEX_PYTHON,    # CONFIRMED
	'application/x-php'         => Wx::Scintilla::Constant::SCLEX_PHPSCRIPT, # CONFIRMED
	'application/x-ruby'        => Wx::Scintilla::Constant::SCLEX_RUBY,      # CONFIRMED
	'text/x-sql'                => Wx::Scintilla::Constant::SCLEX_SQL,       # CONFIRMED
	'application/x-tcl'         => Wx::Scintilla::Constant::SCLEX_TCL,       # CONFIRMED
	'text/vbscript'             => Wx::Scintilla::Constant::SCLEX_VBSCRIPT,  # CONFIRMED
	'text/x-config'             => Wx::Scintilla::Constant::SCLEX_CONF,
	'text/xml'                  => Wx::Scintilla::Constant::SCLEX_XML,       # CONFIRMED
	'text/x-yaml'               => Wx::Scintilla::Constant::SCLEX_YAML,      # CONFIRMED
	'application/x-pir'         => Wx::Scintilla::Constant::SCLEX_NULL,      # CONFIRMED
	'application/x-pasm'        => Wx::Scintilla::Constant::SCLEX_NULL,      # CONFIRMED
	'application/x-perl6'       => 102, # TODO Wx::Scintilla::Constant::PERL_6
	'text/plain'                => Wx::Scintilla::Constant::SCLEX_NULL,      # CONFIRMED
	# for the lack of a better XS lexer (vim?)
	'text/x-perlxs'             => Wx::Scintilla::Constant::SCLEX_CPP,
	'text/x-perltt'             => Wx::Scintilla::Constant::SCLEX_HTML,
	'text/x-csharp'             => Wx::Scintilla::Constant::SCLEX_CPP,
	'text/x-pod'                => Wx::Scintilla::Constant::SCLEX_PERL,
);

# Must ALWAYS return a valid lexer (defaulting to AUTOMATIC as a last resort)
sub lexer {
	my $type = _TYPE($_[1]);
	return Wx::Scintilla::Constant::SCLEX_AUTOMATIC unless $type;
	return Wx::Scintilla::Constant::SCLEX_CONTAINER if $HIGHLIGHTER{$type};
	return Wx::Scintilla::Constant::SCLEX_AUTOMATIC unless $LEXER{$type};
	return $LEXER{$type};
}





######################################################################
# Key Words

# Take mostly from src/scite/src/ properties files
my %KEYWORDS = ();

# Ada keyword list is obtained from src/scite/src/ada.properties
$KEYWORDS{'text/x-adasrc'} = [
	[
		# Ada keywords
		qw{
			abort abstract accept access aliased all array at begin body
			case constant declare delay delta digits do else elsif end entry exception exit for
			function generic goto if in is limited loop new null of others out package 
			pragma private procedure protected raise range record renames requeue return reverse
			select separate subtype tagged task terminate then type until use when while with
		},

		# Ada Operators
		qw{abs and mod not or rem xor},
	],
];

# COBOL keyword list is obtained from src/scite/src/cobol.properties
$KEYWORDS{'text/x-cobol'} = [
	[ qw{
		configuration data declaratives division environment
		environment-division file file-control function i-o i-o-control
		identification input input-output linkage local-storage output procedure
		program program-id receive-control section special-names working-storage
	} ],
	[ qw{
		accept add alter apply assign call chain close compute continue
		control convert copy count delete display divide draw drop eject else
		enable end-accept end-add end-call end-chain end-compute end-delete
		end-display end-divide end-evaluate end-if end-invoke end-multiply
		end-perform end-read end-receive end-return end-rewrite end-search
		end-start end-string end-subtract end-unstring end-write erase evaluate
		examine exec execute exit go goback generate if ignore initialize
		initiate insert inspect invoke leave merge move multiply open otherwise
		perform print read receive release reload replace report reread rerun
		reserve reset return rewind rewrite rollback run search seek select send
		set sort start stop store string subtract sum suppress terminate then
		transform unlock unstring update use wait when wrap write
	} ],
	[ qw{
		access acquire actual address advancing after all allowing
		alphabet alphabetic alphabetic-lower alphabetic-upper alphanumeric
		alphanumeric-edited also alternate and any are area areas as ascending at
		attribute author auto auto-hyphen-skip auto-skip automatic autoterminate
		background-color background-colour backward basis beep before beginning
		bell binary blank blink blinking block bold bottom box boxed by c01 c02
		c03 c04 c05 c06 c07 c08 c09 c10 c11 c12 cancel cbl cd centered cf ch
		chaining changed character characters chart class clock-units cobol code
		code-set col collating color colour column com-reg comma command-line
		commit commitment common communication comp comp-0 comp-1 comp-2 comp-3
		comp-4 comp-5 comp-6 comp-x compression computational computational-1
		computational-2 computational-3 computational-4 computational-5
		computational-6 computational-x computational console contains content
		control-area controls conversion converting core-index corr corresponding
		crt crt-under csp currency current-date cursor cycle cyl-index
		cyl-overflow date date-compiled date-written day day-of-week dbcs de
		debug debug-contents debug-item debug-line debug-name debug-sub-1
		debug-sub-2 debug-sub-3 debugging decimal-point default delimited
		delimiter depending descending destination detail disable disk disp
		display-1 display-st down duplicates dynamic echo egcs egi emi
		empty-check encryption end end-of-page ending enter entry eol eop eos
		equal equals error escape esi every exceeds exception excess-3 exclusive
		exhibit extend extended-search external externally-described-key factory
		false fd fh--fcd fh--keydef file-id file-limit file-limits file-prefix
		filler final first fixed footing for foreground-color foreground-colour
		footing format from full giving global greater grid group heading high
		high-value high-values highlight id in index indexed indic indicate
		indicator indicators inheriting initial installation into invalid invoked
		is japanese just justified kanji kept key keyboard label last leading
		left left-justify leftline length length-check less limit limits lin
		linage linage-counter line line-counter lines lock lock-holding locking
		low low-value low-values lower lowlight manual mass-update master-index
		memory message method mode modified modules more-labels multiple name
		named national national-edited native nchar negative next no no-echo
		nominal not note nstd-reels null nulls number numeric numeric-edited
		numeric-fill o-fill object object-computer object-storage occurs of off
		omitted on oostackptr optional or order organization other others
		overflow overline packed-decimal padding page page-counter packed-decimal
		paragraph password pf ph pic picture plus pointer pop-up pos position
		positioning positive previous print-control print-switch printer
		printer-1 printing prior private procedure-pointer procedures proceed
		process processing prompt protected public purge queue quote quotes
		random range rd readers ready record record-overflow recording records
		redefines reel reference references relative remainder remarks removal
		renames reorg-criteria repeated replacing reporting reports required
		resident return-code returning reverse reverse-video reversed rf rh right
		right-justify rolling rounded s01 s02 s03 s04 s05 same screen scroll sd
		secure security segment segment-limit selective self selfclass sentence
		separate sequence sequential service setshadow shift-in shift-out sign
		size skip1 skip2 skip3 sort-control sort-core-size sort-file-size
		sort-merge sort-message sort-mode-size sort-option sort-return source
		source-computer space spaces space-fill spaces standard standard-1
		standard-2 starting status sub-queue-1 sub-queue-2 sub-queue-3 subfile
		super symbolic sync synchronized sysin sysipt syslst sysout syspch
		syspunch system-info tab tallying tape terminal terminal-info test text
		than through thru time time-of-day time-out timeout times title to top
		totaled totaling trace track-area track-limit tracks trailing
		trailing-sign transaction true type typedef underline underlined unequal
		unit until up updaters upon upper upsi-0 upsi-1 upsi-2 upsi-3 upsi-4
		upsi-5 upsi-6 upsi-7 usage user using value values variable varying
		when-compiled window with words write-only write-verify writerszero zero
		zero-fill zeros zeroes
	} ],
];

# C/C++ keyword list is obtained from src/scite/src/cpp.properties
$KEYWORDS{'text/x-csrc'} = [
	[ qw{
		and and_eq asm auto bitand bitor bool break
		case catch char class compl const const_cast continue
		default delete do double dynamic_cast else enum explicit
		export extern false float for friend goto if inline int long
		mutable namespace new not not_eq operator or or_eq private
		protected public register reinterpret_cast return short
		signed sizeof static static_cast struct switch template this
		throw true try typedef typeid typename union unsigned using
		virtual void volatile wchar_t while xor xor_eq
	} ]
];

$KEYWORDS{'application/php'} = [
	[ qw{
		and array as bool boolean break case cfunction class const
		continue declare default die directory do double echo else
		elseif empty enddeclare endfor endforeach endif endswitch
		endwhile eval exit extends false float for foreach function
		global goto if include include_once int integer isset list
		namespace new null object old_function or parent print real
		require require_once resource return static stdclass string
		switch true unset use var while xor abstract catch clone
		exception final implements interface php_user_filter private
		protected public this throw try __class__ __dir__ __file__
		__function__ __line__ __method__ __namespace__ __sleep
		__wakeup
	} ],
];

$KEYWORDS{'application/javascript'} = [
	[ qw{
		abstract boolean break byte case catch char class
		const continue debugger default delete do double else enum
		export extends final finally float for function goto if
		implements import in instanceof int interface long native
		new package private protected public return short static
		super switch synchronized this throw throws transient try
		typeof var void volatile while with
	} ],
];

# YAML keyword list is obtained from src/scite/src/yaml.properties
$KEYWORDS{'text/x-yaml'} = [
	[ qw{
		true false yes no
	} ],
];

sub keywords {
	my $mime = _MIME($_[1]);
	foreach my $type ( $mime->superpath ) {
		next unless $KEYWORDS{$type};
		return $KEYWORDS{$type};
	}
	return;
}





######################################################################
# Support Functions

sub _MIME {
	my $it = shift;
	if ( Params::Util::_INSTANCE($it, 'Padre::Document') ) {
		$it = $it->mime;
	}
	if ( Params::Util::_INSTANCE($it, 'Padre::MIME') ) {
		return $it;
	}
	return Padre::MIME->find($it);
}
	
sub _TYPE {
	my $it = shift;
	if ( Params::Util::_INSTANCE($it, 'Padre::Document') ) {
		$it = $it->mime;
	}
	if ( Params::Util::_INSTANCE($it, 'Padre::MIME') ) {
		$it = $it->type;
	}
	return $it || '';
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
