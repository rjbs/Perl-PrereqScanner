package Perl::PrereqScanner::Scanner::Moose;
use Moose;
with 'Perl::PrereqScanner::Scanner';
# ABSTRACT: scan for Moose sugar indicators of required modules

=head1 DESCRIPTION

This scanner will look for the following indicators:

=begin :list

* L<Moose> inheritance declared with the C<extends> keyword

* L<Moose> roles included with the C<with> keyword

=end :list

=cut

sub scan_for_prereqs {
  my ($self, $ppi_doc, $req) = @_;

  # Moose-based roles / inheritance
  my @bases =
    grep { Params::Util::_CLASS($_) }
    map  { $self->_q_contents( $_ ) }
    grep { $_->isa('PPI::Token::Quote') || $_->isa('PPI::Token::QuoteLike') }

    # This is what we get when someone does:   with('Foo');
    # The target to get at is the PPI::Token::Quote::Single.
    # -- rjbs, 2010-09-05
    #
    # PPI::Statement
    #   PPI::Token::Word
    #   PPI::Structure::List
    #     PPI::Statement::Expression
    #       PPI::Token::Quote::Single
    #   PPI::Token::Structure

    map  { $_->children }
    grep { $_->child(0)->literal =~ m{\Awith|extends\z} }
    grep { $_->child(0)->isa('PPI::Token::Word') }
    @{ $ppi_doc->find('PPI::Statement') || [] };

  $req->add_minimum($_ => 0) for @bases;
}

1;
