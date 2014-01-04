use v5.16;
use strict;
use warnings;

package Perl::PrereqScanner::Scanner::UseModule;

# ABSTRACT: scan for modules included by Module::Runtime
# These will be shown in preregs -> runtime -> suggests

use Moo;
with 'Perl::PrereqScanner::Scanner';

use Data::Printer; # caller_info => 1;
use Try::Tiny;

=head1 DESCRIPTION

This scanner will look for the following formats or variations there in,
inside BEGIN blocks in test files:

=begin :list

* use_module( 'Fred::BloggsOne', '1.01' );

* use_module( "Fred::BloggsTwo", "2.02" );

* use_module( 'Fred::BloggsThree', 3.03 );

=end :list

=cut

use constant {BLANK => q{ }, TRUE => 1, FALSE => 0, NONE => q{}, TWO => 2,
	THREE => 3,};


sub scan_for_prereqs {
	my ($self, $ppi_doc, $req) = @_;
	my @modules;
	my @version_strings;

#	p $ppi_doc;
	my $module_runtime_include_found = FALSE;

	#test for module_ryntime

	my $includes = $ppi_doc->find('PPI::Statement::Include');
	if ($includes) {
		foreach my $include (@{$includes}) {
			next if $include->type eq 'no';
			if (not $include->pragma) {
				my $module = $include->module;
#				p $module;
				if ($module eq 'Module::Runtime') {
					$module_runtime_include_found = TRUE;
				}
			}
		}
	}

#	p $module_runtime_include_found;
	return if $module_runtime_include_found eq FALSE;
	say 'checking for use_module';

say 'Option 1';
try {
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


	my @chunks =

		map  { [$_->schildren] }
		grep { $_->{children}[4]->content eq 'use_module' }
		grep { $_->child(4)->isa('PPI::Token::Word') }

	    grep { $_->child(2)->content eq '=' }
	    grep { $_->child(2)->isa('PPI::Token::Operator') }

		grep { $_->child(0)->isa('PPI::Token::Symbol') }

		@{$ppi_doc->find('PPI::Statement') || []}; # need for pps remove in midgen -> || {}

#	p @chunks;

	foreach my $hunk (@chunks) {

#		p $hunk;

		# looking for use Module::Runtime ...;
		if (grep { $_->isa('PPI::Structure::List') } @$hunk) {

#			say 'found Module::Runtime';

			# hack for List
			my @hunkdata = @$hunk;

			foreach my $ppi_sl (@hunkdata) {
				if ($ppi_sl->isa('PPI::Structure::List')) {
#					p $ppi_sl;
					foreach my $ppi_se (@{$ppi_sl->{children}}) {
						if ($ppi_se->isa('PPI::Statement::Expression')) {
							foreach my $element (@{$ppi_se->{children}}) {
								if ( $element->isa('PPI::Token::Quote::Single')
									|| $element->isa('PPI::Token::Quote::Double'))
								{
									my $module = $element;
									$module =~ s/^['|"]//;
									$module =~ s/['|"]$//;
									if ($module =~ m/\A[A-Z]/) {
										push @modules, $module;
									}
								}

							}
						}
					}
				}
			}
		}
	}
};

say 'Option 2';
try{
#	say 'lets check for require use_module';
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



	my @chunks =

		map  { [$_->schildren] }
		grep { $_->{children}[2]->content eq 'use_module' }
		grep { $_->child(2)->isa('PPI::Token::Word') }

	    grep { $_->child(0)->content =~ m{\A(?:return)\z} }
		grep { $_->child(0)->isa('PPI::Token::Word') }

		@{$ppi_doc->find('PPI::Statement::Break') || []};

#	p @chunks;

	foreach my $hunk (@chunks) {

#		p $hunk;

		# looking for use Module::Runtime ...;
		if (grep { $_->isa('PPI::Structure::List') } @$hunk) {

#			say 'found Module::Runtime';

			# hack for List
			my @hunkdata = @$hunk;

			foreach my $ppi_sl (@hunkdata) {
				if ($ppi_sl->isa('PPI::Structure::List')) {
#					p $ppi_sl;
					foreach my $ppi_se (@{$ppi_sl->{children}}) {
						if ($ppi_se->isa('PPI::Statement::Expression')) {
							foreach my $element (@{$ppi_se->{children}}) {
								if ( $element->isa('PPI::Token::Quote::Single')
									|| $element->isa('PPI::Token::Quote::Double'))
								{
									my $module = $element;
									$module =~ s/^['|"]//;
									$module =~ s/['|"]$//;
									if ($module =~ m/\A[A-Z]/) {
										push @modules, $module;
									}
								}

							}
						}
					}
				}
			}
		}
	}
};

say 'Option 3';
try{
#
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
#
#
#PPI::Document
#  PPI::Token::Whitespace  	'    '
#  PPI::Statement::Variable
#    PPI::Token::Word  	'my'
#    PPI::Token::Whitespace  	' '
#    PPI::Token::Symbol  	'@specs'
#    PPI::Token::Whitespace  	' '
#    PPI::Token::Operator  	'='
#    PPI::Token::Whitespace  	' '
#    PPI::Token::Word  	'do'
#    PPI::Token::Whitespace  	' '
#    PPI::Structure::Block  	{ ... }
#      PPI::Token::Whitespace  	'\n'
#      PPI::Token::Whitespace  	'      '
#      PPI::Statement::Compound
#        PPI::Token::Word  	'if'
#        PPI::Token::Whitespace  	' '
#        PPI::Structure::Condition  	( ... )
#          PPI::Statement::Expression
#            PPI::Token::Word  	'ref'
#            PPI::Structure::List  	( ... )
#              PPI::Statement::Expression
#                PPI::Token::Symbol  	'$hspec'
#            PPI::Token::Whitespace  	' '
#            PPI::Token::Operator  	'eq'
#            PPI::Token::Whitespace  	' '
#            PPI::Token::Quote::Single  	''ARRAY''
#        PPI::Token::Whitespace  	' '
#        PPI::Structure::Block  	{ ... }
#          PPI::Token::Whitespace  	'\n'
#          PPI::Token::Whitespace  	'        '
#          PPI::Statement
#            PPI::Token::Word  	'map'
#            PPI::Token::Whitespace  	' '
#            PPI::Structure::Constructor  	[ ... ]
#              PPI::Token::Whitespace  	' '
#              PPI::Statement
#                PPI::Token::Magic  	'$_'
#                PPI::Token::Whitespace  	' '
#                PPI::Token::Operator  	'=>'
#                PPI::Token::Whitespace  	' '
#                PPI::Token::Magic  	'$_'
#              PPI::Token::Whitespace  	' '
#            PPI::Token::Operator  	','
#            PPI::Token::Whitespace  	' '
#            PPI::Token::Cast  	'@'
#            PPI::Token::Symbol  	'$hspec'
#            PPI::Token::Structure  	';'
#          PPI::Token::Whitespace  	'\n'
#          PPI::Token::Whitespace  	'      '
#        PPI::Token::Whitespace  	' '
#        PPI::Token::Word  	'elsif'
#        PPI::Token::Whitespace  	' '
#        PPI::Structure::Condition  	( ... )
#          PPI::Statement::Expression
#            PPI::Token::Word  	'ref'
#            PPI::Structure::List  	( ... )
#              PPI::Statement::Expression
#                PPI::Token::Symbol  	'$hspec'
#            PPI::Token::Whitespace  	' '
#            PPI::Token::Operator  	'eq'
#            PPI::Token::Whitespace  	' '
#            PPI::Token::Quote::Single  	''HASH''
#        PPI::Token::Whitespace  	' '
#        PPI::Structure::Block  	{ ... }
#          PPI::Token::Whitespace  	'\n'
#          PPI::Token::Whitespace  	'        '
#          PPI::Statement
#            PPI::Token::Word  	'map'
#            PPI::Token::Whitespace  	' '
#            PPI::Structure::Constructor  	[ ... ]
#              PPI::Token::Whitespace  	' '
#              PPI::Statement
#                PPI::Token::Magic  	'$_'
#                PPI::Token::Whitespace  	' '
#                PPI::Token::Operator  	'=>'
#                PPI::Token::Whitespace  	' '
#                PPI::Token::Word  	'ref'
#                PPI::Structure::List  	( ... )
#                  PPI::Statement::Expression
#                    PPI::Token::Symbol  	'$hspec'
#                    PPI::Token::Operator  	'->'
#                    PPI::Structure::Subscript  	{ ... }
#                      PPI::Statement::Expression
#                        PPI::Token::Magic  	'$_'
#                PPI::Token::Whitespace  	' '
#                PPI::Token::Operator  	'?'
#                PPI::Token::Whitespace  	' '
#                PPI::Token::Cast  	'@'
#                PPI::Structure::Block  	{ ... }
#                  PPI::Statement
#                    PPI::Token::Symbol  	'$hspec'
#                    PPI::Token::Operator  	'->'
#                    PPI::Structure::Subscript  	{ ... }
#                      PPI::Statement::Expression
#                        PPI::Token::Magic  	'$_'
#                PPI::Token::Whitespace  	' '
#                PPI::Token::Operator  	':'
#                PPI::Token::Whitespace  	' '
#                PPI::Token::Symbol  	'$hspec'
#                PPI::Token::Operator  	'->'
#                PPI::Structure::Subscript  	{ ... }
#                  PPI::Statement::Expression
#                    PPI::Token::Magic  	'$_'
#              PPI::Token::Whitespace  	' '
#            PPI::Token::Operator  	','
#            PPI::Token::Whitespace  	'\n'
#            PPI::Token::Whitespace  	'          '
#            PPI::Token::Word  	'keys'
#            PPI::Token::Whitespace  	' '
#            PPI::Token::Cast  	'%'
#            PPI::Token::Symbol  	'$hspec'
#            PPI::Token::Structure  	';'
#          PPI::Token::Whitespace  	'\n'
#          PPI::Token::Whitespace  	'      '
#        PPI::Token::Whitespace  	' '
#        PPI::Token::Word  	'elsif'
#        PPI::Token::Whitespace  	' '
#        PPI::Structure::Condition  	( ... )
#          PPI::Statement::Expression
#            PPI::Token::Operator  	'!'
#            PPI::Token::Word  	'ref'
#            PPI::Structure::List  	( ... )
#              PPI::Statement::Expression
#                PPI::Token::Symbol  	'$hspec'
#        PPI::Token::Whitespace  	' '
#        PPI::Structure::Block  	{ ... }
#          PPI::Token::Whitespace  	'\n'
#          PPI::Token::Whitespace  	'        '
#          PPI::Statement
#            PPI::Token::Word  	'map'
#            PPI::Token::Whitespace  	' '
#            PPI::Structure::Constructor  	[ ... ]
#              PPI::Token::Whitespace  	' '
#              PPI::Statement
#                PPI::Token::Magic  	'$_'
#                PPI::Token::Whitespace  	' '
#                PPI::Token::Operator  	'=>'
#                PPI::Token::Whitespace  	' '
#                PPI::Token::Magic  	'$_'
#              PPI::Token::Whitespace  	' '
#            PPI::Token::Operator  	','
#            PPI::Token::Whitespace  	' '
#            PPI::Token::Word  	'use_module'
#            PPI::Structure::List  	( ... )
#              PPI::Statement::Expression
#                PPI::Token::Quote::Single  	''Moo::Role''
#            PPI::Token::Operator  	'->'
#            PPI::Token::Word  	'methods_provided_by'
#            PPI::Structure::List  	( ... )
#              PPI::Statement::Expression
#                PPI::Token::Word  	'use_module'
#                PPI::Structure::List  	( ... )
#                  PPI::Statement::Expression
#                    PPI::Token::Symbol  	'$hspec'
#          PPI::Token::Whitespace  	'\n'
#          PPI::Token::Whitespace  	'      '
#        PPI::Token::Whitespace  	' '
#        PPI::Token::Word  	'else'
#        PPI::Token::Whitespace  	' '
#        PPI::Structure::Block  	{ ... }
#          PPI::Token::Whitespace  	'\n'
#          PPI::Token::Whitespace  	'        '
#          PPI::Statement
#            PPI::Token::Word  	'die'
#            PPI::Token::Whitespace  	' '
#            PPI::Token::Quote::Double  	'"You gave me a handles of ${hspec} and I have no idea why"'
#            PPI::Token::Structure  	';'
#          PPI::Token::Whitespace  	'\n'
#          PPI::Token::Whitespace  	'      '
#      PPI::Token::Whitespace  	'\n'
#      PPI::Token::Whitespace  	'    '
#    PPI::Token::Structure  	';'

	my @chunks =

		map  { [$_->schildren] }
		grep { $_->{children}[2]->content eq 'use_module' }
		grep { $_->child(2)->isa('PPI::Token::Word') }

	    grep { $_->child(0)->content eq ','} 
		grep { $_->child(0)->isa('PPI::Token::Operator') }

		@{$ppi_doc->find('PPI::Document') || []};

	p @chunks;

	foreach my $hunk (@chunks) {

#		p $hunk;

		# looking for use Module::Runtime ...;
		if (grep { $_->isa('PPI::Structure::List') } @$hunk) {

#			say 'found Module::Runtime';

			# hack for List
			my @hunkdata = @$hunk;

			foreach my $ppi_sl (@hunkdata) {
				if ($ppi_sl->isa('PPI::Structure::List')) {
#					p $ppi_sl;
					foreach my $ppi_se (@{$ppi_sl->{children}}) {
						if ($ppi_se->isa('PPI::Statement::Expression')) {
							foreach my $element (@{$ppi_se->{children}}) {
								if ( $element->isa('PPI::Token::Quote::Single')
									|| $element->isa('PPI::Token::Quote::Double'))
								{
									my $module = $element;
									$module =~ s/^['|"]//;
									$module =~ s/['|"]$//;
									if ($module =~ m/\A[A-Z]/) {
										push @modules, $module;
									}
								}

							}
						}
					}
				}
			}
		}
	}
};


	foreach (0 .. $#modules) {
		$req->add_minimum($modules[$_] => 0);
	}
	p @modules;
	return;
}


#######
# composed method test for include Module::Runtime
#######
sub _is_module_runtime {
	my ($self, $doc) = @_;
	my $module_runtime_include_found = FALSE;
	p $doc;

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
					p $module;
					if ($module eq 'Module::Runtime') {
						$module_runtime_include_found = TRUE;
					}
				}
			}
		}
	};
	p $module_runtime_include_found;
	return $module_runtime_include_found;

}


1;

__END__

181:	final indentation level: 1

Final nesting depth of '{'s is 1
The most recent un-matched '{' is on line 37
37: sub scan_for_prereqs {
                         ^
181:	To save a full .LOG file rerun with -g
