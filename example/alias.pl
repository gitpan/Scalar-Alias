#!perl -w

use strict;
use Devel::Peek;
use Scalar::Alias;

sub foo{
	my alias $foo = shift;

	Dump($foo);
}

foo(42);
foo(undef);
