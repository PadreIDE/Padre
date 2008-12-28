#!/usr/bin/perl 
use strict;
use warnings;


print is_foo_or_bar(), "\n";
sub is_foo_or_bar {
	return foo() or bar();
}
sub foo {
	return 0;
}
sub bar {
    return 42;
}

# problem: the above will print 0 despite it being false
# that is because return has higher precedence than 'or'
# || should be used instead of 'or'
