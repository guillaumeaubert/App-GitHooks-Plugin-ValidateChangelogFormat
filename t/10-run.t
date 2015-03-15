#!perl

use strict;
use warnings;

# Note: don't include Test::FailWarnings here as it interferes with
# Capture::Tiny.
use Capture::Tiny;
use Test::Exception;
use Test::Git;
use Test::More;

use App::GitHooks::Test qw( ok_add_files ok_setup_repository );


## no critic (RegularExpressions::RequireExtendedFormatting)

# Require git.
has_git( '1.7.4.1' );

# List of tests to perform.
my $tests =
[
	# Make sure the plugin correctly analyzes changelog files.
	(
		map
		{
			{
				name     => "'$_' is a monitored file name.",
				files    =>
				{
					$_ => "test\n",
				},
				expected => qr/\Qx The changelog format matches CPAN::Changes::Spec.\E/,
			},
		} qw( Changes CHANGELOG Changes.pod changelog.md )
	),
	# The changelog must contain at least one release.
	{
		name     => 'The changelog must contain at least one release.',
		files    =>
		{
			'Changes' => "Release for test package.\n",
		},
		expected => qr/\Qx The changelog format matches CPAN::Changes::Spec.\E/,
	},
];

# Bail out if Git isn't available.
has_git();
plan( tests => scalar( @$tests ) );

foreach my $test ( @$tests )
{
	subtest(
		$test->{'name'},
		sub
		{
			plan( tests => 4 );

			my $repository = ok_setup_repository(
				cleanup_test_repository => 1,
				config                  => $test->{'config'},
				hooks                   => [ 'pre-commit' ],
				plugins                 => [ 'App::GitHooks::Plugin::ValidateChangelogFormat' ],
			);

			# Set up test files.
			ok_add_files(
				files      => $test->{'files'},
				repository => $repository,
			);

			# Try to commit.
			my $stderr;
			lives_ok(
				sub
				{
					$stderr = Capture::Tiny::capture_stderr(
						sub
						{
							$repository->run( 'commit', '-m', 'Test message.' );
						}
					);
					note( $stderr );
				},
				'Commit the changes.',
			);

			like(
				$stderr,
				$test->{'expected'},
				"The output matches expected results.",
			);
		}
	);
}
