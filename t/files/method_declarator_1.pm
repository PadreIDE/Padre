# From http://contourline.wordpress.com/2010/01/27/better-post-on-moosexdeclare-method-signatures/

use strict;
use warnings;
use MooseX::Declare;
class Holiday::California {
    use DateTime;
    use Carp;
    has '_ca_state_holidays' => (
        'is'      => 'ro',
        'isa'     => 'HashRef',
        'builder' => '_build__ca_state_holidays'
    );
    method _build__ca_state_holidays {
        return {
            '2007/01/01' => q{New Year's Day},
            '2007/01/15' => q{Martin Luther King Jr. Day},
            '2007/02/12' => q{Lincoln's Birthday},
            '2007/02/19' => q{Washington's Birthday},
            '2007/05/28' => q{Memorial Day},
            '2007/07/04' => q{Independence Day},
            '2007/09/03' => q{Labor Day},
            '2007/10/08' => q{Columbus Day},
            '2007/11/12' => q{Veteran's Day (observed)},
            '2007/11/22' => q{Thanksgiving Day},
            '2007/11/23' => q{Day after Thanksgiving},
            '2007/12/24' => q{Christmas Eve},
            '2007/12/25' => q{Christmas Day},
        };
    }
    method is_holiday_or_weekend  ( $dt ) {
        confess if (! $dt->isa('DateTime') );
        if ( $dt->day_abbr =~ /sun|sat/isxm ) {
            return 1;
        }
        elsif (
            defined $self->_ca_state_holidays->{ $dt->ymd('/') } )
        {
            return 1;
        }
        return 0;
    }
}
1;
