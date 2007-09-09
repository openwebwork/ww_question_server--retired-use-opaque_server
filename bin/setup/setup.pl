#!/usr/bin/env perl
#
print "###################################\n";
print "#WeBWorK Question Server          #\n";
print "###################################\n";
print "This script will setup the configuration of WeBWorK Question Server.\n";
print "Continue? (y,n):";
$input = <STDIN>;
chop $input;
if($input eq "n") {exit;}


#APACHE 1 OR 2
print "Will you be using Apache 1 or 2\n";
print "(1,2)>";
$apache = <STDIN>;
chop $apache;
if($apache eq "1") {
    $apachecpan = "Apache::SOAP";
} elsif ($apache eq "2") {
    $apachecpan = "Apache2::SOAP";
} else {
    exit;
}


#HOSTNAME
$hostnameExample = "http://www.example.com/";

print "Please enter the http hostname of the computer.\n";
print "This should be a value like '$hostnameExample'\n";
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

print "Please enter the path to 'latex' command. Leave blank for default. \n";
print "Default '/usr/bin/latex'\n";
print ">";
$latex = <STDIN>;
chop $latex;
if($latex eq "") {
    $latex = "/usr/bin/latex";
}

print "Please enter the path to 'dvipng' command. Leave blank for default. \n";
print "Default '/usr/bin/dvipng'\n";
print ">";
$dvipng = <STDIN>;
chop $dvipng;
if($dvipng eq "") {
    $dvipng = "/usr/bin/dvipng";
}

print "Please enter the path to 'tth' command. Leave blank for default. \n";
print "Default '/usr/bin/tth'\n";
print ">";
$tth = <STDIN>;
chop $tth;
if($tth eq "") {
    $tth = "/usr/bin/tth";
}




$rpc = "/problemserver_rpc";
$files = "/problemserver_files";


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
open(OUTP, ">$wsdlfilename") or die("Cannot open file '$wsdlfilename' for writing.\n");
print OUTP $pod->WSDL;
close OUTP;
print "Done\n";

#APACHE CONFIGURATION FILE CREATION
print "Creating Apache Configuration File...\n";

$conffilename = "problemserver.apache-config";

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
$content =~ s/MARKER_FOR_APACHE/$apachecpan/;

print "   Writing...\n";
open(OUTP2, ">$conffilename") or die("Cannot open file '$conffilename' for writing.\n");
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
$content =~ s/MARKER_FOR_DVIPNG/$dvipng/;
$content =~ s/MARKER_FOR_LATEX/$latex/;
$content =~ s/MARKER_FOR_TTH/$tth/;
print "   Writing...\n";
open(OUTP3, ">global.conf") or die("Cannot open file 'global.conf' for writing.\n");
print OUTP3 $content;
close OUTP3;
print "Done\n";

print "Your WSDL path: '" . $hostname . $files . '/'.$wsdlfilename."'\n";

#POST CONFIGURATION
