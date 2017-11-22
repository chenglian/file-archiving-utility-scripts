#!/usr/opt/perl5/bin/perl
#
# !!!USE AT YOUR OWN RISK!!!
# !!!TEST THOROUGHLY WITH YOUR USE CASES!!!
#
# A simple file purge utility
# This utility delete files that is old enough.
#    
# USAGE: perl purg.pl <source_dir> <number_of_days> <filename_pattern> [IGNORE_SUBFOLDER]
# Input:
#	source_dir			-	the file folder under which files will be deleted
#	number_of_days		-	files number of days, 0 is a valid input.
#	filename_pattern	-	files with names not matching such regex pattern will be ignored. E.g. '.*' is a pattern for all files, '\.log$' is a pattern for *.log.
#							The pattern will be used as regex pattern as is - test your pattern carefully.
#	[ignore_subfolder]	- optional. if specified, will ignore subfolders; o/w process sub folders with resursion.
#
# Output:
#	Files (e.g. old log files) are removed permanently.
#	print logging messages to standard out or standard err
#
#
# Author: andy.hoho@gmail.com
#
################################################################################
use strict; 
use constant {
        RECURSE_SUBFOLDER => "RECURSE_SUBFOLDER",
        IGNORE_SUBFOLDER => "IGNORE_SUBFOLDER"
 };
 
 

#
# Define global variables
#
my $g_usage = "Invalid arguments.\nUSAGE: perl $0 <source_dir> <number_of_days> <filename_regex: eg use '.*' for all> [IGNORE_SUBFOLDER]";
my $g_src;
my $g_days;
my $g_pattern;
my $g_recursion; 


################################################################################
#
# Print logging messages to standard out with a timestamp
#
sub logmsg {
	print( scalar localtime() . " @_\n" );
	return;
}

#
# Print logging messages to standard out with a timestamp
#
sub logerr {
	print STDERR ( scalar localtime() . " ERROR: @_\n$!\n" );
}

#
# Log error msg and exit 1
#
sub die1 {
	logerr @_;
	exit 1;
}

#
# Log error msg and exit 2
#
sub die2 {
	logerr @_;
	exit 2;
}

#
# check if the file is old enough
#
sub isOld {
	my $f = $_[0];
	my $days = $g_days;

	open(IN, "$f") or die1 "can't open $f: $!";
	my $d = -M IN;
	
	close(IN) or die1 "can't close $f: $!";
	
	if ($d >= $days) {
		logmsg "$f is old ".$d." days.";
		return 1;
	} else {
		logmsg "$f is young ".$d." days.";
		return 0;
	}
}

#
# main routine
#

sub purg {
	
	my $srcDir = $_[0];
	
	logmsg "purg args: ", @_;
	
	my ( @files, @folders);
	
	# read the directory
	opendir( DIR, $srcDir ) or die1 "can not open directory $srcDir!\n";
	
	#
	# filter unwanted files and directories
	#
	while (my $fname = readdir(DIR) ) {
		#full file path
		my $filecheck = $srcDir.'/'.$fname;
					
		if (-d $filecheck) {			
			#save data file names in an array, don't include . and ..
			push ( @folders, $fname ) if ( !( $fname eq '.' || $fname eq '..' ) );
		
		} 
		# check if file exists and if file satifies the matching criteria
		elsif ( -f $filecheck) {
			if ($fname !~ /$g_pattern/){
				logmsg "ignored: file name does not match pattern $g_pattern - $fname";
			}elsif (isOld($filecheck)){
				push( @files, $fname );				
			}
		}
		
	}
	
	closedir(DIR) or die1 "can not close directory $srcDir\n";
	
	#
	# delete each file 
	#

	if (@files > 0) {
		for(my $i=0; $i < @files; $i++) {
			
			 my $infile = $srcDir.'/'.$files[$i];
			 unlink($infile) 
				or die1 "unable to delete $infile! $!";

		 	logmsg "Deleted: $infile";
		}				
	} 
	
	#
	# recursion for sub folders for the same treatment
	#
	if ($g_recursion and @folders > 0) {
		for(my $i=0; $i < @folders; $i++) {
			purg ($srcDir.'/'.$folders[$i]);
	    }	
	}				
	
}

################################################################################
#
# main()
#
################################################################################

logmsg "Start file purging under folder: @ARGV ...";

$g_src = $ARGV[0];
$g_days = $ARGV[1];
$g_pattern = $ARGV[2];

# remind user if there is missing argument
if (!$g_src or !$g_pattern) {
	die1 $g_usage;
}

if ($ARGV[1] !~ /^\d+$/){
	die1 $g_usage;
}

# optinal arguments
$g_recursion = $ARGV[3];
if ($g_recursion) {
	$g_recursion = uc($g_recursion);
	if (($g_recursion ne IGNORE_SUBFOLDER) and ($g_recursion ne RECURSE_SUBFOLDER)){
		die1 $g_usage;
	}
} else {
	$g_recursion = RECURSE_SUBFOLDER;
}

# remove tailing / in directories
if ($g_src =~ /\\$/ or $g_src =~ /\/$/) {
	chop ($g_src);
}

#
# call the main routines
#

purg ($g_src);


################################################################################	
#
# The end.
#
logmsg "Done file purging.";
exit 0;
