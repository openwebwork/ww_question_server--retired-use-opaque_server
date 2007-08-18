#!/usr/bin/env perl
#
print "###################################\n";
print "#WeBWorK Question Server          #\n";
print "###################################\n";
print "This script will setup the configuration of WeBWorK Question Server.\n";
print "Continue? (y,n):";
$input = <STDIN>;
chop $input;
if($input eq "n") {
    exit;
}

$filename = "problemserver.apache-config";

print "Will you be using Apache 1 or 2\n";
print "(1,2)>";
$apache = <STDIN>;
chop $apache;
if($apache eq "1") {
    $apache = "Apache::SOAP";
} elsif ($apache eq "2") {
    $apache = "Apache2::SOAP";
}

print "Please enter the http hostname of the computer.\n";
print "This should be a value like 'http://www.example.com'\n";
print ">";
$hostname = <STDIN>;
chop $hostname;

print "Please enter the root directory where WeBWorK Question Server is located. \n";
print "Example: /var/www/ww_question_server \n";
print ">";
$root = <STDIN>;
chop $root;

print "Please enter the directory where the PG libraries are located. \n";
print "Example: /opt/webwork/pg \n";
print ">";
$pg = <STDIN>;
chop $pg;

print "Do you want to configure optional components.\n";
print "(y,n)>";
$input = <STDIN>;
chop $input;
if($input eq "y") {

    print "Please enter a rpc URL path. Leave blank for default.\n";
    print "Default: '/problemserver_rpc'\n";
    print ">";
    $rpc = <STDIN>;
    chop $rpc;
    if($rpc eq "") {
        $rpc = "/problemserver_rpc";
    }

    print "Please enter a URL path where equation files will be stored. Leave blank for default.\n";
    print "Default: '/problemserver_files'\n";
    print ">";
    $files = <STDIN>;
    chop $files;
    if($files eq "") {
        $files = "/problemserver_files";
    }
} else {
    $rpc = "/problemserver_rpc";
    $files = "/problemserver_files";
}


#WSDL FILE CREATION
print "Creating WSDL File...\n";
eval "use lib '$root/lib'"; die "Your root directory is wrong." if $@;
eval "use Pod::WSDL"; die "You do not have Pod::WSDL installed.\n Run perl -MCPAN -e 'install Pod::WSDL' to install. Then rerun this." if $@;
$pod = new Pod::WSDL(
        source => 'ProblemServer',
        location => $hostname.$rpc,
        pretty => 1,
        withDocumentation => 0
        );
$wsdlfilename = "WSDL.wsdl";
$filename = "problemserver.apache-config";
open(OUTP, ">$wsdlfilename") or die("Cannot open file '$wsdlfilename' for writing.\n");
print OUTP $pod->WSDL;
close OUTP;
print "Done\n";

#APACHE CONFIGURATION FILE CREATION
print "Creating Apache Configuration File...\n";

print "   Setting Variables...\n";
$additionalconf = "my \$hostname = '$hostname';\n";
$additionalconf .= "my \$root_dir = '$root';\n";
$additionalconf .= "my \$root_pg_dir = '$pg';\n";
$additionalconf .= "my \$rpc_url = '$rpc';\n";
$additionalconf .= "my \$files_url = '$files';\n";
$wsdl = $hostname . $files . '/' . $wsdlfilename;
$additionalconf .= "my \$wsdl_url = '$wsdl';\n";

print "   Loading Base...\n";
open(INPUT, "<problemserver.apache-config.base");
$content = "";
while(<INPUT>)
{
    my($line) = $_;
    $content .= $line;
}
close INPUT;
$content =~ s/MARKER_FOR_CONF/$additionalconf/;
$content =~ s/MARKER_FOR_APACHE/$apache/;

print "   Writing...\n";
open(OUTP2, ">$filename") or die("Cannot open file '$filename' for writing.\n");
print OUTP2 $content;
close OUTP2;
print "Done\n";

#GLOBAL CONFIGURATION FILE CREATION
print "Creating Global Configuration File...\n";

print "   Loading Base...\n";
open(INPUT2, "<global.conf.base");
$content = "";
while(<INPUT2>)
{
    my($line) = $_;
    $content .= $line;
}
close INPUT2;
print "   Writing...\n";
open(OUTP3, ">global.conf") or die("Cannot open file 'global.conf' for writing.\n");
print OUTP3 $content;
close OUTP3;
print "Done\n";

#POST CONFIGURATION
print "\n\n\n";
print "####POST SETUP#####\n";
print "You need the '$apache' CPAN Module installed.\n";
print "You need to move 'global.conf' into the conf/ directory.\n";
print "You need to move '$filename' into the conf/ directory.\n";
print "You need to include '$filename' in the apache configuration file.\n";
print "You need to move '$wsdlfilename' into the htdocs/ directory. \n";
