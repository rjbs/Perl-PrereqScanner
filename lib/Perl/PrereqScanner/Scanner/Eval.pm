use strict;
use warnings;

package Perl::PrereqScanner::Scanner::Eval;

# ABSTRACT: scan for module names in an eval EXPR

use Moo;
with 'Perl::PrereqScanner::Scanner';
use version 0.9902;
use Try::Tiny 0.12;

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

  my @chunks
    = map { [$_->schildren] }
    grep  { $_->child(0)->literal =~ m{\A(?:eval)\z} }
    grep  { $_->child(0)->isa('PPI::Token::Word') }
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

          my @eval_includes = split /;/, $eval_line;
          foreach my $eval_include (@eval_includes) {

#            if ( $eval_include =~ /::/
#              && $eval_include =~ /^\s*[use|require|no]/)
            if ( $eval_include =~ /^\s*[use|require|no]/) {

              $eval_include =~ s/^\s*(?:use|require|no)\s*//;

              my $module_name = $eval_include;

              $module_name =~ s/(?:\s[\s|\w|\n|.|;]+)$//;
              $module_name =~ s/\s+(?:[\$|\w|\n]+)$//;
              $module_name =~ s/\s+$//;
              push @modules, $module_name;

              my $version_number = $eval_include;
              $version_number =~ s/$module_name\s*//;
              $version_number =~ s/\s*$//;
              $version_number =~ s/[A-Z_a-z]|\s|\$|s|:|;//g;

              try {
                push @version_strings, $version_number
                  if version->parse($version_number)->is_lax;
              }
              catch {
                push @version_strings, 0 if $_;
              };
            }
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

