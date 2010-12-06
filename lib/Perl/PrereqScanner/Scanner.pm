package Perl::PrereqScanner::Scanner;
use Moose::Role;
# ABSTRACT: something that scans for prereqs in a Perl document

=head1 DESCRIPTION

This is a role to be composed into classes that will act as scanners plugged
into a Perl::PrereqScanner object.

These classes must provide a C<scan_for_prereqs> method, which will be called
like this:

  $scanner->scan_for_prereqs($ppi_doc, $version_requirements);

The scanner should alter alter the L<Version::Requirements> object to reflect
its findings about the PPI document.

=cut

requires 'scan_for_prereqs';

# DO NOT RELY ON THIS EXISTING OUTSIDE OF CORE!
# THIS MIGHT GO AWAY WITHOUT NOTICE!
# -- rjbs, 2010-04-06
sub _q_contents {
  my ($self, $token) = @_;
  my @contents;
  if ( $token->isa('PPI::Token::QuoteLike::Words') || $token->isa('PPI::Token::Number') ) {
    @contents = $token->literal;
  } else {
    @contents = $token->string;
  }

  return @contents;
}

1;
