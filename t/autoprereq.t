#!perl
use strict;
use warnings;

use Perl::PrereqScanner;
use PPI::Document;
use Test::More tests => 1;

# t/foo/bin
# t/foo/bin/foobar
# t/foo/lib/DZPA/Empty.pm
# t/foo/lib/DZPA/Main.pm
my $scanner = Perl::PrereqScanner->new;

my %result  = $scanner->scan_document(
  PPI::Document->new('t/foo/lib/DZPA/Main.pm')
);

use Data::Dumper;
diag Dumper(\%result);

ok(1);
