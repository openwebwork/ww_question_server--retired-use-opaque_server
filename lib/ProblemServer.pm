package ProblemServer;

use strict;
use warnings;


use MIME::Base64 qw( encode_base64 decode_base64);

use Safe;

use LWP::Simple;

use ProblemServer::Environment;
use ProblemServer::Utils::RestrictedClosureClass;

use ProblemServer::AnswerRequest;
use ProblemServer::AnswerResponse;

use ProblemServer::ProblemRequest;
use ProblemServer::ProblemResponse;

use ProblemServer::GeneratorRequest;
use ProblemServer::GeneratorResponse;

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

sub new {
    my $self = shift;
    $self = {};
    #Base Conf
    $main::VERSION = "2.3.2";

    #Warnings are passed into self


    #Construct the Server Environment
    my $serverEnviron = new ProblemServer::Environment();

    $SIG{__WARN__} = sub { $self->{warnings} .= shift };

    #Keep the Default Server Environment
    $self->{serverEnviron} = $serverEnviron;

    #Keep the Default Problem Environment
    $self->{problemEnviron} = ($self->{serverEnviron}{problemEnviron});

    $self->{safe} = new Safe;

    bless $self;
    return $self;
}

sub setupTranslator {
    my $self = shift;

    #Warnings are passed into self
    #local $SIG{__WARN__} = sub { $self->{warnings} .= shift };

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

    #Warnings are passed into self
    #local $SIG{__WARN__} = sub { $self->{warnings} .= shift };

    my $image_generator;
    my %imagesModeOptions = %{$self->{serverEnviron}->{pg}{displayModeOptions}{images}};
    $image_generator = WeBWorK::PG::ImageGenerator->new(
	tempDir         => $self->{serverEnviron}->{problemServerDirs}->{tmp}, # global temp dir
	latex	        => $self->{serverEnviron}->{externalPrograms}->{latex},
	dvipng          => $self->{serverEnviron}->{externalPrograms}->{dvipng},
	useCache        => 1,
	cacheDir        => $self->{serverEnviron}->{problemServerDirs}{equationCache},
	cacheURL        => $self->{serverEnviron}->{problemServerURLs}{equationCache},
	cacheDB         => $self->{serverEnviron}->{problemServerFiles}{equationCacheDB},
	useMarkers      => ($imagesModeOptions{dvipng_align} && $imagesModeOptions{dvipng_align} eq 'mysql'),
	dvipng_align    => $imagesModeOptions{dvipng_align},
	dvipng_depth_db => $imagesModeOptions{dvipng_depth_db},
    );
    #DEFINE CLOSURE CLASS FOR IMAGE GENERATOR
    $self->{problemEnviron}{imagegen} = new ProblemServer::Utils::RestrictedClosureClass($image_generator, "add");

    $self->{imageGenerator} = $image_generator;
}

BEGIN {
    $ProblemServer::theServer = new ProblemServer();
    $ProblemServer::theServer->setupTranslator();
    $ProblemServer::theServer->setupImageGenerator();
}

sub downloadFiles {
    my ($self,$files) = @_;
    foreach(@{$files}) {
        my $fileurl = decode_base64($_);
        my $lastslash = rindex($fileurl,'/');
        my $filepath = $self->{serverEnviron}->{problemServerDirs}->{htdocs_temp} . substr($fileurl,$lastslash);
        mirror($fileurl,$filepath);
    }
}

sub runTranslator {
    my ($self,$source,$seed) = @_;

    #Warnings are passed into sel    local $SIG{__WARN__} = sub { $self->{warnings} .= shift };

    $source = decode_base64($source);
    #Assigning Seed
    $self->{problemEnviron}{problemSeed} = $seed;

    #Clear some stuff
    $self->{translator}->{safe} = undef;
    $self->{translator}->{envir} = undef;

    $self->{translator}->{safe} = new Safe;

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
	'PG.pl', 'dangerousMacros.pl','IO.pl','PGbasicmacros.pl','PGanswermacros.pl'
    )};

    #LOAD MACROS INTO TRANSLATOR
    foreach (qw(PG.pl dangerousMacros.pl IO.pl)) {
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
    $self->{translator}->rf_safety_filter(\&ProblemServer::nullSafetyFilter);

    #RUN
    $self->{translator}->translate();
}

sub runChecker {
    my $self = shift;

    #Warnings are passed into self
    #local $SIG{__WARN__} = sub { $self->{warnings} .= shift };

    my $answerArray = shift;

    my $answerHash = {};
    for(my $i=0;$i<@{$answerArray};$i++) {
        $answerHash->{$answerArray->[$i]{field}} = $answerArray->[$i]{answer};
    }
    $self->{translator}->process_answers($answerHash);

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
    #warn "PG: installing a grader\n";
    my $grader = $self->{translator}->rh_flags->{PROBLEM_GRADER_TO_USE} || $self->{serverEnviron}->{pg}->{options}->{grader};
    $grader = $self->{translator}->rf_std_problem_grader if $grader eq "std_problem_grader";
    $grader = $self->{translator}->rf_avg_problem_grader if $grader eq "avg_problem_grader";
    die "Problem grader $grader is not a CODE reference." unless ref $grader eq "CODE";
    $self->{translator}->rf_problem_grader($grader);

    # grade the problem
    #warn "PG: grading the problem\n";
    my ($result, $state) = $self->{translator}->grade_problem(
        answers_submitted  => 1,
        ANSWER_ENTRY_ORDER => \@answerOrder,
        %{$answerHash}  #FIXME?  this is used by sequentialGrader is there a better way?
    );

    my $answers = $self->{translator}->rh_evaluated_answers;
    my $key;
    my $preview;
    my $answerResponse = {};
    my @answersArray;

    foreach $key (keys %{$answers}) {
        #PREVIEW GENERATOR
        $preview = $answers->{"$key"}->{"preview_latex_string"};
        $preview = "" unless defined $preview and $preview ne "";

        $preview = $self->{imageGenerator}->add($preview);

        #ANSWER STRUCT
        $answerResponse = new ProblemServer::AnswerResponse;
        $answerResponse->{field} = $key;
        $answerResponse->{answer} = $answers->{"$key"}->{"original_student_ans"};
        $answerResponse->{answer_msg} = $answers->{"$key"}->{"ans_message"};
        $answerResponse->{correct} = $answers->{"$key"}->{"correct_ans"};
        $answerResponse->{score} = $answers->{"$key"}->{"score"};
        $answerResponse->{evaluated} = $answers->{"$key"}->{"student_ans"};
        $answerResponse->{preview} = encode_base64($preview);
        push(@answersArray, $answerResponse);
    }

    return \@answersArray;
}

sub runImageGenerator {
    my $self = shift;

    #Warnings are passed into self
    #local $SIG{__WARN__} = sub { $self->{warnings} .= shift };

    $self->{imageGenerator}->render(body_text => $self->{translator}->r_text);
}

sub runImageGeneratorAnswers {
    my $self = shift;

    #Warnings are passed into self
    #local $SIG{__WARN__} = sub { $self->{warnings} .= shift };

    $self->{imageGenerator}->render();
}

sub buildProblemResponse {
    my $self = shift;

    #Warnings are passed into self
    #local $SIG{__WARN__} = sub { $self->{warnings} .= shift };

    my $response = new ProblemServer::ProblemResponse;
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
sub nullSafetyFilter {
	return shift, 0; # no errors
}

####################################################################################
#SOAP CALLABLE FUNCTIONS
####################################################################################



=pod
=begin WSDL
_RETURN $string Hello World!
=cut
sub hello {
    return "hello world!";
}


=pod
=begin WSDL
_IN request $ProblemServer::ProblemRequest The Problem Request
_RETURN $ProblemServer::ProblemResponse The Problem Response
=end WSDL
=cut
sub renderProblem {
    my ($self,$request) = @_;
    my $server = $ProblemServer::theServer;
    $server->downloadFiles($request->{files});
    $server->runTranslator($request->{code},$request->{seed});
    $server->runImageGenerator();

    my $response = $server->buildProblemResponse();
    $server->clean();
    return $response;
}

=pod
=begin WSDL
_IN requests @ProblemServer::ProblemRequest The Problem Requests
_RETURN @ProblemServer::ProblemResponse The Problem Response
=end WSDL
=cut
sub renderProblems {
    my ($self,$requests) = @_;
    my $server = $ProblemServer::theServer;

    my @problems;

    foreach($requests) {
        my $request = $_;
	$server->downloadFiles($request->{files});
        $server->runTranslator($request->{code},$request->{seed});
        $server->runImageGenerator();
        my $response = $server->buildProblemResponse();
        push(@problems,$response);
        $server->clean();
    }

    return \@problems;
}

=pod
=begin WSDL
_IN request $ProblemServer::GeneratorRequest
_RETURN $ProblemServer::GeneratorResponse
=end WSDL
=cut
sub generateProblem {
    my ($self,$request) = @_;
    my $server = $ProblemServer::theServer;

    my $trials = $request->{trials};
    my $problem = $request->{problem};

    $server->downloadFiles($problem->{files});

    my @derivedProblems;
    my $found;
    my $problemResponse;
    for(my $itr = 0; $itr < $trials ; $itr++ ) {
        $found = 0;
        $server->runTranslator($problem->{code},$itr + $problem->{seed});
        $problemResponse = $server->buildProblemResponse();
        foreach(@derivedProblems) {
            if($_->{output} eq $problemResponse->{output}) {
                $found = 1;
            }
        }
        if($found == 0) {
            $server->runImageGenerator();
            push(@derivedProblems,$problemResponse);
        }
        $server->clean();
    }

    return \@derivedProblems;
}

=pod
=begin WSDL
_IN requests @ProblemServer::GeneratorRequest
_RETURN @ProblemServer::GeneratorResponse
=end WSDL
=cut
sub generateProblems {
    my ($self,$requests) = @_;
    my $server = $ProblemServer::theServer;

    my @genResponse;
    foreach($requests) {
        my $request = $_;
        my $trials = $request->{trials};
        my $problem = $request->{problem};
	$server->downloadFiles($problem->{files});
        my @derivedProblems;
        my $found;
        for(my $itr = 0; $itr < $trials ; $itr++ ) {
            $found = 0;
            $server->runTranslator($problem->{code},$trials + $problem->{seed});
            my $problemResponse = $server->buildProblemResponse();
            foreach(@derivedProblems->{output}) {
                if($_ eq $problemResponse->{output}) {
                    $found = 1;
                }
            }
            if($found != 1) {
                $server->runImageGenerator();
                push(@derivedProblems,$problemResponse);
            }
            $server->clean();
        }
        my $response = new ProblemServer::GeneratorResponse();
        $response->{problems} = @derivedProblems;
        push(@genResponse,$response);
    }

    return \@genResponse;
}


=pod
=begin WSDL
_IN request $ProblemServer::ProblemRequest
_IN answers @ProblemServer::AnswerRequest
_RETURN @ProblemServer::AnswerResponse
=end WSDL
=cut
sub checkAnswers {
    my ($self,$request,$answers) = @_;
    my $server = $ProblemServer::theServer;

    $server->runTranslator($request->{code},$request->{seed});
    my $result = $server->runChecker($answers);
    $server->runImageGeneratorAnswers();

    $server->clean();
    return $result;
}

1;
