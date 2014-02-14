use strict;
use warnings;

package Perl::PrereqScanner::Scanner::UseModule;

# ABSTRACT: scan for modules included by Module::Runtime
# These will be shown in preregs -> runtime -> suggests

use Moo;
with 'Perl::PrereqScanner::Scanner';
use Tie::Static qw(static);
use Try::Tiny;

=head1 DESCRIPTION

This scanner will look for the following formats or variations there in,
inside BEGIN blocks in test files:

=begin :list

* use_module("Module::Name", x.xx)->new( ... );

* require_module( 'Module::Name');

* use_package_optimistically("Module::Name", x.xx)->new( ... );

* my $abc = use_module("Module::Name", x.xx)->new( ... );

* my $abc = use_package_optimistically("Module::Name", x.xx)->new( ... );

* $abc = use_module("Module::Name", x.xx)->new( ... );

* $abc = use_package_optimistically("Module::Name", x.xx)->new( ... );

* return use_module( 'Module::Name', x,xx )->new( ... );

* return use_package_optimisticall( 'Module::Name', x.xx )->new( ... );


=end :list

=cut

use constant {BLANK => q{ }, TRUE => 1, FALSE => 0, NONE => q{}, TWO => 2,
	THREE => 3,};


sub scan_for_prereqs {
	my ($self, $ppi_doc, $req) = @_;
	my @modules;
	my @version_strings;

# bug out if there is no Include for Module::Runtime found
	return if $self->_is_module_runtime($ppi_doc) eq FALSE;

##	say 'Option 1: use_module( M::N )...';

#
# use_module("Math::BigInt", 1.31)->new("1_234");
#
#PPI::Document
#  PPI::Statement
#	 PPI::Token::Whitespace  	' '
#    PPI::Token::Word  	'use_module'
#    PPI::Structure::List  	( ... )
#      PPI::Statement::Expression
#        PPI::Token::Quote::Double  	'"Math::BigInt"'
#        PPI::Token::Operator  	','
#        PPI::Token::Whitespace  	' '
#        PPI::Token::Number::Float  	'1.31'
#    PPI::Token::Operator  	'->'
#    PPI::Token::Word  	'new'
#    PPI::Structure::List  	( ... )
#      PPI::Statement::Expression
#        PPI::Token::Quote::Double  	'"1_234"'
#    PPI::Token::Structure  	';'
#  PPI::Token::Whitespace  	'\n'


	try {
		my @chunks1 = @{$ppi_doc->find('PPI::Statement') || []};

		foreach my $chunk (@chunks1) {

			if (not $chunk->find(sub { $_[1]->isa('PPI::Token::Symbol') })) {

				# test for module-runtime key-words
				if (
					$chunk->find(
						sub {
							$_[1]->isa('PPI::Token::Word')
								and $_[1]->content
								=~ m{\A[Module::Runtime::]*(?:use_module|use_package_optimistically|require_module)\z};
						}
					)
					)
				{
					# exclude return for continuity and duplications
					if (
						not $chunk->find(
							sub {
								$_[1]->isa('PPI::Token::Word')
									and $_[1]->content =~ m{\A(?:return)\z};
							}
						)
						)
					{

						for (0 .. $#{$chunk->{children}}) {

							# find all ppi_sl
							if ($chunk->{children}[$_]->isa('PPI::Structure::List')) {

								my $ppi_sl = $chunk->{children}[$_]
									if $chunk->{children}[$_]->isa('PPI::Structure::List');

								# say 'Option 1: use_module( M::N )...';
								$self->_module_names_ppi_sl(\@modules, \@version_strings,
									$ppi_sl);
							}
						}
					}
				}
			}
		}
	};


##	say 'Option 2: my $abc = use_module( M::N )...';


#
# my $bi = use_module("Math::BigInt", 1.31)->new("1_234");
#
#PPI::Document
#  PPI::Statement::Variable
#    PPI::Token::Word  	'my'
#    PPI::Token::Whitespace  	' '
#    PPI::Token::Symbol  	'$bi'
#    PPI::Token::Whitespace  	' '
#    PPI::Token::Operator  	'='
#    PPI::Token::Whitespace  	' '
#    PPI::Token::Word  	'use_module'
#    PPI::Structure::List  	( ... )
#      PPI::Statement::Expression
#        PPI::Token::Quote::Double  	'"Math::BigInt"'
#        PPI::Token::Operator  	','
#        PPI::Token::Whitespace  	' '
#        PPI::Token::Number::Float  	'1.31'
#    PPI::Token::Operator  	'->'
#    PPI::Token::Word  	'new'
#    PPI::Structure::List  	( ... )
#      PPI::Statement::Expression
#        PPI::Token::Quote::Double  	'"1_234"'
#    PPI::Token::Structure  	';'
#  PPI::Token::Whitespace  	'\n'

	try {
		# let's extract all ppi_sv
		my @chunks2 = @{$ppi_doc->find('PPI::Statement::Variable') || []};
		foreach my $chunk (@chunks2) {

			# test for my
			if (
				$chunk->find(
					sub {
						$_[1]->isa('PPI::Token::Word')
							and $_[1]->content =~ m{\A(?:my)\z};
					}
				)
				)
			{
				# test for module-runtime key-words
				if (
					$chunk->find(
						sub {
							$_[1]->isa('PPI::Token::Word')
								and $_[1]->content
								=~ m{\A[Module::Runtime::]*(?:use_module|use_package_optimistically)\z};
						}
					)
					)
				{
					for (0 .. $#{$chunk->{children}}) {

						# find all ppi_sl
						if ($chunk->{children}[$_]->isa('PPI::Structure::List')) {

							my $ppi_sl = $chunk->{children}[$_]
								if $chunk->{children}[$_]->isa('PPI::Structure::List');

							# say 'Option 2: my $abc = use_module( M::N )...';
							$self->_module_names_ppi_sl(\@modules, \@version_strings,
								$ppi_sl);

						}
					}
				}
			}
		}
	};


##	say 'Option 3: $q = use_module( M::N )...';

#
# $bi = use_module("Math::BigInt", 1.31)->new("1_234");
#
#PPI::Document
#  PPI::Statement
#    PPI::Token::Symbol  	'$bi'
#    PPI::Token::Whitespace  	' '
#    PPI::Token::Operator  	'='
#    PPI::Token::Whitespace  	' '
#    PPI::Token::Word  	'use_module'
#    PPI::Structure::List  	( ... )
#      PPI::Statement::Expression
#        PPI::Token::Quote::Double  	'"Math::BigInt"'
#        PPI::Token::Operator  	','
#        PPI::Token::Whitespace  	' '
#        PPI::Token::Number::Float  	'1.31'
#    PPI::Token::Operator  	'->'
#    PPI::Token::Word  	'new'
#    PPI::Structure::List  	( ... )
#      PPI::Statement::Expression
#        PPI::Token::Quote::Double  	'"1_234"'
#    PPI::Token::Structure  	';'
#  PPI::Token::Whitespace  	'\n'

	try {
		my @chunks1 = @{$ppi_doc->find('PPI::Statement') || []};

		foreach my $chunk (@chunks1) {

			# test for not my
			if (
				not $chunk->find(
					sub {
						$_[1]->isa('PPI::Token::Word')
							and $_[1]->content =~ m{\A(?:my)\z};
					}
				)
				)
			{

				if ($chunk->find(sub { $_[1]->isa('PPI::Token::Symbol') })) {

					if (
						$chunk->find(
							sub {
								$_[1]->isa('PPI::Token::Operator') and $_[1]->content eq '=';
							}
						)
						)
					{

						# test for module-runtime key-words
						if (
							$chunk->find(
								sub {
									$_[1]->isa('PPI::Token::Word')
										and $_[1]->content
										=~ m{\A[Module::Runtime::]*(?:use_module|use_package_optimistically)\z};
								}
							)
							)
						{
							for (0 .. $#{$chunk->{children}}) {

								# find all ppi_sl
								if ($chunk->{children}[$_]->isa('PPI::Structure::List')) {

									my $ppi_sl = $chunk->{children}[$_]
										if $chunk->{children}[$_]->isa('PPI::Structure::List');

									# say 'Option 3: $q = use_module( M::N )...';
									$self->_module_names_ppi_sl(\@modules, \@version_strings,
										$ppi_sl);
								}
							}
						}
					}
				}
			}
		}
	};


##	say 'Option 4: return use_module( M::N )...';

#
# return use_module(\'App::SCS::PageSet\')->new(
# base_dir => $self->share_dir->catdir(\'pages\'),
# plugin_config => $self->page_plugin_config,
# );
#
#PPI::Document
#  PPI::Statement::Break
#    PPI::Token::Word  	'return'
#    PPI::Token::Whitespace  	' '
#    PPI::Token::Word  	'use_module'
#    PPI::Structure::List  	( ... )
#      PPI::Statement::Expression
#        PPI::Token::Quote::Single  	''App::SCS::PageSet''
#    PPI::Token::Operator  	'->'
#    PPI::Token::Word  	'new'
#    PPI::Structure::List  	( ... )
#      PPI::Token::Whitespace  	'\n'
#      PPI::Token::Whitespace  	'    '
#      PPI::Statement::Expression
#        PPI::Token::Word  	'base_dir'
#        PPI::Token::Whitespace  	' '
#        PPI::Token::Operator  	'=>'
#        PPI::Token::Whitespace  	' '
#        PPI::Token::Symbol  	'$self'
#        PPI::Token::Operator  	'->'
#        PPI::Token::Word  	'share_dir'
#        PPI::Token::Operator  	'->'
#        PPI::Token::Word  	'catdir'
#        PPI::Structure::List  	( ... )
#          PPI::Statement::Expression
#            PPI::Token::Quote::Single  	''pages''
#        PPI::Token::Operator  	','
#        PPI::Token::Whitespace  	'\n'
#        PPI::Token::Whitespace  	'    '
#        PPI::Token::Word  	'plugin_config'
#        PPI::Token::Whitespace  	' '
#        PPI::Token::Operator  	'=>'
#        PPI::Token::Whitespace  	' '
#        PPI::Token::Symbol  	'$self'
#        PPI::Token::Operator  	'->'
#        PPI::Token::Word  	'page_plugin_config'
#        PPI::Token::Operator  	','
#      PPI::Token::Whitespace  	'\n'
#      PPI::Token::Whitespace  	'  '
#    PPI::Token::Structure  	';'

	try {
		my @chunks4 = @{$ppi_doc->find('PPI::Statement::Break') || []};

		for my $chunk (@chunks4) {

			if (
				$chunk->find(
					sub {
						$_[1]->isa('PPI::Token::Word')
							and $_[1]->content =~ m{\A(?:return)\z};
					}
				)
				)
			{

				if (
					$chunk->find(
						sub {
							$_[1]->isa('PPI::Token::Word')
								and $_[1]->content
								=~ m{\A[Module::Runtime::]*(?:use_module|use_package_optimistically)\z};
						}
					)
					)
				{
					for (0 .. $#{$chunk->{children}}) {

						# find all ppi_sl
						if ($chunk->{children}[$_]->isa('PPI::Structure::List')) {
							my $ppi_sl = $chunk->{children}[$_]
								if $chunk->{children}[$_]->isa('PPI::Structure::List');

							# say 'Option 4: return use_module( M::N )...';
							$self->_module_names_ppi_sl(\@modules, \@version_strings,
								$ppi_sl);

						}
					}
				}
			}
		}
	};


	foreach (0 .. $#modules) {
		$req->add_minimum($modules[$_] => $version_strings[$_]);
	}

	return;
}


#######
# composed method test for include Module::Runtime
#######
sub _is_module_runtime {
	my ($self, $doc) = @_;
	my $module_runtime_include_found = FALSE;

#PPI::Document
#  PPI::Statement::Include
#    PPI::Token::Word  	'use'
#    PPI::Token::Whitespace  	' '
#    PPI::Token::Word  	'Module::Runtime'

	try {
		my $includes = $doc->find('PPI::Statement::Include');
		if ($includes) {
			foreach my $include (@{$includes}) {
				next if $include->type eq 'no';
				if (not $include->pragma) {
					my $module = $include->module;
					if ($module eq 'Module::Runtime') {
						$module_runtime_include_found = TRUE;
					}
				}
			}
		}
	};
	return $module_runtime_include_found;

}


#######
# composed method extract module name from PPI::Structure::List
#######
sub _module_names_ppi_sl {
	my ($self, $modules, $version_strings, $ppi_sl) = @_;


	if ($ppi_sl->isa('PPI::Structure::List')) {

#		p $ppi_sl;
		static \ my $previous_module;
		foreach my $ppi_se (@{$ppi_sl->{children}}) {
			for (0 .. $#{$ppi_se->{children}}) {

				if ( $ppi_se->{children}[$_]->isa('PPI::Token::Quote::Single')
					|| $ppi_se->{children}[$_]->isa('PPI::Token::Quote::Double'))
				{
					my $module = $ppi_se->{children}[$_]->content;
					$module =~ s/(?:['|"])//g;
					if ($module =~ m/\A[A-Z]/) {

						# warn 'found module - ' . $module;
						push @$modules, $module;
						$previous_module = $module;
					}
				}
				if ( $ppi_se->{children}[$_]->isa('PPI::Token::Number::Float')
					|| $ppi_se->{children}[$_]->isa('PPI::Token::Number::Version')
					|| $ppi_se->{children}[$_]->isa('PPI::Token::Quote::Single')
					|| $ppi_se->{children}[$_]->isa('PPI::Token::Quote::Double'))
				{
					my $version_string = $ppi_se->{children}[$_]->content;
					$version_string =~ s/(?:['|"])//g;
					next if $version_string !~ m/\A[\d|v]/;

					$version_string
						= version::is_lax($version_string) ? $version_string : 0;

					try {
						@$version_strings = $version_string if $previous_module;
						$previous_module = undef;
					};
				}
			}
		}
	}
}

1;

__END__


