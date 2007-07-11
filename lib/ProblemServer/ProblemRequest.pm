package ProblemServer::ProblemRequest;


=pod
=begin WSDL
        _ATTR id            $string
        _ATTR code          $string
        _ATTR seed          $string
        _ATTR displayMode   $string
        _ATTR answers       @ProblemServer::AnswerRequest
=end WSDL
=cut
sub new {
    my $self = shift;
    my $data = shift;
    $self = {};
    $self->{id}   = $data->{id};
    $self->{code} = $data->{code};
    $self->{seed} = $data->{seed};
    $self->{displayMode} = $data->{displayMode};
    $self->{answers} = $data->{answers};

    bless $self;
    return $self;
}

1;
