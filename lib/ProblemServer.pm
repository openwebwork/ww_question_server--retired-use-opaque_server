package ProblemServer;

use strict;
use warnings;


use MIME::Base64 qw( encode_base64 decode_base64);

use ProblemServer::Environment;
use ProblemServer::Utils::RestrictedClosureClass;

use ProblemServer::AnswerRequest;
use ProblemServer::AnswerResponse;

use ProblemServer::ProblemRequest;
use ProblemServer::ProblemResponse;

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
    #Construct the Server Environment
    my $serverEnviron = new ProblemServer::Environment($ProblemServer::RootDir);


    #Keep the Default Server Environment
    $self->{serverEnviron} = $serverEnviron;

    #Keep the Default Problem Environment
    $self->{problemEnviron} = ($self->{serverEnviron}{problemEnviron});
    #Create Safe Compartment
    $self->{safe} = new Safe;

    bless $self;
    return $self;
}

BEGIN {
$ProblemServer::theServer = new ProblemServer();
}

sub translation {
    my ($self,$request) = @_;

    #Install a local warn handler to collect warnings
    my $warnings = "";
    local $SIG{__WARN__} = sub { $warnings .= shift }
	if $self->{serverEnviron}{pg}{options}{catchWarnings};

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

    #DEFINE SPECIFIC CHANGES TO PROBLEM ENVIRONMENT
    $self->{problemEnviron}{problemSeed} 	= $request->{seed};
    $self->{problemEnviron}{displayMode} 	= translateDisplayModeNames($request->{displayMode});
    $self->{problemEnviron}{languageMode}       = $self->{problemEnviron}{displayMode};
    $self->{problemEnviron}{outputMode}		= $self->{problemEnviron}{displayMode};

    #PREP IMAGE GENERATOR
    my $image_generator;
    if ($request->{displayMode} eq "images") {
    	my %imagesModeOptions = %{$self->{serverEnviron}->{pg}{displayModeOptions}{images}};
	$image_generator = WeBWorK::PG::ImageGenerator->new(
	    tempDir         => $self->{serverEnviron}->{problemServerDirs}->{tmp}, # global temp dir
	    latex	    => $self->{serverEnviron}->{externalPrograms}->{latex},
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
    }



    #ATTACH THE PROBLEM ENVIRONMENT TO TRANSLATOR
    $translator->environment($self->{problemEnviron});

    #INITIALIZING THE TRANSLATOR
    $translator->initialize();

    #PRE-LOAD MACRO FILES
    eval{$translator->pre_load_macro_files(
        $self->{safe},
	$self->{serverEnviron}->{pg}->{directories}->{macros},
	'PG.pl', 'dangerousMacros.pl','IO.pl','PGbasicmacros.pl','PGanswermacros.pl'
    )};
    warn "Error while preloading macro files: $@" if $@;

    #LOAD MACROS INTO TRANSLATOR
    foreach (qw(PG.pl dangerousMacros.pl IO.pl)) {
	my $macroPath = $self->{serverEnviron}->{pg}->{directories}->{macros} . "/$_";
	my $err = $translator->unrestricted_load($macroPath);
	warn "Error while loading $macroPath: $err" if $err;
    }

    #SET OPCODE MASK
    $translator->set_mask();

    #Retrieve Source
    my $source = decode_base64($request->{code});
    #INSERT PROBLEM SOURCE CODE INTO TRANSLATOR
    eval { $translator->source_string( $source ) };
    $@ and die("bad source");

    #CREATE SAFETY FILTER
    $translator->rf_safety_filter(\&ProblemServer::nullSafetyFilter);

    #RUN
    $translator->translate();

    #PROCESS ANSWERS
    my ($result, $state); # we'll need these on the other side of the if block!
    my $answerArray = $request->{answers};
    #die($self->{problemEnviron}->{functAbsTolDefault});
    #die($request->{answer});
    if (defined $answerArray and @{$answerArray}) {
	# process student answers
	#warn "PG: processing student answers\n";

        #take array of answers and make hash
        my $answerHash = {};
        for(my $i=0;$i<@{$answerArray};$i++) {
            $answerHash->{$answerArray->[$i]{field}} = $answerArray->[$i]{answer};
        }
	$translator->process_answers($answerHash);

	# retrieve the problem state and give it to the translator
	#warn "PG: retrieving the problem state and giving it to the translator\n";
	$translator->rh_problem_state({
	    recorded_score =>       "0",
            num_of_correct_ans =>   "0",
	    num_of_incorrect_ans => "0",
	});

	# determine an entry order -- the ANSWER_ENTRY_ORDER flag is built by
	# the PG macro package (PG.pl)
	#warn "PG: determining an entry order\n";
	my @answerOrder = $translator->rh_flags->{ANSWER_ENTRY_ORDER}
            ? @{ $translator->rh_flags->{ANSWER_ENTRY_ORDER} }
	    : keys %{ $translator->rh_evaluated_answers };


	# install a grader -- use the one specified in the problem,
	# or fall back on the default from the course environment.
	# (two magic strings are accepted, to avoid having to
	# reference code when it would be difficult.)
	#warn "PG: installing a grader\n";
	my $grader = $translator->rh_flags->{PROBLEM_GRADER_TO_USE} || $self->{serverEnviron}->{pg}->{options}->{grader};
	$grader = $translator->rf_std_problem_grader if $grader eq "std_problem_grader";
	$grader = $translator->rf_avg_problem_grader if $grader eq "avg_problem_grader";
	die "Problem grader $grader is not a CODE reference." unless ref $grader eq "CODE";
	$translator->rf_problem_grader($grader);

	# grade the problem
	#warn "PG: grading the problem\n";
	($result, $state) = $translator->grade_problem(
            answers_submitted  => 1,
	    ANSWER_ENTRY_ORDER => \@answerOrder,
	    %{$answerHash}  #FIXME?  this is used by sequentialGrader is there a better way?
	);


    }
    my $displayMode = $request->{displayMode};

    #ANSWER EVALUATION AND PREVIEW GENERATOR
    my $answers = $translator->rh_evaluated_answers;
    my $key;
    my $preview;
    my $answerResponse = {};
    my @answersArray;

    foreach $key (keys %{$answers}) {
        #PREVIEW GENERATOR
        $preview = $answers->{"$key"}->{"preview_latex_string"};
        $preview = "" unless defined $preview and $preview ne "";
	if ($displayMode eq "plainText") {
	    $preview = $preview;
	} elsif ($displayMode eq "formattedText") {
            #FIX THIS TO USE TTH
            $preview = $preview;
	} elsif ($displayMode eq "images") {
	    $preview = $image_generator->add($preview);
	} elsif ($displayMode eq "jsMath") {
	    $preview =~ s/</&lt;/g;
            $preview =~ s/>/&gt;/g;
	    $preview = '<SPAN CLASS="math">\\displaystyle{'.$preview.'}</SPAN>';
	}

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

    #GENERATE IMAGES AS NECESSARY
    if ($image_generator) {
        $image_generator->render(refresh => 1);
	$image_generator->render(
	    body_text => $translator->r_text
	);
    }




    #WeBWorK::PG::Translator::pretty_print_rh($answers->{"0AnSwEr1"});
    #die($warnings);

    #CREATE A RESPONSE OBJECT
    my $response = new ProblemServer::ProblemResponse;
    $response->{id} = $request->{id};
    $response->{errors} = $translator->errors;
    $response->{warnings} = $warnings;
    $response->{answers} = \@answersArray;
    $response->{seed} = $request->{seed};
    $response->{body_text} = encode_base64(${$translator->r_text});
    $response->{head_text} = encode_base64(${$translator->r_header});
    $response->{state} = "0";
    $response->{result} = $request->{displayMode};

    return $response;
}

sub generator {
    my ($self,$code,$seed,$trials) = @_;

    my @derivedProblems;
    my @alreadyCreated;

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

    #DEFINE SPECIFIC CHANGES TO PROBLEM ENVIRONMENT
    $self->{problemEnviron}{displayMode} 	= translateDisplayModeNames("images");
    $self->{problemEnviron}{languageMode}       = $self->{problemEnviron}{displayMode};
    $self->{problemEnviron}{outputMode}		= $self->{problemEnviron}{displayMode};

    #PREP IMAGE GENERATOR
    my $image_generator;
    if ("images" eq "images") {
    	my %imagesModeOptions = %{$self->{serverEnviron}->{pg}{displayModeOptions}{images}};
	$image_generator = WeBWorK::PG::ImageGenerator->new(
	    tempDir         => $self->{serverEnviron}->{problemServerDirs}->{tmp}, # global temp dir
	    latex	    => $self->{serverEnviron}->{externalPrograms}->{latex},
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
    }

    my $itr;
    for($itr = $seed;$itr < $trials + $seed;$itr++) {

        #NEW SEED TEST
        $self->{problemEnviron}{problemSeed} 	= $itr;

        #ATTACH THE PROBLEM ENVIRONMENT TO TRANSLATOR
        $translator->environment($self->{problemEnviron});

        #INITIALIZING THE TRANSLATOR
        $translator->initialize();

        #PRE-LOAD MACRO FILES
        eval{$translator->pre_load_macro_files(
            $self->{safe},
        	$self->{serverEnviron}->{pg}->{directories}->{macros},
        	'PG.pl', 'dangerousMacros.pl','IO.pl','PGbasicmacros.pl','PGanswermacros.pl'
        )};
        warn "Error while preloading macro files: $@" if $@;

        #LOAD MACROS INTO TRANSLATOR
        foreach (qw(PG.pl dangerousMacros.pl IO.pl)) {
            my $macroPath = $self->{serverEnviron}->{pg}->{directories}->{macros} . "/$_";
            my $err = $translator->unrestricted_load($macroPath);
            warn "Error while loading $macroPath: $err" if $err;
        }

        #SET OPCODE MASK
        $translator->set_mask();

        #Retrieve Source
        my $source = decode_base64($code);
        #INSERT PROBLEM SOURCE CODE INTO TRANSLATOR
        eval { $translator->source_string( $source ) };
        $@ and die("bad source");

        #CREATE SAFETY FILTER
        $translator->rf_safety_filter(\&ProblemServer::nullSafetyFilter);

        #RUN
        $translator->translate();

        #ANSWERS
        #take array of answers and make hash
        my $answerHash = {};
        $translator->process_answers($answerHash);

        my $answers = $translator->rh_evaluated_answers;

        #CREATE STRING REP
        my $unique = "";
        my $key;
        #foreach $key (keys %{$answers}) {
        #    $unique = $unique . "$key" . $answers->{"$key"}->{"correct_ans"};
        #}
        $unique = encode_base64(${$translator->r_text});
        #IS IT UNIQUE
        my $found = 0;
        foreach(@alreadyCreated) {
            if($_ eq $unique) {
                $found = 1;
            }
        }

        #ADD HTML IF IT ISNT
        if($found == 0) {
            #GENERATE IMAGES AS NECESSARY
            if ($image_generator) {
                $image_generator->render(
                    body_text => $translator->r_text
                );
            }
            my $response = new ProblemServer::GeneratorResponse;
            $response->{html} = encode_base64(${$translator->r_text});
            $response->{seed} = $itr;
            #NEW PROBLEM... PLACE INTO ARRAY
            push(@derivedProblems,$response);
            push(@alreadyCreated,$unique);
        }
    #push(@derivedProblems,encode_base64(${$translator->r_text}));

    }
    return \@derivedProblems;
}

sub checker{
    my ($self,$code,$seed,$answersEntry) = @_;

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

    #DEFINE SPECIFIC CHANGES TO PROBLEM ENVIRONMENT
    $self->{problemEnviron}{displayMode} 	= translateDisplayModeNames("images");
    $self->{problemEnviron}{languageMode}       = $self->{problemEnviron}{displayMode};
    $self->{problemEnviron}{outputMode}		= $self->{problemEnviron}{displayMode};
    $self->{problemEnviron}{problemSeed} 	= $seed;

    #PREP IMAGE GENERATOR
    my $image_generator;
    if ("images" eq "images") {
    	my %imagesModeOptions = %{$self->{serverEnviron}->{pg}{displayModeOptions}{images}};
	$image_generator = WeBWorK::PG::ImageGenerator->new(
	    tempDir         => $self->{serverEnviron}->{problemServerDirs}->{tmp}, # global temp dir
	    latex	    => $self->{serverEnviron}->{externalPrograms}->{latex},
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
    }

    #ATTACH THE PROBLEM ENVIRONMENT TO TRANSLATOR
    $translator->environment($self->{problemEnviron});

    #INITIALIZING THE TRANSLATOR
    $translator->initialize();

    #PRE-LOAD MACRO FILES
    eval{$translator->pre_load_macro_files(
        $self->{safe},
	$self->{serverEnviron}->{pg}->{directories}->{macros},
	'PG.pl', 'dangerousMacros.pl','IO.pl','PGbasicmacros.pl','PGanswermacros.pl'
    )};
    warn "Error while preloading macro files: $@" if $@;

    #LOAD MACROS INTO TRANSLATOR
    foreach (qw(PG.pl dangerousMacros.pl IO.pl)) {
	my $macroPath = $self->{serverEnviron}->{pg}->{directories}->{macros} . "/$_";
	my $err = $translator->unrestricted_load($macroPath);
	warn "Error while loading $macroPath: $err" if $err;
    }

    #SET OPCODE MASK
    $translator->set_mask();

    #Retrieve Source
    my $source = decode_base64($code);
    #INSERT PROBLEM SOURCE CODE INTO TRANSLATOR
    eval { $translator->source_string( $source ) };
    $@ and die("bad source");

    #CREATE SAFETY FILTER
    $translator->rf_safety_filter(\&ProblemServer::nullSafetyFilter);

    #RUN
    $translator->translate();

    #PROCESS ANSWERS
    my ($result, $state); # we'll need these on the other side of the if block!
    my $answerArray = $answersEntry;

    if (defined $answerArray and @{$answerArray}) {
	# process student answers
	#warn "PG: processing student answers\n";

        #take array of answers and make hash
        my $answerHash = {};
        for(my $i=0;$i<@{$answerArray};$i++) {
            $answerHash->{$answerArray->[$i]{field}} = $answerArray->[$i]{answer};
        }
	$translator->process_answers($answerHash);

	# retrieve the problem state and give it to the translator
	#warn "PG: retrieving the problem state and giving it to the translator\n";
	$translator->rh_problem_state({
	    recorded_score =>       "0",
            num_of_correct_ans =>   "0",
	    num_of_incorrect_ans => "0",
	});

	# determine an entry order -- the ANSWER_ENTRY_ORDER flag is built by
	# the PG macro package (PG.pl)
	#warn "PG: determining an entry order\n";
	my @answerOrder = $translator->rh_flags->{ANSWER_ENTRY_ORDER}
            ? @{ $translator->rh_flags->{ANSWER_ENTRY_ORDER} }
	    : keys %{ $translator->rh_evaluated_answers };


	# install a grader -- use the one specified in the problem,
	# or fall back on the default from the course environment.
	# (two magic strings are accepted, to avoid having to
	# reference code when it would be difficult.)
	#warn "PG: installing a grader\n";
	my $grader = $translator->rh_flags->{PROBLEM_GRADER_TO_USE} || $self->{serverEnviron}->{pg}->{options}->{grader};
	$grader = $translator->rf_std_problem_grader if $grader eq "std_problem_grader";
	$grader = $translator->rf_avg_problem_grader if $grader eq "avg_problem_grader";
	die "Problem grader $grader is not a CODE reference." unless ref $grader eq "CODE";
	$translator->rf_problem_grader($grader);

	# grade the problem
	#warn "PG: grading the problem\n";
	($result, $state) = $translator->grade_problem(
            answers_submitted  => 1,
	    ANSWER_ENTRY_ORDER => \@answerOrder,
	    %{$answerHash}  #FIXME?  this is used by sequentialGrader is there a better way?
	);


    }
    my $displayMode = "images";

    #ANSWER EVALUATION AND PREVIEW GENERATOR
    my $answers = $translator->rh_evaluated_answers;
    my $key;
    my $preview;
    my $answerResponse = {};
    my @answersArray;

    foreach $key (keys %{$answers}) {
        #PREVIEW GENERATOR
        $preview = $answers->{"$key"}->{"preview_latex_string"};
        $preview = "" unless defined $preview and $preview ne "";
	if ($displayMode eq "plainText") {
	    $preview = $preview;
	} elsif ($displayMode eq "formattedText") {
            #FIX THIS TO USE TTH
            $preview = $preview;
	} elsif ($displayMode eq "images") {
	    $preview = $image_generator->add($preview);
	} elsif ($displayMode eq "jsMath") {
	    $preview =~ s/</&lt;/g;
            $preview =~ s/>/&gt;/g;
	    $preview = '<SPAN CLASS="math">\\displaystyle{'.$preview.'}</SPAN>';
	}

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

    #GENERATE IMAGES AS NECESSARY
    if ($image_generator) {
        $image_generator->render(refresh => 1);
    }
    return \@answersArray;
}

sub translateDisplayModeNames($) {
	my $name = shift;
	return DISPLAY_MODES()->{$name};
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
_IN request $ProblemServer::ProblemRequest
_RETURN $ProblemServer::ProblemResponse
=end WSDL
=cut
sub renderProblem {
    my ($self,$request) = @_;
    my $server = $ProblemServer::theServer;
    return ProblemServer::translation($server,$request);
}

=pod
=begin WSDL
_IN code $string
_IN seed $string
_IN trials $string
_RETURN @string
=end WSDL
=cut
sub generateProblems {
    my ($self,$code,$seed,$trials) = @_;
    my $server = $ProblemServer::theServer;
    return ProblemServer::generator($server,$code,$seed,$trials);
}


=pod
=begin WSDL
_IN code $string
_IN seed $string
_IN answers @ProblemServer::AnswerRequest
_RETURN @ProblemServer::AnswerResponse
=end WSDL
=cut
sub checkAnswers {
    my ($self,$code,$seed,$answers) = @_;
    my $server = $ProblemServer::theServer;
    return ProblemServer::checker($server,$code,$seed,$answers);
}

1;
