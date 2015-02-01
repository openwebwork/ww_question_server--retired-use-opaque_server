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
    my $self;
    my $data;
    $self = {};
    $self->{questionSession}       	= "";
    $self->{XHTML}     				= "";
    $self->{CSS}   					= "";
    $self->{progressInfo}     		= ""; 
    $self->{resources}    			= [];
    bless $self;
    return $self;
}

1;
