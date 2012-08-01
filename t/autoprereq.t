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
    my ($fh, $filename) = tempfile( UNLINK => 1 );
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

prereq_is('require Require; Require->VERSION(0.50);', { Require => '0.50' });

prereq_is('require Require; Require->VERSION(+0.50);', { Require => 0 });

prereq_is('require Require; foo(); Require->VERSION(1.00);', { Require => 0 });

prereq_is(
  'require Require; Require->VERSION(v1.0.50);',
  { Require => 'v1.0.50' }
);

prereq_is(
  q{require Require; Require->VERSION('v1.0.50');},
  { Require => 'v1.0.50' }
);

prereq_is(
  'require Require; Require->VERSION(q[1.00]);',
  { Require => '1.00' }
);

prereq_is(
  'require Require; Require::Other->VERSION(1.00);',
  { Require => 0 }
);

prereq_is(
  <<'END REQUIRE WITH COMMENT',
require Require::This; # this comment shouldn't matter
Require::This->VERSION(0.450);
END REQUIRE WITH COMMENT
  { 'Require::This' => '0.450' }, 'require with comment'
);

prereq_is(
  'require Require; Require->VERSION(0.450) if some_condition; ',
  { 'Require' => 0 }
);


# Moose features
prereq_is(
  'extends "Foo::Bar";',
  {
    'Foo::Bar' => 0,
  },
);

prereq_is(
  'extends "Foo::Bar"; extends "Foo::Baz";',
  {
    'Foo::Bar' => 0,
    'Foo::Baz' => 0,
  },
);
prereq_is("with 'With::Single';", { 'With::Single' => 0 });
prereq_is(
  "extends 'Extends::List1', 'Extends::List2';",
  {
    'Extends::List1' => 0,
    'Extends::List2' => 0,
  },
);

prereq_is("within('With::Single');", { });

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
  'with ("With::QW1", "With::QW2");',
  {
    'With::QW1' => 0,
    'With::QW2' => 0,
  },
);

prereq_is(
  "with('Paren::Role');",
  {
    'Paren::Role' => 0,
  },
);

prereq_is(
  'with("With::QW1", "With::QW2");',
  {
    'With::QW1' => 0,
    'With::QW2' => 0,
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
  'with "::Foo"',
  { },
);

prereq_is(
  'extends qw(Extends::QW1 Extends::QW2);',
  {
    'Extends::QW1' => 0,
    'Extends::QW2' => 0,
  },
);

prereq_is(
  'use base "Base::QQ1";',
  {
    'Base::QQ1' => 0,
    base => 0,
  },
);

prereq_is(
  'use base 10 "Base::QQ1";',
  {
    'Base::QQ1' => 0,
    base => 10,
  },
);
prereq_is(
  'use base qw{ Base::QW1 Base::QW2 };',
  { 'Base::QW1' => 0, 'Base::QW2' => 0, base => 0 },
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

prereq_is(
  q{use strict; use warnings; use lib '.'; use feature ':5.10';},
  { strict => 0, warnings => 0, feature => 0 },
);

prereq_is(
  q{use Test::More; is 0, 1; done_testing},
  {
    'Test::More' => '0.88',
  },
);

{
    my $scanner = Perl::PrereqScanner->new;
    try {
        $scanner->scan_string(\"\x0");
        fail('scan succeeded');
    } catch {
        like($_, qr/PPI parse failed/);
    };
}

# test cases for Moose 1.03 -version extension
prereq_is(
  'extends "Foo::Bar"=>{-version=>"1.1"};',
  {
    'Foo::Bar' => '1.1',
  },
);

prereq_is(
  'extends "Foo::Bar" => { -version => \'1.1\' };',
  {
    'Foo::Bar' => '1.1',
  },
);

prereq_is(
  'extends "Foo::Bar" => { -version => 13.3 };',
  {
    'Foo::Bar' => '13.3',
  },
);

prereq_is(
  'extends "Foo::Bar" => { -version => \'1.1\' }; extends "Foo::Baz" => { -version => 5 };',
  {
    'Foo::Bar' => '1.1',
    'Foo::Baz' => 5,
  },
);

prereq_is(
  'extends "Foo::Bar"=>{-version=>1},"Foo::Baz"=>{-version=>2};',
  {
    'Foo::Bar' => 1,
    'Foo::Baz' => 2,
  },
);

prereq_is(
  'extends "Foo::Bar" => { -version => "4.3.2" }, "Foo::Baz" => { -version => 2.44894 };',
  {
    'Foo::Bar' => 'v4.3.2',
    'Foo::Baz' => 2.44894,
  },
);

prereq_is(
  'with "With::Single" => { -excludes => "method", -version => "1.1.1" }, "With::Double";',
  {
    'With::Single' => 'v1.1.1',
    'With::Double' => 0,
  },
);

prereq_is(
  'with "With::Single" => { -wow => { -wow => { a => b } }, -version => "1.1.1" }, "With::Double";',
  {
    'With::Single' => 'v1.1.1',
    'With::Double' => 0,
  },
);

prereq_is(
  'with "With::Single" => { -exclude => "method", -version => "1.1.1" },
  "With::Double" => { -exclude => "foo" };',
  {
    'With::Single' => 'v1.1.1',
    'With::Double' => 0,
  },
);

prereq_is(
  'with("Foo::Bar");',
  {
    'Foo::Bar' => 0,
  },
);

prereq_is(
  'with( "Foo::Bar" );',
  {
    'Foo::Bar' => 0,
  },
);

prereq_is(
  'with( "Foo::Bar", "Bar::Baz" );',
  {
    'Foo::Bar' => 0,
    'Bar::Baz' => 0,
  }
);

prereq_is(
  'with( "Foo::Bar" => { -version => "1.1" },
  "Bar::Baz" );',
  {
    'Foo::Bar' => '1.1',
    'Bar::Baz' => 0,
  }
);

prereq_is(
  'with( "Blam::Blam", "Foo::Bar" => { -version => "1.1" },
  "Bar::Baz" );',
  {
    'Blam::Blam' => 0,
    'Foo::Bar' => '1.1',
    'Bar::Baz' => 0,
  }
);

prereq_is(
  'with("Blam::Blam","Foo::Bar"=>{-version=>"1.1"},
  "Bar::Baz" );',
  {
    'Blam::Blam' => 0,
    'Foo::Bar' => '1.1',
    'Bar::Baz' => 0,
  }
);

prereq_is(
  'with("Blam::Blam","Foo::Bar"=>{-version=>"1.1"},
  "Bar::Baz",
  "Hoopla" => { -version => 1 } );',
  {
    'Blam::Blam' => 0,
    'Foo::Bar' => '1.1',
    'Bar::Baz' => 0,
    'Hoopla' => 1,
  }
);

prereq_is(
  'extends("Foo::Bar");',
  {
    'Foo::Bar' => 0,
  },
);

prereq_is(
  'extends( "Foo::Bar" );',
  {
    'Foo::Bar' => 0,
  },
);

prereq_is(
  'extends( "Foo::Bar", "Bar::Baz" );',
  {
    'Foo::Bar' => 0,
    'Bar::Baz' => 0,
  }
);

prereq_is(
  'extends( "Foo::Bar" => { -version => "1.1" },
  "Bar::Baz" );',
  {
    'Foo::Bar' => '1.1',
    'Bar::Baz' => 0,
  }
);

prereq_is(
  'extends( "Blam::Blam", "Foo::Bar" => { -version => "1.1" },
  "Bar::Baz" );',
  {
    'Blam::Blam' => 0,
    'Foo::Bar' => '1.1',
    'Bar::Baz' => 0,
  }
);

prereq_is(
  'extends("Blam::Blam","Foo::Bar"=>{-version=>"1.1"},
  "Bar::Baz" );',
  {
    'Blam::Blam' => 0,
    'Foo::Bar' => '1.1',
    'Bar::Baz' => 0,
  }
);

prereq_is(
  'extends("Blam::Blam","Foo::Bar"=>{-version=>"1.1"},
  "Bar::Baz",
  "Hoopla" => { -version => 1 } );',
  {
    'Blam::Blam' => 0,
    'Foo::Bar' => '1.1',
    'Bar::Baz' => 0,
    'Hoopla' => 1,
  }
);

prereq_is(
  'with(
	\'AAA\' => { -version => \'1\' },
	\'BBB\' => { -version => \'2.1\' },
	\'CCC\' => {
		-version => \'4.012345\',
		default_finders => [ \':InstallModules\', \':ExecFiles\' ],
	},
);',
  {
    'AAA' => 1,
    'BBB' => '2.1',
    'CCC' => '4.012345',
  },
);

prereq_is(
  'with(
    "AAA"
      =>
        {
          -version
            =>
              1
        },
  );',
  {
    'AAA' => 1,
  },
);

prereq_is(
  'with
    "AAA"
      =>
        {
          -version
            =>
              1
        };',
  {
    'AAA' => 1,
  },
);

prereq_is(
  'with(

"Bar"

);',
  {
    'Bar' => 0,
  },
);

prereq_is(
  'with

\'Bar\'

;',
  {
    'Bar' => 0,
  },
);

# invalid code tests
prereq_is( 'with;', {}, );
prereq_is( 'with foo;', {} );

# test cases for aliased.pm
prereq_is(
  q{use aliased 'Long::Custom::Class::Name'},
  {
    'aliased' => 0,
    'Long::Custom::Class::Name' => 0,
  },
);

prereq_is(
  q{use aliased 0.30 'Long::Custom::Class::Name'},
  {
    'aliased' => '0.30',
    'Long::Custom::Class::Name' => 0,
  },
);


prereq_is(
  q{use aliased 'Long::Custom::Class::Name' => 'Name'},
  {
    'aliased' => 0,
    'Long::Custom::Class::Name' => 0,
  },
);

# rolsky says this is a problem case
prereq_is(
  q{use Test::Requires 'Foo'},
  {
    'Test::Requires' => 0,
  },
);

# test cases for POE
prereq_is(
  q{use POE 'Component::IRC'},
  {
    'POE' => 0,
    'POE::Component::IRC' => 0,
  },
);

prereq_is(
  q{use POE qw/Component::IRC Component::Server::NNTP/},
  {
    'POE' => 0,
    'POE::Component::IRC' => 0,
    'POE::Component::Server::NNTP' => 0,
  },
);

# test cases for MooseXTypesCombine
prereq_is(
  <<MXTC,
use parent 'MooseX::Types::Combine';

__PACKAGE__->provide_types_from(qw(
  MooseX::Types::Moose
  MooseX::Types::Path::Class
));
MXTC
  {
    'parent' => '0',
    'MooseX::Types::Combine' => 0,
    'MooseX::Types::Moose' => 0,
    'MooseX::Types::Path::Class' => 0,
  }
);

prereq_is(
  <<'MXTC',
our @ISA = qw{ MooseX::Types::Combine };
__PACKAGE__ -> provide_types_from ( "MooseX::Types::Moose",
  ('MooseX::Types::Common::String', $var_that_wont_match) );
MXTC
  {
    'MooseX::Types::Combine' => 0,
    'MooseX::Types::Moose' => 0,
    'MooseX::Types::Common::String' => 0,
  }
);

prereq_is(
  <<'MXTC',
# this package doesn't inherit from MXTC, it just has a similar method call
__PACKAGE__ -> provide_types_from ( "MooseX::Types::Moose", 'MooseX::Types::Common::String' );
MXTC
  {
  }
);

done_testing;
