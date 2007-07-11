package ProblemServer::WSDL;

use ProblemServer::Environment;
use Pod::WSDL;

use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );

sub handler($) {
    my ($r) = @_;
    my $environ = new ProblemServer::Environment($ENV{PROBLEMSERVER_ROOT});
    my $pod = new Pod::WSDL(
        source => 'ProblemServer',
        location => $environ->{problemServer}->{rpc},
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
