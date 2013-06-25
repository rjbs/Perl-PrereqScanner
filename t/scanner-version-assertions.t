#!perl
use strict;
use warnings;

use File::Temp qw{ tempfile };
use Perl::PrereqScanner;
use PPI::Document;
use Try::Tiny;

use Test::More;

sub prereq_is {
  my ($str, $want, $comment) = @_;
  $comment ||= $str;

  my $scanner = Perl::PrereqScanner->new({scanners => [qw( Perl5 )]});

  # scan_ppi_document
  try {
    my $result = $scanner->scan_ppi_document(PPI::Document->new(\$str));
    is_deeply($result->as_string_hash, $want, $comment);
  }
  catch {
    fail("scanner died on: $comment");
    diag($_);
  };

  # scan_string
  try {
    my $result = $scanner->scan_string($str);
    is_deeply($result->as_string_hash, $want, $comment);
  }
  catch {
    fail("scanner died on: $comment");
    diag($_);
  };

  # scan_file
  try {
    my ($fh, $filename) = tempfile(UNLINK => 1);
    print $fh $str;
    close $fh;
    my $result = $scanner->scan_file($filename);
    is_deeply($result->as_string_hash, $want, $comment);
  }
  catch {
    fail("scanner died on: $comment");
    diag($_);
  };
}

prereq_is('', {}, '(empty string)');

prereq_is('require Foo;', {Foo => 0, Foo => 0,} );

prereq_is('require Foo; Foo->VERSION(1.1);', {Foo => 1.1, Foo => '1.1',} );

prereq_is(
  'require Foo;
if ($x) { 
	Foo->VERSION(1.2); 
} else { 
	Foo->VERSION(1.3); 
}', {Foo => 0, Foo => 0,}
);

prereq_is('use Bar 2.1;', {Bar => 2.1, Bar => '2.1',} );

prereq_is('use Bar; Bar->VERSION(2.2);', {Bar => 2.2, Bar => '2.2',} );

prereq_is(
  'use Bar;
if ($x) { 
	Bar->VERSION(2.3); 
} else { 
	Bar->VERSION(2.4); 
}', {Bar => 0, Bar => 0,}
);





done_testing;

__END__

