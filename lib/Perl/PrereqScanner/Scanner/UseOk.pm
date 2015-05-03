use strict;
use warnings;

package Perl::PrereqScanner::Scanner::UseOk;

# ABSTRACT: scan for module names in use_ok BEGIN blocks

use Moo;
with 'Perl::PrereqScanner::Scanner';
use Tie::Static qw(static);
use Try::Tiny;
use Data::Printer {caller_info => 1, colored => 1,};


=head1 DESCRIPTION

This scanner will look for the following formats or variations there in,
inside BEGIN blocks in test files:

=begin :list

* use_ok( 'Fred::BloggsOne', '1.01' );

* use_ok( "Fred::BloggsTwo", "2.02" );

* use_ok( 'Fred::BloggsThree', 3.03 );

=end :list

=cut

use constant {BLANK => q{ }, NONE => q{}, TWO => 2, THREE => 3,};

sub scan_for_prereqs {
	my ($self, $ppi_doc, $req) = @_;
	my @modules;
	my @version_strings;

	#PPI::Document
	#  PPI::Statement::Scheduled
	#    PPI::Token::Word  	'BEGIN'
	#    PPI::Token::Whitespace  	' '
	#    PPI::Structure::Block  	{ ... }
	#      PPI::Token::Whitespace  	'\n'
	#      PPI::Token::Whitespace  	'\t'
	#      PPI::Statement
	#        PPI::Token::Word  	'use_ok'
	#        PPI::Structure::List  	( ... )
	#          PPI::Token::Whitespace  	' '
	#          PPI::Statement::Expression
	#            PPI::Token::Quote::Single  	''Term::ReadKey''
	#            PPI::Token::Operator  	','
	#            PPI::Token::Whitespace  	' '
	#            PPI::Token::Quote::Single  	''2.30''

	try {
		my @chunks =

			map  { [$_->schildren] }
			grep { $_->child(0)->literal =~ m{\A(?:BEGIN)\z} }
			grep { $_->child(0)->isa('PPI::Token::Word') }
			@{$ppi_doc->find('PPI::Statement::Scheduled') || []};

		foreach my $hunk (@chunks) {

			# looking for use_ok { 'Term::ReadKey' => '2.30' };
			if (grep { $_->isa('PPI::Structure::Block') } @$hunk) {

				# hack for List
				my @hunkdata = @$hunk;
				foreach my $ppi_sb (@hunkdata) {
					if ($ppi_sb->isa('PPI::Structure::Block')) {
						foreach my $ppi_s (@{$ppi_sb->{children}}) {
							if ($ppi_s->isa('PPI::Statement')) {
								if ($ppi_s->{children}[0]->content eq 'use_ok') {
									my $ppi_sl = $ppi_s->{children}[1];
									foreach my $ppi_se (@{$ppi_sl->{children}}) {
										if ($ppi_se->isa('PPI::Statement::Expression')) {
											foreach my $element (@{$ppi_se->{children}}) {
												static \my $previous_module;

												if ( $element->isa('PPI::Token::Quote::Single')
													|| $element->isa('PPI::Token::Quote::Double'))
												{
													my $module = $element;
													$module =~ s/^['|"]//;
													$module =~ s/['|"]$//;
													if ($module =~ m/\A[A-Z]/) {
														push @modules, $module;
														$previous_module = $module;
													}
												}
												if ( $element->isa('PPI::Token::Number::Float')
													|| $element->isa('PPI::Token::Quote::Single')
													|| $element->isa('PPI::Token::Quote::Double'))
												{

													my $version_string = $element->content;

													$version_string =~ s/^['|"]//;
													$version_string =~ s/['|"]$//;
													next if $version_string !~ m/\A[\d|v]/;

													$version_string
														= version::is_lax($version_string)
														? $version_string
														: 0;

													try {
														$version_strings[$#modules] = $version_string
															if $previous_module;
														$previous_module = undef;
													};
												}
											}
										}
									}
								}
							}
						}
					}
				}
			}
		}
	};

# convert undef to 0
	for (0 .. $#version_strings) {
		$version_strings[$_] = 0 if not defined $version_strings[$_];
	}

	foreach (0 .. $#modules) {
		$req->add_minimum(
			$modules[$_] => $version_strings[$_] ? $version_strings[$_] : 0);

	}

	return;
}

1;

__END__

