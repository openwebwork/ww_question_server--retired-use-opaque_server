package OpaqueServer::ProblemResponse;

=pod
=begin WSDL
        _ATTR output        $string The HTML output of the question
        _ATTR warnings      $string Any warnings from translation
        _ATTR errors        $string Any errors from translation
        _ATTR seed          $string The seed of the question.
        _ATTR grading       $string The grading option for the question.
=end WSDL
=cut
sub new {
    my $self;
    my $data;
    $self = {};
    $self->{output}     = "";
    $self->{warnings}   = "";
    $self->{errors}     = "";
    $self->{seed}       = "";
    $self->{grading}    = "";
    bless $self;
    return $self;
}

1;
