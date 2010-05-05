package Perl::PrereqScanner::Scanner::Perl5;
use Moose;
with 'Perl::PrereqScanner::Scanner';
# ABSTRACT: scan for core Perl 5 language indicators of required modules

=head1 DESCRIPTION

This scanner will look for the following indicators:

=begin :list

* plain lines beginning with C<use> or C<require> in your perl modules and scripts, including minimum perl version

* regular inheritance declared with the C<base> and C<parent> pragmata

=end :list

=cut

sub scan_for_prereqs {
  my ($self, $ppi_doc, $req) = @_;

  # regular use and require
  my $includes = $ppi_doc->find('Statement::Include') || [];
  for my $node ( @$includes ) {
    # minimum perl version
    if ( $node->version ) {
      $req->add_minimum(perl => $node->version);
      next;
    }

    # skipping pragmata
    next if grep { $_ eq $node->module } qw{ strict warnings lib feature };

    # inheritance
    if (grep { $_ eq $node->module } qw{ base parent }) {
      # rt#55713: skip arguments to base or parent, focus only on inheritance
      my @meat = grep {
           $_->isa('PPI::Token::QuoteLike::Words')
        || $_->isa('PPI::Token::Quote')
        } $node->arguments;

      my @parents = map { $self->_q_contents($_) } @meat;
      $req->add_minimum($_ => 0) for @parents;
    }

    # regular modules
    my $version = $node->module_version ? $node->module_version->content : 0;

    # base has been core since perl 5.0
    next if $node->module eq 'base' and not $version;

    # rt#55851: 'require $foo;' shouldn't add any prereq
    $req->add_minimum($node->module, $version) if $node->module;
  }
}

1;
