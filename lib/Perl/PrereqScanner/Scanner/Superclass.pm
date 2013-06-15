use strict;
use warnings;

package Perl::PrereqScanner::Scanner::Superclass;
use Moo;
with 'Perl::PrereqScanner::Scanner';
# ABSTRACT: scan for modules loaded with superclass.pm

=head1 DESCRIPTION

This scanner will look for dependencies from the L<superclass> module:

    use superclass 'Foo', Bar => 1.23;

=cut

my $mod_re = qr/^[A-Z_a-z][0-9A-Z_a-z]*(?:(?:::|')[0-9A-Z_a-z]+)*$/;

sub scan_for_prereqs {
    my ( $self, $ppi_doc, $req ) = @_;

    # regular use, require, and no
    my $includes = $ppi_doc->find('Statement::Include') || [];
    for my $node (@$includes) {
        # inheritance
        if ( $node->module eq 'superclass' ) {
            # rt#55713: skip arguments like '-norequires', focus only on inheritance
            my @meat = grep {
                     $_->isa('PPI::Token::QuoteLike::Words')
                  || $_->isa('PPI::Token::Quote')
                  || $_->isa('PPI::Token::Number')
            } $node->arguments;

            my @args = map { $self->_q_contents($_) } @meat;

            while (@args) {
                my $module = shift @args;
                my $version = ( @args && $args[0] !~ $mod_re ) ? shift(@args) : 0;
                $req->add_minimum( $module => $version );
            }
        }
    }
}

1;
