use strict;
use warnings;

package Perl::PrereqScanner::Filter;
# ABSTRACT: something that modifies a Perl document for later scanning

use Moose::Role;

=head1 DESCRIPTION

This is a role to be composed into classes that will act as filters plugged
into a Perl::PrereqScanner object.

These classes must provide a C<filter_ppi_document> method, which will be called
like this:

  $ppi_doc = $filter->filter_ppi_document($ppi_doc);

The scanner should return an alter the L<PPI::Document> object to expose
( or hide ) certain classes of syntax for later extraction.

=cut

requires 'filter_ppi_document';

1;
