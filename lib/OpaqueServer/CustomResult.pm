package OpaqueServer::Resource;

=pod
=begin WSDL
        _ATTR name   $string    key
        _ATTR value  $string    value (pairs)     	
=end WSDL
=cut
sub new {
    my $self;
    $self = {};
    $self->{name}       = "";
    $self->{value}     = "";
}

1;
