use Foo;
require Bar;

sub foo_sub {
}

method foo_method {
}

submethod foo_submethod {
}

macro foo_macro {
}

regex foo_regex {
	<sym> 
}

token foo_token {
	<sym>  
}
rule foo_rule {
	<foo_rule> <foo_token>
}
 
#A class example 
class FooClass {
	
	use Bar;
	
	sub foo_sub {
	}
	
	method foo_method {
	}
	
	submethod foo_submethod {
	}
	
	macro foo_macro {
	}
	
	regex foo_regex {
		<sym> 
	}
	
	token foo_token {
	 	<sym>  
	}
	rule foo_rule {
		<foo_rule> <foo_token>
	}
} 

#An grammar example
#grammar foo_grammar {
#} 

#An role example
#role FooRole {
#};
 
# a package example
package FooPackage;

sub foo_sub {
}

method foo_method {
}

submethod foo_submethod {
}

macro foo_macro {
}

regex foo_regex {
	<sym> 
}

token foo_token {
	<sym>  
}
rule foo_rule {
	<foo_rule> <foo_token>
}
