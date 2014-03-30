use 5.008003;
use strict;
use warnings;

package Exporter::LexicalVars;

use B qw();
use B::Hooks::Parser qw();
use Carp qw(croak);
use Exporter::Shiny qw(import);

our $AUTHORITY   = 'cpan:TOBYINK';
our $VERSION     = '0.000_01';
our %EXPORT_TAGS = ( setup => [qw(import)] );
our @INIT;

sub _generate_import {
	my $me = shift;
	my ($name, $args, $globals) = @_;
	my $caller = $globals->{into};
	
	(my $nominal_file = $caller) =~ s(::)(/)g;
	$INC{"$nominal_file\.pm"} ||= __FILE__;
	
	my $inject = ';';
	for my $var (sort keys %$args)
	{
		unless ($var =~ /\A[\$\@\%][^\W0-9]\w*\z/)
		{
			croak("Not a legal name for a lexical variable: '$var'");
		}
		
		my $value = $args->{$var};
		
		if ($var =~ /\A[\@\%]/ and defined($value) and not ref($value))
		{
			croak("Cannot initialize $var from a scalar value");
		}
		
		if (!ref($value))
		{
			$inject .= sprintf(
				'my(%s)=(%s);',
				$var,
				defined($value) ? B::perlstring($value) : '',
			);
		}
		elsif (ref($value) eq q(CODE))
		{
			push @INIT, $value;
			my $init = $#INIT;
			$inject .= sprintf(
				'my(%s);$%s::INIT[%d]->(\\%s, %s);',
				$var,
				__PACKAGE__,
				$init,
				$var,
				B::perlstring($var),
			);
		}
		else
		{
			croak("Cannot initialize $var from reference of type " . ref($value));
		}
	}
	
	return sub { B::Hooks::Parser::inject($inject) };
}

1;

__END__

=pod

=encoding utf-8

=for stopwords initializer initializers

=head1 NAME

Exporter::LexicalVars - export lexical variables

=head1 SYNOPSIS

	BEGIN {
		package MyVars;
		use Exporter::LexicalVars -setup => {
			'$pi'   => 3.14159,
			'$foo'  => sub {
				my $ref = shift;
				$$ref = "Hello world";
			},
		};
	};
	
	use Data::Dumper;
	
	my $pi = 3;
	
	{
		use MyVars;
		print Dumper($pi);     # 3.14159
		print Dumper($foo);    # Hello world
	}
	
	print Dumper($pi);        # 3

=head1 DESCRIPTION

Exports lexical (C<my>) variables.

In the setup hashref, you can provide either non-reference values to
define in the caller's lexical context, or you can provide initializers
as coderefs.

Initializers are called with a reference to the variable which has been
defined in the caller's lexical context. You can use that reference to not
just assign it a value, but potentially mark the variable as read-only, or
tie the variable, or whatever.

Lexical scalar, array and hash variables are each supported. In the case
of arrays and hashes, providing C<undef> in the setup hashref will
initialize them to empty, but otherwise you must initialize them with
an initializer coderef; not a non-reference scalar value.

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=Exporter-LexicalVars>.

=head1 SEE ALSO

L<Exporter::Tiny>, L<Exporter>, L<Sub::Exporter>, L<perldata>.

L<http://www.perlmonks.org/?node_id=1080253>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2014 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

