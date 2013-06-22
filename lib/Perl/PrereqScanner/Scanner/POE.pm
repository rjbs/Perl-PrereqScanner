use strict;
use warnings;

package Perl::PrereqScanner::Scanner::POE;
use Moose;
with 'Perl::PrereqScanner::Scanner';
# ABSTRACT: scan for POE components

=head1 DESCRIPTION

This scanner will look for POE modules included with C<use POE>

  use POE wq(Component::IRC);

=cut

sub scan_for_prereqs {
  my ($self, $ppi_doc, $req) = @_;

  # regular use and require
  my $includes = $ppi_doc->find('Statement::Include') || [];
  for my $node ( @$includes ) {
    if ( $node->module eq 'POE' ) {
      my @meat = grep {
           $_->isa('PPI::Token::QuoteLike::Words')
        || $_->isa('PPI::Token::Quote')
      } $node->arguments;

      my @components = map { $self->_q_contents($_) } @meat;
      $req->add_minimum("POE::$_" => 0) for @components;
    }
  }
}

1;
