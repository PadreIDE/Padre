# put stuff in GLOBAL package
use Foo;
require Bar;

sub foo-sub { }
method foo-method { }
submethod foo_submethod { }
macro foo_macro { }
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
	constant $PI = 22/7;
	
	my $.foo;
	our $!foo;

	has $field1 is rw;
	has $.public is rw;
	has $!private is rw;

	use Bar;
	
	sub foo_sub { }
	method !private_method {}
	method ^how_method { }
	method foo_method { }
	submethod foo_submethod { }
	macro foo_macro { }
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

#A grammar example
grammar Person {
         rule name { 
         	Name '=' (\N+) 
         }
         rule age  { 
         	Age  '=' (\d+) 
         }
         rule desc {
             <name> \n
             <age>  \n
         }
         # etc.
}

#A module example
module Foo1 {
	sub foo_sub { }
	method foo_method { }
	submethod foo_submethod { }
	macro foo_macro { }
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

#A package example
package FooPackage {
	sub foo_sub { }
	method foo_method { }
	submethod foo_submethod { }
	macro foo_macro { }
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

#A role example
role Pet {
        method feed ($food) {
            $food.open_can;
            $food.put_in_bowl;
            self.eat($food);
        }
}

#a slang example
slang FooSlang {
	token foo_token { 
		<sym> 
	}
}

#a knowhow example
knowhow FooKnowHow {
	token foo_token { 
		<sym> 
	}
}