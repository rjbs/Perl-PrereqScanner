use 5.010;
use strict;
use warnings;

package Perl::PrereqScanner;
# ABSTRACT: a tool to scan your Perl code for its prerequisites


use PPI;
use List::Util qw(max);
use Scalar::Util qw(blessed);
use version;

use namespace::autoclean;

sub _q_contents {
  my ($self, $token) = @_;
  my @contents = $token->isa('PPI::Token::QuoteLike::Words')
    ? ( $token->literal )
    : ( $token->string  );

  return @contents;
}

sub new {
  my ($class) = @_;
  bless {} => $class;
}

sub _add_prereq {
  my ($self, $prereq, $name, $newver) = @_;

  $newver = version->parse($newver) unless blessed($newver);

  if (defined (my $oldver = $prereq->{ $name })) {
    if (defined $newver) {
      $prereq->{ $name } = (sort { $b cmp $a } ($newver, $oldver))[0];
    }
    return;
  }

  $prereq->{ $name } = $newver;
}


=method my $prereqs = $scanner->scan_ppi_document( $ppi_doc );

Return a list of prereqs with their minimum version (0 if no minimum
specified) given a L<PPI> document.

=cut

sub scan_ppi_document {
  my ($self, $ppi_doc) = @_;

  my $prereq = {};

  # regular use and require
  my $includes = $ppi_doc->find('Statement::Include') || [];
  for my $node ( @$includes ) {
    # minimum perl version
    if ( $node->version ) {
      $self->_add_prereq($prereq, perl => $node->version);
      next;
    }

    # skipping pragamata
    next if $node->module ~~ [ qw{ strict warnings lib } ];

    if ( $node->module ~~ [ qw{ base parent } ] ) {
      # the content is in the 5th token
      my @meat = $node->arguments;

      my @parents = map {; $self->_q_contents($_) } @meat;
      $self->_add_prereq($prereq, $_ => 0) for @parents;
    }

    # regular modules
    my $version = $node->module_version ? $node->module_version->content : 0;

    # base has been core since perl 5.0
    next if $node->module eq 'base' and not $version;

    $self->_add_prereq($prereq, $node->module => $version);
  }

  # Moose-based roles / inheritance
  my @bases =
    map  { $self->_q_contents( $_ ) }
    grep { $_->isa('PPI::Token::Quote') || $_->isa('PPI::Token::QuoteLike') }
    map  { $_->children }
    grep { $_->child(0)->literal ~~ [ qw{ with extends } ] }
    grep { $_->child(0)->isa('PPI::Token::Word') }
    @{ $ppi_doc->find('PPI::Statement') || [] };

  $self->_add_prereq($prereq, $_ => 0) for @bases;

  return $prereq;
}

1;
__END__

=for Pod::Coverage::TrustPod
  new

=head1 SYNOPSIS

  use Perl::PrereqScanner;
  my $scan    = Perl::PrereqScanner->new;
  my $prereqs = $scan->scan_ppi_document( $ppi_doc );


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
