package OpaqueServer::AnswerRequest;

=pod
=begin WSDL
        _ATTR field         $string The Answer field
        _ATTR answer        $string The Answer fields value
=end WSDL
=cut
sub new {
    my $self = shift;
    my $data = shift;
    $self = {};
    $self->{field}  = $data->{field};
    $self->{answer} = $data->{answer};
    bless $self;
    return $self;
}

1;
