#!perl -w

use Test qw(plan ok);

plan tests => 4;

use Perl::API;

$a = "abc";

ok(SvCUR($a), 3);
ok(SvLEN($a), 4);

SvCUR_set($a, 1);
ok($a, "a");

SvCUR_set($a, 4);
ok($a, "abc\0");

