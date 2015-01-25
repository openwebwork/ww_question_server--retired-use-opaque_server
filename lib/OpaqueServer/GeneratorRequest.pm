package OpaqueServer::GeneratorRequest;

=pod
=begin WSDL
        _ATTR trials $string The number of attempts at generation
        _ATTR problem $OpaqueServer::ProblemRequest The problem to be generated
=end WSDL
=cut
sub new {
    my $self = shift;
    $self={};
    bless $self;
    return $self;
}

1;
