use 5.008;
use strict;
use warnings;

package Perl::PrereqScanner;
# ABSTRACT: a tool to scan your Perl code for its prerequisites

use PPI 1.205; # module_version
use List::Util qw(max);
use Scalar::Util qw(blessed);
use Version::Requirements 0.100630; # merge with 0-min bug fixed

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

=method scan_string

  my $prereqs = $scanner->scan_string( $perl_code );

Given a string containing Perl source code, this method returns a
Version::Requirements object describing the modules it requires.

=cut

sub scan_string {
  my ($self, $str) = @_;
  my $ppi = PPI::Document->new( \$str );
  return $self->scan_ppi_document( $ppi );
}


=method scan_file

  my $prereqs = $scanner->scan_file( $path );

Given a file path to a Perl document, this method returns a
Version::Requirements object describing the modules it requires.

=cut

sub scan_file {
  my ($self, $path) = @_;
  my $ppi = PPI::Document->new( $path );
  return $self->scan_ppi_document( $ppi );
}


=method scan_ppi_document

  my $prereqs = $scanner->scan_ppi_document( $ppi_doc );

Given a L<PPI::Document>, this method returns a Version::Requirements object
describing the modules it requires.

=cut

sub scan_ppi_document {
  my ($self, $ppi_doc) = @_;

  my $req = Version::Requirements->new;

  # regular use and require
  my $includes = $ppi_doc->find('Statement::Include') || [];
  for my $node ( @$includes ) {
    # minimum perl version
    if ( $node->version ) {
      $req->add_minimum(perl => $node->version);
      next;
    }

    # skipping pragamata
    next if grep { $_ eq $node->module } qw{ strict warnings lib };

    if (grep { $_ eq $node->module } qw{ base parent }) {
      # the content is in the 5th token
      my @meat = $node->arguments;

      my @parents = map { $self->_q_contents($_) } @meat;
      $req->add_minimum($_ => 0) for @parents;
    }

    # regular modules
    my $version = $node->module_version ? $node->module_version->content : 0;

    # base has been core since perl 5.0
    next if $node->module eq 'base' and not $version;

    $req->add_minimum($node->module, $version);
  }

  # Moose-based roles / inheritance
  my @bases =
    map  { $self->_q_contents( $_ ) }
    grep { $_->isa('PPI::Token::Quote') || $_->isa('PPI::Token::QuoteLike') }
    map  { $_->children }
    grep { $_->child(0)->literal =~ m{\Awith|extends\z} }
    grep { $_->child(0)->isa('PPI::Token::Word') }
    @{ $ppi_doc->find('PPI::Statement') || [] };

  $req->add_minimum($_ => 0) for @bases;

  return $req;
}

1;
__END__

=for Pod::Coverage::TrustPod
  new

=head1 SYNOPSIS

  use Perl::PrereqScanner;
  my $scan    = Perl::PrereqScanner->new;
  my $prereqs = $scan->scan_ppi_document( $ppi_doc );
  my $prereqs = $scan->scan_file( $file_path );
  my $prereqs = $scan->scan_string( $perl_code );

=head1 DESCRIPTION

The scanner will extract loosely your distribution prerequisites from your
files.

The extraction may not be perfect but tries to do its best. It will currently
find the following prereqs:

=begin :list

* plain lines beginning with C<use> or C<require> in your perl modules and scripts, including minimum perl version

* regular inheritance declared with the C<base> and C<parent> pragmata

* L<Moose> inheritance declared with the C<extends> keyword

* L<Moose> roles included with the C<with> keyword

=end :list

It will trim the following pragamata: C<strict>, C<warnings>, and C<lib>.
C<base> is trimmed unless a specific version is required.  C<parent> is kept,
since it's only recently become a core library.

=cut
