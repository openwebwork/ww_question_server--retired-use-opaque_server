package OpaqueServer::StartReturn;

=pod
=begin WSDL
        _ATTR questionSession   $string Any errors from translation
        _ATTR XHTML         	$string The HTML output of the question
        _ATTR CSS           	$string The CSS and javaScript (Header) of the question
        _ATTR progressInfo  	$string student progress (past answers?)
        _ATTR resources         @OpaqueServer::Resource array  of resources
=end WSDL
=cut
sub new {
    my $class = shift;
    my ($questionid, $version, $readonly)= @_;
    $self = {};
    $self->{questionSession}       	= "";
    $self->{XHTML}     				= "";
    $self->{CSS}   					= "";
    $self->{progressInfo}     		= ""; 
    $self->{resources}    			= [];
    # initialize
    $self->{questionSession} = $questionid . '-' . $version;
        if ($readonly) {
            $self->{questionSession} = 'ro-' . $self->{questionSession};
        }
    bless $self, $class;
    return $self;
}

sub addResource {  #(local_testopaqueqe_resource $resource)
	my $self = shift;
	my ($resource) = @_;
	warn "StartReturn::addResource: resource $resource is not of the correct type" unless ref($resource);
	push @{$self->{resources}} , $resource;
}
1;
