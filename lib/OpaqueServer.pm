#!/usr/bin/perl -w

use lib qw( /Volumes/WW_test/opt/webwork/webwork2/lib /Volumes/WW_test/opt/webwork/webwork2/pg/lib /Volumes/WW_test/opt/webwork/ww_opaque_server/lib );


sub main::getEngineInfo {
	OpaqueServer::getEngineInfo(@_);
}

package OpaqueServer;

use strict;
use warnings;


use MIME::Base64 qw( encode_base64 decode_base64);

use WWSafe;

use LWP::Simple;

use OpaqueServer::Environment;
use OpaqueServer::Utils::RestrictedClosureClass;

use OpaqueServer::AnswerRequest;
use OpaqueServer::AnswerResponse;

use OpaqueServer::ProblemRequest;
use OpaqueServer::ProblemResponse;

use OpaqueServer::GeneratorRequest;
use OpaqueServer::GeneratorResponse;

use OpaqueServer::StartReturn;
use OpaqueServer::ProcessReturn;

use WeBWorK::PG::Translator;
use WeBWorK::PG::ImageGenerator;



use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );


use constant DISPLAY_MODES => {
	# display name   # mode name
	tex           => "TeX",
	plainText     => "HTML",
	formattedText => "HTML_tth",
	images        => "HTML_dpng",
	jsMath	      => "HTML_jsMath",
	asciimath     => "HTML_asciimath",
	LaTeXMathML   => "HTML_LaTeXMathML",
};
our $DEBUG=0;

sub new {
    my $self = shift;
    $self = {};
    #Base Conf
    $main::VERSION = "2.3.2";

    #Warnings are passed into self


    #Construct the Server Environment
    my $serverEnviron = new OpaqueServer::Environment($ENV{OPAQUESERVER_ROOT});
    #FIXME Hacks
    warn "starting OpaqueServer in new";
    #$SIG{__WARN__} = sub { $self->{warnings} .= shift };

    #Keep the Default Server Environment
    $self->{serverEnviron} = $serverEnviron;

    #Keep the Default Problem Environment
    $self->{problemEnviron} = ($self->{serverEnviron}{problemEnviron});
    #Create Safe Compartment
    $self->{safe} = new WWSafe;

    bless $self;
    return $self;
}

sub setupTranslator {
    my $self = shift;

    #Warnings are passed into self
    #local $SIG{__WARN__} = sub { $self->{warnings} .= shift };

     warn "\n\nOpaqueServer:  setup translator\n\n";

     
    #Create Translator Object
    my $translator = WeBWorK::PG::Translator->new;

    #Attach log modules
    my @modules = @{ $self->{serverEnviron}{pg}{modules} };
    # HACK for apache2
    if (MP2) {
	push @modules, ["Apache2::Log"], ["APR::Table"];
    } else {
    	push @modules, ["Apache::Log"];
    }

    #Evaulate all module packs
    foreach my $module_packages_ref (@modules) {
    	my ($module, @extra_packages) = @$module_packages_ref;
    	# the first item is the main package
    	$translator->evaluate_modules($module);
    	# the remaining items are "extra" packages
    	$translator->load_extra_packages(@extra_packages);
    }

    #Only type of output is images
    $self->{problemEnviron}{displayMode} 	= "HTML_dpng";
    $self->{problemEnviron}{languageMode}       = $self->{problemEnviron}{displayMode};
    $self->{problemEnviron}{outputMode}		= $self->{problemEnviron}{displayMode};

    $self->{translator} = $translator;
}

sub setupImageGenerator {
    my $self = shift;
    warn "\n\n creating image generator \n\n";
    #Warnings are passed into self
    #local $SIG{__WARN__} = sub { $self->{warnings} .= shift };

    my $image_generator;
    my %imagesModeOptions = %{$self->{serverEnviron}->{pg}{displayModeOptions}{images}};
    $image_generator = WeBWorK::PG::ImageGenerator->new(
	tempDir         => $self->{serverEnviron}->{opaqueServerDirs}->{tmp}, # global temp dir
	latex	        => $self->{serverEnviron}->{externalPrograms}->{latex},
	dvipng          => $self->{serverEnviron}->{externalPrograms}->{dvipng},
	useCache        => 1,
	cacheDir        => $self->{serverEnviron}->{opaqueServerDirs}{equationCache},
	cacheURL        => $self->{serverEnviron}->{opaqueServerURLs}{equationCache},
	cacheDB         => $self->{serverEnviron}->{opaqueServerFiles}{equationCacheDB},
	useMarkers      => ($imagesModeOptions{dvipng_align} && $imagesModeOptions{dvipng_align} eq 'mysql'),
	dvipng_align    => $imagesModeOptions{dvipng_align},
	dvipng_depth_db => $imagesModeOptions{dvipng_depth_db},
    );
    #DEFINE CLOSURE CLASS FOR IMAGE GENERATOR
    $self->{problemEnviron}{imagegen} = new OpaqueServer::Utils::RestrictedClosureClass($image_generator, "add");

    $self->{imageGenerator} = $image_generator;
}

BEGIN {
    $OpaqueServer::theServer = new OpaqueServer();
    $OpaqueServer::theServer->setupTranslator();
    $OpaqueServer::theServer->setupImageGenerator();
}

sub downloadFiles {
    my ($self,$files) = @_;
    foreach(@{$files}) {
        my $fileurl = decode_base64($_);
        my $lastslash = rindex($fileurl,'/');
        my $filepath = $self->{serverEnviron}->{opaqueServerDirs}->{htdocs_temp} . substr($fileurl,$lastslash);
        mirror($fileurl,$filepath);
    }
}

# returns a pg core object
sub runTranslator {
    my ($self,$source,$env) = @_;
    warn "running the translator ";
    #warn "source is $source";
    
    $source = decode_base64($source);
    #warn "SOURCE is $source";
    local $SIG{__WARN__} = sub { $self->{warnings} .= shift };
    #Defining the Environment
    while ( my ($key, $value) = each(%$env) ) {
	$self->{problemEnviron}{$key} = $value;
    }

    #Clear some stuff
    $self->{translator}->{safe} = undef;
    $self->{translator}->{envir} = undef;
    $self->{translator}->{safe} = new WWSafe;

    #Setting Environment
    $self->{translator}->environment($self->{problemEnviron});

    #Initializing
    $self->{translator}->initialize();

    #Safe
    #$self->{safe} = new Safe;

    #PRE-LOAD MACRO FILES
    eval{$self->{translator}->pre_load_macro_files(
        $self->{safe},
	$self->{serverEnviron}->{pg}->{directories}->{macros},
	)};
	warn "Error while preloading macro files: $@" if $@;
	#'PG.pl', 'dangerousMacros.pl','IO.pl','PGbasicmacros.pl','PGanswermacros.pl'

    #LOAD MACROS INTO TRANSLATOR
    foreach (qw(PG.pl ) ) {     #    dangerousMacros.pl IO.pl)) {
	my $macroPath = $self->{serverEnviron}->{pg}->{directories}->{macros} . "/$_";
	my $err = $self->{translator}->unrestricted_load($macroPath);
	warn "Error while loading $macroPath: $err" if $err;
    }

    #SET OPCODE MASK
    $self->{translator}->set_mask();

    #INSERT PROBLEM SOURCE CODE INTO TRANSLATOR
    eval { $self->{translator}->source_string( $source ) };
    $@ and die("bad source");

    #CREATE SAFETY FILTER
    $self->{translator}->rf_safety_filter(\&OpaqueServer::nullSafetyFilter);

    #RUN
   eval{$self->{translator}->translate()};
   warn "errors $@" if $@;
   #warn "translation errors ", $self->{warnings};
   #warn "done translating";
}

sub runChecker {
    my $self = shift;

    #Warnings are passed into self
    #local $SIG{__WARN__} = sub { $self->{warnings} .= shift };

    my $answerArray = shift;
    my $answerHash = {};
    for(my $i=0;$i<@{$answerArray};$i++) {
        $answerHash->{decode_base64($answerArray->[$i]{field})} = decode_base64($answerArray->[$i]{answer});
    }
    warn "\nin runChecker answerHash is ", pretty_print_text($answerArray) if ($DEBUG);
    warn "run process_answers in translator";
    $self->{translator}->process_answers($answerHash);
    warn "\nout of process_answers  \n";
    warn "translator ", join(" ", sort keys %{$self->{translator}});
    warn "PROCESSED ANSWERS are \n",pretty_print_text($self->{translator}->rh_evaluated_answers)  if ($DEBUG); 
    # retrieve the problem state and give it to the translator
    #warn "PG: retrieving the problem state and giving it to the translator\n";
    $self->{translator}->rh_problem_state({
        recorded_score =>       "0",
        num_of_correct_ans =>   "0",
        num_of_incorrect_ans => "0",
    });

    # determine an entry order -- the ANSWER_ENTRY_ORDER flag is built by
    # the PG macro package (PG.pl)
    #warn "PG: determining an entry order\n";
    my @answerOrder = $self->{translator}->rh_flags->{ANSWER_ENTRY_ORDER}
        ? @{ $self->{translator}->rh_flags->{ANSWER_ENTRY_ORDER} }
        : keys %{ $self->{translator}->rh_evaluated_answers };


    # install a grader -- use the one specified in the problem,
    # or fall back on the default from the course environment.
    # (two magic strings are accepted, to avoid having to
    # reference code when it would be difficult.)
    my $grader = $self->{translator}->rh_flags->{PROBLEM_GRADER_TO_USE} || $self->{serverEnviron}->{pg}->{options}->{grader};
    warn "PG: installing a grader $grader";
    $grader = $self->{translator}->rf_std_problem_grader if $grader eq "std_problem_grader";
    $grader = $self->{translator}->rf_avg_problem_grader if $grader eq "avg_problem_grader";
    die "Problem grader $grader is not a CODE reference." unless ref $grader eq "CODE";
    $self->{translator}->rf_problem_grader($grader);
    warn "\ngrading problem";    # grade the problem
    my ($result, $state);
    eval{
    ($result, $state) = $self->{translator}->grade_problem(
        answers_submitted  => 1,
        ANSWER_ENTRY_ORDER => \@answerOrder,
        %{$answerHash}  #FIXME?  this is used by sequentialGrader is there a better way?
    );
    };
    warn "errors from grading $@" if $@;
    warn "after grading result: ", join(" ", %$result),  "\nstate ", join(" ", %$state);
    my $answers = $self->{translator}->rh_evaluated_answers;
    warn "evaluated answers: ", join(" ", %$answers);
    my $key;
    my $preview;
    my $answerResponse = {};
    my @answersArray;
    warn "generate previews and mung answers";
    foreach $key (keys %{$answers}) {
        #PREVIEW GENERATOR

        	
        ############################################        
        warn "answerhash $key contains:\n ----------", pretty_print_text($answers->{$key})  if ($DEBUG);
        ################################################
        $preview = $answers->{"$key"}->{"preview_latex_string"};
        $preview = "" unless defined $preview and $preview ne "";

        eval{ $preview = $self->{imageGenerator}->add($preview);
        };
        warn " errors from generating images $@" if $@;
        #ANSWER STRUCT
        $answerResponse = {};
        $answerResponse->{field} = encode_base64($key);
        $answerResponse->{answer} = encode_base64($answers->{"$key"}->{"original_student_ans"}//'');
        $answerResponse->{answer_msg} = encode_base64($answers->{"$key"}->{"ans_message"}//'');
        $answerResponse->{correct} = encode_base64($answers->{"$key"}->{"correct_ans"}//'');
        $answerResponse->{score} = $answers->{"$key"}->{"score"//''};
        $answerResponse->{evaluated} = encode_base64($answers->{"$key"}->{"student_ans"}//'');
        $answerResponse->{preview} = encode_base64($preview//'');
        push(@answersArray, $answerResponse);
    }
    #CORE::warn $self->{errors};
    warn "leaving run checker with answers\n\n", join(" ", @answersArray);
    return \@answersArray;
}

sub runImageGenerator {
    my $self = shift;
    $self->{imageGenerator}->render(body_text => $self->{translator}->r_text);
}

sub runImageGeneratorAnswers {
    my $self = shift;
    $self->{imageGenerator}->render();
}

sub buildProblemResponse {
    my $self = shift;
    my $response = {};
    $response->{errors} = $self->{translator}->errors;
    $response->{warnings} = $self->{warnings};
    $response->{output} = encode_base64(${$self->{translator}->r_text});
    $response->{seed} = $self->{translator}->{envir}{problemSeed};
    $response->{grading} = $self->{translator}->rh_flags->{showPartialCorrectAnswers};
    return $response;
}
sub clean {
    my $self = shift;
    $self->{translator}->{errors} = undef;
    $self->{warnings} = "";


}

sub cleanServer {
    my $self = shift;
    delete($self->{translator});# = undef;
    delete($self->{imageGenerator});# = undef;
}

sub translateDisplayModeNames($) {
	my $name = shift//'images';
	warn "\n\n display mode set to ", DISPLAY_MODES()->{$name}, "\n\n";
	return DISPLAY_MODES()->{$name};
}
sub nullSafetyFilter {
	return shift, 0; # no errors
}

sub pretty_print_text {    # provides text output -- NOT a method
    my $r_input = shift;
    my $level = shift;
    $level = 5 unless defined($level);
    $level--;
    my $space = " "x(5-$level);
    return "PGalias has too much info. Try \$PG->{PG_alias}->{resource_list}" if ref($r_input) eq 'PGalias';  # PGalias just has too much information
    return 'too deep' unless $level > 0;  # only print four levels of hashes (safety feature)
    my $out = '';
    if ( not ref($r_input) ) {
        if (defined $r_input) {
            if ($r_input =~/=$/  or $r_input =~/\+$/) {
        		$out = decode_base64($r_input) ; # try to detect base64	
        	} else {
    			$out = $r_input;    # not a reference
    		}
    	}
    	#$out =~ s/</&lt;/g  ;  # protect for HTML output
    } elsif ("$r_input" =~/hash/i) {  # this will pick up objects whose '$self' is hash and so works better than ref($r_iput).
	    local($^W) = 0;
	    
		$out .= "\n$space$r_input : " ;
		
		
		foreach my $key ( sort ( keys %$r_input )) {
		    next if $key eq 'context'; #skip contexts -- they are too long
			$out .= "\n$space$key => ".pretty_print_text($r_input->{$key}, $level);
		}
	} elsif ("$r_input" =~/array/i ) {
		my @array = @$r_input;
		$out.= "\n$space$r_input : ";
		$out .= "( " ;
		while (@array) {
			$out .= pretty_print_text(shift @array, $level) . " , ";
		}
		$out .= " )";
	} elsif ($r_input =~ /CODE/) {
		$out = "\n$space$r_input";
	} else {
	  	$out = "\n$space$r_input";
		#$out =~ s/</&lt;/g; # protect for HTML output
	}
		$out;
}
####################################################################################
#SOAP CALLABLE FUNCTIONS
####################################################################################



=pod
=begin WSDL
_RETURN $string Hello World!
=cut
sub hello {
    warn "hello world";
    return "hello world!";
}


# =pod
# =begin WSDL
# _IN request $OpaqueServer::ProblemRequest The Problem Request
# _RETURN $OpaqueServer::ProblemResponse The Problem Response
# =end WSDL
# =cut
# sub renderProblem {
#     my ($self,$request) = @_;
#     warn "\n\nentering renderProblem with new request \n";
#     $request->{env}->{displayMode} = translateDisplayModeNames($request->{env}->{displayMode});
#     #warn " \n\n displayMode is ", $request->{env}->{displayMode};
#     my $server = $ProblemServer::theServer;
#     $server->setupTranslator();
#     $server->setupImageGenerator();
#     #warn "run translator ".decode_base64($request->{code});
#     $server->runTranslator($request->{code},$request->{env});
#     warn "done with translator run image generator";
#     eval{ $server->runImageGenerator();};
#     warn "Errors from image generator $@ " if $@;
#     warn "done with image generator run buildProblem response";
# 
#     my $response = $server->buildProblemResponse();
#     #warn "done with buildProblemResponse";
#     warn "________________\n";
#     warn " body text  from render is". decode_base64( $response->{output} );
#     warn "_______________\n";
#     $server->clean();
#     $server->cleanServer();
#     warn "complete response is ", join (" ", keys %$response);
#     return $response;
# }
# 
# =pod
# =begin WSDL
# _IN requests @OpaqueServer::ProblemRequest The Problem Requests
# _RETURN @OpaqueServer::ProblemResponse The Problem Response
# =end WSDL
# =cut
# sub renderProblemAndCheck {
#     my ($self,$request,$answers) = @_;
#     warn "\n\nentering renderProblemandCheck with request \n";
#     warn "ANSWERS SUBMITTED are\n ", pretty_print_text($answers) ;
#     @$answers =  grep { decode_base64($_->{field}) =~/^0AnS/} @$answers;
#     warn "ANSWERS SUBMITTED FILTERED are\n ", join(" ", map {decode_base64($_->{field})."=>".decode_base64($_->{answer})} @$answers);
#     $request->{env}->{displayMode} = translateDisplayModeNames($request->{env}->{displayMode});
#     
#     my $server = $ProblemServer::theServer;
#     $server->setupTranslator();
#     eval {
#     $server->setupImageGenerator();
#     };
#     warn "renderProblemAndCheck: errors in image generator $@" if $@;
#     warn "renderProblemAndCheck running translator";
#     $server->runTranslator($request->{code},$request->{env});
#     ###############################################################
#     warn "run answer checker";
#     my $ansresults = $server->runChecker($answers);
#     warn "done with answer checker";
#     warn "ANSWERS EVALUATED and returned are \n", pretty_print_text($ansresults)  if ($DEBUG);
#     ############################################################
#     eval {
#     $server->runImageGenerator();
#     $server->runImageGeneratorAnswers();
#     };
#     warn "errors from renderProblemAndCheck image generator $@ " if $@;
#     warn "entering renderandcheck buildProblemResponse";
#     my $problemresponse = $server->buildProblemResponse();
#     warn "renderProblemAndCheck done with build problem response\n\n";
#     $server->clean();
#     $server->cleanServer();
#     my $response = {};
#     $response->{problem} = $problemresponse;
#     $response->{answers} = $ansresults;
#     warn "\n\n end renderProblemAndCheck \n\n";
#     return $response;
# }
# 
# =pod
# =begin WSDL
# _IN request $OpaqueServer::PDFRequest
# _RETURN $string
# =end WSDL
# =cut
# sub generatePDF {
#     my($self,$request) = @_;
#     my $server = $ProblemServer::theServer;
# 
#     #Only type of output is images
# 
#     my $tmppath = $server->{serverEnviron}{tmp};
#     my $texpath = "$tmppath/hardcopy.tex";
# 
#     my $file_handle = open my $FH, ">", $texpath;
#     close $FH;
# 
# 
#     foreach(@{$request->{problems}}) {
#         my $problem = $_;
# 	my $code = $problem->{code};
# 	my $env = $problem->{env};
# 	my $seed = $problem->{seed};
# 	$server->setupTranslator();
# 	$self->{problemEnviron}{displayMode} 	= "TeX";
# 	$self->{problemEnviron}{languageMode}   = $self->{problemEnviron}{displayMode};
# 	$self->{problemEnviron}{outputMode}	= $self->{problemEnviron}{displayMode};
#     $server->setupImageGenerator();
# 	$server->runTranslator($code,$env);
#         my $problemResponse = $server->buildProblemResponse();
#         $server->runImageGenerator();
# 	$server->clean();
# 	$server->cleanServer();
#     }
# 
#     return "done";
# }
# 
# 
# =pod
# =begin WSDL
# _IN request $OpaqueServer::ProblemRequest
# _IN answers @OpaqueServer::AnswerRequest
# _RETURN     @OpaqueServer::AnswerResponse
# =end WSDL
# =cut
# sub checkAnswers {
#     my ($self,$request,$answers) = @_;
#     my $server = $OpaqueServer::theServer;
# 
#     $server->runTranslator($request->{code},$request->{seed});
#     my $result = $server->runChecker($answers);
#     $server->runImageGeneratorAnswers();
# 
#     $server->clean();
#     return $result;
# }
# sub handler {
# 	warn "OpaqueServer handler called with @_";
# 
# }
=pod
=begin WSDL
_IN request $string
_RETURN     $string
=end WSDL
=cut

sub getEngineInfo {
		my @in = @_;
        warn "in getEngineInfo";
        return '<engineinfo>
                     <Name>Test Opaqueserver engine</Name>
                     <PHPVersion>' . 'php5.5' . '</PHPVersion>
                     <MemoryUsage>' . '3456' . '</MemoryUsage>
                     <ActiveSessions>' . 0 . '</ActiveSessions>
                     <working>Yes</working>
                 </engineinfo>';
}


=pod
=begin WSDL
_IN questionID       $string
_IN questionVersion  $string
_IN questionBaseUrl  $string
_FAULT               OpaqueServer::Exception
_RETURN     		 $string 
=end WSDL
=cut

sub getQuestionMetadata {
	my ($remoteid, $remoteversion, $questionbaseurl) = @_;
	warn "in getQuestionMetadata";
	handle_special_from_questionid($remoteid, $remoteversion, 'metadata');
     return '<questionmetadata>
                     <scoring><marks>' . 10 . '</marks></scoring>
                     <plainmode>no</plainmode>
             </questionmetadata>';
}

=pod
=begin WSDL
_IN questionID       $string
_IN questionVersion  $string
_IN questionBaseUrl  $string
_IN paramNames       @string 
_IN paramValues      @string
_IN cachedResources  @string
_FAULT               OpaqueServer::Exception 
_RETURN              $OpaqueServer::StartReturn
=end WSDL
=cut

sub start {

	my ($questionid, $questionversion, $url, $paramNames, $paramValues,$cachedResources) = @_;
	warn "in start paramNames = ".ref($paramNames)."  paramValues = ".ref($paramValues);
	handle_special_from_questionid($questionid, $questionversion, 'start');
    # zip params into hash
		my $initparams = {};
		my @paramValues = (ref($paramValues)=~/array/i)? @$paramValues:();
		my @paramNames  = (ref($paramNames)=~/array/i)? @$paramNames:();
		foreach my $key (@paramNames) {
			$initparams->{$key}= pop @paramValues;
		}
	# create startReturn type and fill it
		my $return = OpaqueServer::StartReturn->new();
        $return->{questionID} = $questionid;
        $return->{questionversion} = $questionversion;
		$return->{XHTML} = get_html();
		$return->{CSS} = get_css();
		$return->{progressInfo} = "Try 1";
		
	# load resources urls
		$return->{resources} =['no resources yet'];
	# return start type
	return $return;
}
#     
#    function start($questionid, $questionversion, $url, $paramNames, $paramValues, $cachedResources) {
#         global $CFG;
# 
#         $this->handle_special_from_questionid($questionid, $questionversion, 'start');
# 
#         $initparams = array_combine($paramNames, $paramValues);
# 
#         $return = new local_testopaqueqe_start_return($questionid, $questionversion,
#                 !empty($initparams['display_readonly']));
# 
#         $return->XHTML = $this->get_html($return->questionSession, 1, $initparams);
#         $return->CSS = $this->get_css();
#         $return->progressInfo = "Try 1";
#         $return->addResource(local_testopaqueqe_resource::make_from_file(
#                 $CFG->dirroot . '/local/testopaqueqe/pix/world.gif', 'world.gif', 'image/gif'));
# 
#         return $return;
#     }

=pod
=begin WSDL
_IN questionSession  $string
_IN names    @string
_IN values   @string 
_FAULT               OpaqueServer::Exception
_RETURN              $OpaqueServer::ProcessReturn
=end WSDL
=cut

sub process {
	my ($questionSession, $names, $values) = @_;
    warn "in process";
    # zip params into hash
		my $params = {};
		my @values = @$values;
		foreach my $key (@$names) {
			$params->{$key}= pop @values;
		}
	handle_special_from_process($params);
	
	
	my $return = OpaqueServer::ProcessReturn->new();
}

=pod
=begin WSDL
_IN questionSession  $string
_FAULT               OpaqueServer::Exception
=end WSDL
=cut

sub stop {
	my $questionSession = shift;
	warn "in stop";
	handle_special_from_sessionid($questionSession, 'stop');
}

###########################################
# Utility functions
###########################################

sub handle_special_from_sessionid {
	my ($questionsession, $action) = @_;
}

sub handle_special_from_questionid {
	my ($questionid, $questionversion, $action) = @_;
}

sub handle_special_from_process {

}
sub get_html {
	my ($sessionid, $try, $submitteddata) = @_;
	my $disabled = '';
	if (substr($sessionid, 0, 3) eq 'ro-') {
		$disabled = 'disabled="disabled" ';
	}

	my $hiddendata = {
		'try' => $try,
	};

    my $output = '
<div class="local_testopaqueqe">
<h2><span>Hello <img src="%%RESOURCES%%/world.gif" alt="world" />!</span></h2>
<p>This is the WeBWorK test Opaque engine  '  .
    $sessionid . ' on try ' . $try . '</p>';

	foreach my $name ($hiddendata)  {
		$output .= '<input type="hidden" name="%%IDPREFIX%%' . $name .
				'" value="' . htmlspecialchars($hiddendata->{$name}) . '" />' . "\n";
	}

        $output .= '
        <h3>Actions</h3>
<p><input type="submit" name="%%IDPREFIX%%submit" value="Submit" ' . $disabled . '/> or
    <input type="submit" name="%%IDPREFIX%%finish" value="Finish" ' . $disabled . '/>
    (with a delay of <input type="text" name="%%IDPREFIX%%slow" value="0.0" size="3" ' .
            $disabled . '/> seconds during processing).
    If finishing assign a mark of <input type="text" name="%%IDPREFIX%%mark" value="' .
            10 . '.00" size="3" ' . $disabled . '/>.</p>
<p><input type="submit" name="%%IDPREFIX%%fail" value="Throw a SOAP fault" ' . $disabled . '/></p>
<h3>Submitted data</h3>
<table>
<thead>
<tr><th>Name</th><th>Value</th></tr>
</thead>
<tbody>';

	foreach my $name ($submitteddata)  {
		$output .= '<tr><th>' . $name . '</td><td>' . 
		htmlspecialchars($submitteddata->{$name}) . "</th></tr>\n";
	}

    $output .= '
</tbody>
</table>
</div>';

        return $output;
    
}
sub get_css {
    return '
.que.opaque .formulation .local_testopaqueqe {
    border-radius: 5px 5px 5px 5px;
    background: #E4F1FA;
    padding: 0.5em;

}
.local_testopaqueqe h2 {
    margin: 0 0 10px;
}
.local_testopaqueqe h2 span {
    background: black;
    border-radius: 5px 5px 5px 5px;
    padding: 0 10px;
    line-height: 60px;
    font-size: 50px;
    font-weight: bold;
    color: #CCBB88;
}
.local_testopaqueqe h2 span img {
    vertical-align: bottom;
}
.local_testopaqueqe table th {
    text-align: left;
    padding: 0 0.5em 0 0;
}
.local_testopaqueqe table td {
    padding: 0 0.5em 0 0;
}';
}
sub htmlspecialchars {
	return shift;
}
1;
