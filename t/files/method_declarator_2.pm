# From Method::Signatures t/examples/iso_date_example.t

package Foo;

use Method::Signatures;

method new($class:@_) {
    bless {@_}, $class;
}

method iso_date(
    :$year!,    :$month = 1, :$day = 1,
    :$hour = 0, :$min   = 0, :$sec = 0
)
{
    return "$year-$month-$day $hour:$min:$sec";
}

1;
