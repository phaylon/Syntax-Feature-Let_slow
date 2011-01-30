use strictures  1;
use Test::More  0.96;
use Test::Fatal 0.003;

use syntax qw( let );

do {
    my $val = let ($x = 4) ($y = 5) { $x * $y };
    is $val, 20, 'two vars, one line';
};

do {
    my @val = let ($x = 3) ($y = 7) { $x .. $y };
    is_deeply \@val, [3..7], 'list context';
};

do {
    my $val = let ($x = 3) ($y = 7) { $x .. $y };
    is $val, 7, 'scalar context returns last value';
};

do {
    my $val = let (($x, $y) = (3, 5)) {
        $x + $y;
    };
    is $val, 8, 'multivalue declaration';
};

do {
    my $cb  = sub { [@_] };
    my $uri = { host => 'foo.com', path => '/bar' };
    is_deeply
        $cb->(let ($u = $uri) { $u->{host}, $u->{path} }, 23),
        [qw( foo.com /bar 23 )],
        'expression embedding';
};

do {
    my $val = let ($x = 3) ($y = $x * $x) { $y };
    is $val, 9, 'access to previous declaration';
};

do {
    my $add = sub {
        let ($x = shift)
            ($y = shift) {
            return $x + $y unless shift;
            'inner-fallback';
        };
        'outer-return';
    };
    my $val = $add->(11, 12);
    is $val, 23, 'return from outer scope';
    my $no_ret = $add->(11, 12, 1);
    is $no_ret, 'outer-return', 'normal return';
};

done_testing;
