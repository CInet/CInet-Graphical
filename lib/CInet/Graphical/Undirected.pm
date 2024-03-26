=encoding utf8

=head1 NAME

CInet::Graphical::Undirected - Separation in undirected graphs

=head1 SYNOPSIS

    # Construct an undirected graph on 5 vertices
    my $G = UndirectedGraph 5 => [[1,2], [2,3], [3,4], [4,5]];
    my $A = $G->relation; # Get its CI structure

=cut

# ABSTRACT: Separation in undirected graphs
package CInet::Graphical::Undirected;

use Modern::Perl 2018;
use Export::Attrs;
use Scalar::Util qw(blessed);

use CInet::Base;
use CInet::Propositional::Families;

use Graph::Undirected;
use Algorithm::Combinatorics qw(subsets);
use Array::Set qw(set_diff);

=head1 DESCRIPTION

This class represents an undirected graph. Every undirected graph defines
a CI relation via its notion of I<separation>: two nodes C<i> and C<j> are
separated given a set of nodes C<K> if every path between C<i> and C<j> in
the graph intersects the set C<K>.

Note that in particular C< (ij|) > holds if and only if there is no path
between the two nodes, i.e., they are in distinct connected components.
There exists a set C<K> such that C< (ij|K) > if and only if there is no
edge between C<i> and C<j>.

The CI relations arising in this way have a finite axiomatization: they
are compositional graphoids which are upward-stable and weakly transitive.
These axioms are available as L<MarkovNetworks|CInet::Propositional::Families>.

=head2 Methods

=head3 new

    my $G = CInet::Graph::Undirected->new($cube => [@edges]);

Construct a new undirected graph whose vertices are indexed by the ground
set elements in C<$cube> and with edges from the array C<@edges> which
must be passed as a reference. Each edge is encoded as a 2-element arrayref
of elements of C<< $cube->set >>.

=cut

sub new {
    my $class = shift;
    my $self = bless { }, $class;

    # Undocumented constructor from a Graph::Undirected.
    if (blessed($_[0]) and $_[0]->isa('Graph::Undirected')) {
        my $graph = shift;
        $self->{cube} = Cube($graph->vertices);
        $self->{graph} = $graph;
    }
    else {
        my ($cube, $edges) = @_;
        $self->{cube} = $cube = Cube($cube);
        $self->{graph} = my $graph = Graph::Undirected->new(
            vertices => $cube->set,
            edges => $edges,
        );
    }
    $self
}

=head3 cube

    my $cube = $G->cube;

Return the underlying L<CInet::Cube> which provides the vertex set of
the graph.

=cut

sub cube {
    shift->{cube}
}

=head3 vertices

    my @V = $G->vertices;

Return the vertices of the graph.

=cut

sub vertices {
    shift->{graph}->vertices
}

=head3 edges

    my @E = $G->edges;

Return the edges of the graph.

=cut

sub edges {
    shift->{graph}->edges
}

=head3 delete

    my $Gd = $G->delete($K);

Delete the vertices C<$K> and all incident edges from the graph.
This is the induced subgraph on the complement of C<$K>.

=cut

sub delete {
    my ($self, $K) = @_;
    my $graph = $self->{graph}->copy;
    __PACKAGE__->new($graph->delete_vertices(@$K))
}

=head3 contract

    my $Gc = $G->contract($K);

Contract the vertices C<$K> in the graph. This removes each vertex
in C<$K> and for each removed vertex, its neighbors are connected
into a clique.

=cut

sub contract {
    my ($self, $K) = @_;
    my $graph = $self->{graph}->copy;
    for my $k (@$K) {
        my $neigh = set_diff([$graph->neighbors($k)], $K);
        $graph->delete_vertex($k);
        $graph->add_edges(map @$_, subsets($neigh, 2));
    }
    __PACKAGE__->new($graph)
}

=head3 paths

    my @all    = $G->paths;
    my @fromto = $G->paths($i => $j);

Given vertices C<$i> and C<$j> in the graph, returns all simple paths
between these vertices. If no vertices are given, all simple paths in
the graph are returned.

=cut

sub paths {
    my $self = shift;
    my $graph = $self->{graph};
    if (@_ == 0) { # all paths
        return map { $graph->all_paths(@$_) } subsets($self->{cube}->set, 2);
    }
    else { # from $i to $j
        return $graph->all_paths(@_);
    }
}

=head3 is_connected

    my $bool = $G->is_connected;

Return if the graph is connected.

=cut

sub is_connected {
    shift->{graph}->is_connected
}

=head3 connected_components

    my @C = $G->connected_components;

Return the connected components as CInet::Graphical::Undirected objects.
The cubes of the components are over subsets of the original ground set.

=cut

sub connected_components {
    my $self = shift;
    return $self if $self->is_connected;
    my $graph = $self->{graph};
    map { __PACKAGE__->new($graph->subgraph($_)) } $graph->connected_components
}

=head3 ci

    my $bool = $G->ci($ijK);

Return whether a square C<$ijK> of C<< $G->cube >> represents a separation
statement in the graph. This checks whether every path from C<$i> to C<$j>
intersects C<$K>, or equivalently if removing C<$K> disconnects C<$i> and
C<$j>.

=cut

sub ci {
    my ($self, $ijK) = @_;
    my ($ij, $K) = @$ijK;
    my ($i, $j) = @$ij;

    # Check if i and j are in different connected components
    # after $K is removed from the graph.
    my $graph = $self->{graph}->copy;
    $graph->delete_vertices(@$K)->is_reachable($i, $j)
}

=head3 relation

    my $A = $G->relation;

Compute the L<CInet::Relation> of the graph containing all separation
statements. For individual statements, see L<ci|/"ci">.

=cut

sub relation {
    my $self = shift;
    my ($cube, $graph) = $self->@{'cube', 'graph'};
    my $N = $cube->set;
    my $A = CInet::Relation->new($cube, '1' x $cube->squares);
    for (subsets($N, 2)) {
        my $ijK = [ $_, set_diff($N, $_) ];
        $A->cival($ijK) = 0 unless $graph->has_edge(@$_);
    }
    Gaussoids->completion($A)
}

=head3 permute

    my $Gp = $G->permute($p);

Apply a permutation of the vertex set. The resulting graph exists
over the same ground set (with the same C<$cube>).

=cut

sub permute {
    my ($self, $p) = @_;
    my $i = 0;
    my %lut = map { $_ => $p->[$i++] } $self->{cube}->set->@*;
    my $perm = sub { $lut{$_[0]} };
    my $graph = $self->{graph}->copy;
    __PACKAGE__->new($self->{cube} => [$graph->rename_vertices($perm)->edges])
}

=head3 description

    my $str = $G->description;

Returns a human-readable description of the object.

=cut

sub description {
    my $self = shift;
    'Undirected graph on vertices ' . join(', ', $self->vertices) .
    ' with edges ' . join(', ', map { join('-', @$_) } $self->edges)
}

=head2 Exports

=head3 UndirectedGraph :Export(:DEFAULT)

    my $G = UndirectedGraph(@args);

This is a shorthand for the C<< CInet::Undireced->new >> constructor.

This sub is exported by default.

=cut

sub UndirectedGraph :Export(:DEFAULT) {
    __PACKAGE__->new(@_)
}

=head3 UndirectedGraphs :Export(:DEFAULT)

    my $seq = UndirectedGraphs($cube);

Returns a lazy sequence of all undirected graphs on the ground set
of C<$cube>.

=cut

sub UndirectedGraphs :Export(:DEFAULT) {
    my $cube = Cube(shift);
    my $it = subsets($cube->set, 2);
    CInet::Seq::Wrapper->new($it)->map(sub{
        __PACKAGE__->new($cube, $_)
    })
}

=head1 AUTHOR

Tobias Boege <tobs@taboege.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (C) 2024 by Tobias Boege.

This is free software; you can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

=cut

":wq"
