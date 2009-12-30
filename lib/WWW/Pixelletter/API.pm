package WWW::Pixelletter::API;
use strict;
use warnings;
use LWP::UserAgent;
use File::Util;
use 5.010000;
our $VERSION = '0.1';
use constant ALLOWED_FILE_EXTENSIONS => qw/pdf doc xls ppt rtf wpd psd odt ods odp odg/;
use constant MAX_FILE_SIZE => 8388607;

sub new
{
    my ($class, %args) = @_;
    my $self = {}; 

    # Some Defaults
    $self->{url} = 'http://www.pixelletter.de/xml/index.php';
    $self->{test_mode} = 'false';

    foreach my $arg (keys %args)
    {
        $self->{$arg} = $args{$arg};
    }

    # Check for required parameters
    foreach( qw/username password/ )
    {
        unless( $self->{$_} )
        {
            die( "Required parameter $_ not defined\n" );
        }
    }

    # The user agent can also be passed (if you want to recycle...), but usually
    # it will be defined new here
    if( ! $self->{user_agent} )
    {
        my $ua = LWP::UserAgent->new;
        $self->{user_agent} = $ua;
    }
    bless($self);
    return($self);
}

sub addFile
{
    my( $self, $file ) = @_;
    my $f = File::Util->new();
    my @files;
    if( $self->{files} )
    {
        @files = @{ $self->{files} };
    }

    # Does the file exist
    if( ! -f $file )
    {
        die( "File $file does not exist\n" );
    }

    # Is it one of the "allowed" extensions (a rudementary test to make sure user is
    # not trying to send something which pixelletter does not understand
    my $allowed = undef;
    my $extension = ( $file =~ m/.*\.(.*?)$/ )[0];
    foreach( ALLOWED_FILE_EXTENSIONS )
    {
        if( $_ eq $extension )
        {
            $allowed = 1;
            last;
        }
    }
    if( ! $allowed )
    {
        die( "$extension is not an allowed file type.  Allowed file extensions are: " . join( ', ', ALLOWED_FILE_EXTENSIONS ) . "\n" );
    }

    # Make sure file is not too big (pixelletter only accepts up to 8MB
    if( $f->size( $file ) > MAX_FILE_SIZE )
    {
        die( "Cannot process $file because pixelletter only allowes files up to MAX_FILE_SIZE bytes\n" );
    }

    # Add the file to the form
    push( @files, [$file] );
    $self->{files} = \@files;
}

sub files
{
    my $self = shift;
    return $self->{files};
}

sub filecount
{
    my $self = shift;
    if( $self->{files} )
    {
        return( scalar( @{ $self->{files} } ) );
    }
    return 0;
}

sub sendFax
{
    my( $self, $fax_number ) = @_;
    
    if( ! $fax_number || $fax_number !~ m/^\+[0-9\- ]*$/ )
    {
        die( "Not a valid fax number\n".
             "Pixelletter only accepts fax numbers formated like this example: +49 89 12345678\n".
             "You must have a '+' before the country code, and a space either side of the area " .
             "code\n" );
    }

    if( $self->filecount() < 1 )
    {
        die( "No files to send...\n" );
    }

    my $xml = qq!<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<pixelletter version="1.0">
  <auth>
   <email>$self->{username}</email>
   <password>$self->{password}</password>
   <agb>ja</agb>
   <widerrufsverzicht>ja</widerrufsverzicht>
   <testmodus>$self->{test_mode}</testmodus>
  </auth>
  <order>
    <options>
      <type>upload</type>
      <action>2</action>
      <fax>$fax_number</fax>
     </options>
  </order>
</pixelletter>
!;

    my %form = ( 'xml' => $xml );
    my $file_idx = 0;
    foreach( @{ $self->files() } )
    {
        $form{'uploadfile'.$file_idx} = $_;
        $file_idx++;
    }

    my $response = $self->{user_agent}->post( $self->{url}, Content_Type => 'multipart/form-data', Content => \%form );
    unless ($response->is_success)
    {
        die( "Error connecting to server: " . $response->status_line . "\n" );
    }

    my $response_xml = $response->content;
    if( $response_xml =~ m/result code\=\"(\d*)\".*\<msg\>(.*?)\<\/msg\>/s )
    {
        if( $1 == 100 )
        {
            return( $1, $2 );
        }
        else
        {
            die( "Send failed ($1): $2\n" );
        }
    }
    die( "Send failed:\n$response_xml\n" );
}

sub sendPost
{
    my( $self, $post_center ) = @_;
    die( "sendPost is not implemented yet!\n" );
}
__END__

=pod

=head1 NAME

WWW::Pixelletter::API - an interface to the Pixelletter API

=head1 SYNOPSIS

  use WWW::Pixelletter::API;
  my $pl = WWW::Pixelletter::API->new( 'username' => $username, 'password' => $password, 'test' => undef );

=head1 DESCRIPTION

Interface to pixelletter (http://pixelletter.de/) to allow sending faxes

=head1 METHODS

=head2 new
 
  my $pl = WWW::Pixelletter::API->new( 'username'  => $username, 
                                       'password'  => $password,
                                       'test_mode' => undef );
  $pl->addFile( $filename1 );
  $pl->addFile( $filename2 );
  $pl->sendFax( $fax_number );

Variables:
  username   Your username (email) for pixelletter
  password   Your password
  test_mode  [true|false]  Default is false.  Set to true if you want to test the interface without costs
  url        The default url is defined in the package.  Set to change to another base URL
  user_agent By default a LWP::UserAgent is initialised.  You can pass an existing user agent here if you wish
             to recycle.

=head2 addFile

Add a file to the stack of outgoing files.

  $pl->addFile( $filename );

Allowed file types are: pdf doc xls ppt rtf wpd psd odt ods odp odg
See the Pixelletter website for changes!

=head2 files

returns an array reference of the files already added

=head2 filecount

returns the number of files already added

=head2 sendFax

  $pl->sendFax( $fax_number );

Sends the files to the given fax number

=head2 sendPost

  $pl->sendPost( $mail_center );

Sends the files by post (the first file should have the address field visible through an envelope window!)

!! This function is not yet implemented !!

=head1 AUTHOR

Robin Clarke C<rcl@cpan.org>

=head1 LASTMOD

29.12.2009

=head1 CREATED

29.12.2009

=cut
