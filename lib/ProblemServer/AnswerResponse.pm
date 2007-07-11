package ProblemServer::AnswerResponse;

=pod
=begin WSDL
        _ATTR field         $string
        _ATTR score         $string
        _ATTR answer        $string
        _ATTR answer_msg    $string
        _ATTR correct       $string
        _ATTR evaluated     $string
        _ATTR preview       $string
=end WSDL
=cut
sub new {
    my $self = shift;
    my $data = shift;
    $self = {};
    $self->{field}          = $data->{field};
    $self->{answer}         = $data->{answer};
    $self->{answer_msg}     = $data->{answer_msg};
    $self->{correct}        = $data->{correct};
    $self->{score}          = $data->{score};
    $self->{evaluated}      = $data->{evaluated};
    $self->{preview}        = $data->{preview};
    bless $self;
    return $self;
}

1;
