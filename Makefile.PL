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
	 "CPAN::Meta::Requirements"  => '2.122',
	 "File::Spec::Functions"     => '3.4',
	 "Getopt::Long"              => '2.39',
	 "Getopt::Long::Descriptive" => '0.093',
	 "List::MoreUtils"           => '0.33',
	 "List::Util"                => '1.27',
	 "Module::Path"              => '0.09',
	 "Moose"                     => '2.0802',
	 "Moose::Role"               => '2.0802',
	 "PPI"                       => '1.215',
	 "Params::Util"              => '1.07',
	 "Scalar::Util"              => '1.27',
	 "String::RewritePrefix"     => '0.006',
	 "namespace::autoclean"      => '0.13',
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
