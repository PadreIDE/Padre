# From Method::Signatures t/examples/strip_ws.t

package Foo;

use Method::Signatures;

method strip_ws($str is alias) {
    $str =~ s{^\s+}{};
    $str =~ s{\s+$}{};
    return;
}

1;

