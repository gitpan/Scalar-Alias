#!perl -w

use strict;
use Test::More tests => 4;

use Scalar::Alias;

my %h;
my alias $x = $h{x};

$x = 10;
is $x, 10;
is_deeply \%h, {x => 10}, 'hash element (defer)';

my @a;
my alias $y = $a[0];
$y = 42;
is $y, 42;
is_deeply \@a, [42], 'array element (defer)';
