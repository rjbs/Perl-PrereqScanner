use strict;
use warnings;

package Perl::PrereqScanner::Scanner::MooseXTypesCombine;
use Moose;
with 'Perl::PrereqScanner::Scanner';
# ABSTRACT: scan for type libraries exported with MooseX::Types::Combine

use List::MoreUtils qw( any );
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

  # * split doc into chunks by package (very tricky - PPI does not support this yet)
  # * for each package:
  # * check for base/parent/isa
  # * find provide_types_from
  # * find quoted words

  foreach my $chunk ( $ppi_doc ){
    my @prereqs = $self->_determine_inheritance_from_mxtc($chunk);

    # short-circuit if it doesn't look like this package isa mxtc
    next unless @prereqs;

    # find the method call that sets the types being exported
    my $methods = $chunk->find(sub {
      $_[1]->isa('PPI::Token::Word') and $_[1]->content eq 'provide_types_from'
    }) || [];

    # parse the statements that contain the method call we just searched for
    push @prereqs, $self->_parse_mxtypes_from_statement($_)
      for map { $_->parent } @$methods;

    $req->add_minimum($_ => 0) for @prereqs;
  }
}

# There should be a 'use base', 'use parent', or '@ISA = ' (or 'push @ISA')
# somewhere that includes MooseX::Types::Combine.
sub _determine_inheritance_from_mxtc {
  my ($self, $ppi_doc) = @_;
  my @modules;
  my $mxtc = 'MooseX::Types::Combine';

  # NOTE: Similar logic is found in some of the scanners;
  # perhaps this could be refactored into something reusable.

  # find "use base" or "use parent"
  my $includes = $ppi_doc->find('Statement::Include') || [];
  for my $node ( @$includes ) {
    if (grep { $_ eq $node->module } qw{ base parent }) {
      my @meat = grep {
           $_->isa('PPI::Token::QuoteLike::Words')
        || $_->isa('PPI::Token::Quote')
      } $node->arguments;

      my @parents = map { $self->_q_contents($_) } @meat;

      # the main scanner should pick up base/parent and mxtc
      # but it's easy enough to add them here, so do it for completeness
      push @modules, $node->module, $mxtc
        if any { $_ eq $mxtc } @parents;
    }
  }

  return @modules if @modules;

  # if there was no base/parent, look for any statement that mentions @ISA
  my $isa = $ppi_doc->find(sub {
    $_[1]->isa('PPI::Token::Symbol') && $_[1]->content eq '@ISA'
  }) || [];
  $isa = [ map { $_->parent } @$isa ];

  # See if any of those @ISA statements include our module.
  # This is far from foolproof, but probably good enough.
  @modules = $mxtc
    if any { $_->find_any(sub {
        (
          $_[1]->isa('PPI::Token::QuoteLike::Words') ||
          $_[1]->isa('PPI::Token::Quote')
        ) &&
          any { $_ eq $mxtc } $self->_q_contents($_[1])
      });
    } @$isa;

  # take care to always return a list
  return @modules;
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
  # check that the statement matches $wanted
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

  # this expects quoted module names and won't work if vars are passed
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
