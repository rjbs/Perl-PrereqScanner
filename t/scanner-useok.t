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

  my $scanner = Perl::PrereqScanner->new({scanners => [qw( UseOk )]});

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

prereq_is(
  'BEGIN {
		use_ok( \'Term::ReadKey\', \'2.30\' );
		use_ok( \'Term::ReadLine\', \'1.10\' );
	}', {'Term::ReadKey' => '2.30', 'Term::ReadLine' => '1.10',}
);

prereq_is(
  'BEGIN {
		use_ok( \'Fred::BloggsOne\', \'1.01\' );
		use_ok( "Fred::BloggsTwo", "2.02" );
		use_ok( \'Fred::BloggsThree\', 3.03 );

	}',
  {'Fred::BloggsOne' => 1.01, 'Fred::BloggsTwo' => 2.02, 'Fred::BloggsThree' => 3.03,}
);

prereq_is(
  'BEGIN {
		use_ok( \'Fred::BloggsOne\');
		use_ok( "Fred::BloggsTwo", "two" );
		use_ok( \'Fred::BloggsThree\', 3.03 );

	}',
  {'Fred::BloggsOne' => 0, 'Fred::BloggsTwo' => 0, 'Fred::BloggsThree' => 3.03,}
);

done_testing;

__END__

# we are only checking for module names so version string will always be zero
