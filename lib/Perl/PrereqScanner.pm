use 5.010;
package Perl::PrereqScanner;
use Moose;
# ABSTRACT: a tool to scan your Perl code for its prerequisites

=head1 DESCRIPTION

The scanner will extract loosely your distribution prerequisites from your
files.

The extraction may not be perfect but tries to do its best. It will currently
find the following prereqs:

=over 4

=item * plain lines beginning with C<use> or C<require> in your perl
modules and scripts. This includes minimum perl version.

=item * regular inheritance declated with the C<base> and C<parent>
pragamata.

=item * L<Moose> inheritance declared with the C<extends> keyword.

=item * L<Moose> roles included with the C<with> keyword.

=back

It will trim the following pragamata: C<strict>, C<warnings>, C<base>
and C<lib>. However, C<parent> is kept, since it's not in a core module.

It will also trim the modules shipped within your dist.

=cut

use PPI;
use version;
use namespace::autoclean;

sub _q_contents {
  my ($self, $token) = @_;
  my @contents = $token->isa('PPI::Token::QuoteLike::Words')
    ? ( $token->literal )
    : ( $token->string  );

  return @contents;
}

sub scan_document {
  my ($self, $ppi_doc) = @_;

  my %prereqs;

  # regular use and require
  my $includes = $ppi_doc->find('Statement::Include') || [];
  for my $node ( @$includes ) {
    # minimum perl version
    if ( $node->version ) {
      $prereqs{perl} = $node->version;
      next;
    }

    # skipping pragamata
    next if $node->module ~~ [ qw{ strict warnings lib } ];

    if ( $node->module ~~ [ qw{ base parent } ] ) {
      # the content is in the 5th token
      my @meat = $node->arguments;

      my @parents = map {; $self->_q_contents($_) } @meat;
      @prereqs{ @parents } = (0) x @parents;

      # base is in perl core, parent isn't
      next if $node->module eq 'base';
    }

    # regular modules
    my $version = $node->module_version ? $node->module_version->content : 0;
    $prereqs{ $node->module } = $version;
  }

  # for moose specifics, let's fetch top-level statements
  my @statements =
    grep { $_->child(0)->isa('PPI::Token::Word') }
    grep { ref($_) eq 'PPI::Statement' } # no ->isa()
    $ppi_doc->children;

  # roles: with ...
  my @roles =
    map  { $self->_q_contents( $_->child(2) ) }
    grep { $_->child(0)->literal eq 'with' }
    @statements;

  @prereqs{ @roles } = (0) x @roles;

  # inheritance: extends ...
  my @bases =
    map  { $self->_q_contents( $_ ) }
    grep { $_->isa('PPI::Token::Quote') || $_->isa('PPI::Token::QuoteLike') }
    map  { $_->children }
    grep { $_->child(0)->literal eq 'extends' }
    @statements;

  @prereqs{ @bases } = (0) x @bases;

  return %prereqs;
}

__PACKAGE__->meta->make_immutable;
1;
