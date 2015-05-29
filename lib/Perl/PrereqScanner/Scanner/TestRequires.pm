use strict;
use warnings;

package Perl::PrereqScanner::Scanner::TestRequires;

# ABSTRACT: scan for modules in Test::Requires

use Moo;
with 'Perl::PrereqScanner::Scanner';

use Try::Tiny;

=head1 DESCRIPTION

This scanner is for identifying modules considered as suggests in test files

Only use against test files in t/ to indicate: 

	prereqs => { 
		runtime => { 
			suggests => { ... 

as per https://metacpan.org/module/CPAN::Meta::Spec

=cut

use constant {BLANK => q{ }, NONE => q{}, TWO => 2, THREE => 3,};

sub scan_for_prereqs {
	my ($self, $ppi_doc, $req) = @_;
	my @modules;
	my @version_strings;

# looking for use Test::Requires { 'Test::Pod' => 1.46 };

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

try {
	my @chunks = @{$ppi_doc->find('PPI::Statement::Include') || []};

	foreach my $hunk (@chunks) {

		# test for use
		if (
			$hunk->find(
				sub {
					$_[1]->isa('PPI::Token::Word') and $_[1]->content =~ m{\A(?:use)\z};
				}
			)
			)
		{

			# test for Test::Requires
			if (
				$hunk->find(
					sub {
						$_[1]->isa('PPI::Token::Word')
							and $_[1]->content =~ m{\A(?:Test::Requires)\z};
					}
				)
				)
			{

				foreach ( 0 .. $#{$hunk->{children}}) {

					# looking for use Test::Requires { 'Test::Pod' => '1.46' };
					if ($hunk->{children}[$_]->isa('PPI::Structure::Constructor')) {

						my $ppi_sc = $hunk->{children}[$_]
							if $hunk->{children}[$_]->isa('PPI::Structure::Constructor');

						foreach (0 .. $#{$ppi_sc->{children}}) {

							if ($ppi_sc->{children}[$_]->isa('PPI::Statement')) {

								my $ppi_s = $ppi_sc->{children}[$_]
									if $ppi_sc->{children}[$_]->isa('PPI::Statement');

								foreach my $element (@{$ppi_s->{children}}) {

									# extract module name
									if ( $element->isa('PPI::Token::Quote::Double')
										|| $element->isa('PPI::Token::Quote::Single')
										|| $element->isa('PPI::Token::Word'))
									{
										my $module_name = $element->content;
										$module_name =~ s/(?:'|")//g;

										push @modules, $module_name
											if $module_name =~ m/\A(?:[A-Z])/;
									}

									# extract version string
									if ( $element->isa('PPI::Token::Number::Float')
										|| $element->isa('PPI::Token::Quote::Double')
										|| $element->isa('PPI::Token::Quote::Single'))
									{
										my $version_string = $element->content;
										$version_string =~ s/(?:'|")//g;
										if ($version_string =~ m/\A(?:[0-9])/) {
											$version_string = version::is_lax($version_string) ? $version_string : 0;
											$version_strings[$#modules] = $version_string;
										}
									}
								}
							}
						}
					}

					# looking for use Test::Requires qw(MIME::Types);
					if ($hunk->{children}[$_]->isa('PPI::Token::QuoteLike::Words')) {

						my $ppi_tqw = $hunk->{children}[$_]
							if $hunk->{children}[$_]->isa('PPI::Token::QuoteLike::Words');

							my $operator = $ppi_tqw->{operator};
							my @type = split(//, $ppi_tqw->{sections}->[0]->{type});

							my $module = $ppi_tqw->{content};
							$module =~ s/$operator//;
							my $type_open = '\A\\' . $type[0];

							$module =~ s{$type_open}{};
							my $type_close = '\\' . $type[1] . '\Z';

							$module =~ s{$type_close}{};
							push @modules, split(BLANK, $module);

					}
				}
			}
		}
	}

	};

	foreach (0 .. $#modules) {
		$req->add_minimum(
			$modules[$_] => $version_strings[$_] ? $version_strings[$_] : 0);
	}

	return;
}


1;

