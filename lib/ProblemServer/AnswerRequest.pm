package ProblemServer::AnswerRequest;

=pod
=begin WSDL
        _ATTR field         $string
        _ATTR answer        $string
=end WSDL
=cut
sub new {
    my $self = shift;
    my $data = shift;
    $self = {};
    $self->{field}   = $data->{field};
    $self->{answer} = $data->{answer};
    bless $self;
    return $self;
}

1;
