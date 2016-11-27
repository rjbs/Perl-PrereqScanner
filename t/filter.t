#!perl
use strict;
use warnings;

use Perl::PrereqScanner;
use PPI::Document;
use Try::Tiny;
use File::Spec::Functions;

use Test::More;

our $LAST_DOCUMENT;

{

    package Perl::PrereqScanner::Filter::StubMunger;

    use Moose qw( with );
    with "Perl::PrereqScanner::Filter";

    sub filter_ppi_document {
        return $_[1];
    }
    __PACKAGE__->meta->make_immutable;
}
{

    package Perl::PrereqScanner::Filter::BadMunger;

    use Moose qw( with );
    with "Perl::PrereqScanner::Filter";

    sub filter_ppi_document { return }
    __PACKAGE__->meta->make_immutable;
}
{

    package Perl::PrereqScanner::Filter::EvalMunger;

    use Moose qw( with );
    with "Perl::PrereqScanner::Filter";

    use Data::Dump qw(pp);
    our $DEPTH = 0;

    sub _find_evals {
        my ($document) = @_;
        return $document->find(
            sub {
                return 0 unless $_[1]->isa('PPI::Statement');
                my $first = $_[1]->first_element;
                return 0
                  unless $first->isa('PPI::Token::Word')
                  and $first->content eq 'eval';
                my $schild = $_[1]->schild(1);
                return 0
                  unless $schild->isa('PPI::Token::Quote')
                  or $schild->isa('PPI::Token::HereDoc');
                return 1;
            }
        ) || [];
    }

    sub _replace_eval {
        my ($eval) = @_;

        my $body = $eval->child(2);

        my $text;

        if ( $body->isa('PPI::Token::HereDoc') ) {
            $text = join q[], $body->heredoc;
        }
        elsif ( $body->can('literal') ) {
            $text = $body->literal;
        }
        elsif ( not $body->interpolations ) {
            $text = $body->string;
            my %UNESCAPE = (
                "\\\"" => "\"",
                "\\\\" => "\\",
            );
            $text =~ s/(\\.)/$UNESCAPE{$1} || $1/ge;
        }
        else {
            return;
        }
        my $fake_document = PPI::Document->new( \"eval { $text }" );
        $eval->{children}->[2] = $fake_document->schild(0)->child(2)->clone;
        _replace_document_evals($eval);
        return $eval;
    }

    sub _replace_document_evals {
        my ($document) = @_;
        pp($document) if $DEPTH > 1;
        my $found_evals = _find_evals($document);
        _replace_eval($_) for @{$found_evals};
        return $document;
    }

    sub filter_ppi_document {
        $::LAST_DOCUMENT = $_[1];
        _replace_document_evals( $_[1] );
        return $_[1];
    }
    __PACKAGE__->meta->make_immutable;
}

my $last_fail;

sub filter_file {
    my ( $filename, $filters ) = @_;

    my $scanner =
      Perl::PrereqScanner->new( { filters => [ @{ $filters || [] } ] } );
    my $result;
    try {
        $result = $scanner->scan_file($filename)->as_string_hash;
        undef $last_fail;
    }
    catch {
        $last_fail = $_;
        $result    = '{{FAIL}}';
    };
    return $result;
}

my $base = { strict => 0, warnings => 0 };
my $expanded = { %{$base}, 'File::Spec' => 0, 'IO::File' => '1.08' };
my $fail = '{{FAIL}}';

my $mungers = {
    'BadMunger' => {
        'simple'  => $fail,
        'heredoc' => $fail,
        'double'  => $fail,
        'block'   => $fail,
    },
    'StubMunger' => {
        'simple'  => $base,
        'heredoc' => $base,
        'double'  => $base,
        'block'   => $expanded,
    },
    'EvalMunger' => {
        'simple'  => $expanded,
        'heredoc' => $expanded,
        'double'  => $expanded,
        'block'   => $expanded,
    },
};

sub do_diag {
    defined $last_fail and diag "Last Error:---\n$last_fail";
    defined $LAST_DOCUMENT
      and diag "Document:---\n" . $LAST_DOCUMENT->serialize;
    PPI::Document->errstr
      and diag "PPI::Document->errstr:---\n" . PPI::Document->errstr;
}

for my $munger ( sort keys %$mungers ) {
    for my $file ( sort keys %{ $mungers->{$munger} } ) {
        my $real_file = catfile( qw( corpus scan ), "eval-$file.pl" );
        is_deeply(
            filter_file( $real_file, [$munger] ),
            $mungers->{$munger}->{$file},
            "$munger gives expected result for eval-$file"
        ) or do_diag;
    }
}

done_testing;
