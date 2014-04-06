use strict;
use warnings;

package Perl::PrereqScanner::Scanner::Eval;

# ABSTRACT: scan for module names in an eval EXPR

use Moo;
with 'Perl::PrereqScanner::Scanner';

use Try::Tiny;
use List::Util qw(any first);

=head1 DESCRIPTION

This scanner will look for the following formats or variations there in,
note all lines start with eval:

=begin :list

* eval "use Test::Pod $min_tp";

* eval "use Win32::UTCFileTime" if $^O eq 'MSWin32' && $] >= 5.006;

* eval "require Test::Kwalitee::Extra";

=end :list

=cut


sub scan_for_prereqs {
	my ($self, $ppi_doc, $req) = @_;

	#PPI::Document
	#  PPI::Statement
	#    PPI::Token::Word  	'eval'
	#    PPI::Token::Whitespace  	' '
	#    PPI::Token::Quote::Double  	'"require Test::Kwalitee::Extra $mod_ver"'
	#    PPI::Token::Structure  	';'


	try {
		my @chunks1 = @{$ppi_doc->find('PPI::Statement')};

		foreach my $chunk (@chunks1) {
			if (
				$chunk->find(
					sub {
						$_[1]->isa('PPI::Token::Word')
							and $_[1]->content =~ m{\A(?:eval|try)\z};
					}
				)
				)
			{

				for (0 .. $#{$chunk->{children}}) {

					# ignore sub blocks - false positive
					last if $chunk->{children}[$_]->content eq 'sub';


					if ( $chunk->{children}[$_]->isa('PPI::Token::Quote::Double')
						|| $chunk->{children}[$_]->isa('PPI::Token::Quote::Single'))
					{
						my $eval_line = $chunk->{children}[$_]->content;
						$eval_line =~ s/(?:'|"|{|})//g;
						my @eval_includes = split /;/, $eval_line;

						foreach my $eval_include (@eval_includes) {
							$self->mod_ver($req, $eval_include);
						}
					}

					if ($chunk->{children}[$_]->isa('PPI::Structure::Block')) {
						my @children = $chunk->{children}[$_]->children;

						foreach my $child_element (@children) {
							if ($child_element->isa('PPI::Statement::Include')) {

								my $eval_line = $child_element->content;
								my @eval_includes = split /;/, $eval_line;

								foreach my $eval_include (@eval_includes) {
									$self->mod_ver($req, $eval_include);
								}
							}
						}
					}
				}
			}
		}
	};


#PPI::Document
#  PPI::Statement
#    PPI::Token::Word  	'eval'
#    PPI::Token::Whitespace  	' '
#    PPI::Structure::Block  	{ ... }
#      PPI::Statement::Include
#        PPI::Token::Word  	'require'
#        PPI::Token::Whitespace  	' '
#        PPI::Token::Word  	'PAR::Dist'
#        PPI::Token::Structure  	';'
#      PPI::Token::Whitespace  	' '
#      PPI::Statement
#        PPI::Token::Word  	'PAR::Dist'
#        PPI::Token::Operator  	'->'
#        PPI::Token::Word  	'VERSION'
#        PPI::Structure::List  	( ... )
#          PPI::Statement::Expression
#            PPI::Token::Number::Float  	'0.17'


	try {
		my @chunks2 = @{$ppi_doc->find('PPI::Statement')};

		foreach my $chunk (@chunks2) {
			if (
				$chunk->find(
					sub {
						$_[1]->isa('PPI::Token::Word')
							and $_[1]->content =~ m{\A(?:eval|try)\z};
					}
				)
				)
			{

				my $module_name;
				my $module_version;
				for (0 .. $#{$chunk->{children}}) {

					if ($chunk->{children}[$_]->isa('PPI::Structure::Block')) {

						my $ppi_sb = $chunk->{children}[$_]
							if $chunk->{children}[$_]->isa('PPI::Structure::Block');

						$self->eval_info($ppi_sb, \$module_name, \$module_version);

					}

					$req->add_minimum($module_name => $module_version)
						if version::is_lax($module_version);

				}
			}
		}
	};

#PPI::Document
#  PPI::Statement::Sub
#    PPI::Token::Word  	'sub'
#    PPI::Token::Whitespace  	' '
#    PPI::Token::Word  	'_assert_ssl'
#    PPI::Token::Whitespace  	' '
#    PPI::Structure::Block  	{ ... }
#      PPI::Token::Whitespace  	'\n'
#      PPI::Token::Whitespace  	'\t\t'
#      PPI::Statement
#        PPI::Token::Word  	'eval'
#        PPI::Token::Whitespace  	' '
#        PPI::Structure::Block  	{ ... }
#          PPI::Token::Whitespace  	' '
#          PPI::Statement::Include
#            PPI::Token::Word  	'require'
#            PPI::Token::Whitespace  	' '
#            PPI::Token::Word  	'IO::Socket::SSL'
#            PPI::Token::Structure  	';'
#          PPI::Token::Whitespace  	' '
#          PPI::Statement
#            PPI::Token::Word  	'IO::Socket::SSL'
#            PPI::Token::Operator  	'->'
#            PPI::Token::Word  	'VERSION'
#            PPI::Structure::List  	( ... )
#              PPI::Statement::Expression
#                PPI::Token::Number::Float  	'1.44'
#          PPI::Token::Whitespace  	' '
#        PPI::Token::Structure  	';'
#      PPI::Token::Whitespace  	'\n'

	try {
		my @chunks3 = @{$ppi_doc->find('PPI::Statement::Sub')};

		foreach my $chunk (@chunks3) {

			if (
				$chunk->find(
					sub {
						$_[1]->isa('PPI::Token::Word')
							and $_[1]->content =~ m{\A(?:sub)\z};
					}
				)
				)
			{

				my $module_name;
				my $module_version;
				for (0 .. $#{$chunk->{children}}) {
					if ($chunk->{children}[$_]->isa('PPI::Structure::Block')) {
						my $ppi_sb = $chunk->{children}[$_]
							if $chunk->{children}[$_]->isa('PPI::Structure::Block');
						for (0 .. $#{$ppi_sb->{children}}) {
							if ($ppi_sb->{children}[$_]->isa('PPI::Statement')) {
								my $ppi_s = $ppi_sb->{children}[$_]
									if $ppi_sb->{children}[$_]->isa('PPI::Statement');
								my @chunks3 = @{$ppi_s->{children}};
								if (
									any {
										$_->isa('PPI::Token::Word')
											and $_->content =~ m{\A(?:eval|try)\z};
									}
									@{$ppi_s->{children}}
									)
								{
									my @ppisb = first {
										$_->isa('PPI::Structure::Block');
									}
									@{$ppi_s->{children}};

									# extract first Structure::Block
									my $ppi_sb = $ppisb[0];

									$self->eval_info($ppi_sb, \$module_name, \$module_version);

									$req->add_minimum($module_name => $module_version)
										if version::is_lax($module_version);
								}
							}
						}
					}
				}
			}
		}
	};


	return;
}

#######
# composed Method
#######
sub mod_ver {
	my ($self, $req, $eval_include) = @_;

	if ($eval_include =~ /^\s*[use|require|no]/) {

		$eval_include =~ s/^\s*(?:use|require|no)\s*//;

		my $module_name = $eval_include;

		$module_name =~ s/(?:\s[\s|\w|\n|.|;]+)$//;
		$module_name =~ s/\s+(?:[\$|\w|\n]+)$//;
		$module_name =~ s/\s+$//;
		$module_name =~ m/\A([\w|:]+)\b/;
		$module_name = $1;

		# check for first char upper
		next if not $module_name =~ m/\A(?:[A-Z])/;

		my $version_string = $eval_include;
		$version_string =~ s/$module_name\s*//;
		$version_string =~ s/\s*$//;
		$version_string =~ s/[A-Z_a-z]|\s|\$|s|:|;//g;
		$version_string = version::is_lax($version_string) ? $version_string : 0;

		$req->add_minimum($module_name => $version_string);

	}

	return;
}

#######
# composed Method
#######
sub eval_info {
	my ($self, $ppi_sb, $mn_ref, $mv_ref) = @_;

	for (0 .. $#{$ppi_sb->{children}}) {

		# find module name
		if ($ppi_sb->{children}[$_]->isa('PPI::Statement::Include')) {
			my $ppi_si = $ppi_sb->{children}[$_]
				if $ppi_sb->{children}[$_]->isa('PPI::Statement::Include');
			if ( $ppi_si->{children}[0]->isa('PPI::Token::Word')
				&& $ppi_si->{children}[0]->content eq 'require')
			{
				${$mn_ref} = $ppi_si->{children}[2]->content
					if $ppi_si->{children}[2]->isa('PPI::Token::Word');
			}
		}

		# find module version if we previously found a name
		if ($ppi_sb->{children}[$_]->isa('PPI::Statement')) {
			my $ppi_s = $ppi_sb->{children}[$_]
				if $ppi_sb->{children}[$_]->isa('PPI::Statement');
			if (
				(
					    $ppi_s->{children}[0]->isa('PPI::Token::Word')
					and $ppi_s->{children}[0]->content eq ${$mn_ref}
				)
				&& (  $ppi_s->{children}[2]->isa('PPI::Token::Word')
					and $ppi_s->{children}[2]->content eq 'VERSION')
				)
			{
				my $ppi_sl = $ppi_s->{children}[3]
					if $ppi_s->{children}[3]->isa('PPI::Structure::List');
				${$mv_ref} = $ppi_sl->{children}[0]->{children}[0]->content;
			}
		}
	}

	return;
}


1;

__END__


