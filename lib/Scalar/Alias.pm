package Scalar::Alias;

use 5.008_001;
use strict;
#use warnings;

our $VERSION = '0.02';

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

1;
__END__

=head1 NAME

Scalar::Alias - Perl extention to declare lexical aliases

=head1 VERSION

This document describes Scalar::Alias version 0.02.

=head1 SYNOPSIS

	use Scalar::Alias;

	sub inc{
		my alias $x = shift;
		$x++;
		return;
	}

	my $i = 0;
	inc($i);
	print $i, "\n"; # => 1

=head1 DESCRIPTION

Scalar::Alias allows you to declare lexical aliases.

There are many modules that provides variable aliases, but this module is
faster than any other alias modules, because it walks into compiled syntax
trees and inserts custom alias opcodes into the syntax tree.

=head1 DEPENDENCIES

Perl 5.8.1 or later, and a C compiler.

=head1 BUGS

No bugs have been reported.

Please report any bugs or feature requests to the author.

=head1 SEE ALSO

L<Scalar::Types>.

L<perltodo/"lexical aliases">.

Other alias modules:

L<Lexical::Alias>.

L<Lexical::Util>

L<Devel::LexAlias>.

L<Tie::Alias>.

L<Variable::Alias>.

=head1 AUTHOR

Goro Fuji (gfx) E<lt>gfuji(at)cpan.orgE<gt>.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2009, Goro Fuji (gfx). Some rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
