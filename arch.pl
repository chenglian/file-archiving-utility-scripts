#!/usr/opt/perl5/bin/perl
#
# !!!USE AT YOUR OWN RISK!!!
# !!!TEST THOROUGHLY WITH YOUR USE CASES!!!
#
# A simple file archiving utility based on Zip
# This utility does not delete any original file.
#    
# USAGE: perl arch.pl <source_dir> <target_dir> <number_of_days> <ALL|EACH|_YYYYMMDD|_YYMMDD> [IGNORE_SUBFOLDER]
# Input:
#	source_dir		-	the file folder under which files and subfolders will be archived (.zip files are ignored)
#	target_dir		-	the file folder for the compressed files (can be the same as source_dir)
#	number_of_days	-	files number of days
#
#	filepattern		-	
#						ALL:		compress all files into one file; include sub folders (if not ignored) 
#						EACH:		compress each individual file
#						_YYYYMMDD:	compress multiple files into one zip file based on the 8-digit date pattern in the file name. Preceeding UNDER_SCORE must be present.
#						_YYMMDD:		compress multiple files into one zip file based on the 6-digit date pattern in the file name. Preceeding UNDER_SCORE must be present.
#
#	[ignore_subfolder]	-	optional. if specified, will ignore subfolders; o/w process sub folders with resursion.
#
# Output:
#	Generate .zip files to the target folder
#	print logging messages to standard out or standard err
#
#
# Author: andy.hoho@gmail.com
#
################################################################################
use strict; 
use File::Basename;
use File::Path qw(make_path remove_tree);
use File::Spec;
use FindBin qw($Bin);
					# This assumes perl Zip module can't be installed for some reason,
use lib "$Bin/lib"; # and the module is copied under ./lib folder.
					# Remove this if the Zip module is already installed.
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);

use constant {
        ALL   => "ALL",
        EACH  => "EACH",
        _YYYYMMDD => "_YYYYMMDD",
        _YYMMDD => "_YYMMDD",
        RECURSE_SUBFOLDER => "RECURSE_SUBFOLDER",
        IGNORE_SUBFOLDER => "IGNORE_SUBFOLDER"
 };
 
 

#
# Define global variables
#
my $g_usage = "Invalid arguments.\nUSAGE: perl $0 <source_dir> <target_dir> <number_of_days> <ALL|EACH|_YYYYMMDD|_YYMMDD> [IGNORE_SUBFOLDER]";
my $g_src;
my $g_dest;
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

# get file name from file full path
sub getfn {
	my($vol,$dir,$file) = File::Spec->splitpath($_[0]);
	return $file;
}
# get dir name from file full path
sub getdir {
	my($vol,$dir,$file) = File::Spec->splitpath($_[0]);
	return $dir;
}

#
# Build directory structure if not exists
#
sub mdir {
	my $dir = getdir($_[0]);
	if (! -d $dir) {
		make_path($dir);
	}
}

#
# get today's date in yyyy-mm-dd format
#
sub getdate {
	
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
	my $result = sprintf("%02d-%02d-%02d", $year+1900, $mon+1, $mday);
	return $result;
	
}

#
# compress one single file 
#	arg1: source file
#	arg2: destination of the compressed file
#
sub zipf {
	my $fi = $_[0];
	my $fo = $_[1];
	my $zip1;
	
	
	if (! -f $fi){
		die1 "$fi is not a file!"
	}
	
	$zip1 = Archive::Zip->new();
	$zip1->addFile($fi, basename($fi))
	   	 	or die1 "unable to add file $fi to archive. $!";		
	
	# make directory if necessary
	mdir($fo);
	
	if ($zip1->writeToFileNamed($fo) != AZ_OK){
		die1 "unable to write file $fo . $!";
	}
		
}

#
# compress multiple files into one single zipped file
#	arg1: the REFERENCE to the array of a list of source files
#	arg2: destination of the compressed file
#
sub zipfs {
	my @fi = @{$_[0]};
	my $fo = $_[1];
	
	my $z = Archive::Zip->new();
	my ($f, $i);
	
	for($i=0; $i < @fi; $i++) {
		$f = $fi[$i];
		if (! -f $f){
			die1 "$f is not a file!"
		}
		
		$z->addFile($f, basename($f))
	    	or die1 "unable to add files $f to archive. $!";
		
	}	
	
	# make directory if necessary
	mdir($fo);
	    
	if ($z->overwriteAs($fo) != AZ_OK){
		die1 "unable to write file $fo != AZ_OK!";
	}
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
# check if a file should be included
#
sub ifInclude {
	if (! -f $_[0]) {
		die1 "ifInclude: $_[0] is not a file!";
	}
	return (($_[0] !~ /\.(zip)$/) and isOld($_[0]) );
}

################################################################################
#
# compress each file into a new file
# process files under sub folders recursively if enabled. 
#
################################################################################
sub arch_each {
	
	# extract and assign parameters
	my ($srcDir, $destDir);
	$srcDir = $_[0];
	$destDir = $_[1];
	
	logmsg "arch_each args: ", @_;
	
	my (@files, @folders);
	
	# read the directory
	opendir( DIR, $srcDir ) or die1 "can not open directory $srcDir!\n";
	
	if (!$destDir) {
		die1 "can not open directory $destDir!\n";
	}
	
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
		# check if file exists and if file satifies the matching criteria (e.g. old enough and has not been compressed already)
		elsif ( (-f $filecheck) && ifInclude($filecheck)) {
			
			push( @files, $fname ) if ( !( $fname eq '.' || $fname eq '..' ) );
		}
		
	}
	
	closedir(DIR) or die1 "can not close directory $srcDir\n";
	
	#
	# compress each file into a separte compressed file
	#

	if (@files > 0) {
		for(my $i=0; $i < @files; $i++) {
			
			 my $infile = $srcDir.'/'.$files[$i];
			 my $outfile = $destDir.'/'.$files[$i].'.zip';
			 
		 	zipf($infile, $outfile);
		 	logmsg $infile." -> ".$outfile;
		}				
	} 
	
	#
	# recursion for sub folders for the same treatment
	#
	if ($g_recursion and @folders > 0) {
		for(my $i=0; $i < @folders; $i++) {
			arch_each ($srcDir.'/'.$folders[$i], $destDir.'/'.$folders[$i]);
	    }	
	}				
		
}



################################################################################
#
# compress multiple files under the same directory into one single zipped file
# ignore sub folders
#
################################################################################

sub arch_all_filesOnly {
	# extract and assign parameters
	my ($srcDir, $destDir);
	$srcDir = $_[0];
	$destDir = $_[1];
	
	logmsg "arch_all_filesOnly args: ", @_;
	
	my ($fname, @files, $outfile);
	
	# read the directory
	opendir( DIR, $srcDir ) or die1 "can not open directory $srcDir!\n";
	
	if (!$destDir) {
		die1 "can not open directory $destDir!\n";
	}
	
	#
	# filter unwanted files and directories
	#
	while ($fname = readdir(DIR) ) {
		#full file path
		my $filecheck = $srcDir.'/'.$fname;

		# check if file exists and if file satifies the matching criteria (e.g. old enough and has not been compressed already)
		# ignore directories
		if ( (-f $filecheck) && ifInclude($filecheck)) {
			push( @files, $filecheck );
		}
		
	}
	
	closedir(DIR) or die1 "can not close directory $srcDir\n";
	
	#
	# compress files into a single compressed file
	#
	
	$outfile = $destDir."/".basename($srcDir)."_".getdate().".zip";
	
	if (@files > 0) {
		 zipfs(\@files, $outfile);
		 logmsg "archived: {", @files, "} -> $outfile";				
	} 
	
}

################################################################################
#
# compress at directory level tree in to one single file
#
################################################################################

sub arch_all {
	
	# check if ignore sub folders, if so, zip files only.
	if ($g_recursion eq IGNORE_SUBFOLDER ){
		
		arch_all_filesOnly ($_[0],$_[1]);
		
		return;
		
	} ####################################################
	
	# 
	# needs to process sub folders recursively
	#
	
	# extract and assign parameters
	my ($srcDir, $destDir);
	$srcDir = $_[0];
	$destDir = $_[1];
	
	logmsg "arch_all args: ", @_;
	
	my ($zip, $zipName, $outfile, $member, @members, $i, $pred);	
	
	if (! -d $srcDir){
		die1 "$srcDir is not a directry or does not exist!"
	}
	
	$zip = Archive::Zip->new();
	
	$zipName = basename($srcDir);
	
	#
	# this routine will be called for each member
	#
	$pred = sub {
		my $f = $_;
		if (-f $f){
			return ifInclude($f);
		}
		return 1;		
	};
	
	if ($zip->addTree($srcDir,$zipName, $pred) != AZ_OK){
	   	 die1 "unable to add file $srcDir to archive. $!";				
	}
		
	# make directory if necessary
	mdir($destDir);
	
	$outfile = $srcDir."/".$zipName."_".getdate().".zip";
	if ($zip->overwriteAs($outfile) != AZ_OK){
		die1 "unable to write file $outfile . $!";
	} 
	
	logmsg "Archived $srcDir -> $outfile";
		
}

#
# check if a string array contains a given string
#
sub contains {
	my @a = @{$_[0]};
	my $e = $_[1];

	for (my $i=0; $i < @a; $i++){
		next unless defined $e; # added this line to avoid warning message about "$e uniitialized"
		if ($e eq $a[$i]){
			return 1;
		}
	}
	
	return 0;
}
################################################################################
# compress multiple files into a compressed file based on the date info in the file name
# resurse into sub folders for the same treatment if enabled
################################################################################
sub arch_date {
	
	# extract and assign parameters
	my ($srcDir, $destDir);
	$srcDir = $_[0];
	$destDir = $_[1];
	
	logmsg "arch_date args: ", @_;
	
	my (@files, @folders, @matches);
	
	# read the directory
	opendir( DIR, $srcDir ) or die1 "can not open directory $srcDir!\n";
	
	if (!$destDir) {
		die1 "can not open directory $destDir!\n";
	}
	
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
		# check if file exists and if file satifies the matching criteria (e.g. old enough and has not been compressed already)
		elsif ( (-f $filecheck) && ifInclude($filecheck)) {
			
			push( @files, $fname ) if ( !( $fname eq '.' || $fname eq '..' ) );
		}
		
	}
	
	closedir(DIR) or die1 "can not close directory $srcDir\n";
	
	#
	# find out all dates in the file names
	# 	
	if (@files > 0) {
		if ($g_pattern eq _YYYYMMDD){
			for(my $i=0; $i < @files; $i++) {
				if ($files[$i] =~ /(_\d{8})/){
					my $match = $1;
					if (!contains(\@matches, $match)){
						push (@matches, $match);
					}
				}
			}							
		}elsif ($g_pattern eq _YYMMDD){
			for(my $i=0; $i < @files; $i++) {
				if ($files[$i] =~ /(_\d{6})/){
					my $match = $1;
					if (!contains(\@matches, $match)){
						push (@matches, $match);
					}
				}
			}							
		}

	} 
	
	#
	# zip files based on each date
	#
	if (@matches > 0){
		for(my $j=0; $j < @matches; $j++) { ##### for each date
			my (@matchedFiles, $d, $outfile);
			$d = $matches[$j];
			for (my $n = 0; $n < @files; $n++){
				next unless defined $d; # added this line to avoid warning message about "$d uniitialized"
				if ($files[$n] =~ /$d/){
					push (@matchedFiles, $srcDir.'/'.$files[$n]);
				}
			}
			
			# zip files
			if (@matchedFiles > 0){
				
				$outfile = $destDir.'/'.$d.'.zip';
				
				zipfs(\@matchedFiles, $outfile);
				
				logmsg "archived: {", @matchedFiles, "} -> $outfile";				
			}
		}
		
	}
	
	#
	# recursion for sub folders for the same treatment
	#
	if ($g_recursion and @folders > 0) {
		for(my $i=0; $i < @folders; $i++) {
			arch_date ($srcDir.'/'.$folders[$i], $destDir.'/'.$folders[$i]);
	    }	
	}				
	

} ### end of arch

################################################################################
#
# main()
#
################################################################################

logmsg "Start file archiving @ARGV ...";

$g_src = $ARGV[0];
$g_dest = $ARGV[1];
$g_days = $ARGV[2];
$g_pattern = uc($ARGV[3]);

# remind user if there is missing argument
if (!$g_src or !$g_dest or !$g_pattern) {
	die1 $g_usage;
}

if ($ARGV[2] !~ /^\d+$/){
	die1 $g_usage;
}

if ($g_pattern !~ /^(ALL|EACH|_YYYYMMDD|_YYMMDD)$/) {
	die1 $g_usage;
}

# optinal arguments
$g_recursion = $ARGV[4];
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

if ($g_dest =~ /\\$/ or $g_dest =~ /\/$/) {
	chop ($g_dest);
}

#
# call the main routines
#
if ($g_pattern eq EACH) {
	arch_each $g_src,$g_dest;
}
elsif ($g_pattern eq ALL) {
	arch_all $g_src,$g_dest;
}
elsif ($g_pattern eq _YYYYMMDD or $g_pattern eq _YYMMDD) {
	arch_date $g_src,$g_dest;
}



################################################################################	
#
# The end.
#
logmsg "Done file archiving.";
exit 0;
