use strict;
use warnings;
package Perl::PrereqScanner::Scanner::Moose;
use base 'Perl::PrereqScanner::Scanner';

sub scan_for_prereqs {
  my ($self, $ppi_doc, $req) = @_;

  # Moose-based roles / inheritance
  my @bases =
    map  { $self->_q_contents( $_ ) }
    grep { $_->isa('PPI::Token::Quote') || $_->isa('PPI::Token::QuoteLike') }
    map  { $_->children }
    grep { $_->child(0)->literal =~ m{\Awith|extends\z} }
    grep { $_->child(0)->isa('PPI::Token::Word') }
    @{ $ppi_doc->find('PPI::Statement') || [] };

  $req->add_minimum($_ => 0) for @bases;
}

1;
