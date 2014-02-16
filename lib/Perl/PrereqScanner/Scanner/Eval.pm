use strict;
use warnings;

package Perl::PrereqScanner::Scanner::Eval;

# ABSTRACT: scan for module names in an eval EXPR

use Moo;
with 'Perl::PrereqScanner::Scanner';

use Try::Tiny;

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


1;

__END__


