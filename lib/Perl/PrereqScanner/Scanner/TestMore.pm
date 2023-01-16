use strict;
use warnings;

package Perl::PrereqScanner::Scanner::TestMore;
# ABSTRACT: scanner to find recent Test::More usage

use Moo;
use List::Util 1.33 'none';
with 'Perl::PrereqScanner::Scanner';

sub scan_for_prereqs {
  my ($self, $ppi_doc, $req) = @_;

  return if none { $_ eq 'Test::More' } $req->required_modules;

  $req->add_minimum('Test::More' => '0.88') if grep {
      $_->isa('PPI::Token::Word') && $_->content eq 'done_testing';
  } map {
      my @c = $_->children;
      @c == 1 ? @c : ()
  } @{ $ppi_doc->find('Statement') || [] }
}

1;

__END__

=head1 DESCRIPTION

This scanner will check if a given test is using recent functions from
L<Test::More>, and increase the minimum version for this module
accordingly.

