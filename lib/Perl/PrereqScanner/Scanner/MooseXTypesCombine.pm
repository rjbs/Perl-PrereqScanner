use strict;
use warnings;

package Perl::PrereqScanner::Scanner::MooseXTypesCombine;
use Moose;
with 'Perl::PrereqScanner::Scanner';
# ABSTRACT: scan for type libraries exported with MooseX::Types::Combine

use Params::Util ();

=head1 DESCRIPTION

This scanner will look for L<MooseX::Types> libraries
exported via L<MooseX::Types::Combine>.

  package MyTypes
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

  # foreach $package {
    # TODO: is this the most optimal query to perform first?
    # TODO: is this the only way to use MXTC?
    # TODO: find all Statements, then look for this beneath?
    my $methods = $ppi_doc->find(sub {
      $_[1]->isa('PPI::Token::Word') and $_[1]->content eq 'provide_types_from'
    }) || [];

    # TODO: confirm we're in a package that inherits from MXTC
    #if( grep { $_ eq 'MooseX::Types::Combine' } @parents ){
    push @mxtypes, $self->_parse_mxtypes_from_statement($_)
      for map { $_->parent } @$methods;

    $req->add_minimum($_ => 0) for @mxtypes;
  #}
  #}
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
