use 5.008;
use strict;
use warnings;

package Perl::PrereqScanner;
# ABSTRACT: a tool to scan your Perl code for its prerequisites

# use Moose;
use Moo;
use Types::Standard qw( ArrayRef );
# use Perl::PrereqScanner::Types;
# we need this due to confess test
use Carp;

use List::Util qw(max);
use Params::Util qw(_CLASS);
use Perl::PrereqScanner::Scanner;
use PPI 1.215; # module_version, bug fixes

use String::RewritePrefix 0.005 rewrite => {
	-as      => '__rewrite_scanner',
	prefixes => { '' => 'Perl::PrereqScanner::Scanner::', '=' => '' },
};

use CPAN::Meta::Requirements 2.120630; # normalized v-strings
# use namespace::autoclean;

#kpd
use Data::Printer { caller_info => 1, colored => 1, };
use Compiler::Lexer;

# has avaible_scanners => (
	# is       => 'ro',
	# isa      => 'ArrayRef[Perl::PrereqScanner::Scanner]',
	# init_arg => undef,
	# writer   => '_set_avaible_scanners',
# );

has 'avaible_scanners' => (
	is       => 'rwp',
	isa      => ArrayRef[],
	init_arg => undef,
#	writer   => '_set_avaible_scanners', # done by rwp
);

## used by BUILD hence duble prefex __
sub __scanner_from_str {

	# p $_[0];

	# prefix Perl::PrereqScanner::Scanner::
	my $class = __rewrite_scanner( $_[0] );

	# p $class;
	# p _CLASS($class);

## _CLASS from Prams::Util tests for "normalised" form ie: A::B::C
# it is also doing -> use $class
	confess "illegal class name: $class" unless _CLASS($class);
	eval "require $class; 1" or die $@;

	# p $class->new;

	return $class->new;
}

## used by BUILD hence duble prefex __
sub __prepare_scanners {
	my ( $self, $specs ) = @_;

	my @scanners = map { ; ref $_ ? $_ : __scanner_from_str($_) } @$specs;

	# p @scanners;
	return \@scanners;
}


sub BUILD {
	my ( $self, $arg ) = @_;

## All
##  my @scanners = @{ $arg->{scanners} || [ qw(Perl5 TestMore Moose Aliased POE TestRequires UseOk) ] };

## core
	my @scanners = @{ $arg->{scanners} || [qw( Perl5 Moose )] };

## these are just bastards modifiers, fixing drud, should be run LAST
	my @bastards = @{ $arg->{scanners} || [ qw( TestMore Aliased POE ) ] };

  my @extra = @{ [ qw( TestRequires UseOk ) ] };

	my @extra_scanners = @{ $arg->{extra_scanners} || [] };

	my $scanners = $self->__prepare_scanners( [ @scanners, @bastards, @extra, @extra_scanners ] );

	$self->_set_avaible_scanners($scanners);
#	p $self->avaible_scanners;
}

=method scan_string

  my $prereqs = $scanner->scan_string( $perl_code );

Given a string containing Perl source code, this method returns a
CPAN::Meta::Requirements object describing the modules it requires.

This method will throw an exception if PPI fails to parse the code.

=cut

sub scan_string {
	my ( $self, $str ) = @_;
	my $ppi = PPI::Document->new( \$str );
	confess "PPI parse failed: " . PPI::Document->errstr unless defined $ppi;

	return $self->scan_ppi_document($ppi);
}


=method scan_file

  my $prereqs = $scanner->scan_file( $path );

Given a file path to a Perl document, this method returns a
CPAN::Meta::Requirements object describing the modules it requires.

This method will throw an exception if PPI fails to parse the code.

=cut

sub scan_file {
	my ( $self, $path ) = @_;
	my $ppi = PPI::Document->new($path);
	confess "PPI failed to parse '$path': " . PPI::Document->errstr
		unless defined $ppi;

	return $self->scan_ppi_document($ppi);
}

sub scan_file_fast {
	my ( $self, $path ) = @_;
	my $ppi = PPI::Document->new($path);
	confess "PPI failed to parse '$path': " . PPI::Document->errstr
		unless defined $ppi;

	return $self->scan_ppi_document($ppi);
}


=method scan_ppi_document

  my $prereqs = $scanner->scan_ppi_document( $ppi_doc );

Given a L<PPI::Document>, this method returns a CPAN::Meta::Requirements object
describing the modules it requires.

=cut

sub scan_ppi_document {
	my ( $self, $ppi_doc ) = @_;

	my $req = CPAN::Meta::Requirements->new;
#	p $req;
	# p $self->avaible_scanners;
	for my $scanner ( @{ $self->avaible_scanners } ) {
		$scanner->scan_for_prereqs( $ppi_doc, $req );
	}
# p $req;
	return $req;
}

sub scan_comp_lex_document {
	my ( $self, $ppi_doc ) = @_;

	my $req = CPAN::Meta::Requirements->new;

	for my $scanner ( @{ $self->avaible_scanners } ) {
		$scanner->scan_for_prereqs( $ppi_doc, $req );
	}

	return $req;
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

=cut
