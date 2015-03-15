package App::GitHooks::Plugin::ValidateChangelogFormat;

use strict;
use warnings;

use base 'App::GitHooks::Plugin';

# Internal dependencies.
use App::GitHooks::Constants qw( :PLUGIN_RETURN_CODES );

# External dependencies.
use CPAN::Changes;
use Try::Tiny;
use version qw();


=head1 NAME

App::GitHooks::Plugin::ValidateChangelogFormat - Validate the format of changelog files.


=head1 DESCRIPTION

This plugin verifies that the changes log conforms to the specifications
outlined in C<CPAN::Changes::Spec>.


=head1 VERSION

Version 1.0.0

=cut

our $VERSION = '1.0.0';


=head1 METHODS

=head2 get_file_pattern()

Return a pattern to filter the files this plugin should analyze.

    my $file_pattern = App::GitHooks::Plugin::ValidateChangelogFormat->get_file_pattern(
        app => $app,
    );

=cut

sub get_file_pattern
{
    return qr/^(?:changes|changelog)(?:\.(?:md|pod))?$/ix;
}


=head2 get_file_check_description()

Return a description of the check performed on files by the plugin and that
will be displayed to the user, if applicable, along with an indication of the
success or failure of the plugin.

    my $description = App::GitHooks::Plugin::ValidateChangelogFormat->get_file_check_description();

=cut

sub get_file_check_description
{
    return 'The changelog format matches CPAN::Changes::Spec.';
}

=head2 run_pre_commit_file()

Code to execute for each file as part of the pre-commit hook.

    my $success = App::GitHooks::Plugin::ValidateChangelogFormat->run_pre_commit_file();

The code in this subroutine is mostly adapted from L<Test::CPAN::Changes>.

=cut

sub run_pre_commit_file
{
    my ( $class, %args ) = @_;
    my $file = delete( $args{'file'} );
    my $git_action = delete( $args{'git_action'} );
    my $app = delete( $args{'app'} );
    my $repository = $app->get_repository();

    # Ignore deleted files.
    return $PLUGIN_RETURN_SKIPPED
        if $git_action eq 'D';

    my $changes =
    try {
        return CPAN::Changes->load( $repository->work_tree() . '/' . $file );
    }
    catch {
        die "Unable to parse the change log\n";
    };

    my @releases = $changes->releases();

    die "The change log does not contain any releases\n"
        if scalar( @releases ) == 0;

    my @errors = ();
    my $count = 0;
    foreach my $release ( @releases ) {
        $count++;
        my $error_prefix = sprintf(
            "Release %s/%s",
            $count,
            scalar( @releases ),
        );

        try {
            my $date = $release->date();

            die "the release date is missing.\n"
                if !defined( $date ) || ( $date eq '' );

            die "date '$date' is not in the recommended format.\n"
                if $date !~ m/^${CPAN::Changes::W3CDTF_REGEX}$/x && $date !~ m/^${CPAN::Changes::UNKNOWN_VALS}$/x;

        }
        catch {
            push( @errors, "$error_prefix: $_" );
        };

        try {
            # Strip off -TRIAL before testing.
            ( my $version = $release->version() ) =~ s/-TRIAL$//;

            die "the version number is missing.\n"
                if $version eq '';

            die "version '$version' is not a valid version number.\n"
                if !version::is_lax($version);
        }
        catch {
            push( @errors, "$error_prefix: $_" );
        };
    }

    die join( '', @errors ) . "\n"
        if scalar( @errors ) != 0;

    return $PLUGIN_RETURN_PASSED;
}


=head1 SEE ALSO

=over 4

=item * L<Test::CPAN::Changes>

=item * L<CPAN::Changes::Spec>

=item * L<CPAN::Changes>

=back


=head1 BUGS

Please report any bugs or feature requests through the web interface at
L<https://github.com/guillaumeaubert/App-GitHooks-Plugin-ValidateChangelogFormat/issues/new>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc App::GitHooks::Plugin::ValidateChangelogFormat


You can also look for information at:

=over

=item * GitHub's request tracker

L<https://github.com/guillaumeaubert/App-GitHooks-Plugin-ValidateChangelogFormat/issues>

=item * AnnoCPAN: Annotated CPAN documentation

l<http://annocpan.org/dist/app-githooks-plugin-validatechangelogformat>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/app-githooks-plugin-validatechangelogformat>

=item * MetaCPAN

L<https://metacpan.org/release/App-GitHooks-Plugin-ValidateChangelogFormat>

=back


=head1 AUTHOR

L<Guillaume Aubert|https://metacpan.org/author/AUBERTG>,
C<< <aubertg at cpan.org> >>.


=head1 COPYRIGHT & LICENSE

Copyright 2015 Guillaume Aubert.

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License version 3 as published by the Free
Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see http://www.gnu.org/licenses/

=cut

1;
