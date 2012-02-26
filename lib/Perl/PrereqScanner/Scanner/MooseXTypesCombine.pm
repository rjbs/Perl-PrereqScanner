use strict;
use warnings;

package Perl::PrereqScanner::Scanner::MooseXTypesCombine;
use Moose;
with 'Perl::PrereqScanner::Scanner';
# ABSTRACT: scan for type libraries exported with MooseX::Types::Combine

use List::Util qw( first );
use Params::Util ();

=head1 DESCRIPTION

This scanner will look for L<MooseX::Types> libraries
exported via L<MooseX::Types::Combine>.

  package MyTypes;
  use parent 'MooseX::Types::Combine';

  __PACKAGE__->provide_types_from(qw(
    MooseX::Types::Moose
    MooseX::Types::Path::Class
  ));

=cut

sub scan_for_prereqs {
  my ($self, $ppi_doc, $req) = @_;
  my @mxtypes;

  # NOTE: The docs for PPI::Statement say that the package/namespace stuff is not there yet.

  # TODO: What we probably should be doing:
  # * find package declaration
  # * check for base/parent/isa
  # * find provide_types_from
  # * find quoted words

  # TODO: make sure MXTC is included in the prereqs
  return unless $self->_inherits_from_moosex_types_combine($ppi_doc);

  # foreach $package {
    # TODO: is this the most optimal query to perform first?
    # TODO: is this the only way to use MXTC?
    # TODO: find all Statements, then look for this beneath?

    # find the method call that sets the types being exported
    my $methods = $ppi_doc->find(sub {
      $_[1]->isa('PPI::Token::Word') and $_[1]->content eq 'provide_types_from'
    }) || [];

    # TODO: confirm we're in a package that inherits from MXTC

    # parse the statements that contain the method call we just searched for
    push @mxtypes, $self->_parse_mxtypes_from_statement($_)
      for map { $_->parent } @$methods;

    $req->add_minimum($_ => 0) for @mxtypes;
  #}
}

# There should be a 'use base', 'use parent', or '@ISA = ' (or 'push @ISA')
# somewhere that includes MooseX::Types::Combine.
sub _inherits_from_moosex_types_combine {
  my ($self, $ppi_doc) = @_;

  # FIXME: this is incredibly naive and should be way more robust.
  # FIXME: is it in fact better than nothing?

  # Short-circuit if that class name doesn't appear in the doc.
  return $ppi_doc->find_any(sub {
    (
      $_[1]->isa('PPI::Token::QuoteLike::Words') ||
      $_[1]->isa('PPI::Token::Quote')
    ) &&
      first { $_ eq 'MooseX::Types::Combine' } $self->_q_contents($_[1])
  });
}

sub _parse_mxtypes_from_statement {
  my ($self, $statement) = @_;

  # this is naive and very specific but it matches the MXTC synopsis
  my $wanted = [
    [ Word     => '__PACKAGE__' ],
    [ Operator => '->' ],
    [ Word     => 'provide_types_from' ],
  ];

  my @tokens = $statement->schildren;
  my $i = 0;
  foreach my $token ( @tokens ){
    my ($type, $content) = @{ $wanted->[$i++] };
    return
      unless $token->isa('PPI::Token::' . $type)
        and $token->content eq $content;
    last if $i == @$wanted;
  }

  # the list passed to this method is what we are looking for
  my $list = $tokens[$i];
  return
    unless $list && $list->isa('PPI::Structure::List');

  my $words = $list->find(sub {
    $_[1]->isa('PPI::Token::QuoteLike::Words') ||
    $_[1]->isa('PPI::Token::Quote')
  }) || [];

  return
    grep { Params::Util::_CLASS($_) }
    map  { $self->_q_contents($_) }
      @$words;
}

1;
