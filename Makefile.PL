use strict;
use warnings;

use 5.008;

use ExtUtils::MakeMaker 6.30;


my %WriteMakefileArgs = (
  "ABSTRACT"       => "a tool to scan your Perl code for its prerequisites",
  "AUTHOR"         => "Jerome Quelin, Ricardo Signes <rjbs\@cpan.org>",
  'BUILD_REQUIRES' => {
    "File::Temp" => '0.2301',
    "PPI"        => '1.215',
    "Test::More" => '0.98',
    "Try::Tiny"  => '0.12',
  },
  "CONFIGURE_REQUIRES" => {"ExtUtils::MakeMaker" => "6.30"},
  "DISTNAME"           => "Perl-PrereqScanner",
  "EXE_FILES"          => ["bin/scan_prereqs"],
  "LICENSE"            => "perl",
  "NAME"               => "Perl::PrereqScanner",
  'PREREQ_PM'          => {
    "CPAN::Meta::Requirements" => '2.122',
    "Carp"                     => '1.26',
    "Compiler::Lexer"          => '0.11',
    "Data::Printer"            => '0.35',
    "File::Spec::Functions"    => '3.4',
    "Getopt::Long"             => '2.39',
    "List::MoreUtils"          => '0.33',
    "List::Util"               => '1.27',
    "Moo"                      => '1.002',
    "PPI"                      => '1.215',
    "Params::Util"             => '1.07',
    "Pod::Usage"               => '1.63',
    "String::RewritePrefix"    => '0.006',
    "Type::Library"            => '0.006',
    "Type::Utils"              => '0.006',
    "Types::Standard"          => '0.006',
    "constant"                 => '1.27',
  },
  "VERSION" => "1.015",
  "test"    => {"TESTS" => "t/*.t"}
);


unless (eval { ExtUtils::MakeMaker->VERSION(6.56) }) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod (keys %$br) {
    if (exists $pp->{$mod}) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);
