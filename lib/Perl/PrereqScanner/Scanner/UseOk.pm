use strict;
use warnings;

package Perl::PrereqScanner::Scanner::UseOk;
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

#use Data::Printer {caller_info => 1, colored => 1,};
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
                      if ( $element->isa('PPI::Token::Quote::Single')
                        || $element->isa('PPI::Token::Quote::Double'))
                      {
                        my $module = $element;
                        $module =~ s/^['|"]//;
                        $module =~ s/['|"]$//;
                        if ($module =~ m/\A[A-Z]/) {
                          push @modules, $module;
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
  }

#  p @modules;
  foreach (0 .. $#modules) {
    $req->add_minimum($modules[$_] => 0);    # $version_strings[$_]);
  }

  return;
}


1;


