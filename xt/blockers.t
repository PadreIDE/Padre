# Test for open blocker tickets

use strict;
use warnings;

use Test::More;
use LWP::UserAgent;

# Don't run tests for installs
unless ( $ENV{AUTOMATED_TESTING} or $ENV{RELEASE_TESTING} ) {
	plan( skip_all => "Author tests not required for installation" );
}

plan tests => 2;

my $ua = LWP::UserAgent->new;
$ua->timeout(30);
$ua->env_proxy;

my $response = $ua->get(
	'http://padre.perlide.org/trac/query?priority=blocker&status=accepted&status=assigned&status=new&status=reopened&col=id&order=priority'
);
ok( $response->is_success, 'Got HTTP status OK' );

# Count the number of blockers
# once this is working properly, for now we'll just check if we get No tickets found
# my $tickets = () = $response->decoded_content, qr/<a href="?\/trac\/ticket\/(\d+)"?[^>]*>\#\1<\/a/;
#is( $tickets, 0, 'No open blocker tickets' );

$response->content =~ m!(No tickets found)!;
my $tickets = $1;

is( $tickets, "No tickets found", 'No open blocker tickets' );

