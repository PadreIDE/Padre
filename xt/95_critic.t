use strict;
use warnings;

use Test::More;
plan skip_all => 'Test::Perl::Critic required to criticise code' if not eval "use Test::Perl::Critic; 1";
all_critic_ok('blib/lib/Padre', 't');

