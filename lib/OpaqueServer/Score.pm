package OpaqueServer::Score;

=pod
=begin WSDL
        _ATTR axis   $string Axis for grading if more than one
        _ATTR marks  $string Grade        	
=end WSDL
=cut
sub new {
    my $self;
    $self = {};
    $self->{axis}       = "";
    $self->{marks}      = "";
    bless $self;
    return $self;
}

1;
