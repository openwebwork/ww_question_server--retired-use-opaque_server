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
    my $class = shift;
    $class = ref($class) if ref($class); # get class name from object.
    $self = {};
    $self->{content}       = "";
    $self->{encoding}     = "";
    $self->{filename}     = "";
    $self->{mimeType}     = ""; 
    bless $self, $class;
    return $self;
}

sub  make_from_file  {
		my $self = shift;
		my ($path, $name, $mimetype, $encoding ) = @_;
		$encoding//'';		
        my $resource = $self->new();
        $resource->{encoding} = $encoding;
        $resource->{filename} = $name;
        $resource->{mimeType} = $mimetype;
        {   # read file contents
			local( $/ ) ;
			open( my $fh, $path ) or die "can't find file $path to open\n";
			$resource->{content} = <$fh>;
			close($fh);
		}
        return $resource;
}
1;
