
# this is nonsensical code which is intended to
# provide a base for manually stress-testing the
# find-variable-declaration and
# lexical-variable-replace
# functions.
# TODO: Proper unit-testification

my $foo;
while (!$foo) {
  my $bar;
  for(my $i=0; $i < 100; $i++) {
    if ($i== 5) {
      $foo = 1;
      $bar += 1;
      my @bAz;
      my $bAz;
      my $baz = 4;
      my @baz = (5);
      for (my $j = 0; $j < @baz; $j++) {
        $#baz--;
        $#bAz--;
        $bAz[2] = "blah $baz";
        $baz = "blub ${bAz} @bAz @{bAz}
                $bAz[0] $#bAz";
        $bAz++;
      }
    }
  }
  if ($ARGV[0]) {
    print "hi";
  }
  if (rand() < 0.2) {
    $foo = 0;
    $bar -= 1;
  }
}


