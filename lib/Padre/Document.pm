package Padre::Document;

=pod

=head1 NAME

Padre::Document - Padre Document API

=head1 DESCRIPTION

The B<Padre::Document> class provides a base class, default implementation
and API documentation for document type support in L<Padre>.

As an API, it allows L<Padre> developers and plug-in authors to implement
extended support for various document types in Padre, while ensuring that
a naive default document implementation exists that allows Padre to provide
basic support (syntax highlighting mainly) for many document types without
the need to install extra modules unless you need the extra functionality.

=head2 Document Type Registration

Padre uses MIME types as the fundamental identifier when working with
documents. Files are typed at load-time based on file extension (with a
simple heuristic fallback when opening files with no extension).

Many of the MIME types are unofficial X-style identifiers, but in cases
without an official type, Padre will try to use the most popular
identifier (based on research into the various language communities).

Each supported mime has a mapping to a Scintilla lexer (for syntax
highlighting), and an optional mapping to the class that provides enhanced
support for that document type.

Plug-ins that implement support for a document type provide a
C<registered_documents> method that the plug-in manager will call as needed.

Plug-in authors should B<not> load the document classes in advance, they
will be automatically loaded by Padre as needed.

Padre does B<not> currently support opening non-text files.

=head2 File to MIME type mapping

Padre has a built-in hash mapping the file extensions to MIME types.
In certain cases (.t, .pl, .pm) Padre also looks in the content of the
file to determine if the file is Perl 5 or Perl 6.

MIME types are mapped to lexers that provide the syntax highlighting.

MIME types are also mapped to modules that implement
special features needed by that kind of a file type.

Plug-ins can add further mappings.

=head2 Plan

Padre has a built-in mapping of file extension to either
a single MIME type or function name. In order to determine
the actual MIME type Padre checks this hash. If the key
is a subroutine it is called and it should return the
MIME type of the file.

The user has a way in the GUI to add more file extensions
and map them to existing MIME types or functions. It is probably
better to have a commonly used name along with the MIME type
in that GUI instead of the MIME type only.

I wonder if we should allow the users (and or plug-in authors) to
change the functions or to add new functions that will map
file content to MIME type or if we should just tell them to
patch Padre. What if they need it for some internal project?

A plug-in is able to add new supported MIME types. Padre should
either check for collisions if a plug-in wants to provide
an already supported MIME type or should allow multiple support
modules with a way to select the current one. (Again I think we
probably don't need this. People can just come and add the
MIME types to Padre core.) (not yet implemented)

A plug-in can register zero or more modules that implement
special features needed by certain MIME types. Every MIME type
can have only one module that implements its features. Padre is
checking if a MIME type already has a registered module and
does not let to replace it.
(Special features such as commenting out a few lines at once,
auto-completion or refactoring tools).

Padre should check if the given MIME type is one that is
in the supported MIME type list. (TO DO)

Each MIME type is mapped to one or more lexers that provide
the syntax highlighting. Every MIME type has to be mapped to at least
one lexer but it can be mapped to several lexers as well.
The user is able to select the lexer for each MIME type.
(For this each lexer should have a reasonable name too.) (TO DO)

Every plug-in should be able to add a list of lexers to the existing
MIME types regardless if the plug-in also provides the class that
implements the features of that MIME type. By default Padre
supports the built-in syntax highlighting of Scintilla.
Perl 5 currently has two L<PPI> based syntax highlighter,
Perl 6 can use the STD.pm or Rakudo/PGE for syntax highlighting but
there are two plug-ins – Parrot and Kate – that can provide syntax
highlighting to a wide range of MIME types.

C<provided_highlighters()> returns a list of arrays like this:

    ['Module with a colorize function' => 'Human readable Name' => 'Long description']

C<highlighting_mime_types()> returns a hash where the keys are module
names listed in C<provided_highlighters>, the values are array references to MIME types:

    'Module::A' => [ mime-type-1, mime-type-2]

The user can change the MIME type mapping of individual
files and Padre should remember this choice and allow the
user to change it to another specific MIME type
or to set it to "Default by extension".

=head1 METHODS

=cut

use 5.008;
use strict;
use warnings;
use Carp ();
use File::Spec 3.21 (); # 3.21 needed for volume-safe abs2rel
use File::Temp       ();
use Params::Util     ();
use Wx::Scintilla    ();
use Padre::Constant  ();
use Padre::Current   ();
use Padre::Util      ();
use Padre::Wx        ();
use Padre::MimeTypes ();
use Padre::File      ();
use Padre::Logger;

our $VERSION    = '0.92';
our $COMPATIBLE = '0.91';





######################################################################
# Basic Language Support

my %COMMENT_LINE_STRING = (
	'text/x-abc'                => '\\',
	'text/x-actionscript'       => '//',
	'text/x-adasrc'             => '--',
	'text/x-asm'                => '#',
	'text/x-bat'                => 'REM',
	'application/x-bibtex'      => '%',
	'application/x-bml'         => [ '<?_c', '_c?>' ],
	'text/x-c'                  => '//',
	'text/x-cobol'              => '      *',
	'text/x-config'             => '#',
	'text/x-csharp'             => '//',
	'text/css'                  => [ '/*', '*/' ],
	'text/x-c++src'             => '//',
	'text/x-eiffel'             => '--',
	'text/x-forth'              => '\\',
	'text/x-fortran'            => '!',
	'text/x-haskell'            => '--',
	'text/html'                 => [ '<!--', '-->' ],
	'application/javascript'    => '//',
	'application/x-latex'       => '%',
	'text/x-java-source'        => '//',
	'application/x-lisp'        => ';',
	'text/x-lua'                => '--',
	'text/x-makefile'           => '#',
	'text/x-matlab'             => '%',
	'text/x-pascal'             => [ '{', '}' ],
	'application/x-perl'        => '#',
	'application/x-perl6'       => '#',
	'text/x-perltt'             => [ '<!--', '-->' ],
	'text/x-perlxs'             => '//',
	'application/x-php'         => '#',
	'text/x-pod'                => '#',
	'text/x-python'             => '#',
	'application/x-ruby'        => '#',
	'application/x-shellscript' => '#',
	'text/x-sql'                => '--',
	'application/x-tcl'         => [ 'if 0 {', '}' ],
	'text/vbscript'             => "'",
	'text/xml'                  => [ '<!--', '-->' ],
	'text/x-yaml'               => '#',
);


# JavaScript keywords
my @SCINTILLA_JS_KEYWORDS = qw{
	abstract boolean break byte case catch char class
	const continue debugger default delete do double else enum export extends
	final finally float for function goto if implements import in instanceof
	int interface long native new package private protected public
	return short static super switch synchronized this throw throws
	transient try typeof var void volatile while with
};

# PHP keywords
my @SCINTILLA_PHP_KEYWORDS = qw{
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
	__function__ __line__ __method__ __namespace__ __sleep __wakeup
};

# VB keyword list is obtained from src/scite/src/vb.properties
my @SCINTILLA_VB_KEYWORDS = qw{addressof alias and as attribute base begin binary
	boolean byref byte byval call case cdbl cint clng compare const csng cstr currency
	date decimal declare defbool defbyte defcur
	defdate defdbl defdec defint deflng defobj defsng defstr defvar dim do double each else
	elseif empty end enum eqv erase error event exit explicit false for friend function get
	global gosub goto if imp implements in input integer is len let lib like load lock long
	loop lset me mid midb mod new next not nothing null object on option optional or paramarray
	preserve print private property public raiseevent randomize redim rem resume return rset
	seek select set single static step stop string sub text then time to true type typeof
	unload until variant wend while with withevents xor
};

# Take mostly from src/scite/src/ properties files
my %SCINTILLA_KEY_WORDS = (

	# C/C++ keyword list is obtained from src/scite/src/cpp.properties
	'text/x-c' => [
		[   qw{
				and and_eq asm auto bitand bitor bool break
				case catch char class compl const const_cast continue
				default delete do double dynamic_cast else enum explicit export
				extern false float for friend goto if inline int long mutable
				namespace new not not_eq operator or or_eq private protected
				public register reinterpret_cast return short signed sizeof
				static static_cast struct switch template this throw true try
				typedef typeid typename union unsigned using virtual void
				volatile wchar_t while xor xor_eq
				}
		]
	],

	# PHP keyword list is obtained from src/scite/src/html.properties
	'application/x-php' => [ [@SCINTILLA_PHP_KEYWORDS] ],

	'text/x-sql' => [
		[   qw{
				absolute action add admin after aggregate alias all allocate
				alter and any are array as asc assertion at authorization
				before begin binary bit body both breadth by call
				cascade cascaded case cast catalog check class
				close collate collation column commit completion connect
				connection constraint constraints constructor continue
				corresponding create cross cube current current_date
				current_path current_role current_time current_timestamp
				current_user cursor cycle data deallocate dec decimal
				declare default deferrable deferred delete depth deref desc
				describe descriptor destroy destructor deterministic dictionary
				diagnostics disconnect distinct domain drop dynamic each
				else end end-exec equals escape every except exception exec
				execute exists exit external false fetch first for
				foreign found from free full function general get global go
				goto grant group grouping having host hour identity if ignore
				immediate in indicator initialize initially inner inout input
				insert intersect interval into is isolation iterate
				join key language large last lateral leading left less level
				like limit local locator loop map match
				merge minus modifies modify module names national natural
				new next no none not numeric object of off old
				on only open operation option or order ordinality out outer
				output package pad parameter parameters partial path postfix
				precision prefix preorder prepare preserve primary prior
				privileges procedure public read reads real recursive ref
				references referencing relative replace restrict result return returns
				revoke right role rollback rollup routine row rows savepoint
				schema scroll scope search second section select sequence
				session session_user set sets size some| space
				specific specifictype sql sqlexception sqlstate sqlwarning
				start state statement static structure system_user table
				temporary terminate than then timezone_hour
				timezone_minute to trailing transaction translation treat
				trigger true under union unique unknown unnest update usage
				user using value values variable varying view when
				whenever where with without work write zone
				}
		],

		# keywords2 - being used for datatypes
		[

			# oracle centric
			qw( varchar varchar2 nvarchar nvarchar2 char nchar number
				integer pls_integer binary_integer long date time
				timestamp with local timezone interval year day month second minute
				raw rowid urowid mlslabel clob nclob blob bfile xmltype rowtype
				),
			qw(
				boolean smallint null localtime localtimestamp  int integer
				float double char character
				),

		],

		# pldoc keywords - bare minimum
		[qw( headcom deprecated param return throws )],

		# SQL*Plus
		[   qw(
				accept append archive log archivelog attribute
				break btitle
				change clear column default compute connect copy
				define del describe disconnect document
				edit execute exit
				get
				help host html
				input
				list logon
				markup
				newpage
				password pause print product_user_profile prompt
				recover remark repfooter repheader restrict run
				save set show label shutdown silent spool start startup store
				timing ttitle
				undefine
				variable
				version
				whenever oserror sqlerror
				)
		],

		# User Keywords #1 , reserve this for PLSQL functions, procedures, packages
		[   qw(
				utl_coll utl_encode utl_file utl_http utl_inaddr utl_raw utl_ref
				utl_smtp utl_tcp utl_url
				anydata anytype anydataset

				dbms_alert dbms_application_info dbms_apply_adm dbms_aq dbms_aqadm
				dbms_aqelm dbms_capture_adm dbms_ddl dbms_debug dbms_defer
				dbms_defer_query dbms_defer_sys dbms_describe
				dbms_distributed_trust_admin dbms_fga dbms_flashback
				dbms_hs_passthrough dbms_iot dbms_job dbms_ldap dbms_libcache
				dbms_lob dbms_lock dbms_logmnr dbms_logmnr_cdc_publish
				dbms_logmnr_cdc_subscribe dbms_logmnr_d dbms_logstdby dbms_metadata
				dbms_mgwadm dbms_mgwmsg dbms_mview dbms_obfuscation_toolkit
				dbms_odci dbms_offline_og dbms_offline_snapshot dbms_olap
				dbms_oracle_trace_agent dbms_oracle_trace_user dbms_outln
				dbms_outln_edit dbms_output dbms_pclxutil dbms_pipe dbms_profiler
				dbms_propagation_adm dbms_random dbms_rectifier_diff dbms_redefinition
				dbms_refresh dbms_repair dbms_repcat dbms_repcat_admin
				dbms_repcat_instantiate dbms_repcat_rgt dbms_reputil
				dbms_resource_manager dbms_resource_manager_privs dbms_resumable
				dbms_rls dbms_rowid dbms_rule dbms_rule_adm dbms_session
				dbms_shared_pool dbms_space dbms_space_admin dbms_sql dbms_stats
				dbms_storage_map dbms_streams dbms_streams_adm dbms_trace
				dbms_transaction dbms_transform dbms_tts dbms_types dbms_utility
				dbms_wm dbms_xdb dbms_xdbt dbms_xdb_version dbms_xmldom dbms_xmlgen
				dbms_xmlparser dbms_xmlquery dbms_xmlsave dbms_xplan dbms_xslprocessor
				debug_extproc
				)
		],

		# User Keywords #2 , sql functions
		[   qw( sqlerrm
				abs greatest sin
				acos group_id sinh add_months hextoraw soundex ascii initcap sqlcode
				asciistr instr sqlerrm asin lag sqrt atan last_day stddev atan2 lead
				substr avg least sum bfilename length sys_context bin_to_num lnnvl
				sysdate bitand ln systimestamp cardinality localtimestamp tan case
				statement log tanh cast lower to_char ceil lpad to_clob chartorowid
				ltrim to_date chr max to_dsinterval coalesce median to_lob compose min
				to_multi_byte concat mod to_nclob months_between to_number convert nanvl
				to_single_byte corr new_time to_timestamp cos next_day to_timestamp_tz
				cosh nullif to_yminterval count numtodsinterval translate covar_pop
				numtoyminterval trim covar_samp nvl trunc cume_dist nvl2 trunc
				current_date power tz_offset current_timestamp rank uid
				dbtimezone rawtohex upper decode remainder user decompose replace
				userenv dense_rank round var_pop dump var_samp exp rpad variance extract
				rtrim vsize floor sessiontimezone from_tz sign
				)
		],

		# User Keywords #3 , exception types
		[

			# exception types
			qw(
				no_data_found too_many_rows invalid_cursor value_error
				invalid_number zero_divide dup_val_on_index cursor_already_open
				not_logged_on transaction_backed_out login_denied program_error
				storage_error timeout_on_resource others
				) ],

		# User Keywords #4 , reserve this for plugins, eg known schema entities
		[qw()],

	],

	# YAML keyword list is obtained from src/scite/src/yaml.properties
	'text/x-yaml' => [ [qw{true false yes no}] ],

	# The list is obtained from src/scite/src/cpp.properties
	# Some of these are reserved for future use.
	# https://developer.mozilla.org/en/JavaScript/Reference/Reserved_Words
	'application/javascript' => [ [@SCINTILLA_JS_KEYWORDS] ],

	# CSS keyword list is obtained from src/scite/src/css.properties
	'text/css' => [
		[

			# CSS1
			qw{
				color background-color background-image background-repeat background-attachment background-position background
				font-family font-style font-variant font-weight font-size font
				word-spacing letter-spacing text-decoration vertical-align text-transform text-align text-indent line-height
				margin-top margin-right margin-bottom margin-left margin
				padding-top padding-right padding-bottom padding-left padding
				border-top-width border-right-width border-bottom-width border-left-width border-width
				border-top border-right border-bottom border-left border
				border-color border-style width height float clear
				display white-space list-style-type list-style-image list-style-position list-style
				position top bottom left right
				}
		],

		# Pseudoclasses
		[qw( link visited hover active focus first-child lang )],

		[

			# CSS2
			qw{
				border-top-color border-right-color border-bottom-color border-left-color border-color
				border-top-style border-right-style border-bottom-style border-left-style border-style
				top right bottom left position z-index direction unicode-bidi
				min-width max-width min-height max-height overflow clip visibility content quotes
				counter-reset counter-increment marker-offset
				size marks page-break-before page-break-after page-break-inside page orphans widows
				font-stretch font-size-adjust unicode-range units-per-em src
				panose-1 stemv stemh slope cap-height x-height ascent descent widths bbox definition-src
				baseline centerline mathline topline text-shadow
				caption-side table-layout border-collapse border-spacing empty-cells speak-header
				cursor outline outline-width outline-style outline-color
				volume speak pause-before pause-after pause cue-before cue-after cue
				play-during azimuth elevation speech-rate voice-family pitch pitch-range stress richness
				speak-punctuation speak-numeral
				visibility z-index
				}

		],
		[

			# CSS3
			qw{
				border-radius border-top-right-radius border-bottom-right-radius border-bottom-left-radius
				border-top-left-radius box-shadow columns column-width column-count column-rule column-gap
				column-rule-color column-rule-style column-rule-width resize opacity word-wrap
				}
		],

		# pseudo elements
		[qw( first-letter first-line before after selection)],

		# I presume extended in LexCSS means -moz -x -webkit and friends
		# extended-props
		[qw( )],

		# extended-pseudo-classes
		[qw( )],

		# extended-pseudo-elements
		[qw( )],
	],

	# HTML keyword list is obtained from src/scite/src/css.properties
	'text/html' => [
		[

			# HTML elements
			qw{a abbr acronym address applet area b base basefont
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
			qw{abbr accept-charset accept accesskey action align alink
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
			qw{
				address article aside audio base canvas command details datalist embed
				figure figcaption footer header hgroup keygen mark menu meter nav output
				progress ruby rt rp section source time video wbr
				},

			# HTML 5 attributes
			qw{
				async autocomplete autofocus contenteditable contextmenu draggable
				form formaction formenctype formmethod formnovalidate formtarget
				list manifest max min novalidate pattern placeholder
				required reversed role sandbox scoped seamless sizes spellcheck srcdoc step
				},
		],

		# Embedded Javascript
		[@SCINTILLA_JS_KEYWORDS],

		# Embedded Python
		[   qw(and as assert break class continue def del elif
				else except exec finally for from global if import in is lambda None
				not or pass print raise return try while with yield)
		],

		# Embedded VBScript
		[@SCINTILLA_VB_KEYWORDS],

		# Embedded PHP
		[@SCINTILLA_PHP_KEYWORDS],

	],

	# Ada keyword list is obtained from src/scite/src/ada.properties
	'text/x-adasrc' => [
		[

			# Ada keywords
			qw{abort abstract accept access aliased all array at begin body
				case constant declare delay delta digits do else elsif end entry exception exit for
				function generic goto if in is limited loop new null of others out package pragma
				private procedure protected raise range record renames requeue return reverse
				select separate subtype tagged task terminate then type until use when while with
				},

			# Ada Operators
			qw{abs and mod not or rem xor},
		]
	],

	# COBOL keyword list is obtained from src/scite/src/cobol.properties
	'text/x-cobol' => [
		[   qw{configuration data declaratives division environment
				environment-division file file-control function i-o i-o-control
				identification input input-output linkage local-storage output procedure
				program program-id receive-control section special-names working-storage},
		],
		[   qw{accept add alter apply assign call chain close compute continue
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
				transform unlock unstring update use wait when wrap write},
		],
		[   qw{access acquire actual address advancing after all allowing
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
				zero-fill zeros zeroes},
		],
	],

	# Haskell keyword list is obtained from src/scite/src/haskell.properties
	'text/x-haskell' => [
		[

			# Haskell 98
			qw{case class data default deriving do else hiding if
				import in infix infixl infixr instance let module
				newtype of then type where forall foreign
				}
		],
		[

			# Haskell Foreign Function Interface (FFI) (
			qw{export label dynamic safe threadsafe unsafe stdcall ccall prim}
		],
	],

	# Pascal keyword list is obtained from src/scite/src/pascal.properties
	'text/x-pascal' => [
		[

			# Pascal keywords
			qw{absolute abstract and array as asm assembler automated begin case
				cdecl class const constructor deprecated destructor dispid dispinterface div do downto
				dynamic else end except export exports external far file final finalization finally for
				forward function goto if implementation in inherited initialization inline interface is
				label library message mod near nil not object of on or out overload override packed
				pascal platform private procedure program property protected public published raise
				record register reintroduce repeat resourcestring safecall sealed set shl shr static
				stdcall strict string then threadvar to try type unit unsafe until uses var varargs
				virtual while with xor
				},

			# Smart pascal highlighting
			qw{add default implements index name nodefault read readonly
				remove stored write writeonly},

			# Pascal package
			#TODO only package dpk should get this list
			qw{package contains requires},
		],
	],

	# ActionScript keyword list is obtained from src/scite/src/cpp.properties
	'text/x-actionscript' => [
		[   qw{
				add and break case catch class continue default delete do
				dynamic else eq extends false finally for function ge get gt if implements import in
				instanceof interface intrinsic le lt ne new not null or private public return
				set static super switch this throw true try typeof undefined var void while with
				}
		],
		[   qw{
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
		],
	],

	# Inspired from Perl 6 vim syntax file
	# https://github.com/petdance/vim-perl/blob/master/syntax/perl6.vim
	'application/x-perl6' => [
		[

			# Perl 6 routine declaration keywords
			qw{macro sub submethod method multi proto only rule token regex category},

			# Perl 6 module keywords
			qw{module class role package enum grammar slang subset},

			# Perl 6 variable keywords
			qw{self},

			# Perl 6 include keywords
			qw{use require},

			# Perl 6 conditional keywords
			qw{if else elsif unless},

			# Perl 6 variable storage keywords
			qw{let my our state temp has constant},

			# Perl 6 repeat keywords
			qw{for loop repeat while until gather given},

			# Perl flow control keywords
			qw{take do when next last redo return contend maybe defer
				default exit make continue break goto leave async lift},

			# Perl 6 type constraints keywords
			qw{is as but trusts of returns handles where augment supersede},

			# Perl 6 closure traits keywords
			qw{BEGIN CHECK INIT START FIRST ENTER LEAVE KEEP
				UNDO NEXT LAST PRE POST END CATCH CONTROL TEMP},

			# Perl 6 exception keywords
			qw{die fail try warn},

			# Perl 6 property keywords
			qw{prec irs ofs ors export deep binary unary reparsed rw parsed cached
				readonly defequiv will ref copy inline tighter looser equiv assoc
				required},

			# Perl 6 number keywords
			qw{NaN Inf},

			# Perl 6 pragma keywords
			qw{oo fatal},

			# Perl 6 type keywords
			qw{Object Any Junction Whatever Capture Match
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
			qw{div x xx mod also leg cmp before after eq ne le lt
				gt ge eqv ff fff and andthen Z X or xor
				orelse extra m mm rx s tr},
		],
	],
	
	# 8 different keyword lists for povray
	'text/x-povray' => [
		# structure keyword1 == SCE_POV_DIRECTIVE
		[qw( declare local undef default macro if else while end
		include version debug error warning switch case range break
		ifdef indef  fopen fclose read write render statistics )],
		
		# objects  SCE_POV_WORD2
		[
		qw(blob  box bicubic_patch object light_source 
		camera  cylinder cubic global_settings height_field
		isosurface julia_fractal sor sphere sphere_sweep superellipsoid
		torus triangle quadric quartic sky_sphere plane poly polygon ),
		
		qw(
		looks_like bounded_by contained_by clipped_by
		),
		qw(
		union intersection difference
		)
		],
		
		# patterns  SCE_POV_WORD3
		[qw( agate bozo checker cells bumps brick facets dents crackle
		hexagon gradient granite  spotted spiral1 ripples marble
		leopard spiral2 wrinkles)],
			
		# transforms  SCE_POV_WORD4
		[qw( translate rotate scale transform matrix point_at look_at )],
		
		# modifiers - SCE_POV_WORD5
		[qw( 
		
		)],
		
		## float functions - SCE_POV_WORD6
		[qw(
		abs acos acosh asc asin asinh atan atanh atan2 ceil cos cosh defined 
		degrees dimensions dimension_size div exp file_exists floor int inside 
		ln log max min mod pow radians rand seed select sin sinh sqrt strcmp strlen 
		tan tanh val vdot vlength ), 
		## vector functions
		qw( min_extent max_extent trace vaxis_rotate vcross vrotate 
		vnormalize vturbulence ),
		## string functions
		qw( chr concat str strlwr strupr substr vstr )
		],
		
		## reserved identifiers SCE_POV_WORD7
		[qw(
		x y z red green blue alpha filter rgb rgbf rgba rgbfa u v
		)],
	],

);
$SCINTILLA_KEY_WORDS{'text/x-c++src'} = $SCINTILLA_KEY_WORDS{'text/x-c'};
$SCINTILLA_KEY_WORDS{'text/x-perlxs'} = $SCINTILLA_KEY_WORDS{'text/x-c'};





#####################################################################
# Task Integration

sub task_functions {
	return '';
}

sub task_outline {
	return '';
}

sub task_syntax {
	return '';
}





#####################################################################
# Document Registration

# NOTE: This is probably a bad place to store this
my $UNSAVED = 0;





#####################################################################
# Constructor and Accessors

use Class::XSAccessor {
	getters => {
		unsaved      => 'unsaved',
		filename     => 'filename',    # setter is defined as normal function
		file         => 'file',        # Padre::File - object
		editor       => 'editor',
		timestamp    => 'timestamp',
		mimetype     => 'mimetype',
		encoding     => 'encoding',
		errstr       => 'errstr',
		tempfile     => 'tempfile',
		highlighter  => 'highlighter',
		outline_data => 'outline_data',
	},
	setters => {
		set_editor       => 'editor',
		set_timestamp    => 'timestamp',
		set_mimetype     => 'mimetype',
		set_encoding     => 'encoding',
		set_newline_type => 'newline_type',
		set_errstr       => 'errstr',
		set_tempfile     => 'tempfile',
		set_highlighter  => 'highlighter',
		set_outline_data => 'outline_data',
	},
};

=pod

=head2 C<new>

  my $doc = Padre::Document->new(
      filename => $file,
  );

C<$file> is optional and if given it will be loaded in the document.
MIME type is defined by the C<guess_mimetype> function.

=cut

sub new {
	my $class = shift;
	my $self = bless {@_}, $class;

	# This sub creates the document object and is allowed to use self->filename,
	# once noone else uses it, it shout be deleted from the $self - hash before
	# leaving the sub.
	# Use document->{file}->filename instead!
	if ( $self->{filename} ) {
		$self->{file} = Padre::File->new(
			$self->{filename},
			info_handler => sub {
				$self->current->main->info( $_[1] );
			}
		);

		unless ( defined $self->{file} ) {
			$self->error( Wx::gettext('Error while opening file: no file object') );
			return;
		}

		if ( defined $self->{file}->{error} ) {
			$self->error( $self->{file}->{error} );
			return;
		}

		# The Padre::File - module knows how to format the filename to the right
		# syntax to correct (for example) .//file.pl to ./file.pl)
		$self->{filename} = $self->{file}->{filename};

		if ( $self->{file}->exists ) {

			# Test script must be able to pass an alternate config object
			# NOTE: Since when do we support per-document configuration objects?
			my $config = $self->{config} || $self->current->config;
			if ( defined( $self->{file}->size ) and ( $self->{file}->size > $config->editor_file_size_limit ) ) {
				my $ret = Wx::MessageBox(
					sprintf(
						Wx::gettext(
							"The file %s you are trying to open is %s bytes large. It is over the arbitrary file size limit of Padre which is currently %s. Opening this file may reduce performance. Do you still want to open the file?"
						),
						$self->{file}->{filename},
						_commafy( -s $self->{file}->{filename} ),
						_commafy( $config->editor_file_size_limit )
					),
					Wx::gettext("Warning"),
					Wx::YES_NO | Wx::CENTRE,
					$self->current->main,
				);
				if ( $ret != Wx::YES ) {
					return;
				}
			}
		}
		$self->load_file;
	} else {
		$self->{unsaved}      = ++$UNSAVED;
		$self->{newline_type} = $self->default_newline_type;
	}

	unless ( $self->mimetype ) {
		my $mimetype = $self->guess_mimetype;
		if ( defined $mimetype ) {
			$self->set_mimetype($mimetype);
		} else {
			$self->error(
				Wx::gettext(
					"Error while determining MIME type.\nThis is possibly an encoding problem.\nAre you trying to load a binary file?"
				)
			);
			return;
		}
	}

	$self->rebless;

	# NOTE: Hacky support for the Padre Popularity Contest
	unless ( defined $ENV{PADRE_IS_TEST} ) {
		my $popcon = $self->current->ide->{_popularity_contest};
		$popcon->count( 'mime.' . $self->mimetype ) if $popcon;
	}

	return $self;
}

sub rebless {
	my $self = shift;

	# Rebless as either to a subclass if there is a mime-type or
	# to the the base class,
	# This isn't exactly the most elegant way to do this, but will
	# do for a first implementation.
	my $mime_type = $self->mimetype or return;
	my $class = Padre::MimeTypes->get_mime_class($mime_type) || __PACKAGE__;
	TRACE("Reblessing to mimetype: '$class'") if DEBUG;
	if ($class) {
		unless ( $class->VERSION ) {
			eval "require $class;";
			die "Failed to load $class: $@" if $@;
		}
		bless $self, $class;
	}

	my $module   = Padre::MimeTypes->get_current_highlighter_of_mime_type($mime_type);
	my $filename = '';                                                                # Not undef
	$filename = $self->{file}->filename
		if defined( $self->{file} )
			and defined( $self->{file}->{filename} );
	if ( not $module ) {
		$self->current->main->error(
			sprintf(
				Wx::gettext("No module mime_type='%s' filename='%s'"),
				$mime_type, $filename
			)
		);
	}
	$self->set_highlighter($module);

	return;
}

sub current {
	Padre::Current->new( document => $_[0] );
}

# Abstract methods, each subclass should implement it
# TO DO: Clearly this isn't ACTUALLY abstract (since they exist)

sub scintilla_word_chars {
	return '';
}

sub scintilla_key_words {
	my $self = shift;
	my $mime = $self->mimetype or return [];
	$SCINTILLA_KEY_WORDS{$mime} or return [];
}

sub get_calltip_keywords {
	return {};
}

sub get_function_regex {
	return '';
}

#
# $doc->get_comment_line_string;
#
# this is of course dependant on the language, and thus it's actually
# done in the subclasses. however, we provide base empty methods in
# order for padre not to crash if user wants to un/comment lines with
# a document type that did not define those methods.
#
# TO DO Remove this base method
sub get_comment_line_string {
	my $self = shift;
	my $mime = $self->mimetype or return;
	$COMMENT_LINE_STRING{$mime} or return;
}





######################################################################
# Padre::Cache Integration

# The detection of VERSION allows us to make this call without having
# to load modules at document destruction time if it isn't needed.
sub DESTROY {
	if ( defined $_[0]->{filename} and $Padre::Cache::VERSION ) {
		Padre::Cache->release( $_[0]->{filename} );
	}
}





#####################################################################
# Padre::Document GUI Integration

sub colourize {
	my $self   = shift;
	my $lexer  = $self->lexer;
	my $editor = $self->editor;
	$editor->SetLexer($lexer);
	TRACE("colourize called") if DEBUG;

	$editor->remove_color;
	if ( $lexer == Wx::Scintilla::SCLEX_CONTAINER ) {
		$self->colorize;
	} else {
		TRACE("Colourize is being called") if DEBUG;
		$editor->Colourise( 0, $editor->GetLength );
		TRACE("Colourize completed") if DEBUG;
	}
}

sub colorize {
	my $self = shift;
	TRACE("colorize called") if DEBUG;

	my $module = $self->highlighter;
	TRACE("module: '$module'") if DEBUG;
	if ( $module eq 'stc' ) {

		#TO DO sometime this happens when I open Padre with several file
		# I think this can be somehow related to the quick (or slow ?) switching of
		# what is the current document while the code is still running.
		# for now I hide the warnings as this would just frighten people and the
		# actual problem seems to be only the warning or maybe late highighting
		# of a single document - szabgab
		#Carp::cluck("highlighter is set to 'stc' while colorize() is called for " . ($self->filename || '') . "\n");
		#warn "Length: " . $self->editor->GetTextLength;
		return;
	}

	# allow virtual modules if they have a colorize method
	unless ( $module->can('colorize') ) {
		eval "use $module";
		if ($@) {
			Carp::cluck( "Could not load module '$module' for file '" . ( $self->{file}->filename || '' ) . "'\n" );
			return;
		}
	}
	if ( $module->can('colorize') ) {
		TRACE("Call '$module->colorize(@_)'") if DEBUG;
		$module->colorize(@_);
	} else {
		warn("Module $module does not have a colorize method\n");
	}
	return;
}

# For ts without a newline type
# TO DO: get it from config
sub default_newline_type {
	my $self = shift;

	# Very ugly hack to make the test script work
	if ( $0 =~ /t.70_document\.t/ ) {
		return Padre::Constant::NEWLINE;
	}

	$self->current->config->default_line_ending;
}

=pod

=head2 C<error>

    $document->error( $msg );

Open an error dialog box with C<$msg> as main text. There's only one OK
button. No return value.

=cut

# TO DO: A globally used error/message box function may be better instead
#       of replicating the same function in many files:
sub error {
	$_[0]->current->main->message( $_[1], Wx::gettext('Error') );
}





#####################################################################
# Disk Interaction Methods

# These methods implement the interaction between the document and the
# filesystem.

sub basename {
	my $self = shift;
	if ( defined $self->{file} ) {
		return $self->{file}->basename;
	}
	return $self->{file}->{filename};
}

sub dirname {
	my $self = shift;
	if ( defined $self->{file} ) {
		return $self->{file}->dirname;
	}
	return;
}

sub is_new {
	return !!( not defined $_[0]->file );
}

sub is_modified {
	return !!( $_[0]->editor->GetModify );
}

sub is_saved {
	return !!( defined $_[0]->file and not $_[0]->is_modified );
}

sub is_unsaved {
	return !!( $_[0]->editor->GetModify and defined $_[0]->file );
}

# Returns true if this is a new document that is too insignificant to
# bother checking with the user before throwing it away.
# Usually this is because it's empty or just has a space or two in it.
sub is_unused {
	my $self = shift;
	return '' unless $self->is_new;
	return 1  unless $self->is_modified;
	return 1  unless $self->text_get =~ /\S/s;
	return '';
}

sub is_readonly {
	my $self = shift;

	my $file = $self->file;
	return 0 unless defined($file);

	# Fill the cache if it's empty and assume read-write as a default
	$self->{readonly} ||= $self->file->readonly || 0;

	return $self->{readonly};
}

# Returns true if file has changed on the disk
# since load time or the last time we saved it.
# Check if the file on the disk has changed
# 1) when document gets the focus (gvim, notepad++)
# 2) when we try to save the file (gvim)
# 3) every time we type something ????
sub has_changed_on_disk {
	my $self = shift;
	return 0 unless defined $self->file;
	return 0 unless defined $self->timestamp;

	# Caching the result for two lines saved one stat-I/O each time this sub is run
	my $timestamp_now = $self->timestamp_now;
	return 0 unless defined $timestamp_now; # there may be no mtime on remote files

	# Return -1 if file has been deleted from disk
	return -1 unless $timestamp_now;

	# Return 1 if the file has changed on disk, otherwise 0
	return $self->timestamp < $timestamp_now ? 1 : 0;
}

sub timestamp_now {
	my $self = shift;
	my $file = $self->file;
	return 0 unless defined $file;

	# It's important to return undef if there is no ->mtime for this filetype
	return undef unless $file->can('mtime');
	return $file->mtime;
}

=pod

=head2 C<load_file>

 $doc->load_file;

Loads the current file.

Sets the B<Encoding> bit using L<Encode::Guess> and tries to figure
out what kind of newlines are in the file. Defaults to C<utf-8> if it
could not figure out the encoding.

Returns true on success false on failure. Sets C<< $doc->errstr >>.

=cut

sub load_file {
	my $self = shift;
	my $file = $self->file;

	if (DEBUG) {
		my $name = $file->{filename} || '';
		TRACE("Loading file '$name'");
	}

	# Show the file-changed-dialog again after the file was (re)loaded:
	delete $self->{_already_popup_file_changed};

	# check if file exists
	if ( !$file->exists ) {

		# file doesn't exist, try to create an empty one
		if ( !$file->write('') ) {

			# oops, error creating file. abort operation
			$self->set_errstr( $file->error );
			return;
		}
	}

	# load file
	$self->set_errstr('');
	my $content = $file->read;
	if ( !defined($content) ) {
		$self->set_errstr( $file->error );
		return;
	}
	$self->{timestamp} = $self->timestamp_now;

	# if guess encoding fails then use 'utf-8'
	require Padre::Locale;
	$self->{encoding} = Padre::Locale::encoding_from_string($content);

	#warn $self->{encoding};
	require Encode;
	$content = Encode::decode( $self->{encoding}, $content );

	# Determine new line type using file content.
	$self->{newline_type} = Padre::Util::newline_type($content);

	# Cache the original value of various things so we can do
	# smart things at save time later.
	$self->{original_content} = $content;
	$self->{original_newline} = $self->{newline_type};

	return 1;
}

# New line type can be one of these values:
# WIN, MAC (for classic Mac) or UNIX (for Mac OS X and Linux/*BSD)
# Special cases:
# 'Mixed' for mixed end of lines,
# 'None' for one-liners (no EOL)
sub newline_type {
	$_[0]->{newline_type} or $_[0]->default_newline_type;
}

# Get the newline char(s) for this document.
# TO DO: This solution is really terrible - it should be {newline} or at least a caching of the value
#       because of speed issues:
sub newline {
	my $self = shift;
	if ( $self->newline_type eq 'WIN' ) {
		return "\r\n";
	} elsif ( $self->newline_type eq 'MAC' ) {
		return "\r";
	}
	return "\n";
}

=pod

=head2 C<autocomplete_matching_char>

The first argument needs to be a reference to the editor this method should
work on.

The second argument is expected to be a event reference to the event object
which is the reason why the method was launched.

This method expects a hash as the third argument. If the last key typed by the
user is a key in this hash, the value is automatically added and the cursor is
set between key and value. Both key and value are expected to be ASCII codes.

Usually used for brackets and text signs like:

  $self->autocomplete_matching_char(
      $editor,
      $event,
      39  => 39,  # ' '
      40  => 41,  # ( )
  );

Returns 1 if something was added or 0 otherwise (if anybody cares about this).

=cut

sub autocomplete_matching_char {
	my $self   = shift;
	my $editor = shift;
	my $event  = shift;
	my %table  = @_;
	my $key    = $event->GetUnicodeKey;
	unless ( $table{$key} ) {
		return 0;
	}

	# Is autocomplete enabled
	my $current = $self->current;
	my $config  = $current->config;
	unless ( $config->autocomplete_brackets ) {
		return 0;
	}

	# Is something selected?
	my $pos  = $editor->GetCurrentPos;
	my $text = $editor->GetSelectedText;
	if ( defined $text and length $text ) {
		my $start = $editor->GetSelectionStart;
		my $end   = $editor->GetSelectionEnd;
		$editor->GotoPos($end);
		$editor->AddText( chr( $table{$key} ) );
		$editor->GotoPos($start);

	} else {
		my $nextChar;
		if ( $editor->GetTextLength > $pos ) {
			$nextChar = $editor->GetTextRange( $pos, $pos + 1 );
		}
		unless ( defined($nextChar) && ord($nextChar) == $table{$key}
			and ( !$config->autocomplete_multiclosebracket ) )
		{
			$editor->AddText( chr( $table{$key} ) );
			$editor->CharLeft;
		}
	}

	return 1;
}

sub set_filename {
	my $self     = shift;
	my $filename = shift;

	unless ( defined $filename ) {
		warn 'Request to set filename to undef from ' . join( ',', caller );
		return 0;
	}

	# Shortcut if no change in file name
	if ( defined $self->{filename} and $self->{filename} eq $filename ) {
		return 1;
	}

	# Flush out old state information, primarily the file object.
	# Additionally, whenever we change the name of the file we can no
	# longer trust that we are in the same project, so flush that as well.
	delete $self->{filename};
	delete $self->{file};
	delete $self->{project_dir};

	# Save the new filename
	$self->{file} = Padre::File->new($filename);

	# Padre::File reformats filenames to the protocol/OS specific format, so use this:
	$self->{filename} = $self->{file}->{filename};
}

# Only a dummy for documents which don't support this
sub autoclean {
	my $self = shift;

	return 1;
}

sub save_file {
	my $self    = shift;
	my $current = $self->current;
	my $manager = $current->ide->plugin_manager;
	unless ( $manager->hook( 'before_save', $self ) ) {
		return;
	}

	# Show the file-changed-dialog again after the file was saved:
	delete $self->{_already_popup_file_changed};

	# If padre is run on files that have no project
	# I.E Padre foo.pl &
	# The assumption of $self->project as defined will cause a fail
	my $config;
	$config = $self->project->config if $self->project;
	$self->set_errstr('');

	if ( $config and $config->save_autoclean ) {
		$self->autoclean;
	}

	my $content = $self->text_get;
	my $file    = $self->file;
	unless ( defined $file ) {

		# NOTE: Now we have ->set_filename, should this situation ever occur?
		$file = Padre::File->new( $self->filename );
		$self->{file} = $file;
	}

	# This is just temporary for security and should prevend data loss:
	if ( $self->{filename} ne $file->{filename} ) {
		my $ret = Wx::MessageBox(
			sprintf(
				Wx::gettext('Visual filename %s does not match the internal filename %s, do you want to abort saving?'),
				$self->{filename},
				$file->{filename}
			),
			Wx::gettext("Save Warning"),
			Wx::YES_NO | Wx::CENTRE,
			$current->main,
		);

		return 0 if $ret == Wx::YES;
	}

	# Not set when first time to save
	# Allow the upgrade from ascii to utf-8 if there were unicode characters added
	unless ( $self->{encoding} and $self->{encoding} ne 'ascii' ) {
		require Padre::Locale;
		$self->{encoding} = Padre::Locale::encoding_from_string($content);
	}

	my $encode = '';
	if ( defined $self->{encoding} ) {
		$encode = ":raw:encoding($self->{encoding})";
	} else {
		warn "encoding is not set, (couldn't get from contents) when saving file $file->{filename}\n";
	}

	unless ( $file->write( $content, $encode ) ) {
		$self->set_errstr( $file->error );
		return;
	}

	# File must be closed at this time, slow fs/userspace-fs may not
	# return the correct result otherwise!
	$self->{timestamp} = $self->timestamp_now;

	# Determine new line type using file content.
	$self->{newline_type} = Padre::Util::newline_type($content);

	# Update read-only-cache
	$self->{readonly} = $self->file->readonly;

	$manager->hook( 'after_save', $self );

	return 1;
}

=pod

=head2 C<write>

Writes the document to an arbitrary local file using the same semantics
as when we do a full file save.

=cut

sub write {
	my $self = shift;
	my $file = shift;          # File object, not just path
	my $text = $self->text_get;

	# Get the locale, but don't save it.
	# This could fire when only one of two characters have been
	# typed, and we may not know the encoding yet.
	# Not set when first time to save
	# Allow the upgrade from ascii to utf-8 if there were unicode characters added
	my $encoding = $self->{encoding};
	unless ( $encoding and $encoding ne 'ascii' ) {
		require Padre::Locale;
		$encoding = Padre::Locale::encoding_from_string($text);
	}
	if ( defined $encoding ) {
		$encoding = ":raw:encoding($encoding)";
	}

	# Write the file
	$file->write( $text, $encoding );
}

=pod

=head2 C<reload>

Reload the current file discarding changes in the editor.

Returns true on success false on failure. Error message will be in C<< $doc->errstr >>.

TO DO: In the future it should backup the changes in case the user regrets the action.

=cut

sub reload {
	my $self = shift;
	my $file = $self->file or return;
	return $self->load_file;
}

# Copies document content to a temporary file.
# Returns temporary file name.
sub store_in_tempfile {
	my $self = shift;

	$self->create_tempfile unless $self->tempfile;

	open my $FH, ">", $self->tempfile;
	print $FH $self->text_get;
	close $FH;

	return $self->tempfile;
}

sub create_tempfile {
	my $tempfile = File::Temp->new( UNLINK => 0 );
	$_[0]->set_tempfile( $tempfile->filename );
	close $tempfile;

	return;
}

sub remove_tempfile {
	unlink $_[0]->tempfile;
	return;
}





#####################################################################
# Basic Content Manipulation

sub text_get {
	$_[0]->editor->GetText;
}

sub text_length {
	$_[0]->editor->GetLength;
}

sub text_set {
	$_[0]->editor->SetText( $_[1] );
}

sub text_like {
	my $self = shift;
	return !!( $self->text_get =~ /$_[0]/m );
}

sub text_with_one_nl {
	my $self   = shift;
	my $text   = $self->text_get or return;
	my $nlchar = "\n";
	if ( $self->newline_type eq 'WIN' ) {
		$nlchar = "\r\n";
	} elsif ( $self->newline_type eq 'MAC' ) {
		$nlchar = "\r";
	}
	$text =~ s/$nlchar/\n/g;
	return $text;
}

sub text_replace {
	my $self = shift;
	my $to   = shift;
	my $from = $self->text_get;

	# Generate a delta and apply it
	require Padre::Delta;

	#TODO Please implement the text_patch method or remove
	#$self->text_patch(
	#	Padre::Delta->from_scalars( \$from, \$to )
	#);
}

sub text_delta {
	my $self = shift;
	my $delta = Params::Util::_INSTANCE( shift, 'Padre::Delta' ) or return;
	$delta->apply( $self->editor );
}





#####################################################################
# GUI Integration Methods

# Determine the Scintilla lexer to use
sub lexer {
	my $self = shift;

	# this should never happen as now we set mime-type on everything
	return Wx::Scintilla::SCLEX_AUTOMATIC unless $self->mimetype;

	my $highlighter = $self->highlighter;
	if ( not $highlighter ) {
		$self->current->main->error(
			sprintf(
				Wx::gettext("no highlighter for mime-type '%s' using stc"),
				$self->mimetype
			)
		);
		$highlighter = 'stc';
	}
	TRACE("The highlighter is '$highlighter'") if DEBUG;
	return Wx::Scintilla::SCLEX_CONTAINER if $highlighter ne 'stc';
	return Wx::Scintilla::SCLEX_AUTOMATIC unless defined Padre::MimeTypes->get_lexer( $self->mimetype );

	TRACE( 'STC Lexer will be based on mime type "' . $self->mimetype . '"' ) if DEBUG;
	return Padre::MimeTypes->get_lexer( $self->mimetype );
}

# What should be shown in the notebook tab
sub get_title {
	my $self = shift;
	if ( defined( $self->{file} ) and defined( $self->{file}->filename ) and ( $self->{file}->filename ne '' ) ) {
		return $self->basename;
	} else {
		$self->{unsaved} ||= ++$UNSAVED;
		my $str = sprintf(
			Wx::gettext("Unsaved %d"),
			$self->{unsaved},
		);

		# A bug in Wx requires a space at the front of the title
		# (For reasons I don't understand yet)
		return ' ' . $str;
	}
}

# TO DO: experimental
sub get_indentation_style {
	my $self   = shift;
	my $config = $self->current->config;

	# TO DO: (document >) project > config

	my $style;
	if ( $config->editor_indent_auto ) {

		# TO DO: This should be cached? What's with newish documents then?
		$style = $self->guess_indentation_style;
	} else {
		$style = {
			use_tabs    => $config->editor_indent_tab,
			tabwidth    => $config->editor_indent_tab_width,
			indentwidth => $config->editor_indent_width,
		};
	}

	return $style;
}

=head2 C<get_indentation_level_string>

Calculates the string that should be used to indent a given
number of levels for this document.

Takes the indentation level as an integer argument which
defaults to one. Note that indenting to level 2 may be different
from just concatenating the indentation string to level one twice
due to tab compression.

=cut

sub get_indentation_level_string {
	my $self  = shift;
	my $level = shift;
	$level = 1 if not defined $level;
	my $style        = $self->get_indentation_style;
	my $indent_width = $style->{indentwidth};
	my $tab_width    = $style->{tabwidth};
	my $indent;

	if ( $style->{use_tabs} and $indent_width != $tab_width ) {

		# do tab compression if necessary
		# - First, convert all to spaces (aka columns)
		# - Then, add an indentation level
		# - Then, convert to tabs as necessary
		my $tab_equivalent = " " x $tab_width;
		$indent = ( " " x $indent_width ) x $level;
		$indent =~ s/$tab_equivalent/\t/g;
	} elsif ( $style->{use_tabs} ) {
		$indent = "\t" x $level;
	} else {
		$indent = ( " " x $indent_width ) x $level;
	}
	return $indent;
}

=head2 C<event_on_char>

NOT IMPLEMENTED IN THE BASE CLASS

This method - if implemented - is called after any addition of a character
to the current document. This enables document classes to aid the user
in the editing process in various ways, e.g. by auto-pairing of brackets
or by suggesting usable method names when method-call syntax is detected.

Parameters retrieved are the objects for the document, the editor, and the
wxWidgets event.

Returns nothing.

Cf. C<Padre::Document::Perl> for an example.

=head2 C<event_on_context_menu>

NOT IMPLEMENTED IN THE BASE CLASS

This method - if implemented - is called when a user triggers the context menu
(either by right-click or the context menu key or Shift+F10) in an editor after
the standard context menu was created and populated in the C<Padre::Wx::Editor>
class.
By manipulating the menu document classes may provide the user with
additional options.

Parameters retrieved are the objects for the document, the editor, the
context menu (C<Wx::Menu>) and the event.

Returns nothing.

=head2 C<event_on_left_up>

NOT IMPLEMENTED IN THE BASE CLASS

This method - if implemented - is called when a user left-clicks in an
editor. This can be used to implement context-sensitive actions if
the user presses modifier keys while clicking.

Parameters retrieved are the objects for the document, the editor,
and the event.

Returns nothing.

=cut





#####################################################################
# Project Integration Methods

sub project {
	my $self    = shift;
	my $manager = $self->current->ide->project_manager;

	# If we have a cached project_dir return the object based on that
	if ( defined $self->{project_dir} ) {
		return $manager->project( $self->{project_dir} );
	}

	# Anonymous files don't have a project
	my $file = $self->file or return;

	# Currently no project support for remote files
	return unless $file->{protocol} eq 'local';

	# Find the project for this document's filename
	my $project = $manager->from_file( $file->{filename} );
	return undef unless defined $project;

	# To prevent the creation of tons of references to the project object,
	# cache the project by it's root directory.
	$self->{project_dir} = $project->root;

	return $project;
}

sub project_dir {
	my $self = shift;
	unless ( defined $self->{project_dir} ) {

		# Find the project, which slightly bizarely caches the
		# location of the project via it's root.
		# NOTE: Yes this looks weird, but it is significantly
		# less weird than the code it replaced.
		$self->project;
	}
	return $self->{project_dir};
}

# Find the project-relative file name
sub filename_relative {
	File::Spec->abs2rel( $_[0]->filename, $_[0]->project_dir );
}





#####################################################################
# Document Analysis Methods

# Unreliable methods that provide heuristic best-attempts at automatically
# determining various document properties.

# Left here as it is used in many places.
# Maybe we need to remove this sub.
sub guess_mimetype {
	my $self = shift;
	Padre::MimeTypes->guess_mimetype(
		$self->{original_content},
		$self->file,
	);
}

=head2 C<guess_indentation_style>

Automatically infer the indentation style of the document using
L<Text::FindIndent>.

Returns a hash reference containing the keys C<use_tabs>,
C<tabwidth>, and C<indentwidth>. It is suitable for passing
to C<set_indendentation_style>.

=cut

sub guess_indentation_style {
	my $self = shift;
	my $text = $self->text_get;

	# Hand off to the standalone module
	my $indentation = 'u'; # Unknown
	if ( length $text ) {

		# Allow for the delayed loading of Text::FindIndent if we startup
		# with no file or a completely empty file.
		require Text::FindIndent;
		$indentation = Text::FindIndent->parse(
			\$text,
			skip_pod => $self->isa('Padre::Document::Perl'),
		);
	}

	my $style;
	my $config = $self->current->config;
	if ( $indentation =~ /^t\d+/ ) { # we only do ONE tab
		$style = {
			use_tabs    => 1,
			tabwidth    => $config->editor_indent_tab_width || 8,
			indentwidth => 8,
		};
	} elsif ( $indentation =~ /^s(\d+)/ ) {
		$style = {
			use_tabs    => 0,
			tabwidth    => $config->editor_indent_tab_width || 8,
			indentwidth => $1,
		};
	} elsif ( $indentation =~ /^m(\d+)/ ) {
		$style = {
			use_tabs    => 1,
			tabwidth    => $config->editor_indent_tab_width || 8,
			indentwidth => $1,
		};
	} else {

		# fallback
		$style = {
			use_tabs    => $config->editor_indent_tab,
			tabwidth    => $config->editor_indent_tab_width,
			indentwidth => $config->editor_indent_width,
		};
	}

	return $style;
}

=head2 C<guess_filename>

  my $name = $document->guess_filename

When creating new code, one job that the editor should really be able to do
for you without needing to be told is to work out where to save the file.

When called on a new unsaved file, this method attempts to guess what the
name of the file should be based purely on the content of the file.

In the base implementation, this returns C<undef> to indicate that the
method cannot make a reasonable guess at the name of the file.

Your MIME type specific document subclass should implement any file name
detection as it sees fit, returning the file name as a string.

=cut

sub guess_filename {
	my $self = shift;

	# If the file already has an existing name, guess that
	my $filename = $self->filename;
	if ( defined $filename ) {
		return ( File::Spec->splitpath($filename) )[2];
	}

	return undef;
}

=head2 C<guess_subpath>

  my $subpath = $document->guess_subpath;

When called on a new unsaved file, this method attempts to guess what the
sub-path of the file should be inside of the current project, based purely
on the content of the file.

In the base implementation, this returns a null list to indicate that the
method cannot make a reasonable guess at the name of the file.

Your MIME type specific document subclass should implement any file name
detection as it sees fit, returning the project-rooted sub-path as a list
of directory names.

These directory names do not need to exist, they only represent intent.

=cut

sub guess_subpath {
	my $self = shift;

	# For an unknown document type, we cannot make any reasonable guess
	return ();
}

sub functions {
	my $self = shift;
	my $task = Params::Util::_DRIVER( $self->task_functions, 'Padre::Task' ) or return;
	$task->find( $self->text_get );
}

sub pre_process {
	return 1;
}

sub selection_stats {
	my $self    = shift;
	my $text    = $self->editor->GetSelectedText;
	my $words   = 0;
	my $newline = $self->newline;
	my $lines   = 1;
	$lines++ while ( $text =~ /$newline/g );
	$words++ while ( $text =~ /\s+/g );

	my $chars_with_space    = length $text;
	my $whitespace          = "\n\r\t ";
	my $chars_without_space = $chars_with_space - ( $text =~ tr/$whitespace// );

	return ( $lines, $chars_with_space, $chars_without_space, $words );
}

sub stats {
	my $self                = shift;
	my $chars_without_space = 0;
	my $words               = 0;
	my $editor              = $self->editor;
	my $text                = $self->text_get;
	my $lines               = $editor->GetLineCount;
	my $chars_with_space    = $editor->GetTextLength;

	# TODO: Remove this limit? Right now, it is greater than the default file size limit.
	if ( length $text < 2_500_000 ) {
		$words++ while ( $text =~ /\s+/g );

		my $whitespace = "\n\r\t ";

		# TODO: make this depend on the current character set
		#       see http://en.wikipedia.org/wiki/Whitespace_character
		$chars_without_space = $chars_with_space - ( $text =~ tr/$whitespace// );
	} else {
		$words               = Wx::gettext('Skipped for large files');
		$chars_without_space = Wx::gettext('Skipped for large files');
	}

	# not set when first time to save
	# allow the upgread of ascii to utf-8
	require Padre::Locale;
	if ( not $self->{encoding} or $self->{encoding} eq 'ascii' ) {
		$self->{encoding} = Padre::Locale::encoding_from_string($text);
	}
	return (
		$lines, $chars_with_space, $chars_without_space, $words, $self->{newline_type},
		$self->{encoding}
	);
}





#####################################################################
# Document Manipulation Methods

# Delete all leading spaces.
# Passes through to the editor by default, and is only defined in the
# document class so that document classes can overload and do special stuff.
sub delete_leading_spaces {
	my $self = shift;
	my $editor = $self->editor or return;
	return $editor->delete_leading_spaces;
}

# Delete all trailing spaces.
# Passes through to the editor by default, and is only defined in the
# document class so that document classes can overload and do special stuff.
sub delete_trailing_spaces {
	my $self = shift;
	my $editor = $self->editor or return;
	return $editor->delete_trailing_spaces;
}





#####################################################################
# Unknown Methods
# Dumped here because it's not clear which section they belong in

# should return ($length, @words)
# where $length is the length of the prefix to be replaced by one of the words
# or
# return ($error_message)
# in case of some error
sub autocomplete {
	my $self   = shift;
	my $editor = $self->editor;
	my $pos    = $editor->GetCurrentPos;
	my $line   = $editor->LineFromPosition($pos);
	my $first  = $editor->PositionFromLine($line);

	# line from beginning to current position
	my $prefix = $editor->GetTextRange( $first, $pos );
	$prefix =~ s{^.*?(\w+)$}{$1};
	my $last = $editor->GetLength;
	my $text = $editor->GetTextRange( 0, $last );
	my $pre  = $editor->GetTextRange( 0, $first + length($prefix) );
	my $post = $editor->GetTextRange( $first, $last );

	my $regex = eval {qr{\b(\Q$prefix\E\w+)\b}};
	return ("Cannot build regular expression for '$prefix'.") if $@;

	my %seen;
	my @words;
	push @words, grep { !$seen{$_}++ } reverse( $pre =~ /$regex/g );
	push @words, grep { !$seen{$_}++ } ( $post =~ /$regex/g );

	if ( @words > 20 ) {
		@words = @words[ 0 .. 19 ];
	}

	return ( length($prefix), @words );
}

# Individual document classes should override this method.
# It gets a string (the current selection) and it should
# return a list of files that are possible matches to that file.
# In Perl for example A::B  would be mapped to A/B.pm in various places on
# the filesystem.
sub guess_filename_to_open {
	return;
}

# Individual document classes should override this method.
# It needs to return the document specific help topic string.
# In Perl this is using PPI to find the correct token
sub find_help_topic {
	return;
}

# Individual document classes should override this method.
# see L<Padre::Help>
sub get_help_provider {
	return;
}

sub _commafy {
	my $number = reverse shift;
	$number =~ s/(\d{3})(?=\d)/$1,/g;
	return scalar reverse $number;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
