use v5.36;
use open qw(:std :utf8);

package GNewsIO;
use strict;

use warnings;
no warnings;

use Carp qw(carp);
use File::Basename qw(dirname);
use File::Spec::Functions qw(catfile);
use Mojo::JSON qw(decode_json);
use Mojo::URL;
use Mojo::UserAgent;
use Storable qw(dclone);
use String::Redactable;

use GNewsIO::Article;
use GNewsIO::Error;
use GNewsIO::Results;

our $VERSION = '0.001_01';

=encoding utf8

=head1 NAME

GNewsIO - The GNews.io API

=head1 SYNOPSIS

	use GNewsIO;

	my $gnewsio = GNewsIO->new(
		# required for queries
		api_key => $ENV{GNEWSIO_API_KEY},

		# optional
		base_url => $base_url, # if you aren't hitting the actual server
		country  => $country,  # one of the supported news source countries
		lang     => $lang,     # one of the supported languages
		)

=head1 DESCRIPTION

=over 4

=item new( ARGS )




=cut

sub new ($class, %args) {
	my $self = bless {}, $class;
	if( exists $args{'api_key'} ) {
		$self->{'api_key_redactable'} = String::Redactable->new($args{api_key});
		}

	state @keys = qw(base_url country lang);
	foreach my $key ( @keys ) {
		$self->{$key} = $args{'key'} if exists $args{$key};
		}

	$self->{'search_url'}    = $self->base_url->clone->path('search');
	$self->{'headlines_url'} = $self->base_url->clone->path('top-headlines');

	my $data_file_path = $self->_data_file_path;

	$self->{'data'} = {};
	if( -e $data_file_path ) {
		$self->{'data'}  = do {
			local $/;
			open my $fh, '<:encoding(UTF-8)', $data_file_path;
			decode_json(<$fh>);
			};
		}

	return $self;
	}

=back

=head2 Instance methods

=over 4

=item * base_url()

Returns the beginning of the URL (everything but the endpoint name). That's either
the C<base_url> you set in C<new>, or C<https://gnews.io/api/v4/>. Setting a
different base URL might be handy in testing.

=cut

sub base_url ($self) { $self->{'base_url'} //= Mojo::URL->new('https://gnews.io/api/v4/') }

sub _data_file_name ($self) { 'gnewsio_data.json' }

sub _data_file_path ($self) {
	my $inc_path = catfile( split /::/, __PACKAGE__ ) . '.pm';
	my $location = catfile( dirname($INC{$inc_path}), $self->_data_file_name );
	}

sub _has_api_key ($self) {
	exists $self->{'api_key_redactable'};
	}

=item * headlines(HASHREF)

Queries the Headlines endpoint. The accepted keys in HASHREF are:

The return value is an L<GNewsIO::Results> object.

See L<https://docs.gnews.io/endpoints/top-headlines-endpoint>.

=cut

sub headlines ($self, $hash = {} ) {
	my $json = $self->_query( $self->{'headlines_url'}, $hash );
	}

sub _query ($self, $url, $hash = {}) {
	state @keys = qw(country lang);

	unless( $self->_has_api_key ) {
		carp "No API key was set, and queries require it. Create a new object with an API key.";
		return;
		}

	my $args = dclone $hash;
	foreach my $key ( @keys ) {
		next unless exists $self->{$key} ;
		next if     exists $hash->{$key};

		$args->{$key} = $hash->{$key};
		}

	say 'ARGS: ' . Mojo::Util::dumper( $args );
	$url = $url->clone->query($args->%*);

	my $tx = Mojo::UserAgent->new->get(
		$url
		=>  {
			'X-Api-Key' => $self->{'api_key_redactable'}->to_str_unsafe,
			( exists $self->{'user_agent'} ? ('User-agent' => $self->{'user_agent'}) : () ),
			}
		);

	unless($tx->res->is_success) {
		say $tx->req->to_string;
		say $tx->res->to_string;
		return GNewsIO::Error->new(
			code          => $tx->res->code,
			response_body => $tx->res->json,
			);
		}


	say STDERR $tx->req->to_string;

	my $json = $tx->res->json;
	bless $json, 'GNewsIO::Result';

	foreach my $article ( $json->{articles}->@* ) {
		bless $article, 'GNewsIO::Article';
		}

	return $json;
	}

=item * search(STR, HASHREF)

Queries the Search endpoint. The first argument in a string that represents
the query. See L<https://docs.gnews.io/endpoints/search-endpoint#query-syntax>.

*Special characters require quotes around them

The accepted keys in HASHREF are:

The return value is an L<GNewsIO::Results> object.

See L<https://docs.gnews.io/endpoints/search-endpoint>.

=cut

sub search ($self, $q, $hash = {} ) {
	$hash->{'q'} = $q;
	my $json = $self->_query( $self->{'search_url'}, $hash );
	}

=back

=head3 Fetching some data

We can grab the list of supported countries and languages from the official
website. This isn't something that you want to do for regular tasks.

This is also cached in as a JSON file in the same directory as the main
module from the original distribution, which you may not be able to write to.

=over 4

=item * create_data_file

=cut

sub create_data_file ($self, $file = $self->_data_file_path) {
	my $data = $self->_create_data;

	open my $fh, '>:raw', $file or do {
		carp "Could not open <$file> for writing: $!";
		return;
		};

	print {$fh} encode_json($data);
	close $fh;
	}

sub _create_data ($self) {
	my $data = {
		_meta => {
			generator         => __PACKAGE__,
			generated         => scalar localtime,
			generator_version => $self->VERSION,
			},
		countries => {},
		languages => {},
		};

	my $countries = $self->fetch_supported_countries;
	my $languages = $self->fetch_supported_languages;

	$data->{'countries'} = ref $countries ? $countries : {};
	$data->{'languages'} = ref $languages ? $languages : {};

	return $data;
	}

sub _extract ($self, $h2_id) {
	my $dom = $self->_fetch_doc_page;
	return {} unless defined $dom;
	$self->_extract_table($dom, $h2_id);
	}

sub _extract_table ($self, $dom, $h2_id) {
	$dom
		->find( sprintf 'h2#%s + table > tbody tr', $h2_id)
		->map( sub { reverse $_->children->map('text')->to_array->@* } )
		->to_array
		->@*;
	}

sub _fetch_doc_page ($self, $url = 'https://docs.gnews.io/endpoints/top-headlines-endpoint' ) {
	state $cached_dom;
	return $cached_dom if defined $cached_dom;

	my $tx = Mojo::UserAgent->new->get($url);
	return unless $tx->res->is_success;

	return $cached_dom = $tx->res->dom;
	};

=item * fetch_supported_countries

Returns an array ref of hash ref where the key is the two-letter code for the
country and the value is that country's full English name.

=cut

sub fetch_supported_countries ($self) {
	state $h2_id = 'supported-countries';
	my %items = $self->_extract($h2_id);
	return \%items;
	}

=item * fetch_supported_languages

Returns an array ref of hash ref where the key is the two-letter code for the
language and the value is that language's English name.

=cut

sub fetch_supported_languages ($self) {
	state $h2_id = 'supported-languages';
	my %items = $self->_extract($h2_id);
	return \%items;
	}

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
