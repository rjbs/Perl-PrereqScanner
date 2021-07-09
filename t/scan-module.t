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

# Test with ourself!

module_prereq_is(
  'Perl::PrereqScanner',
  {
    'CPAN::Meta::Requirements'      => '2.124',
    'List::Util'                    => 0,
    'Module::Path'                  => 0,
    'Moose'                         => 0,
    'PPI'                           => '1.215',
    'Params::Util'                  => 0,
    'Perl::PrereqScanner::Filter'   => 0,
    'Perl::PrereqScanner::Scanner'  => 0,
    'Safe::Isa'                     => 0,
    'String::RewritePrefix'         => '0.005',
    'namespace::autoclean'          => 0,
    'perl'                          => '5.008',
    'strict'                        => 0,
    'warnings'                      => 0,
  },
);

done_testing;
