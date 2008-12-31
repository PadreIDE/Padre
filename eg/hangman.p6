#
# Written by Ovid
# http://use.perl.org/~Ovid/journal/38191
#

use v6;

class Hangman {
    has $.wordlist;

    has $!word           is rw;
    has $!finished       is rw;
    has @!man            is rw;
    has @!bodyparts      is rw;
    has $!num_misses     is rw = 0;
    has @!guess          is rw;
    has %!missed_letters is rw;
    has $!state          is rw;

    subset Letter of Str where { $_ ~~ /^ <[a..z]> $/ };

    method init() {
        my @words = =open($.wordlist);
        my $attempts = 0;

        repeat until self!valid_word or $attempts > 100 {
            $attempts++;
            $!word = @words.pick;
        }

        if $attempts > 100 {
            die "Quit trying to find valid word in ($.wordlist) after 100 tries";
        }
        @!man = (
            [ < + - - - - - + >   ],
            [ '|', ' ' xx 5, '|'  ],
            [ '|', ' ' xx 5, '|'  ],
            [ '|', ' ' xx 5, '|'  ],
            [ < + - - - - - + >   ],
        );
        @!bodyparts = (
            [ 2, 3, '|' ],    # torso
            self!shuffle(
                [ 2, 2, '-'  ],     # left arm
                [ 2, 4, '-'  ],     # right arm
                [ 3, 2, '/'  ],     # left leg
                [ 3, 4, '\\' ],     # right leg '
            ),
            [ 1, 3, 'o' ],
        );
        @!guess = '_' xx $!word.chars;
        $!state = join("\n", self!render_man, self!render_guess) ~ "\n";
    }

    # Letter $letter is broken
    method guess_letter ($letter) {
        say "You guessed '$letter'";

        if %!missed_letters.exists($letter) {
            warn "You've already guessed '$letter'\n";
            return;
        }
        if $!finished {
            warn $!state;
            return;
        }

        my @found;
        my @letters = $!word.split('');
        my $ord = $letter.ord;
        for 0..(@letters.elems - 1) -> $i {
            if @letters[$i].ord == $ord {
                @found.push($i);
            }
        }
        #if not $!word ~~ /$letter/ {
        if not @found.elems {
            %!missed_letters{$letter} = 1;
            self!handle_bad_guess;
            return;
        }
        else {
            self!handle_good_guess($letter, @found);
            return 1;
        }
    }

    my method handle_bad_guess {
        my $part = @!bodyparts.shift;
        @!man[ $part[0] ][ $part[1] ] = $part[2];

        if not @!bodyparts.elems {
            $!state = "You've been hanged!  The word was '$!word'\n"
                ~ self!build_state;
            $!finished = 1;
        }
        else {
            $!state = "Wrong!\n" ~ self!build_state;
        }
    }

    my method build_state {
        return sprintf "%s\n%s\nMissed: %s\n",
            self!render_man,
            self!render_guess,
            join( ' ', %!missed_letters.keys.sort );
    }

    my method handle_good_guess ($letter, @found) {

        @!guess[@found] = $letter xx @found.elems;

        if not grep { $_ eq '_' }, @!guess {
            $!state = "You won!  The word was '$!word'\n"
                ~ self!build_state;
            $!finished = 1;
        }
        else {
            $!state = "Right!\n" ~ self!build_state;
        }
    }

    my method render_guess () {
        return @!guess.join(' ');
    }

    my method render_man () {
        my $man;
        for @!man -> $array {
            $man ~= $array.join('') ~ "\n";
        }
        return $man;
    }

    # XXX File bug report on slurpy copy
    #my method shuffle (*@items is copy) {
    my method shuffle (*@items) {
        # Fisher-Yates shuffle
        my $i = @items.elems;
        while ($i) {
            my $j = $i.rand.int;
            $i--;
            @items[ $i, $j ] = @items[ $j, $i ];
        }
        return @items;
    }

    my method valid_word () {
        return $!word ~~ /^ <[a..z]> ** 6..* $/;
    }

    method get_word () {
        return $!word;
    }

    method is_hung () {
        return not @!bodyparts.elems;
    }

    method to_string () {
        return $!state;
    }
}

my $man = Hangman.new( wordlist => './wordlist' );
$man.init();

for <m a b c d e i s p> -> $letter {
    $man.guess_letter($letter);
    say $man.to_string;
}