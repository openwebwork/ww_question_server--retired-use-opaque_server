package OpaqueServer::Score;

=pod
=begin WSDL
        _ATTR axis   $string Axis for grading if more than one
        _ATTR marks  $string Grade  grade string      	
=end WSDL
=cut
sub new {
    my $class = shift;
    my $marks = shift;
    my $axis = shift//'';
    my $self = {};
    $self->{axis}       = $axis;
    $self->{marks}      = $marks;
    bless $self, $class;
    return $self;
}

1;
