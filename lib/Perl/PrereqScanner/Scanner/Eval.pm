use strict;
use warnings;

package Perl::PrereqScanner::Scanner::Eval;

# ABSTRACT: scan for module names in an eval EXPR
use Types::Standard qw( ArrayRef );
use Moo;
with 'Perl::PrereqScanner::Scanner';
use version 0.9902;
use Try::Tiny 0.12;
use Data::Printer {caller_info => 1, colored => 1,};

has 'modules' => (
	is      => 'rw',
	isa     => ArrayRef,
	init_arg => undef,
	clearer => '_clear_modules',
);

=head1 DESCRIPTION

This scanner will look for the following formats or variations there in,
note all lines start with eval:

=begin :list

* eval "use Test::Pod $min_tp";

* eval "use Win32::UTCFileTime" if $^O eq 'MSWin32' && $] >= 5.006;

* eval "require Test::Kwalitee::Extra";

=end :list

=cut

#my @modules;
#my @version_strings;


sub scan_for_prereqs {
  my ($self, $ppi_doc, $req) = @_;

  my @modules;
$self->_clear_modules;

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

#  p @chunks;

  foreach my $hunk (@chunks) {

    if (
      grep {
             $_->isa('PPI::Token::Quote::Double')
          || $_->isa('PPI::Token::Quote::Single')
          || $_->isa('PPI::Structure::Block')
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
          p $eval_line;
          $eval_line =~ s/(?:'|"|{|})//g;

          my @eval_includes = split /;/, $eval_line;

          foreach my $eval_include (@eval_includes) {

#            if ( $eval_include =~ /::/
#              && $eval_include =~ /^\s*[use|require|no]/)
#


            if ($eval_include =~ /^\s*[use|require|no]/) {

              $eval_include =~ s/^\s*(?:use|require|no)\s*//;

              $self->mod_ver( $req, $eval_include);
## consider composed method theory start

#              my $module_name = $eval_include;
#
#              $module_name =~ s/(?:\s[\s|\w|\n|.|;]+)$//;
#              $module_name =~ s/\s+(?:[\$|\w|\n]+)$//;
#              $module_name =~ s/\s+$//;
#              push @modules, $module_name;
#
#              my $version_number = $eval_include;
#              $version_number =~ s/$module_name\s*//;
#              $version_number =~ s/\s*$//;
#              $version_number =~ s/[A-Z_a-z]|\s|\$|s|:|;//g;
#
#              try {
#                push @version_strings, $version_number
#                  if version->parse($version_number)->is_lax;
#              }
#              catch {
#                push @version_strings, 0 if $_;
#              };


## consider composed method theory end

            }
          }
        }
      }
#      p @hunkdata;
      foreach my $element_block (@hunkdata) {
        if ($element_block->isa('PPI::Structure::Block')) {

#          p $element_block;
          my @children = $element_block->children;

#          p @children;

          foreach my $child_element (@children) {
            if ($child_element->isa('PPI::Statement::Include')) {

              my $eval_line = $child_element->content;

          my @eval_includes = split /;/, $eval_line;

          foreach my $eval_include (@eval_includes) {



#              p $eval_include;
              if ($eval_include =~ /^\s*[use|require|no]/) {

                $eval_include =~ s/^\s*(?:use|require|no)\s*//;
                p $eval_include;

                $self->mod_ver( $req, $eval_include);

#              my $module_name = $eval_include;
#
#              $module_name =~ s/(?:\s[\s|\w|\n|.|;]+)$//;
#              $module_name =~ s/\s+(?:[\$|\w|\n]+)$//;
#              $module_name =~ s/\s+$//;
##              push @modules, $module_name;
##              push @{$self->modules}, $module_name ;
##@modules = @{$self->modules};
##p @modules;
##p $self->modules;
#
##return;
#              my $version_number = $eval_include;
#              $version_number =~ s/$module_name\s*//;
#              $version_number =~ s/\s*$//;
#              $version_number =~ s/[A-Z_a-z]|\s|\$|s|:|;//g;
#
#              try {
#				 version->parse($version_number)->is_lax;
#              }
#              catch {
#                $version_number =0 if $_;
#              };
#
#p $version_number;
#$req->add_minimum($module_name => $version_number);

              }

}

            }
          }


        }
      }

    }
  }

#p $self->modules;

  foreach (0 .. $#modules) {
    $req->add_minimum($modules[$_] => $version_strings[$_]);
  }

  return;
}

#######
# composed Method
#######
sub mod_ver {
  my ($self, $req, $eval_include) = @_;
p $eval_include;
  my $module_name = $eval_include;

  $module_name =~ s/(?:\s[\s|\w|\n|.|;]+)$//;
  $module_name =~ s/\s+(?:[\$|\w|\n]+)$//;
  $module_name =~ s/\s+$//;
#  push @modules, $module_name;
#  p @modules;
p $module_name;

  my $version_number = $eval_include;
  $version_number =~ s/$module_name\s*//;
  $version_number =~ s/\s*$//;
  $version_number =~ s/[A-Z_a-z]|\s|\$|s|:|;//g;

#  try {
#    push @version_strings, $version_number
#      if version->parse($version_number)->is_lax;
#  }
#  catch {
#    push @version_strings, 0 if $_;
#  };
#  p @version_strings;
              try {
				 version->parse($version_number)->is_lax;
              }
              catch {
                $version_number =0 if $_;
              };

p $version_number;
$req->add_minimum($module_name => $version_number);

  return;
}


1;

__END__

