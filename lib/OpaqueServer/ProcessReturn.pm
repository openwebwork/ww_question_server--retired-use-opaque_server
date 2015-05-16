package OpaqueServer::ProcessReturn;

=pod
=begin WSDL
        _ATTR XHTML         $string  Problem content
        _ATTR CSS           $string  Problem CSS      	
        _ATTR progressInfo  $string  progress info    
        _ATTR questionEnd   $string   boolean
        _ATTR resources     @OpaqueServer::Resource  array
        _ATTR results       $OpaqueServer::Results  complex value

=end WSDL
=cut
sub new {
    my $self;
    my $data;
    $self = {};
    $self->{XHTML}       	= "";
    $self->{CSS}     		= "";
    $self->{progressInfo}   = "";
    $self->{questionEnd}    = ""; 
    $self->{resources}   	= [];
    $self->{results}     	= ""; 
    bless $self;
    return $self;
}

sub addResource {   # (local_testopaqueqe_resource $resource)
	my $self = shift;
	my ($resource) = @_;
	warn "StartReturn::addResource: resource $resource is not of the correct type" unless ref($resource);
	push @{$self->{resources}} , $resource;
}
1;
