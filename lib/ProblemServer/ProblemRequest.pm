package ProblemServer::ProblemRequest;


=pod
=begin WSDL
        _ATTR code          $string The PG code to be translated.
        _ATTR seed          $string The seed to be used for randomization.
        _ATTR files         @string The external files needed.
=end WSDL
=cut
sub new {
    my $self = shift;
    my $data = shift;
    $self = {};
    $self->{code} = $data->{code};
    $self->{seed} = $data->{seed};
    $self->{files} = $data->{files};
    bless $self;
    return $self;
}

1;
