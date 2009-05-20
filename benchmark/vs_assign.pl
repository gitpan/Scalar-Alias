#!perl -w

use strict;
use Benchmark qw(:all);

use Scalar::Alias;

print "For integer\n";
my @integers = ((42) x 100);
cmpthese -1 => {
	alias => sub{
		for my $i(@integers){
			my alias $x = $i;
		}
	},
	assign => sub{
		for my $i(@integers){
			my $x = $i;
		}
	},
};

print "For string\n";
my @strings = (('foo') x 100);
cmpthese -1 => {
	alias => sub{
		for my $i(@strings){
			my alias $x = $i;
		}
	},
	assign => sub{
		for my $i(@strings){
			my $x = $i;
		}
	},
};

print "For object reference\n";
my @refs = ((bless{}) x 100);
cmpthese -1 => {
	alias => sub{
		for my $i(@refs){
			my alias $x = $i;
		}
	},
	assign => sub{
		for my $i(@refs){
			my $x = $i;
		}
	},
};
