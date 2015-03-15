package OpaqueServer::Exception;

=pod
=begin WSDL
        _ATTR content   $string exceptionThrown
=end WSDL
=cut

sub new {
    my $self;
    $self = {};
    $self->{content}       = "";
    bless $self;
    return $self;
}

1;
