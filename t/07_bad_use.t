#!perl -w

use strict;
use Test::More tests => 3;

use Scalar::Alias;

eval q{
	my alias $x;
};
like $@, qr/Cannot declare my alias \$x without assignment/;

eval q{
	my alias $x->{foo} = 10;
};
like $@, qr/Cannot declare my alias \$x with dereference/;

eval q{
	my alias $x = 10;
	$x++;
};
like $@, qr/read-only/;
