package Padre::ErrorParser;

use strict;
use warnings;

sub parse_string {
    my $string = shift;
    
    my @error_list;
    my $in_near;
    
    my @lines = split(/\n/, $string);
    
    foreach my $line (@lines) {
	$line =~ s/\r/ /g;
	print "STARTofLINE:\n" . $line . "\n:ENDofLINE\nIN_NEAR: " . $in_near . "\n";
	
	if (!$in_near) {
	    if ($line =~ /^(.*)\sat\s(.*)\sline\s(\d+)(\.|,\snear\s\"(.*)(\")*)$/) {
		my %err_item = (
		    message => $1,
		    file    => $2,
		    lineno  => $3,
		);
		my $near     = $5;
		my $near_end = $6;
		
	
		if ($near and !$near_end) {
		    $in_near = $near; 
		} elsif ($near and $near_end) {
		    $err_item{near} = $near;
		}
		push @error_list, \%err_item;
	    } 
	
	} else {
	    if ($line =~ /^(.*)\"$/) {
		$in_near .= $1;
		$error_list[-1]->{near} = $in_near;
		$in_near = "";
	    } else {
		$in_near .= $line;
	    }
	}
    }
    return @error_list;
}

1;