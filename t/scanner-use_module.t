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

	my $scanner = Perl::PrereqScanner->new({scanners => [qw( UseModule )]});

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
	'use Data::Printer;
use Foo::Bar;
', {}, '(no Module::Runtime)'
);

prereq_is(
	'use Data::Printer;
use Module::Runtime;
use Foo::Bar;
', {}, '(use Module::Runtime)'
);

prereq_is(
	'use Module::Runtime;
use_module("Math::BigInt", 1.31)->new("1_234");
', {'Math::BigInt' => 0}, '("use_module( M::N )...")'
);

prereq_is(
	'use Module::Runtime;
require_module("Math::BigInt");
', {'Math::BigInt' => 0}, '("require_module( R::M )")'
);

prereq_is(
	'use Module::Runtime;
use_package_optimistically("Math::BigInto", 1.234)->new("1_234");
', {'Math::BigInto' => 0}, '("use_package_optimistically( P::M )...")'
);

prereq_is(
	'use Module::Runtime;
    require_module(\'B::Hooks::EndOfScope::PP::HintHash\');
', {'B::Hooks::EndOfScope::PP::HintHash' => 0}, '("require_module( B::Hooks::EndOfScope::PP::HintHash )"'
);

prereq_is(
	'use Module::Runtime;
BEGIN {
  if (_PERL_VERSION =~ /^5\.009/) {
    # CBA to figure out where %^H got broken and which H::U::HH is sane enough
    die "By design B::Hooks::EndOfScope does not operate in pure-perl mode on perl 5.9.X\n"
  }
  elsif (_PERL_VERSION < \'5.010\') {
    require_module(\'B::Hooks::EndOfScope::PP::HintHash\');
    *on_scope_end = \&B::Hooks::EndOfScope::PP::HintHash::on_scope_end;
  }
  else {
    require_module(\'B::Hooks::EndOfScope::PP::FieldHash\');
    *on_scope_end = \&B::Hooks::EndOfScope::PP::FieldHash::on_scope_end;
  }
}
',
{'B::Hooks::EndOfScope::PP::HintHash' => 0, 'B::Hooks::EndOfScope::PP::FieldHash' => 0,}, '("require_module( B::Hooks )"'
);

#prereq_is(
#	'use Module::Runtime;
#$bi = use_package_optimistically("Math::BigInto", 1.234)->new("1_234");
#', {'Math::BigInto' => 0}, '("Math::BigInto", 1.234)'
#);


prereq_is(
	'use Module::Runtime;
my $bi = use_module("Math::BigInt", 1.31)->new("1_234");
', {'Math::BigInt' => 0}, '("my $bi = use_module( M::N )...")'
);

prereq_is(
	'use Module::Runtime;
$bi = use_module("Math::BigInt", 1.31)->new("1_234");
', {'Math::BigInt' => 0}, '("$bi = use_module( M::N )...")'
);



prereq_is(
	'use Module::Runtime;
return use_module(\'App::SCS::PageSet\')->new(
base_dir => $self->share_dir->catdir(\'pages\'),
plugin_config => $self->page_plugin_config,
);
', {'App::SCS::PageSet' => 0}, '("return use_module( M::N )...")'
);

#prereq_is(
#	'use Module::Runtime;
#return use_package_optimistically(\'App::SCS::PageSeto\')->new(
#base_dir => $self->share_dir->catdir(\'pages\'),
#plugin_config => $self->page_plugin_config,
#);
#', {'App::SCS::PageSeto' => 0}, '("App::SCS::PageSeto", 0)'
#);
#
#prereq_is(
#	'use Module::Runtime;
#return use_module("App::SCS::Web")->new(app => $self);
#', {'App::SCS::Web' => 0}, '("App::SCS::Web", 0)'
#);
#
#prereq_is(
#	'use Module::Runtime;
#return use_package_optimisticall("App::SCS::Webo")->new(app => $self);
#', {'App::SCS::Webo' => 0}, '("App::SCS::Webo", 0)'
#);
#
#prereq_is(
#	'use Module::Runtime;
#  return use_module(\'App::SCS::PageSetxx\')->new(
#    base_dir => $self->share_dir->catdir(\' pages \'),
#    plugin_config => $self->page_plugin_config,
#  );
#', {'App::SCS::PageSetxx' => 0}, '("App::SCS::Pagesetxx", 0)'
#);


#prereq_is('use Module::Runtime;
#    my @specs = do {
#      if (ref($hspec) eq \'ARRAY\') {
#        map [ $_ => $_ ], @$hspec;
#      } elsif (ref($hspec) eq \'HASH\') {
#        map [ $_ => ref($hspec->{$_}) ? @{$hspec->{$_}} : $hspec->{$_} ],
#          keys %$hspec;
#      } elsif (!ref($hspec)) {
#        map [ $_ => $_ ], use_module(\'Moo::Role\')->methods_provided_by(use_module($hspec))
#      } else {
#        die "You gave me a handles of ${hspec} and I have no idea why";
#      }
#    };
#', {'Moo::Role' => 0}, '("Moo::Role", 0)');


done_testing;

__END__

# we are only checking for module names so version string will always be zero
