#!/Volumes/WW_test/opt/local/bin/perl -w

################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package OpaqueServer::RenderProblem;
=head1 NAME

Render one pg problem problem from the command line by directly accessing 
the pg directory and parts of the webwork2 directory.

=head1 SYNOPSIS

 use WeBWorK::Utils::Tasks qw(renderProblems);

=head1 DESCRIPTION

This module provides functions for rendering html from files outside the normal
context of being for a particular user in an existing problem set.

It also provides functions which are useful for taking problems which are not
part of any set and making live versions of them, or loading them into the
editor.

=cut

use strict;
use warnings;


#######################################################
# Find the webwork2 root directory
#######################################################
BEGIN {
        die "WEBWORK_ROOT not found in environment. \n
             WEBWORK_ROOT can be defined in your .cshrc or .bashrc file\n
             It should be set to the webwork2 directory (e.g. /opt/webwork/webwork2)"
                unless exists $ENV{WEBWORK_ROOT};
	# Unused variable, but define it twice to avoid an error message.
	$WeBWorK::Constants::WEBWORK_DIRECTORY = $ENV{WEBWORK_ROOT};
	
	# Define MP2 -- this would normally be done in webwork.apache2.4-config
	$ENV{MOD_PERL_API_VERSION}=2;
}

####################################
# Specify that we are using apache2 protocol
####################################
use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );

###################################
# Obtain the basic urls and the paths to the basic directories on this site
###################################

BEGIN {
	my $hostname = 'http://localhost';
	my $courseName = 'gage_course';

	#Define the OpaqueServer static variables
	my $topDir = $WeBWorK::Constants::WEBWORK_DIRECTORY;
	$topDir =~ s|webwork2?$||;   # remove webwork2 link
	my $root_dir = "$topDir/ww_opaque_server";
	my $root_pg_dir = "$topDir/pg";
	my $root_webwork2_dir = "$topDir/webwork2";

	my $rpc_url = '/opaqueserver_rpc';
	my $files_url = '/opaqueserver_files';
	my $wsdl_url = '/opaqueserver_wsdl';

	
	# Find the library directories for 
	# ww_opaque_server, pg and webwork2
	# and place them in the search path for modules

	eval "use lib '$root_dir/lib'"; die $@ if $@;
	eval "use lib '$root_pg_dir/lib'"; die $@ if $@;
	eval "use lib '$root_webwork2_dir/lib'"; die $@ if $@;

	############################################
	# Define basic urls and the paths to basic directories, 
	############################################
	$OpaqueServer::TopDir = $topDir;   #/opt/webwork/
	$OpaqueServer::Host = $hostname;
	$OpaqueServer::RootDir = $root_dir;
	$OpaqueServer::RootPGDir = $root_pg_dir;
	$OpaqueServer::RootWebwork2Dir = $root_webwork2_dir;
	$OpaqueServer::RPCURL = $rpc_url;
	$OpaqueServer::WSDLURL = $wsdl_url;

	$OpaqueServer::FilesURL = $files_url;
	$OpaqueServer::courseName = $courseName;

	# suppress warning messages
	my $foo = $OpaqueServer::TopDir; 
	$foo = $OpaqueServer::RootDir;
	$foo = $OpaqueServer::Host;
	$foo = $OpaqueServer::WSDLURL;
	$foo = $OpaqueServer::FilesURL;
	$foo ='';
} # END BEGIN


#use OpaqueServer;
use Carp;
use WeBWorK::DB;
use WeBWorK::Utils::Tasks qw(fake_set fake_problem fake_user);   # may not be needed
use WeBWorK::PG; 
use WeBWorK::PG::ImageGenerator; 
use WeBWorK::DB::Utils qw(global2user); 
use WeBWorK::Form;
use WeBWorK::Debug;
use WeBWorK::CourseEnvironment;
use PGUtil qw(pretty_print not_null);
use constant fakeSetName => "Undefined_Set";
use constant fakeUserName => "Undefined_User";
use vars qw($courseName);

$Carp::Verbose = 1;


##############################
# Create the course environment $ce and the database object $db
##############################
our $ce = create_course_environment();
my $dbLayout = $ce->{dbLayout};	
our $db = WeBWorK::DB->new($dbLayout);


########################################################################
# Run problem on a given file
########################################################################

my $filePath = "Library/Rochester/setAlgebra01RealNumbers/lhp1_25-30.pg";

print "rendering file at $filePath\n";
my $formFields = {                            #$r->param();
    	AnSwEr0001 =>'foo',
    	AnSwEr0002 => 'bar',
    	AnSwEr0003 => 'foobar',
    };
my $pg = renderOpaquePGProblem($filePath, $formFields);

# print "result \n",pretty_print($pg, 'text');
print "\n", $pg->{body_text}, "\n";

########################################################################
# Subroutine which renders the problem
########################################################################
# TODO 
#      allow for formField inputs with the response
#      allow problem seed input
#      allow for adjustment of other options
########################################################################

sub renderOpaquePGProblem {
    #print "entering renderOpaquePGProblem\n\n";
    my $problemFile = shift//'';
    my $formFields  = shift//'';
    my %args = ();


	my $key = '3211234567654321';
	
	my $user          = $args{user} || fake_user($db);
	my $set           = $args{'this_set'} || fake_set($db);
	my $problem_seed  = $args{'problem_seed'} || 0; #$r->param('problem_seed') || 0;
	my $showHints     = $args{showHints} || 0;
	my $showSolutions = $args{showSolutions} || 0;
	my $problemNumber = $args{'problem_number'} || 1;
    my $displayMode   = $ce->{pg}->{options}->{displayMode};
    # my $key = $r->param('key');
  
	
	my $translationOptions = {
		displayMode     => $displayMode,
		showHints       => $showHints,
		showSolutions   => $showSolutions,
		refreshMath2img => 1,
		processAnswers  => 1,
		QUIZ_PREFIX     => '',	
		use_site_prefix => $ce->{server_root_url},
		use_opaque_prefix => 1,	
	};
	my $extras = {};   # Check what this is used for.
	
	# Create template of problem then add source text or a path to the source file
	local $ce->{pg}{specialPGEnvironmentVars}{problemPreamble} = {TeX=>'',HTML=>''};
	local $ce->{pg}{specialPGEnvironmentVars}{problemPostamble} = {TeX=>'',HTML=>''};
	my $problem = fake_problem($db, 'problem_seed'=>$problem_seed);
	$problem->{value} = -1;	
	if (ref $problemFile) {
			$problem->source_file('');
			$translationOptions->{r_source} = $problemFile; # a text string containing the problem
	} else {
			$problem->source_file($problemFile); # a path to the problem
	}
	
	#FIXME temporary hack
	$set->set_id('this set') unless $set->set_id();
	$problem->problem_id("1") unless $problem->problem_id();
		
		
	my $pg = new WeBWorK::PG(
		$ce,
		$user,
		$key,
		$set,
		$problem,
		123, # PSVN (practically unused in PG)
		$formFields,
		$translationOptions,
		$extras,
	);
		$pg;
}

####################################################################################
# Create_course_environment -- utility function
# requires webwork_dir
# requires courseName to keep warning messages from being reported
# Remaining inputs are required for most use cases of $ce but not for all of them.
####################################################################################



sub create_course_environment {
	my $ce = WeBWorK::CourseEnvironment->new( 
				{webwork_dir		=>		$OpaqueServer::RootWebwork2Dir, 
				 courseName         =>      $OpaqueServer::courseName,
				 webworkURL         =>      $OpaqueServer::RPCURL,
				 pg_dir             =>      $OpaqueServer::RootPGDir,
				 });
	warn "Unable to find environment for course: |$OpaqueServer::courseName|" unless ref($ce);
	return ($ce);
}


1;
