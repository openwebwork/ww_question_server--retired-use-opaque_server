package OpaqueServer::Results;

=pod
=begin WSDL
        _ATTR questionLine         $string summary of question
        _ATTR answerLine           $string summary of answer        	
        _ATTR actionSummary        $string  summary of action    
        _ATTR attempts             $string   (integer)
        _ATTR scores               @OpaqueServer::Score  compoundObject
        _ATTR customResults        @OpaqueServer::CustomResult compoundObject

=end WSDL
=cut
sub new {
    my $self;
    my $data;
    $self = {};
    $self->{questionLine}       = "";
    $self->{answerLine}     	= "";
    $self->{actionSummary}   	= "";
    $self->{attempts}     		= ""; 
    $self->{scores}   			= [];
    $self->{customResults}     	= []; 

    bless $self;
    return $self;
}

1;
