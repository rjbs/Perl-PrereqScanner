package Perl::PrereqScanner::Scanner;
use Moose::Role;

# DO NOT RELY ON THIS EXISTING OUTSIDE OF CORE!
# THIS MIGHT GO AWAY WITHOUT NOTICE!
# -- rjbs, 2010-04-06
sub _q_contents {
  my ($self, $token) = @_;
  my @contents = $token->isa('PPI::Token::QuoteLike::Words')
    ? ( $token->literal )
    : ( $token->string  );

  return @contents;
}

1;
