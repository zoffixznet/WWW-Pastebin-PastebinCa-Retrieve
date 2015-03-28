package WWW::Pastebin::PastebinCa::Retrieve;

use warnings;
use strict;

# VERSION

use base 'WWW::Pastebin::Base::Retrieve';
use HTML::TokeParser::Simple;
use HTML::Entities;

sub _make_uri_and_id {
    my ( $self, $id ) = @_;

    my ( $private ) = $id =~ m{(?:http://)? (?:www\.)? (.+?) pastebin\.ca};

    $private = ''
        unless defined $private;

    $id =~ s{ ^ \s+ | (?:http://)? (?:www\.)?.*? pastebin\.ca/ | \s+ $}{}gxi;
    return ( URI->new("http://${private}pastebin.ca/$id"), $id );
}

sub _parse {
    my ( $self, $content ) = @_;
    return $self->_set_error( 'Nothing to parse (empty document retrieved)' )
        unless defined $content and length $content;

    my $parser = HTML::TokeParser::Simple->new( \$content );

    my %data;
    my %nav = (
        level       => 0,
        get_lang    => 0,
        get_name    => 0,
        get_date    => 0,
        get_desc    => 0,
    );
    while ( my $t = $parser->get_token ) {
        if ( $t->is_start_tag('h2')
            #and defined $t->get_attr('class')
            #and $t->get_attr('class') eq 'first'
        ) {

            $nav{level} = 1;
        }
        elsif ( $nav{level} == 1 and $t->is_start_tag('dt') ) {
            @nav{ qw(level  get_name) } = (2, 1);
        }
        elsif ( $nav{get_name} == 1 and $t->is_text ) {
            $data{name} = $t->as_is;
            $nav{get_name} = 0;
        }
        elsif ( $t->is_start_tag('p') and defined $t->get_attr('id')
            and $t->get_attr('id') eq 'des'
        ) {
            $nav{get_desc} = 1;
        }
        elsif ( $nav{get_desc} and $t->is_text ) {
            $data{desc} = $t->as_is;
            $nav{get_desc} = 0;
        }
        elsif ( $nav{level} == 2 and $t->is_start_tag('dd') ) {
            $nav{get_date} = 1;
            $nav{level}++;
        }
        elsif ( $nav{get_date} and $t->is_text ) {
            $data{post_date} = $t->as_is;
            $data{post_date} =~ s/\s+/ /g;
            $data{post_date} =~ s/&nbsp;//g;
            $nav{get_date}   = 0;
            $nav{level} = 7;
        }
        elsif ( $nav{level} == 7 and $t->is_start_tag('span') ) {
            $nav{level}++;
        }
        elsif ( $t->is_start_tag('textarea')
            and defined $t->get_attr('name')
            and $t->get_attr('name') eq 'content' ) {
            $nav{get_paste} = 1;
        }
        elsif ( $nav{get_paste} and $t->is_text ) {
            $data{content} = $t->as_is;
            $nav{get_paste} = 0;
            $nav{get_lang} = 1;
        }
        elsif ( $nav{get_lang} == 1 and  $t->is_start_tag('select') ) {
            $nav{get_lang} = 2;
        }
        elsif ( $nav{get_lang} == 2 and $t->is_start_tag('option')
            and $t->get_attr('selected')
        ) {
            $nav{get_lang} = 3;
        }
        elsif ( $nav{get_lang} == 3 and $t->is_text ) {
            $data{language} = $t->as_is;
            $nav{success} = 1;
            last;
        }

    }
    unless ( $nav{success} ) {
        my $message = "Failed to parse paste.. ";
        $message .= $nav{level}
                  ? "\$nav{level} == $nav{level}"
                  : "that paste ID doesn't seem to exist";
        return $self->_set_error( $message );
    }

    decode_entities( $_ ) for values %data;

    $self->content( $data{content} );
    return \%data;
}

1;
__END__

=for stopwords desc

=head1 NAME

WWW::Pastebin::PastebinCa::Retrieve - a module to retrieve pastes from http://pastebin.ca/ website

=head1 SYNOPSIS

=for pod_spiffy start code section

    my $paster = WWW::Pastebin::PastebinCa::Retrieve->new;

    $paster->retrieve('http://pastebin.ca/951898')
        or die $paster->error;

    print "Paste content is:\n$paster\n";

=for pod_spiffy end code section

=head1 DESCRIPTION

The module provides interface to retrieve pastes from
L<http://pastebin.ca/> website via Perl.

=head1 CONSTRUCTOR

=head2 C<new>

=for pod_spiffy in key value | out object

    my $paster = WWW::Pastebin::PastebinCa::Retrieve->new;

    my $paster = WWW::Pastebin::PastebinCa::Retrieve->new(
        timeout => 10,
    );

    my $paster = WWW::Pastebin::PastebinCa::Retrieve->new(
        ua => LWP::UserAgent->new(
            timeout => 10,
            agent   => 'PasterUA',
        ),
    );

Constructs and returns a brand new juicy WWW::Pastebin::PastebinCa::Retrieve
object. Takes two arguments, both are I<optional>. Possible arguments are
as follows:

=head3 C<timeout>

=for pod_spiffy in scalar

    ->new( timeout => 10 );

B<Optional>. Specifies the C<timeout> argument of L<LWP::UserAgent>'s
constructor, which is used for retrieving. B<Defaults to:> C<30> seconds.

=head3 C<ua>

=for pod_spiffy in object

    ->new( ua => LWP::UserAgent->new( agent => 'Foos!' ) );

B<Optional>. If the C<timeout> argument is not enough for your needs
of mutilating the L<LWP::UserAgent> object used for retrieving, feel free
to specify the C<ua> argument which takes an L<LWP::UserAgent> object
as a value. B<Note:> the C<timeout> argument to the constructor will
not do anything if you specify the C<ua> argument as well. B<Defaults to:>
plain boring default L<LWP::UserAgent> object with C<timeout> argument
set to whatever C<WWW::Pastebin::PastebinCa::Retrieve>'s C<timeout>
argument is set to as well as C<agent> argument is set to mimic Firefox.

=head1 METHODS

=head2 C<retrieve>

=for pod_spiffy in scalar | out hashref

    my $results_ref = $paster->retrieve('http://pastebin.ca/951898')
        or die $paster->error;

    my $results_ref = $paster->retrieve('951898')
        or die $paster->error;

Instructs the object to retrieve a paste specified in the argument. Takes
one mandatory argument which can be either a full URI to the paste you
want to retrieve or just its ID.
On failure returns either C<undef> or an empty list depending on the context
and the reason for the error will be available via C<error()> method.
On success returns a hashref with the following keys/values:

    $VAR1 = {
          'language' => 'Raw',
          'content' => 'blah blah content of the paste',
          'post_date' => 'Friday, March 21st, 2008 at 1:05:19pm MDT',
          'name' => 'Unnamed',
          'desc' => 'Perl stuff'
    };

=over 14

=item language

    { 'language' => 'Raw' }

The (computer) language of the paste.

=item content

    { 'content' => 'select t.terr_id, max(t.start_date) as start_dat' }

The content of the paste.

=item post_date

    { 'post_date' => 'Wednesday, March 5th, 2008 at 10:31:42pm MST' }

The date when the paste was created

=item name

    { 'name' => 'Mine' }

The name of the poster or the title of the paste.

=item desc

    { 'desc' => 'Perl stuff' }

Contains description of the paste.

=back

=head2 C<error>

=for pod_spiffy in scalar optional | out scalar

    $paster->retrieve('951898')
        or die $paster->error;

On failure C<retrieve()> returns either C<undef> or an empty list depending
on the context and the reason for the error will be available via C<error()>
method. Takes no arguments, returns an error message explaining the failure.

=head2 C<id>

=for pod_spiffy in no args | out scalar

    my $paste_id = $paster->id;

Must be called after a successful call to C<retrieve()>. Takes no arguments,
returns a paste ID number of the last retrieved paste irrelevant of whether
an ID or a URI was given to C<retrieve()>

=head2 C<uri>

=for pod_spiffy in no args | out scalar

    my $paste_uri = $paster->uri;

Must be called after a successful call to C<retrieve()>. Takes no arguments,
returns a L<URI> object with the URI pointing to the last retrieved paste
irrelevant of whether an ID or a URI was given to C<retrieve()>

=head2 C<results>

=for pod_spiffy in no args | out hashref

    my $last_results_ref = $paster->results;

Must be called after a successful call to C<retrieve()>. Takes no arguments,
returns the exact same hashref the last call to C<retrieve()> returned.
See C<retrieve()> method for more information.

=head2 C<content>

=for pod_spiffy in no args | out scalar

    my $paste_content = $paster->content;

    print "Paste content is:\n$paster\n";

Must be called after a successful call to C<retrieve()>. Takes no arguments,
returns the actual content of the paste. B<Note:> this method is overloaded
for this module for interpolation. Thus you can simply interpolate the
object in a string to get the contents of the paste.

=head2 C<ua>

=for pod_spiffy in object | out subref

    my $old_LWP_UA_obj = $paster->ua;

    $paster->ua( LWP::UserAgent->new( timeout => 10, agent => 'foos' );

Returns a currently used L<LWP::UserAgent> object used for retrieving
pastes. Takes one optional argument which must be an L<LWP::UserAgent>
object, and the object you specify will be used in any subsequent calls
to C<retrieve()>.

=for pod_spiffy hr

=head1 REPOSITORY

=for pod_spiffy start github section

Fork this module on GitHub:
L<https://github.com/zoffixznet/WWW-Pastebin-PastebinCa-Retrieve>

=for pod_spiffy end github section

=head1 BUGS

=for pod_spiffy start bugs section

To report bugs or request features, please use
L<https://github.com/zoffixznet/WWW-Pastebin-PastebinCa-Retrieve/issues>

If you can't access GitHub, you can email your request
to C<bug-www-pastebin-pastebinca-retrieve at rt.cpan.org>

=for pod_spiffy end bugs section

=head1 AUTHOR

=for pod_spiffy start author section

=for pod_spiffy author ZOFFIX

=for text Zoffix Znet <zoffix at cpan.org>

=for pod_spiffy end author section

=head1 LICENSE

You can use and distribute this module under the same terms as Perl itself.
See the C<LICENSE> file included in this distribution for complete
details.

=cut
