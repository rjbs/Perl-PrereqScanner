use 5.008;
use strict;
use warnings;

package Perl::PrereqScanner;
# ABSTRACT: a tool to scan your Perl code for its prerequisites

use Carp qw(confess);
use List::Util qw(max);
use Params::Util qw(_CLASS);
use PPI 1.205; # module_version
use Scalar::Util qw(blessed);
use String::RewritePrefix rewrite => {
  -as => '__rewrite_scanner',
  prefixes => { '' => 'Perl::PrereqScanner::Scanner::', '=' => '' },
};

use Version::Requirements 0.100630; # merge with 0-min bug fixed

use namespace::autoclean;

sub new {
  my ($class, $arg) = @_;

  my @scanners = @{ $arg->{scanners} || [ qw(Default Moose) ] };
  my @extra_scanners = @{ $arg->{extra_scanners} || [] };
  bless {
    scanners => $class->__prepare_scanners([ @scanners, @extra_scanners ]),
  } => $class;
}

sub __scanner_class {
  my $class = __rewrite_scanner($_[0]);
  confess "illegal class name: $class" unless _CLASS($class);
  eval "require $class; 1" or die $@;
  return $class;
}

sub __prepare_scanners {
  my ($self, $specs) = @_;
  my @scanners = map {; ref $_ ? $_ : __scanner_class($_)->new } @$specs;

  return \@scanners;
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

  for my $scanner (@{ $self->{scanners} }) {
    $scanner->scan_for_prereqs($ppi_doc, $req);
  }

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
