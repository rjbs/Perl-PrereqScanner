#!perl
use strict;
use warnings;

use Perl::PrereqScanner;
use PPI::Document;
use Try::Tiny;

use Test::More;

# t/eg/lib/Empty.pm
# t/eg/lib/Main.pm
sub prereq_is {
  my ($str, $want) = @_;

  my $scanner = Perl::PrereqScanner->new;

  try {
    my %result  = $scanner->scan_document( PPI::Document->new(\$str) );
    is_deeply(\%result, $want, $str);
  } catch {
    fail("scanner died on: $str");
  }
}

prereq_is('', { });
prereq_is('use Use::NoVersion;', { 'Use::NoVersion' => 0 });
prereq_is('use Use::Version 0.50;', { 'Use::Version' => '0.50' });
prereq_is('require Require;', { Require => 0 });

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
  'use parent qw{ Parent::QW1 Parent::QW2 };',
  {
    'Parent::QW1' => 0,
    'Parent::QW2' => 0,
    parent => 0,
  },
);

done_testing;
