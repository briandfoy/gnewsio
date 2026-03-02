use v5.10;

my $countries = {
			type => '//any',
			of => [ '//nil', strings( countries() ) ],
			};

my $langs = {
			type => '//any',
			of => [ '//nil', strings( languages() ) ],
			};

my $iso8601 = {
			type => 'tag:example.com,EXAMPLE:rx/datetime/iso8601',
			};

my $query =  { type => '//str', length => { min => 1, max => 200 } };

my $max = {
			type  => '//int',
			range => { min => 1, max => 100 },
			};
my $page = {
			type  => '//int',
			range => { min => 1 },
			};
my $truncate = {
			type => '//any',
			of => [ '//nil', strings( qw(contents) ) ],
			};

my $generator = $0;
chomp( my $repo = `git config --get remote.origin.url` );
chomp( my $commit = `git rev-parse HEAD` );
chomp( my $dirty  = `git status --porcelain -- $0` );
$dirty = !! length $dirty;

my %meta_shared = (
	generator => $generator,
	generated => scalar localtime,
	repo      => $repo,
	commit    => $commit,
	dirty     => $dirty,
	);


# https://docs.gnews.io/endpoints/search-endpoint
my $headlines_params = {
	_meta => {
		%meta_shared,
		url       => 'https://docs.gnews.io/endpoints/top-headlines-endpoint',
		},
	_defaults => {
		page => 1,
		max  => 10,
        'category' => 'general',
		},
	type => '//rec',
	required => {
		},
	optional => {
        'category' => {
        	type => '//any',
        	of   => [ '//nil', strings( qw(general world nation business technology entertainment sports science health) ) ],
        	},
		'lang'     => $langs,
		'country'  => $countries,
		'max'      => $max,
		'nullable' => {
			type => '//any',
			of   => [ '//nil', strings( variations_of( qw(title description image)) ) ],
			},
		'from'     => $iso8601,
		'to'       => $iso8601,
        'q'        => $query,
		'page'     => $page,
		'truncate' => $truncate,
		},
	};

my $search_params = {
	_meta => {
		%meta_shared,
		url       => 'https://docs.gnews.io/endpoints/search-endpoint',
		},
	_defaults => {
		page => 1,
		max  => 10,
		},
    type => '//rec',
    required => {
        'q' => $query,
        },
    optional => {
		'lang'     => $langs,
		'country'  => $countries,
		'max'      => $max,
		'in'       => {
			type => '//any',
			of => [ '//nil', strings( variations_of( qw(title description content)) ) ],
			},
		'nullable' => {
			type => '//any',
			of => [ '//nil', strings( variations_of( qw(title description content)) ) ],
			},
		'from'     => $iso8601,
		'to'       => $iso8601,
		'sortby'   => {
			type => '//any',
			of => [ '//nil', strings( qw(publishedAt relevance) ) ],
			},
		'page'     => $page,
		'truncate' => $truncate,
        },
    };

use YAML::XS qw(Dump);

my @table = (
	[ 'rx/search.rx.yml',    $search_params    ],
	[ 'rx/headlines.rx.yml', $headlines_params ],
	);

ROW: foreach my $row ( @table ) {
	say "Writing $row->[0]";
	open my $fh, '>:encoding(UTF-8)', $row->[0] or do {
		warn "Could not open <$row->[0]>: $!";
		next ROW;
		};
	say { $fh } Dump($row->[1]);
	}

sub variations_of {
	state $rc = require Algorithm::Combinatorics;
	my @items = @_;

	my @combos = ();
	foreach $k ( 1 .. @items ) {
		my $iter = Algorithm::Combinatorics::variations(\@items, $k);
		while (my $perm = $iter->next) {
			push @combos, join(",", @$perm);
			}
		}

	return @combos;
	}

sub strings {
	map { { type => '//str', value => $_ } } @_;
	}

sub languages {
	my $lang_file = 'data/languages.txt';
	my @languages = do {
		open my $fh, '<:utf8', $lang_file;
		map { (split /\s+/)[0] } <$fh>;
		}
	}

sub countries {
	my $lang_file = 'data/countries.txt';
	my @countries = do {
		open my $fh, '<:utf8', $lang_file;
		map { (split /\s+/)[0] } <$fh>;
		}
	}
