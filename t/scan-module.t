#!perl
use strict;
use warnings;

use Perl::PrereqScanner;
use Try::Tiny;

use Test::More;

sub module_prereq_is {
  my ($module_name, $want, $comment) = @_;
  $comment ||= $module_name;

  my $scanner = Perl::PrereqScanner->new;

  # scan_ppi_document
  try {
    my $result  = $scanner->scan_module( $module_name );
    is_deeply($result->as_string_hash, $want, $comment);
  } catch {
    fail("scanner died on: $comment");
    diag($_);
  };

}

# Test with some Core modules whose dependencies are unlikely to change (very often)

module_prereq_is(
  'Getopt::Std',
  {
    'Exporter' => 0,
    'perl'     => '5.000',
  },
);

module_prereq_is(
  'Carp',
  {
    'Exporter' => 0,
    'perl'     => '5.006',
    'strict'   => 0,
    'warnings' => 0,
  },
);

# Test with ourself!

module_prereq_is(
  'Perl::PrereqScanner',
  {
    'CPAN::Meta::Requirements'      => '2.120630',
	'Carp'                          => '1.20',
    'List::Util'                    => 0,
    'Module::Path'                  => 0,
    'Moo'                           => '1.002',
    'MooX::Types::MooseLike::Base'  => 0,
    'PPI'                           => '1.215',
    'Params::Util'                  => 0,
    'Perl::PrereqScanner::Scanner'  => 0,
    'String::RewritePrefix'         => '0.005',
    'namespace::autoclean'          => 0,
    'perl'                          => '5.008',
    'strict'                        => 0,
    'warnings'                      => 0,
  },
);

done_testing;


