use Test;
BEGIN { plan tests => 2 }

use strict;
use warnings;

use WWW::Pixelletter::API;

ok( 1 );

my %params = ( username  => 'test',
               password  => 'test',
               test_mode => 'true' );


my $pl;
eval
{
    $pl = new WWW::Pixelletter::API( %params );
};
ok( defined( $pl ), 1, 'Error creating new object: ' . $@ );
