=encoding utf8

=head1 NAME

CInet::Graphical - Graphical models

=head1 SYNOPSIS

    # Imports all related modules
    use CInet::Graphical;

=head2 VERSION

This document describes CInet::Graphical v0.0.1.

=cut

# ABSTRACT: Graphical models
package CInet::Graphical;

our $VERSION = "v0.0.1";

=head1 DESCRIPTION

...

=cut

use Modern::Perl 2018;
use Import::Into;

sub import {
    CInet::Graphical::Undirected -> import::into(1);
}

=head1 AUTHOR

Tobias Boege <tobs@taboege.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (C) 2020 by Tobias Boege.

This is free software; you can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

=cut

":wq"
