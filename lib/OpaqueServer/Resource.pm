package OpaqueServer::Resource;

=pod
=begin WSDL
        _ATTR content   $string content
        _ATTR encoding  $string encoding 	
        _ATTR filename  $string filename     
        _ATTR mimeType  $string mimeType

=end WSDL
=cut
sub new {
    my $self;
    $self = {};
    $self->{content}       = "";
    $self->{encoding}     = "";
    $self->{filename}     = "";
    $self->{mimeType}     = ""; 
    bless $self;
    return $self;
}

1;
