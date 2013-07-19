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

  #PPI::Document
  #  PPI::Statement
  #    PPI::Token::Word  	'eval'
  #    PPI::Token::Whitespace  	' '
  #    PPI::Token::Quote::Double  	'"require Test::Kwalitee::Extra $mod_ver"'
  #    PPI::Token::Structure  	';'

try{
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
          || $_->isa('PPI::Structure::Block')
      } @$hunk
      )
    {
      my @hunkdata = @$hunk;

      foreach my $element (@hunkdata) {
        if ( $element->isa('PPI::Token::Quote::Double')
          || $element->isa('PPI::Token::Quote::Single'))
        {

          my $eval_line = $element->content;
          $eval_line =~ s/(?:'|"|{|})//g;
          my @eval_includes = split /;/, $eval_line;

          foreach my $eval_include (@eval_includes) {
            $self->mod_ver($req, $eval_include);
          }
        }
      }

      foreach my $element_block (@hunkdata) {
        if ($element_block->isa('PPI::Structure::Block')) {

          my @children = $element_block->children;

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

#######
# my $HAVE_MOOSE = eval { require Moose };
# # my $HAVE_MOOSE = eval '|" require Moose '|";
#######
try {
  my @chunk2
    = map { [$_->schildren] }
    grep  { $_->child(6)->literal =~ m{\A(?:eval)\z} }
    grep  { $_->child(6)->isa('PPI::Token::Word') }
    @{$ppi_doc->find('PPI::Statement::Variable') || []};

  foreach my $hunk2 (@chunk2) {

    if (
      grep {
             $_->isa('PPI::Token::Quote::Double')
          || $_->isa('PPI::Token::Quote::Single')
          || $_->isa('PPI::Structure::Block')
      } @$hunk2
      )
    {
      my @hunkdata = @$hunk2;

      foreach my $element_block (@hunkdata) {
        if ($element_block->isa('PPI::Structure::Block')) {
          my @children = $element_block->children;

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
      foreach my $element (@hunkdata) {
        if ( $element->isa('PPI::Token::Quote::Double')
          || $element->isa('PPI::Token::Quote::Single'))
        {

          my $eval_line = $element->content;
          $eval_line =~ s/(?:'|"|{|})//g;
          my @eval_includes = split /;/, $eval_line;

          foreach my $eval_include (@eval_includes) {
            $self->mod_ver($req, $eval_include);
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

    my $version_number = $eval_include;
    $version_number =~ s/$module_name\s*//;
    $version_number =~ s/\s*$//;
    $version_number =~ s/[A-Z_a-z]|\s|\$|s|:|;//g;

    try {
      version->parse($version_number)->is_lax;
    }
    catch {
      $version_number = 0 if $_;
    };

    $req->add_minimum($module_name => $version_number);

  }

  return;
}


1;

__END__

