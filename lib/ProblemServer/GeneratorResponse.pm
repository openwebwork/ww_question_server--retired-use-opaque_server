package ProblemServer::GeneratorResponse;

=pod
=begin WSDL
        _ATTR html  $string
        _ATTR seed  $string
=end WSDL
=cut
sub new {
    my $self = shift;
    my $data = shift;
    $self = {};
    $self->{html}          = $data->{html};
    $self->{seed}          = $data->{seed};
    bless $self;
    return $self;
}

1;
