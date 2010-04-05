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

  my $scanner = Perl::PrereqScanner->new;

  # scan_ppi_document
  try {
    my $result  = $scanner->scan_ppi_document( PPI::Document->new(\$str) );
    is_deeply($result->as_string_hash, $want, $comment);
  } catch {
    fail("scanner died on: $comment");
    diag($_);
  };

  # scan_string
  try {
    my $result  = $scanner->scan_string( $str );
    is_deeply($result->as_string_hash, $want, $comment);
  } catch {
    fail("scanner died on: $comment");
    diag($_);
  };

  # scan_file
  try {
    my ($fh, $filename) = tempfile();
    print $fh $str;
    close $fh;
    my $result  = $scanner->scan_file( $filename );
    is_deeply($result->as_string_hash, $want, $comment);
  } catch {
    fail("scanner died on: $comment");
    diag($_);
  };
}

prereq_is('', { }, '(empty string)');
prereq_is('use Use::NoVersion;', { 'Use::NoVersion' => 0 });
prereq_is('use Use::Version 0.50;', { 'Use::Version' => '0.50' });
prereq_is('require Require;', { Require => 0 });

prereq_is(
  'use Use::Version 0.50; use Use::Version 1.00;',
  {
    'Use::Version' => '1.00',
  },
);

prereq_is(
  'use Use::Version 1.00; use Use::Version 0.50;',
  {
    'Use::Version' => '1.00',
  },
);

prereq_is(
  'use Import::IgnoreAPI require => 1;',
  { 'Import::IgnoreAPI' => 0 },
);


# Moose features
prereq_is("with 'With::Single';", { 'With::Single' => 0 });
prereq_is(
  "extends 'Extends::List1', 'Extends::List2';",
  {
    'Extends::List1' => 0,
    'Extends::List2' => 0,
  },
);

prereq_is(
  "with 'With::Single', 'With::Double';",
  {
    'With::Single' => 0,
    'With::Double' => 0,
  },
);

prereq_is(
  "with 'With::Single' => { -excludes => 'method'}, 'With::Double';",
  {
    'With::Single' => 0,
    'With::Double' => 0,
  },
);

prereq_is(
  'with qw(With::QW1 With::QW2);',
  {
    'With::QW1' => 0,
    'With::QW2' => 0,
  },
);

prereq_is(
  'extends qw(Extends::QW1 Extends::QW2);',
  {
    'Extends::QW1' => 0,
    'Extends::QW2' => 0,
  },
);

prereq_is('use base "Base::QQ1";', { 'Base::QQ1' => 0 });
prereq_is(
  'use base 10 "Base::QQ1";',
  {
    'Base::QQ1' => 0,
    base => 10,
  },
);
prereq_is(
  'use base qw{ Base::QW1 Base::QW2 };',
  { 'Base::QW1' => 0, 'Base::QW2' => 0 },
);

prereq_is(
  'use parent "Parent::QQ1";',
  {
    'Parent::QQ1' => 0,
    parent => 0,
  },
);

prereq_is(
  'use parent 10 "Parent::QQ1";',
  {
    'Parent::QQ1' => 0,
    parent => 10,
  },
);

prereq_is(
  'use parent 2 "Parent::QQ1"; use parent 2 "Parent::QQ2"',
  {
    'Parent::QQ1' => 0,
    'Parent::QQ2' => 0,
    parent => 2,
  },
);

prereq_is(
  'use parent 2 "Parent::QQ1"; use parent 1 "Parent::QQ2"',
  {
    'Parent::QQ1' => 0,
    'Parent::QQ2' => 0,
    parent => 2,
  },
);

prereq_is(
  'use parent qw{ Parent::QW1 Parent::QW2 };',
  {
    'Parent::QW1' => 0,
    'Parent::QW2' => 0,
    parent => 0,
  },
);

# test case for #55713: support for use parent -norequire
prereq_is(
  'use parent -norequire, qw{ Parent::QW1 Parent::QW2 };',
  {
    'Parent::QW1' => 0,
    'Parent::QW2' => 0,
    parent => 0,
  },
);

# test case for #55851: require $foo
prereq_is(
  'my $foo = "Carp"; require $foo',
  {},
);

# test case for ignoring pragmata
prereq_is(
  q{use strict; use warnings; use lib '.'; use feature ':5.10';},
  {},
);
done_testing;
