use strict;
use warnings;

package Perl::PrereqScanner::Scanner::Eval;

# ABSTRACT: scan for module names in an eval EXPR

use Moo;
with 'Perl::PrereqScanner::Scanner';

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
  my @modules;
  my @version_strings;

  #PPI::Document
  #  PPI::Statement
  #    PPI::Token::Word  	'eval'
  #    PPI::Token::Whitespace  	' '
  #    PPI::Token::Quote::Double  	'"require Test::Kwalitee::Extra $mod_ver"'
  #    PPI::Token::Structure  	';'

  my @chunks =
    map  { [$_->schildren] }
    grep { $_->child(0)->literal =~ m{\A(?:eval)\z} }
    grep { $_->child(0)->isa('PPI::Token::Word') }
    @{$ppi_doc->find('PPI::Statement') || []};

  foreach my $hunk (@chunks) {

    if (
      grep {
             $_->isa('PPI::Token::Quote::Double')
          || $_->isa('PPI::Token::Quote::Single')
      } @$hunk
      )
    {

      # hack for List
      my @hunkdata = @$hunk;
      foreach my $element (@hunkdata) {
        if ( $element->isa('PPI::Token::Quote::Double')
          || $element->isa('PPI::Token::Quote::Single'))
        {

          my $eval_line = $element->content;
          $eval_line =~ s/(?:'|"|{|})//g;

          if ($eval_line =~ /::/ && $eval_line =~ /^\s*[use|require|no]/) {

            $eval_line =~ s/^\s*(?:use|require|no)\s*//;

            my $module_name = $eval_line;

            $module_name =~ s/(?:\s[\s|\w|\n|.|;]+)$//;
            $module_name =~ s/\s+(?:[\$|\w|\n]+)$//;
            $module_name =~ s/\s+$//;
            push @modules, $module_name;

            my $version_number = $eval_line;
            $version_number =~ s/$module_name\s*//;
            $version_number =~ s/\s*$//;
			$version_number =~ s/[A-Z_a-z]|\$//g;
            push @version_strings, $version_number || 0;
          }
        }
      }
    }
  }

  foreach (0 .. $#modules) {
    $req->add_minimum($modules[$_] => $version_strings[$_]);
  }

  return;
}

1;

__END__

