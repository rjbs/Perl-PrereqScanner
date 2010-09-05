package Perl::PrereqScanner::Scanner::TestMore;
use Moose;
use List::AllUtils 'none';
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
