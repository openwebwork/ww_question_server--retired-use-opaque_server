package ProblemServer::AnswerResponse;

=pod
=begin WSDL
        _ATTR field         $string The answer field
        _ATTR score         $string The score
        _ATTR answer        $string The students answer
        _ATTR answer_msg    $string A message about the students answer
        _ATTR correct       $string The correct answer
        _ATTR evaluated     $string The evaluated answer
        _ATTR preview       $string A link to the students answer image
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
