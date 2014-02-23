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

  my $scanner = Perl::PrereqScanner->new({scanners => [qw( Eval )]});

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
  'eval "use Test::Kwalitee::Extra 0.000007";',
  {'Test::Kwalitee::Extra' => '0.000007',}
);

prereq_is(
  'eval " use  Test::Kwalitee::ExtraB   0.000007 " ;',
  {'Test::Kwalitee::ExtraB' => '0.000007',}
);

prereq_is('eval "require Test::Kwalitee::Extra";',
  {'Test::Kwalitee::Extra' => 0,});

prereq_is(
  'eval "no Test::Kwalitee::Extra 0.000007";',
  {'Test::Kwalitee::Extra' => '0.000007',}
);

prereq_is(
  'eval \'use Test::Kwalitee 0.000007\';',
  {'Test::Kwalitee' => '0.000007',}
);

prereq_is('eval "use Test::Pod $min_tp";', {'Test::Pod' => 0});

prereq_is(
  'eval "use Win32::UTCFileTime" if $^O eq \'MSWin32\' && $] >= 5.006;',
  {'Win32::UTCFileTime' => 0});

prereq_is('eval { my $term = Term::ReadLine->new(\'none\') };',
  {}, '(empty string)');


## we can now handle stuff like:
## my $ver=1.22;
## eval "use Test::Pod $ver;"
prereq_is('
my $ver=1.22;
eval "use Test::Pod $ver";',
{'Test::Pod' => 0,}, 'eval "use Test::Pod $ver";',
);

prereq_is(
  'eval "use Test::Pod::No404s";',
  {'Test::Pod::No404s' => 0,},
);

prereq_is(
  'eval "use Test::Script 1.05; 1;"',
  {'Test::Script' => '1.05'},
);

prereq_is(
  'eval "use Test::Spelling 0.12; use Pod::Wordlist::hanekomu; 1;"',
  {'Test::Spelling' => '0.12', 'Pod::Wordlist::hanekomu' => 0, },
);

prereq_is(
  'eval "require Moose";',
  {'Moose' => 0},
);

prereq_is(
  'eval "use Moo 1.002; 1;";',
  {'Moo' => '1.002'},
);

prereq_is(
'eval { require Locale::Msgfmt; Locale::Msgfmt->import(); };',
  { 'Locale::Msgfmt' => 0 }
);

prereq_is(
  'eval { require Moose };',
  {'Moose' => '0'},
);

prereq_is(
  'eval { require Moose; 1; };',
  {'Moose' => '0'},
);

prereq_is(
  'eval { no Moose; 1; };',
  {'Moose' => '0'},
);

prereq_is(
  'eval { use Moose 2.000 };',
  {'Moose' => '2.000'},
);

prereq_is(
  'eval "require Moose";',
  {'Moose' => 0},
);

prereq_is(
  'eval { use Moose 2.000; 1; };',
  {'Moose' => '2.000'},
);

prereq_is(
  'my $HAVE_MOOSE = eval { require Moose };',
  {'Moose' => 0},
);

prereq_is(
  'my $HAVE_MOOSE = eval { require Moose; 1; };',
  {'Moose' => 0},
);

prereq_is(
  'my $HAVE_MOOSE = eval { use Moose 2.000; 1; };',
  {'Moose' => '2.000'},
);

prereq_is(
  'my $HAVE_MOOSE = eval { no Moose; };',
  {'Moose' => 0},
);

prereq_is(
  'my $HAVE_MOOSE = eval " require Moose ";',
  {'Moose' => 0},
);

### try tests
prereq_is(
'try { require Locale::Msgfmt; Locale::Msgfmt->import(); };',
  { 'Locale::Msgfmt' => 0 }
);

prereq_is(
  'try { require Moose };',
  {'Moose' => '0'},
);

prereq_is(
  'try { require Moose; 1; };',
  {'Moose' => '0'},
);

prereq_is(
  'try { no Moose; 1; };',
  {'Moose' => '0'},
);

prereq_is(
  'try { use Moose 2.000 };',
  {'Moose' => '2.000'},
);

prereq_is(
  'try { use Moose 2.000; 1; };',
  {'Moose' => '2.000'},
);

prereq_is(
  'my $HAVE_MOOSE = try { require Moose };',
  {'Moose' => 0},
);

prereq_is(
  'my $HAVE_MOOSE = try { require Moose; 1; };',
  {'Moose' => 0},
);

prereq_is(
  'my $HAVE_MOOSE = try { require Moose; "zero"; };',
  {'Moose' => 0},
);

prereq_is(
  'my $HAVE_MOOSE = try { use Moose 2.000; 1; };',
  {'Moose' => '2.000'},
);

prereq_is(
  'my $HAVE_MOOSE = try { no Moose; };',
  {'Moose' => 0},
);

### test for #issue38
prereq_is(
  'do { try { require MooseX::Getopt; (traits => [\'Getopt\']) } };',
  { 'MooseX::Getopt' => 0},
);

#### test for false positive - oliver++
prereq_is(
'ok(eval{ $p2->execute ;1}, \'execute method does not blow up\');',
  { }, ('false positive - execute')
);

prereq_is(
'ok(eval{ $p2->apply_params ;1}, \'empty apply_params\');',
  { }, ('false positive - empty')
);

prereq_is(
'ok( try{ $p2->execute };, \'execute method does not blow up\');',
  { }, ('false positive - execute')
);

prereq_is(
'ok( try{ $p2->apply_params };, \'empty apply_params\');',
  { }, ('false positive - empty')
);
#### ^^


### xdg
prereq_is(
'eval {require PAR::Dist; PAR::Dist->VERSION(0.17)}',
  {'PAR::Dist' => 0.17},
);

prereq_is(
'try {require PAR::Dist; PAR::Dist->VERSION(0.17)};',
  {'PAR::Dist' => 0.17},
);

prereq_is(
'eval {require PAR::Dist; PAR::Dist->VERSION("three")}',
  {'PAR::Dist' => 0},
);

prereq_is(
"    eval { require IO::Socket::IP; IO::Socket::IP->VERSION(0.25) } ? 'IO::Socket::IP' :
    'IO::Socket::INET';",
  {'IO::Socket::IP' => 0.25},
);

prereq_is(
"    eval { require IO::Socket::IP; IO::Socket::IP->VERSION('zero') } ? 'IO::Socket::IP' :
    'IO::Socket::INET';",
  {'IO::Socket::IP' => 0},
);

## 


done_testing;

__END__

