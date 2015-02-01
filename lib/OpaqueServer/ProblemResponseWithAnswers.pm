package OpaqueServer::ProblemResponseWithAnswers;

=pod
=begin WSDL
        _ATTR problem       $OpaqueServer::ProblemResponse The problem response
        _ATTR answers       @OpaqueServer::AnswerResponse The answers
=end WSDL
=cut
sub new {
    my $self = shift;
    $self = {};
    bless $self;
    return $self;
}

1;
