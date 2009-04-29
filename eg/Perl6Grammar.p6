
use v6;

grammar Property {
	rule key { 
		(\w+)
	}
	rule value { 
		(\w+)
	}
	rule entry {
		<key> '=' <value> (';')?
	}
}

my $text = "foo=bar;me=self;";
if $text ~~ /^<Property::entry>+$/ {
	"Matched".say;
} else {
	"Not Matched".say;
}