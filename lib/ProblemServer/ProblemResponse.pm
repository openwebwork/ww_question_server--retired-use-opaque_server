package ProblemServer::ProblemResponse;

=pod
=begin WSDL
        _ATTR id            $string
        _ATTR head_text     $string
        _ATTR body_text     $string
        _ATTR seed          $string
        _ATTR answers       @ProblemServer::AnswerResponse
        _ATTR warnings      $string
        _ATTR errors        $string
        _ATTR flags         $string
        _ATTR result        $string
        _ATTR state         $string
=end WSDL
=cut
sub new {
    my $self;
    my $data;
    $self = {};
    $self->{id}         = "0";
    $self->{head_text}  = "Default Header";
    $self->{body_text}  = "Default Body";
    $self->{seed}       = "0";
    $self->{answers}    = {};
    $self->{warnings}   = "";
    $self->{errors}     = "";
    $self->{flags}      = "";
    $self->{result}     = "";
    $self->{state}      = "";
    bless $self;
    return $self;
}

1;
