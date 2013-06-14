use strict;
use warnings;

package Perl::PrereqScanner::Scanner::TestRequires;
use Moo;
with 'Perl::PrereqScanner::Scanner';
# ABSTRACT: scan for Moose sugar indicators of required modules

=head1 DESCRIPTION

This scanner will look for the following indicators:

=begin :list

* L<Moose> inheritance declared with the C<extends> keyword

* L<Moose> roles included with the C<with> keyword

=end :list

=cut
#use Data::Printer { caller_info => 1, colored => 1, };
use constant { BLANK => q{ }, NONE => q{}, TWO => 2, THREE => 3, };

sub scan_for_prereqs {
  my ($self, $ppi_doc, $req) = @_;
	my @modules;
	my @version_strings;

# looking for use Test::Requires { 'Test::Pod' => 1.46 };
  my @chunks =
	#  PPI::Statement::Include
	#    PPI::Token::Word  	'use'
	#    PPI::Token::Whitespace  	' '
	#    PPI::Token::Word  	'Test::Requires'
	#    PPI::Token::Whitespace  	' '
	#    PPI::Structure::Constructor  	{ ... }
	#      PPI::Token::Whitespace  	' '
	#      PPI::Statement
	#        PPI::Token::Quote::Single  	''Test::Pod''
	#        PPI::Token::Whitespace  	' '
	#        PPI::Token::Operator  	'=>'
	#        PPI::Token::Whitespace  	' '
	#        PPI::Token::Number::Float  	'1.46'
	#      PPI::Token::Whitespace  	' '
	#    PPI::Token::Structure  	';'
		map { [ $_->schildren ] }

		grep { $_->child(2)->literal =~ m{\A(?:Test::Requires)\z} }
		grep { $_->child(2)->isa('PPI::Token::Word') }

		grep { $_->child(0)->literal =~ m{\A(?:use)\z} }
		grep { $_->child(0)->isa('PPI::Token::Word') } @{ $ppi_doc->find('PPI::Statement::Include') || [] };

	foreach my $hunk (@chunks) {

		# looking for use Test::Requires { 'Test::Pod' => '1.46' };
		if ( grep { $_->isa('PPI::Structure::Constructor') } @$hunk ) {

			# hack for List
			my @hunkdata = @$hunk;
			foreach my $ppi_sc (@hunkdata) {
				if ( $ppi_sc->isa('PPI::Structure::Constructor') ) {
					foreach my $ppi_s ( @{ $ppi_sc->{children} } ) {
						if ( $ppi_s->isa('PPI::Statement') ) {
							foreach my $element ( @{ $ppi_s->{children} } ) {
								if (   $element->isa('PPI::Token::Quote::Single')
									|| $element->isa('PPI::Token::Quote::Double') )
								{
									my $module = $element;
									$module =~ s/^['|"]//;
									$module =~ s/['|"]$//;
									if ( $module =~ m/\A[A-Z]/ ) {
										push @modules, $module;
									}
								}
							}
						}
					}
				}
			}
		}

		# looking for use Test::Requires qw(MIME::Types);
		if ( grep { $_->isa('PPI::Token::QuoteLike::Words') } @$hunk ) {

			# hack for List
			my @hunkdata = @$hunk;

			foreach my $ppi_tqw (@hunkdata) {
				if ( $ppi_tqw->isa('PPI::Token::QuoteLike::Words') ) {

					my $operator = $ppi_tqw->{operator};
					my @type = split( //, $ppi_tqw->{sections}->[0]->{type} );

					my $module = $ppi_tqw->{content};
					$module =~ s/$operator//;
					my $type_open = '\A\\' . $type[0];

					$module =~ s{$type_open}{};
					my $type_close = '\\' . $type[1] . '\Z';

					$module =~ s{$type_close}{};
					push @modules, split( BLANK, $module );

				}
			}
		}
	}
#	p @modules;
	foreach ( 0 .. $#modules ){
	$req->add_minimum($modules[$_] => 0);# $version_strings[$_]);
	}

	return;
}


1;

