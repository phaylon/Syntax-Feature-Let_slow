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
    my @ary = qw( a b c d );
    my $val = let (@ary = qw( a b c d )) { @ary };
    is $val, 4, 'scalar context returns array count';
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
        let ($x = shift) ($y = shift) {
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

do {
    my ($x, $y) = let ($n = 17) ($m = 23) {
        is $n, 17, 'first value';
        is $m, 23, 'second value';
        let ($z = $n * 2) { $z },
        let ($z = $m * 2) { $z };
    };
    is $x, 34, 'first of nested values';
    is $y, 46, 'second of nested values';
};

sub nested_wa { let ($x) { let ($y) { let ($z) { wantarray ? 1 : 0 } } } }

do {
    my ($ls_ctx) = nested_wa;
    is $ls_ctx, 1, 'nested list context via sub';
    my $sc_ctx = nested_wa;
    is $sc_ctx, 0, 'nested scalar context via sub';
    my @foo = qw( a b c );
    is scalar(let ($x) { let ($y) { let ($z) { @foo } } }),
        3, 'nested scalar context inline';
    is_deeply [let ($x) { let ($y) { let ($z) { @foo } } }],
        [qw( a b c )], 'nested list context inline';
};

done_testing;
