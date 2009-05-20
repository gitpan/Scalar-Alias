#!perl -w

use strict;
use constant HAS_LEAKTRACE => eval{ require Test::LeakTrace };
use Test::More HAS_LEAKTRACE ? (tests => 2) : (skip_all => 'Testing leaktrace');
use Test::LeakTrace;

use Scalar::Alias;

no_leaks_ok{
	my $x = 10;
	my alias $y = $x;

	$x++;
	$y++;
};

sub inc{
	my alias $x = shift;
	$x++;
}

no_leaks_ok{
	my $i = 0;
	inc($i);
};
