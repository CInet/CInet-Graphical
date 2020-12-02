=encoding utf8

=head1 NAME

CInet::Graphical::Undirected - Separation in undirected graphs

=head1 SYNOPSIS

    ...

=cut

# ABSTRACT: Separation in undirected graphs
package CInet::Graphical::Undirected;

use utf8;
use Modern::Perl 2018;
use Export::Attrs;
use Carp;

use CInet::Base;

use Scalar::Util qw(reftype);
use Algorithm::Combinatorics qw(subsets);
use Array::Set qw(set_union set_intersect set_diff set_symdiff);

use overload (
    q[""] => \&str,
);

=head1 DESCRIPTION

...

=cut

sub new {
    my ($class, $cube, @edges) = @_;
    my $self = bless { }, $class;
    $self->{cube} = $cube;
    for my $ij (@edges) {
        my ($i, $j) = @$ij;
        $self->{$i}{$j} = 1;
        $self->{$j}{$i} = 1;
    }
    $self
}

sub vertices {
    shift->{cube}->set->@*
}

sub drop {
    my ($self, @K) = @_;
    my @W = set_diff($self->{cube}->set, \@K)->@*;
    my $cube = CInet::Cube->new(\@W);

    my @edges;
    for my $i (@W) {
        for my $j (@W) {
            push @edges, [$i, $j]
                if $self->{$i}{$j};
        }
    }
    __PACKAGE__->new($cube => @edges);
}

# Return a double hashref $r such that $r->{$i}{$j} indicates whether
# $i and $j are in the same connected component. The algorithm uses
# the method of summing over powers of the adjacency matrix, mainly
# for ease of implementation, over breadth-first search.
sub reachability {
    use Math::Matrix;

    my $self = shift;
    my @V = $self->vertices;
    my @adj;
    for my $i (@V) {
        my @adji;
        for my $j (@V) {
            push @adji, 0+!! $self->{$i}{$j};
        }
        push @adj, [@adji];
    }

    my $M = Math::Matrix->new(@adj);
    my $Mk = Math::Matrix->id(0+ @V);
    my $P = Math::Matrix->zeros(0+ @V);
    for (1 .. @V) {
        $Mk *= $M;
        $P += $Mk;
    }

    my %reach;
    for my $p (0 .. $#V) {
        for my $q (0 .. $#V) {
            $reach{$V[$p]}->{$V[$q]} = 0+!! $P->[$p][$q];
        }
    }

    \%reach
}

sub ci {
    my ($self, $ijK) = @_;
    my ($ij, $K) = @$ijK;
    my ($i, $j) = @$ij;

    # Check if i and j are in different connected components
    # after $K is removed from the graph.
    not $self->drop(@$K)->reachability->{$i}{$j}
}

sub relation {
    my $self = shift;
    my $cube = $self->{cube};
    my $n = $cube->set->@*;
    my $A = CInet::Relation->new($cube);
    for my $K (subsets($cube->set)) {
        next if @$K > $n - 2;
        my $GK = $self->drop(@$K);
        my $r = $GK->reachability;
        for my $ij (subsets([$GK->vertices], 2)) {
            my ($i, $j) = @$ij;
            my $ijK = [ $ij, $K ];
            $A->[$cube->pack($ijK)] = 0+!! $r->{$i}{$j};
        }
    }
    $A
}

sub str {
    my $self = shift;
    my (@edges, @isol);
    for my $i ($self->vertices) {
        my $c = 0;
        for my $j (sort keys $self->{$i}->%*) {
            next unless $self->{$i}{$j};
            $c++;
            push @edges, "$i-$j" unless $j le $i;
        }
        push @isol, $i if not $c;
    }
    join ', ', @edges, @isol
}

sub UndirectedGraphs :Export(:DEFAULT) {
    my $cube = CUBE(shift);
    my @edges = subsets($cube->set, 2);
    map { __PACKAGE__->new($cube, @$_) }
        subsets(\@edges)
}

":wq"
