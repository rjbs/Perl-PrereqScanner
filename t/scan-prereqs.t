#!perl
use strict;
use warnings;

use File::Temp qw{ tempfile };
use Perl::PrereqScanner;
use PPI::Document;
use Try::Tiny;
use File::Spec::Functions;

use Test::More;

# try to be cross-platform
my $script = catfile(qw(bin scan_prereqs));
my $files = join(' ', map { catfile(qw(corpus scan), "$_.pl") } qw(foo bar));

# depending on exact output match is a bit fragile and may become cumbersome
# but we'll try it for now.
foreach my $test (
    [default => '' => <<OUTPUT],
* ${\catfile(qw( corpus scan foo.pl ))}
File::Spec = 0
IO::File   = 1.08
strict     = 0
warnings   = 0
* ${\catfile(qw( corpus scan bar.pl ))}
Exporter    = 0
File::Temp  = 0.12
Time::Local = 0
strict      = 0
warnings    = 0
OUTPUT

    [combined => '--combine' => <<OUTPUT],
Exporter    = 0
File::Spec  = 0
File::Temp  = 0.12
IO::File    = 1.08
Time::Local = 0
strict      = 0
warnings    = 0
OUTPUT

) {
    my ( $name, $args, $exp ) = @$test;
    my $command = "$^X $script $args $files";
    my $out = do {
        open(my $fh, "$command |")
            or die "Failed to execute '$command': $!";
        local $/;
        <$fh>;
    };
    is $out, $exp, "Expected output for $name";
}

done_testing;
