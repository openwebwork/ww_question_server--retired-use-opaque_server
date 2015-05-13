package OpaqueServer::WSDL;

use Pod::WSDL;
use OpaqueServer;

use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );

sub handler($) {
    my ($r) = @_;

    my $pod = new Pod::WSDL(
        source => 'OpaqueServer',
        location => "$OpaqueServer::Host/opaqueserver_rpc", #$ENV{OPAQUESERVER_HOST}.$ENV{OPAQUESERVER_RPC},
        pretty => 1,
        withDocumentation => 0
        );
    #$r->content_type('application/wsdl+xml');
    if (MP2) {
        #$r->send_http_header;
    } else {
        $r->send_http_header;
    }
    print($pod->WSDL);
    return 0;
}

1;
