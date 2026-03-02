use v5.36;

package GNewsIO::Error;
use parent qw(Hash::AsObject);

=encoding utf8

=head1 NAME

GNewsIO::Error - the result from a bad query

=head1 SYNOPSIS

	my $result = GNewsIO->new(...)->search( ... );

	if( $result->is_error ) { # you have this sort of object
		...
		}
	else {  # you have the GNewsIO::Result
		...
		}

=head1 DESCRIPTION

=over 4

=item * articles

Returns the empty array ref, always, to have the same interface as L<GNewsIO::Result>.

=cut

sub articles       ($self) { [] }

sub errors         ($self) {
	my $e = $self->{'response_body'}{'errors'} ;
	if( ref $e eq ref [] ) {
		return [ $self->{'response_body'}{'errors'}->@* ];
		}
	elsif( ref $e eq ref {} ) {
		return [ map { "Parameter <$_>: $e->{$_}" } keys $e->%* ];
		}
	}

=item * information

Returns the empty hash ref, always, to have the same interface as L<GNewsIO::Result>.

=cut

sub information    ($self) { {} }

sub is_auth_error  ($self) {
	$self->{code} =~ m/400/a
		&&
	exists $self->{response_body}
		&&
	exists $self->{response_body}{'errors'}
		&&
	grep /API key/, $self->{response_body}{'errors'}->@*
	}

=item * is_error

Returns true, always. The same method in L<GNewsIO::Result> returns false.

=cut

sub is_error       ($self) { 1 }

=item * is_query_error

Returns true if these are all true (found by trial and error):

=over 4

=item * the HTTP response code is 400 (which seems to be the only one it uses)

=item * the errors in the response JSON is an array ref (sometimes its a hash ref)

=item * one of the error strings mentions C<query>

=back

Note that
=cut

sub is_query_error ($self) {
	$self->{code} =~ m/400/a
		&&
	exists $self->{response_body}
		&&
	exists $self->{response_body}{'errors'}
		&&
	ref $self->{response_body}{'errors'} eq ref []
		&&
	grep /query/, $self->{response_body}{'errors'}->@*
	}

=item * is_error

Returns false, always. The same method in L<GNewsIO::Result> returns true.

=cut

sub is_success     ($self) { 0 }


=item * total_articles

Returns 0, always. The same method in L<GNewsIO::Result> returns the number
of articles.

=cut

sub total_articles ($self) { 0  }

=back

=head1 TO DO


=head1 SEE ALSO


=head1 SOURCE AVAILABILITY

This source is in Github:

	http://github.com/briandfoy/gnews

=head1 AUTHOR

brian d foy, C<< <> >>

=head1 COPYRIGHT AND LICENSE

Copyright © 2026-2026, brian d foy, All Rights Reserved.

You may redistribute this under the terms of the Artistic License 2.0.

=cut

__PACKAGE__;
