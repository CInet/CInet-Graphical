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

use Math::Matrix;

use Algorithm::Combinatorics qw(subsets);
use Array::Set qw(set_diff);

use overload (
    q[""] => \&str,
);

=head1 DESCRIPTION

...

=cut

sub getidx {
    use List::SomeUtils qw(firstidx);
    my $X = shift;
    map {
        my $y = $_;
        my $idx = firstidx { $_ eq $y } @$X;
        die "element '$y' not found" if $idx < 0;
        $idx;
    } @_
}

sub new {
    my ($class, $cube, @edges) = @_;

    my $self = bless { }, $class;
    $self->{cube} = $cube;
    $self->{matrix} = my $matrix =
        Math::Matrix->zeros($cube->dim);

    for my $ij (@edges) {
        my ($i, $j) = getidx($cube->set, @$ij);
        $matrix->[$i][$j] = 1;
        $matrix->[$j][$i] = 1;
    }

    $self
}

sub vertices {
    shift->{cube}->set->@*
}

sub drop {
    my ($self, @K) = @_;
    my $matrix = $self->{matrix};
    my @W = set_diff($self->{cube}->set, \@K)->@*;
    my $cube = CInet::Cube->new(\@W);

    my @edges;
    for my $i (@W) {
        for my $j (@W) {
            push @edges, [$i, $j]
                if $matrix->[$i][$j];
        }
    }
    __PACKAGE__->new($cube => @edges);
}

# Return a double hashref $r such that $r->{$i}{$j} indicates whether
# $i and $j are in the same connected component. The algorithm uses
# the method of summing over powers of the adjacency matrix, mainly
# for ease of implementation, over breadth-first search.
sub reachability {
    my $self = shift;
    my $matrix = $self->{matrix};
    my @V = $self->vertices;

    my $Mk = Math::Matrix->id(0+ @V);
    my $P = Math::Matrix->zeros(0+ @V);
    for (1 .. @V) {
        $Mk *= $matrix;
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
    my ($cube, $matrix) = $self->@{'cube', 'matrix'};

    my %lut;
    for my $idx (0 .. $cube->set->$#*) {
        $lut{$cube->set->[$idx]} = $idx;
    }

    my (@edges, @isol);
    for my $i ($self->vertices) {
        my $c = 0;
        for my $j ($self->vertices) {
            next unless $matrix->[$lut{$i}][$lut{$j}];

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
