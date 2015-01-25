package OpaqueServer::GeneratorResponse;

=pod
=begin WSDL
        _ATTR problems @OpaqueServer::ProblemResponse An array of problems that were generated.
=end WSDL
=cut
sub new {
    my $self = shift;
    $self = {};

    bless $self;
    return $self;
}

1;
