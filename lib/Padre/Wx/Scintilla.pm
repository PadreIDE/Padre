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

our $VERSION    = '0.94';
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
	my $mime = _MIME($_[1]);
	foreach my $type ( $mime->superpath ) {
		return $HIGHLIGHTER{$type} if $HIGHLIGHTER{$type};
	}
	return '';
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
	'application/x-r'           => Wx::Scintilla::Constant::SCLEX_R,         # CONFIRMED
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
	my $mime = _MIME($_[1]);
	return Wx::Scintilla::Constant::SCLEX_AUTOMATIC unless $mime->type;

	# Search the mime type super path for a lexer
	foreach my $type ( $mime->superpath ) {
		if ( $HIGHLIGHTER{$type} ) {
			return Wx::Scintilla::Constant::SCLEX_CONTAINER;
		}
		return $LEXER{$type} if $LEXER{$type};
	}

	# Fall through to Scintilla's autodetection
	return Wx::Scintilla::Constant::SCLEX_AUTOMATIC;
}





######################################################################
# Key Words

# Taken mostly from src/scite/src/ properties files.
# Keyword lists are defined here in MIME type order
my %KEYWORDS = ();

# Support for the unknown mime type
$KEYWORDS{''} = [ ];

$KEYWORDS{'application/php'} = [
	q{
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
	},
];

$KEYWORDS{'application/javascript'} = [
	q{
		abstract boolean break byte case catch char class
		const continue debugger default delete do double else enum
		export extends final finally float for function goto if
		implements import in instanceof int interface long native
		new package private protected public return short static
		super switch synchronized this throw throws transient try
		typeof var void volatile while with
	},
];

# Inspired from Perl 6 vim syntax file
# https://github.com/petdance/vim-perl/blob/master/syntax/perl6.vim
$KEYWORDS{'application/x-perl6'} = [
	join( '', 

		# Perl 6 routine declaration keywords
		q{macro sub submethod method multi proto only rule token regex category},

		# Perl 6 module keywords
		q{module class role package enum grammar slang subset},

		# Perl 6 variable keywords
		q{self},

		# Perl 6 include keywords
		q{use require},

		# Perl 6 conditional keywords
		q{if else elsif unless},

		# Perl 6 variable storage keywords
		q{let my our state temp has constant},

		# Perl 6 repeat keywords
		q{for loop repeat while until gather given},

		# Perl flow control keywords
		q{take do when next last redo return contend maybe defer
			default exit make continue break goto leave async lift},

		# Perl 6 type constraints keywords
		q{is as but trusts of returns handles where augment supersede},

		# Perl 6 closure traits keywords
		q{BEGIN CHECK INIT START FIRST ENTER LEAVE KEEP
			UNDO NEXT LAST PRE POST END CATCH CONTROL TEMP},

		# Perl 6 exception keywords
		q{die fail try warn},

		# Perl 6 property keywords
		q{prec irs ofs ors export deep binary unary reparsed rw parsed cached
			readonly defequiv will ref copy inline tighter looser equiv assoc
			required},

		# Perl 6 number keywords
		q{NaN Inf},

		# Perl 6 pragma keywords
		q{oo fatal},

		# Perl 6 type keywords
		q{Object Any Junction Whatever Capture Match
			Signature Proxy Matcher Package Module Class
			Grammar Scalar Array Hash KeyHash KeySet KeyBag
			Pair List Seq Range Set Bag Mapping Void Undef
			Failure Exception Code Block Routine Sub Macro
			Method Submethod Regex Str Blob Char Byte
			Codepoint Grapheme StrPos StrLen Version Num
			Complex num complex Bit bit bool True False
			Increasing Decreasing Ordered Callable AnyChar
			Positional Associative Ordering KeyExtractor
			Comparator OrderingPair IO KitchenSink Role
			Int int int1 int2 int4 int8 int16 int32 int64
			Rat rat rat1 rat2 rat4 rat8 rat16 rat32 rat64
			Buf buf buf1 buf2 buf4 buf8 buf16 buf32 buf64
			UInt uint uint1 uint2 uint4 uint8 uint16 uint32
			uint64 Abstraction utf8 utf16 utf32},

		# Perl 6 operator keywords
		q{div x xx mod also leg cmp before after eq ne le lt
			gt ge eqv ff fff and andthen Z X or xor
			orelse extra m mm rx s tr},
	)
];

# Ruby keywords
# The list is obtained from src/scite/src/ruby.properties
$KEYWORDS{'application/x-ruby'} = [
	q{
			__FILE__ and def end in or self unless __LINE__ begin defined?
			ensure module redo super until BEGIN break do false next rescue
			then when END case else for nil retry true while alias class
			elsif if not return undef yield
			}
	
];

# VB keyword list is obtained from src/scite/src/vb.properties
$KEYWORDS{'text/vbscript'} = [
	q{
		addressof alias and as attribute base begin binary
		boolean byref byte byval call case cdbl cint clng compare const csng cstr currency
		date decimal declare defbool defbyte defcur
		defdate defdbl defdec defint deflng defobj defsng defstr defvar dim do double each else
		elseif empty end enum eqv erase error event exit explicit false for friend function get
		global gosub goto if imp implements in input integer is len let lib like load lock long
		loop lset me mid midb mod new next not nothing null object on option optional or paramarray
		preserve print private property public raiseevent randomize redim rem resume return rset
		seek select set single static step stop string sub text then time to true type typeof
		unload until variant wend while with withevents xor
	},
];

# ActionScript keyword list is obtained from src/scite/src/cpp.properties
$KEYWORDS{'text/x-actionscript'} = [
	q{
		add and break case catch class continue default delete do
		dynamic else eq extends false finally for function ge get gt if implements import in
		instanceof interface intrinsic le lt ne new not null or private public return
		set static super switch this throw true try typeof undefined var void while with
		}
	,
	q{
		Array Arguments Accessibility Boolean Button Camera Color
		ContextMenu ContextMenuItem Date Error Function Key LoadVars LocalConnection Math
		Microphone Mouse MovieClip MovieClipLoader NetConnection NetStream Number Object
		PrintJob Selection SharedObject Sound Stage String StyleSheet System TextField
		TextFormat TextSnapshot Video Void XML XMLNode XMLSocket
		_accProps _focusrect _global _highquality _parent _quality _root _soundbuftime
		arguments asfunction call capabilities chr clearInterval duplicateMovieClip
		escape eval fscommand getProperty getTimer getURL getVersion gotoAndPlay gotoAndStop
		ifFrameLoaded Infinity -Infinity int isFinite isNaN length loadMovie loadMovieNum
		loadVariables loadVariablesNum maxscroll mbchr mblength mbord mbsubstring MMExecute
		NaN newline nextFrame nextScene on onClipEvent onUpdate ord parseFloat parseInt play
		prevFrame prevScene print printAsBitmap printAsBitmapNum printNum random removeMovieClip
		scroll set setInterval setProperty startDrag stop stopAllSounds stopDrag substring
		targetPath tellTarget toggleHighQuality trace unescape unloadMovie unLoadMovieNum updateAfterEvent
		}
	,
];

# Ada keyword list is obtained from src/scite/src/ada.properties
$KEYWORDS{'text/x-adasrc'} = [

	# Ada keywords
	q{
		abort abstract accept access aliased all array at begin body
		case constant declare delay delta digits do else elsif end entry exception exit for
		function generic goto if in is limited loop new null of others out package
		pragma private procedure protected raise range record renames requeue return reverse
		select separate subtype tagged task terminate then type until use when while with
	} .

	# Ada Operators
	q{abs and mod not or rem xor},
];

$KEYWORDS{'text/x-csharp'} = [
	# C# keywords
	q{
		abstract as base bool break by byte case catch char
		checked class const continue decimal default delegate
		do double else enum equals event explicit extern
		false finally fixed float for foreach goto if
		implicit in int interface internal into is lock long
		namespace new null object on operator out override
		params private protected public readonly ref return sbyte
		sealed short sizeof stackalloc static string struct
		switch this throw true try typeof uint ulong unchecked unsafe
		ushort using virtual void volatile while
	} .

	# C# contextual keywords
	q{
		add alias ascending descending dynamic from
		get global group into join let orderby partial
		remove select set value var where yield
	}
];

# COBOL keyword list is obtained from src/scite/src/cobol.properties
$KEYWORDS{'text/x-cobol'} = [
	q{
		configuration data declaratives division environment
		environment-division file file-control function i-o i-o-control
		identification input input-output linkage local-storage output procedure
		program program-id receive-control section special-names working-storage
	},
	q{
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
	},
	q{
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
	},
];

# C/C++ keyword list is obtained from src/scite/src/cpp.properties
$KEYWORDS{'text/x-csrc'} = [
	q{
		and and_eq asm auto bitand bitor bool break
		case catch char class compl const const_cast continue
		default delete do double dynamic_cast else enum explicit
		export extern false float for friend goto if inline int long
		mutable namespace new not not_eq operator or or_eq private
		protected public register reinterpret_cast return short
		signed sizeof static static_cast struct switch template this
		throw true try typedef typeid typename union unsigned using
		virtual void volatile wchar_t while xor xor_eq
	}
];

# Haskell keyword list is obtained from src/scite/src/haskell.properties
$KEYWORDS{'text/x-haskell'} = [
	# Haskell 98
	q{case class data default deriving do else hiding if
		import in infix infixl infixr instance let module
		newtype of then type where forall foreign
		}
	,
	

		# Haskell Foreign Function Interface (FFI) (
		q{export label dynamic safe threadsafe unsafe stdcall ccall prim}
	,
];

# Java keyword list is obtained from src/scite/src/cpp.properties
$KEYWORDS{'text/x-java'} = [
	q{
		abstract assert boolean break byte case catch char class
		const continue default do double else enum extends final
		finally float for goto if implements import instanceof int
		interface long native new package private protected public
		return short static strictfp super switch synchronized this
		throw throws transient try var void volatile while
	}
];

# Pascal keyword list is obtained from src/scite/src/pascal.properties
$KEYWORDS{'text/x-pascal'} = [
		# Pascal keywords
		q{absolute abstract and array as asm assembler automated begin case
			cdecl class const constructor deprecated destructor dispid dispinterface div do downto
			dynamic else end except export exports external far file final finalization finally for
			forward function goto if implementation in inherited initialization inline interface is
			label library message mod near nil not object of on or out overload override packed
			pascal platform private procedure program property protected public published raise
			record register reintroduce repeat resourcestring safecall sealed set shl shr static
			stdcall strict string then threadvar to try type unit unsafe until uses var varargs
			virtual while with xor
			} .

		# Smart pascal highlighting
		q{add default implements index name nodefault read readonly
			remove stored write writeonly} .

		# Pascal package
		#TODO only package dpk should get this list
		q{package contains requires},
];

$KEYWORDS{'application/x-perl'} = [
	# Perl Keywords
	q{
		NULL __FILE__ __LINE__ __PACKAGE__ __DATA__ __END__ AUTOLOAD
		BEGIN CORE DESTROY END EQ GE GT INIT LE LT NE CHECK abs accept
		alarm and atan2 bind binmode bless caller chdir chmod chomp chop
		chown chr chroot close closedir cmp connect continue cos crypt
		dbmclose dbmopen defined delete die do dump each else elsif endgrent
		endhostent endnetent endprotoent endpwent endservent eof eq eval
		exec exists exit exp fcntl fileno flock for foreach fork format
		formline ge getc getgrent getgrgid getgrnam gethostbyaddr gethostbyname
		gethostent getlogin getnetbyaddr getnetbyname getnetent getpeername
		getpgrp getppid getpriority getprotobyname getprotobynumber getprotoent
		getpwent getpwnam getpwuid getservbyname getservbyport getservent
		getsockname getsockopt glob gmtime goto grep gt hex if index
		int ioctl join keys kill last lc lcfirst le length link listen
		local localtime lock log lstat lt map mkdir msgctl msgget msgrcv
		msgsnd my ne next no not oct open opendir or ord our pack package
		pipe pop pos print printf prototype push quotemeta qu
		rand read readdir readline readlink readpipe recv redo
		ref rename require reset return reverse rewinddir rindex rmdir
		scalar seek seekdir select semctl semget semop send setgrent
		sethostent setnetent setpgrp setpriority setprotoent setpwent
		setservent setsockopt shift shmctl shmget shmread shmwrite shutdown
		sin sleep socket socketpair sort splice split sprintf sqrt srand
		stat study sub substr symlink syscall sysopen sysread sysseek
		system syswrite tell telldir tie tied time times truncate
		uc ucfirst umask undef unless unlink unpack unshift untie until
		use utime values vec wait waitpid wantarray warn while write
		xor given when default say state UNITCHECK
	},
];

# 8 different keyword lists for povray
$KEYWORDS{'text/x-povray'} = [
	# structure keyword1 == SCE_POV_DIRECTIVE
	q{
		declare local undef default macro if else while end
		include version debug error warning switch case range break
		ifdef indef  fopen fclose read write render statistics
	},

	# objects  SCE_POV_WORD2
	q{
		blob  box bicubic_patch object light_source
		camera  cylinder cubic global_settings height_field
		isosurface julia_fractal sor sphere sphere_sweep superellipsoid
		torus triangle quadric quartic sky_sphere plane poly polygon
	} .
	q{
		looks_like bounded_by contained_by clipped_by
	} .
	q{
		union intersection difference
	},

	# patterns  SCE_POV_WORD3
	q{
		agate bozo checker cells bumps brick facets dents crackle
		hexagon gradient granite  spotted spiral1 ripples marble
		leopard spiral2 wrinkles
	},

	# transforms  SCE_POV_WORD4
	q{
		translate rotate scale transform matrix point_at look_at
	},

	# modifiers - SCE_POV_WORD5
	q{

	},

	## float functions - SCE_POV_WORD6
	q{
		abs acos acosh asc asin asinh atan atanh atan2 ceil cos cosh defined
		degrees dimensions dimension_size div exp file_exists floor int inside
		ln log max min mod pow radians rand seed select sin sinh sqrt strcmp strlen
		tan tanh val vdot vlength
	} .

	## vector functions
	q{
		min_extent max_extent trace vaxis_rotate vcross vrotate
		vnormalize vturbulence
	} .

	## string functions
	q{
		chr concat str strlwr strupr substr vstr
	},

	## reserved identifiers SCE_POV_WORD7
	q{
		x y z red green blue alpha filter rgb rgbf rgba rgbfa u v
	},
];

# Python keywords
# The list is obtained from src/scite/src/python.properties
$KEYWORDS{'text/x-python'} = [
	q{
		and as assert break class continue def del elif
		else except exec finally for from global if import in is lambda None
		not or pass print raise return try while with yield
	},
];

# YAML keyword list is obtained from src/scite/src/yaml.properties
$KEYWORDS{'text/x-yaml'} = [
	q{
		true false yes no
	},
];

# HTML keywords contains all kinds of things
$KEYWORDS{'text/html'} = [
	join( ' ',
		# HTML elements
		q{a abbr acronym address applet area b base basefont
			bdo big blockquote body br button caption center
			cite code col colgroup dd del dfn dir div dl dt em
			fieldset font form frame frameset h1 h2 h3 h4 h5 h6
			head hr html i iframe img input ins isindex kbd label
			legend li link map menu meta noframes noscript
			object ol optgroup option p param pre q s samp
			script select small span strike strong style sub sup
			table tbody td textarea tfoot th thead title tr tt u ul
			var xml xmlns
			},

		# HTML attributes
		q{abbr accept-charset accept accesskey action align alink
			alt archive axis background bgcolor border
			cellpadding cellspacing char charoff charset checked cite
			class classid clear codebase codetype color cols colspan
			compact content coords
			data datafld dataformatas datapagesize datasrc datetime
			declare defer dir disabled enctype event
			face for frame frameborder
			headers height href hreflang hspace http-equiv
			id ismap label lang language leftmargin link longdesc
			marginwidth marginheight maxlength media method multiple
			name nohref noresize noshade nowrap
			object onblur onchange onclick ondblclick onfocus
			onkeydown onkeypress onkeyup onload onmousedown
			onmousemove onmouseover onmouseout onmouseup
			onreset onselect onsubmit onunload
			profile prompt readonly rel rev rows rowspan rules
			scheme scope selected shape size span src standby start style
			summary tabindex target text title topmargin type usemap
			valign value valuetype version vlink vspace width
			text password checkbox radio submit reset
			file hidden image
			^data-
			},

		# HTML 5 elements
		q{
			address article aside audio base canvas command details datalist embed
			figure figcaption footer header hgroup keygen mark menu meter nav output
			progress ruby rt rp section source time video wbr
			},

		# HTML 5 attributes
		q{
			async autocomplete autofocus contenteditable contextmenu draggable
			form formaction formenctype formmethod formnovalidate formtarget
			list manifest max min novalidate pattern placeholder
			required reversed role sandbox scoped seamless sizes spellcheck srcdoc step
			},
	),

	# Embedded Javascript
	$KEYWORDS{'application/javascript'}->[0],

	# Embedded Python
	q{
		and as assert break class continue def del elif
		else except exec finally for from global if import in is lambda None
		not or pass print raise return try while with yield
	},

	# Embedded VBScript
	$KEYWORDS{'text/vbscript'}->[0],

	# Embedded PHP
	$KEYWORDS{'application/php'}->[0],
];

# Clean the keywords
foreach my $list ( values %KEYWORDS ) {
	foreach my $i ( 0 .. $#$list ) {
		$list->[$i] =~ s/\A\s+//;
		$list->[$i] =~ s/\s+\Z//;
		$list->[$i] =~ s/\s+/ /g;
	}
}

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

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
