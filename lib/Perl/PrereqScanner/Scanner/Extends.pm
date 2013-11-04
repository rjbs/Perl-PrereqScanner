use strict;
use warnings;

package Perl::PrereqScanner::Scanner::Extends;
# ABSTRACT: scan for extends in MooseX::Declare

use Moo;
with 'Perl::PrereqScanner::Scanner';

=head1 DESCRIPTION

This scanner will look for MooseX::Declare and extract only the
B<extends> after class

  use MooseX::Declare;
    class Finance::Bank::Bankwest::Error
    extends Throwable::Error { ... }

=cut

use constant {FALSE => 0, TRUE => 1,};

sub scan_for_prereqs {
  my ($self, $ppi_doc, $req) = @_;
  my @modules;
  my @version_strings;

#PPI::Document
#  PPI::Statement::Include
#    PPI::Token::Word  	'use'
#    PPI::Token::Whitespace  	' '
#    PPI::Token::Word  	'MooseX::Declare'
#    PPI::Token::Structure  	';'

  my $ppi_tw = $ppi_doc->find('PPI::Token::Word');
  return if not ref $ppi_tw;# handel empty string test
  my $mxd    = FALSE;

  foreach my $token_word (@$ppi_tw) {
    $mxd = TRUE if ($token_word->content eq 'MooseX::Declare');
  }

# no 'MooseX::Declare' so let's not waist any more time
  if ($mxd eq TRUE) {

#  PPI::Statement
#    PPI::Token::Word  	'class'
#    PPI::Token::Whitespace  	' '
#    PPI::Token::Word  	'Finance::Bank::Bankwest::Error'
#    PPI::Token::Whitespace  	'\n'
#    PPI::Token::Whitespace  	'    '
#    PPI::Token::Word  	'extends'
#    PPI::Token::Whitespace  	' '
#    PPI::Token::Word  	'Throwable::Error'
#    PPI::Token::Whitespace  	' '
#    PPI::Structure::Block  	{ ... }

# ok so we do it again, but we are on the hunt
    my @words;
    foreach my $token_word (@$ppi_tw) {
      push @words, $token_word->content;
    }

# the pattern is the word following extends is what we want
    foreach (0 .. $#words) {
      if ($words[$_] eq 'extends') {
        push @modules, $words[$_ + 1];
      }
    }

    foreach (0 .. $#modules) {
      $req->add_minimum($modules[$_] => 0);
    }
  }
  return;
}

1;

__END__

