
# this is nonsensical code which is intended to
# provide a base for manually stress-testing the
# find-variable-declaration and
# rename-variable
# functions.
# TODO: Proper unit-testification

my $foo;
while (!$foo) {
  my $bar;
  foreach my $i (0..100) {
    if ($i== 5) {
      $foo = 1;
      $bar += 1;
      my @bAz;
      my $bAz;
      my $baz = 4;
      my @baz = (5);
      my %baz = qw(a b);
      for (my $j = 0; $j < @baz; $j++) {
        $#baz--;
        $#bAz--;
        $bAz[2] = "blah $baz";
        $baz = "blub ${bAz} @bAz @{bAz}
                $bAz[0] $#bAz
                $baz{foo} @baz{foo}";
        $bAz++;
        $baz{foo} = "bar";
        @baz{bar} = ("hi");
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


