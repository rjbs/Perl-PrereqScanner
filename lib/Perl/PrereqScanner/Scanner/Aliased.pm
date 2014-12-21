use strict;
use warnings;

package Perl::PrereqScanner::Scanner::Aliased;
# ABSTRACT: scan for OO module aliases via aliased.pm

use Moose;
with 'Perl::PrereqScanner::Scanner';

=head1 DESCRIPTION

This scanner will look for aliased OO modules:

  use aliased 'Some::Long::Long::Name' => 'Short::Name';

  Short::Name->new;
  ...

=cut

sub scan_for_prereqs {
  my ($self, $ppi_doc, $req) = @_;

  # regular use and require
  my $includes = $ppi_doc->find('Statement::Include') || [];
  for my $node ( @$includes ) {
    # aliasing
    if (grep { $_ eq $node->module } qw{ aliased }) {
      # We only want the first argument to aliased
      my @args = grep {
           $_->isa('PPI::Token::QuoteLike::Words')
        || $_->isa('PPI::Token::Quote')
        } $node->arguments;

      next unless @args;
      my ($module) = $self->_q_contents($args[0]);
      $req->add_minimum($module => 0);
    }
  }
}

1;
