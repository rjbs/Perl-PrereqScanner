use 5.008;
use strict;
use warnings;

package Perl::PrereqScanner;
# ABSTRACT: a tool to scan your Perl code for its prerequisites

use Moose;

use Safe::Isa qw( $_isa );
use List::Util qw(max);
use Params::Util qw(_CLASS);
use Perl::PrereqScanner::Scanner;
use Perl::PrereqScanner::Filter;
use PPI 1.215; # module_version, bug fixes
use String::RewritePrefix 0.005 rewrite => {
  -as => '__rewrite_scanner',
  prefixes => { '' => 'Perl::PrereqScanner::Scanner::', '=' => '' },
}, rewrite => {
  -as => '__rewrite_filter',
  prefixes => { '' => 'Perl::PrereqScanner::Filter::', '=' => '' },
};

use CPAN::Meta::Requirements 2.124; # normalized v-strings

use namespace::autoclean;

has scanners => (
  is  => 'ro',
  isa => 'ArrayRef[Perl::PrereqScanner::Scanner]',
  init_arg => undef,
  writer   => '_set_scanners',
);

has filters => (
  is  => 'ro',
  isa => 'ArrayRef[Perl::PrereqScanner::Filter]',
  init_arg => undef,
  writer   => '_set_filters',
);

sub __scanner_from_str {
  my $class = __rewrite_scanner($_[0]);
  confess "illegal class name: $class" unless _CLASS($class);
  eval "require $class; 1" or die $@;
  return $class->new;
}

sub __prepare_scanners {
  my ($self, $specs) = @_;
  my @scanners = map {; ref $_ ? $_ : __scanner_from_str($_) } @$specs;

  return \@scanners;
}

sub __filter_from_str {
  my $class = __rewrite_filter($_[0]);
  confess "illegal class name: $class" unless _CLASS($class);
  eval "require $class; 1" or die $@;
  return $class->new;
}

sub __prepare_filters {
  my ($self, $specs) = @_;
  my @scanners = map {; ref $_ ? $_ : __filter_from_str($_) } @$specs;

  return \@scanners;
}

sub BUILD {
  my ($self, $arg) = @_;

  my @scanners = @{ $arg->{scanners} || [ qw(Perl5 Superclass TestMore Moose Aliased POE) ] };
  my @filters  = @{ $arg->{filters}  || [ ] };

  my @extra_scanners = @{ $arg->{extra_scanners} || [] };

  my $scanners = $self->__prepare_scanners([ @scanners, @extra_scanners ]);
  my $filters  = $self->__prepare_filters([ @filters ]);

  $self->_set_scanners($scanners);
  $self->_set_filters($filters);
}

=method scan_string

  my $prereqs = $scanner->scan_string( $perl_code );

Given a string containing Perl source code, this method returns a
CPAN::Meta::Requirements object describing the modules it requires.

This method will throw an exception if PPI fails to parse the code.

B<Warning!>  It isn't entirely clear whether PPI prefers to receive
strings as octet strings or character strings.  For now, my advice
is to pass octet strings.

=cut

sub scan_string {
  my ($self, $str) = @_;
  my $ppi = PPI::Document->new( \$str );
  confess "PPI parse failed: " . PPI::Document->errstr unless defined $ppi;

  return $self->scan_ppi_document( $ppi );
}

=method scan_file

  my $prereqs = $scanner->scan_file( $path );

Given a file path to a Perl document, this method returns a
CPAN::Meta::Requirements object describing the modules it requires.

This method will throw an exception if PPI fails to parse the code.

=cut

sub scan_file {
  my ($self, $path) = @_;
  my $ppi = PPI::Document->new( $path );
  confess "PPI failed to parse '$path': " . PPI::Document->errstr
      unless defined $ppi;

  return $self->scan_ppi_document( $ppi );
}

=method scan_ppi_document

  my $prereqs = $scanner->scan_ppi_document( $ppi_doc );

Given a L<PPI::Document>, this method returns a CPAN::Meta::Requirements object
describing the modules it requires.

=cut

sub scan_ppi_document {
  my ($self, $orig_ppi_doc) = @_;

  my $ppi_doc = $orig_ppi_doc->clone;

  for my $filter (@{ $self->{filters} }) {
    $ppi_doc = $filter->filter_ppi_document($ppi_doc);
    confess "Filter $filter failed to return a PPI::Document" unless $ppi_doc->$_isa("PPI::Document");
  }

  my $req = CPAN::Meta::Requirements->new;

  for my $scanner (@{ $self->{scanners} }) {
    $scanner->scan_for_prereqs($ppi_doc, $req);
  }

  return $req;
}

=method scan_module

  my $prereqs = $scanner->scan_module( $module_name );

Given the name of a module, eg C<'PPI::Document'>,
this method returns a CPAN::Meta::Requirements object
describing the modules it requires.

=cut

sub scan_module {
  my ($self, $module_name) = @_;

  # consider rewriting to use Module::Which -- rjbs, 2013-11-03
  require Module::Path;
  if (defined(my $path = Module::Path::module_path($module_name))) {
    return $self->scan_file($path);
  }

  confess "Failed to find file for module '$module_name'";
}

1;
__END__

=for Pod::Coverage::TrustPod
  new

=head1 SYNOPSIS

  use Perl::PrereqScanner;
  my $scanner = Perl::PrereqScanner->new;
  my $prereqs = $scanner->scan_ppi_document( $ppi_doc );
  my $prereqs = $scanner->scan_file( $file_path );
  my $prereqs = $scanner->scan_string( $perl_code );
  my $prereqs = $scanner->scan_module( $module_name );

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

* OO namespace aliasing using the C<aliased> module

=end :list

=head2 Scanner Plugins

Perl::PrereqScanner works by running a series of scanners over a PPI::Document
representing the code to scan.  By default the "Perl5", "Moose", "TestMore",
"POE", and "Aliased" scanners are run.  You can supply your own scanners when
constructing your PrereqScanner:

  # Us only the Perl5 scanner:
  my $scanner = Perl::PrereqScanner->new({ scanners => [ qw(Perl5) ] });

  # Use any stock scanners, plus Example:
  my $scanner = Perl::PrereqScanner->new({ extra_scanners => [ qw(Example) ] });

=head2 Filter Plugins

Perl::PrereqScanner also supports document restructuring filters, which can be
useful in situations where code hides inside quoted strings. Assuming a filter
can remove the effect of the quoting safely, subsequent scanners will be able
to see the revealed code.

  my $scanner = Perl::PrereqScanner->new({ filters  => [ qw(ExampleFilter) ],
                                           scanners => [ qw(Perl5)         ], });

=head1 SEE ALSO

L<scan-perl-prereqs>, in this distribution, is a command-line interface to the scanner

=cut
