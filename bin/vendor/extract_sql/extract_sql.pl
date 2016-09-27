#!/usr/bin/perl -w
##############################################################################
##  
##  Written by: Jared Cheney <jared.cheney@gmail.com>
##
##  Original Template written by: 
##     Brandon Zehm <caspian@dotconf.net> and Jared Cheney <elph@leph.net>
##  
##  License:
##  
##  This <programName> (hereafter referred to as "program") is free software;
##    you can redistribute it and/or modify it under the terms of the GNU General
##    Public License as published by the Free Software Foundation; either version
##    2 of the License, or (at your option) any later version.
##  Note that when redistributing modified versions of this source code, you
##    must ensure that this disclaimer and the above coder's names are included
##    VERBATIM in the modified code.
##  
##  Disclaimer:
##    This program is provided with no warranty of any kind, either expressed or
##    implied.  It is the responsibility of the user (you) to fully research and
##    comprehend the usage of this program.  As with any tool, it can be misused,
##    either intentionally (you're a vandal) or unintentionally (you're a moron).
##    THE AUTHOR(S) IS(ARE) NOT RESPONSIBLE FOR ANYTHING YOU DO WITH THIS PROGRAM
##    or anything that happens because of your use (or misuse) of this program,
##    including but not limited to anything you, your lawyers, or anyone else
##    can dream up.  And now, a relevant quote directly from the GPL:
##    
##    NO WARRANTY
##    
##    11. BECAUSE THE PROGRAM IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
##    FOR THE PROGRAM, TO THE EXTENT PERMITTED BY APPLICABLE LAW.  EXCEPT WHEN
##    OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
##    PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED
##    OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
##    MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE ENTIRE RISK AS
##    TO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU.  SHOULD THE
##    PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING,
##    REPAIR OR CORRECTION.
##    
##############################################################################
# Written by: Jared Cheney <jared.cheney@gmail.com>
#
# Purpose:  This program will extract the necessary portions from a full 
#           database mysqldump file required to restore a single table.
#
# Creation Date: 2008-05-23
#
# Changelog:
#  2008-05-23  v1.0  Jared Cheney
#   - initial release
#
#############################################################################

## FIXME's:

use strict;


## Global Variable(s)
my %conf = (
    "programName"          => $0,                                ## The name of this program
    "version"              => '1.0',                             ## The version of this program
    "authorName"           => 'Jared Cheney',                    ## Author's Name
    "authorEmail"          => 'jared.cheney@gmail.com',          ## Author's Email Address
    "debug"                => 0,                                 ## Default debug level
    "mode"                 => '',
    

    ## PROGRAM VARIABLES
    "logFile"              => '',                                ## default log file, if none specified on command line
    "prepend"              => '',                                ## Something that gets added to every msg that the script outputs
    "alertCommand"         => '',                                ## cmd to run if printmsg() contains the string 'ERR' or 'CRIT' or 'WARN'
    "noExtras"             => 0,                                 ## if 1, then we'll skip extra cmds for disabling foreign key checks, etc. at top of file
    "listTables"           => 0,                                 ## if 1, then return a list of tables contained in the restore file
);

$conf{'programName'} =~ s/(.)*[\/,\\]//;                         ## Remove path from filename
$0 = "[$conf{'programName'}]";









#############################
##
##      MAIN PROGRAM
##
#############################

## Initialize
initialize();

## Process Command Line
processCommandLine();


## get current timestamp for use later
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
$mon +=1;
if ($mon < 10) {$mon = "0" . $mon}
if ($mday < 10) {$mday = "0" . $mday}
$year +=1900;
printmsg ("current date is $mon/$mday/$year",3);


if ($conf{'mode'} eq "running") {
    printmsg ("INFO => PROGRAM STARTED",1);

    #############################
    ########    MAIN CODE    ####
    #############################
    
    if ($conf{'restoreFile'}) {
        ## open the mysqldump file
        open(STDIN, "<$conf{'restoreFile'}") || quit("ERROR => Couldn't open file $conf{'restoreFile'}: $!", 3);
    }
    
    my $flag = 0;
    
    ## go through the file one line at a time
    while (my $line = <STDIN>) {
        
        if ($conf{'listTables'}) {
            if ($line =~ /^-- Table structure for table `(.*)`/) {
                print $1 . "\n";
            }
        }
        else {
        
            ## if we're not ignoring extra lines, and we haven't set the flag, and if it's not a 40000 code, then print
            if (!$conf{'noExtras'} && !$flag) {
                if ($line =~ /^\/\*!(.....).*\*\//) { print $line unless ($1 == 40000); }
            }
            
            ## set a flag when we encounter the table we want
            if ($line =~ /^-- Table structure for table `$conf{'tableName'}`/) {
                $flag = 1;
                printmsg("Turning flag on", 1);
            }
            ## turn flag off as soon as we encounter next table definition
            elsif ($line =~ /^-- Table structure for table/) {
                $flag = 0;
                printmsg("Turning flag off", 1);
            }
            
            ## if flag is set, then print to STDOUT, otherwise just move on
            if ($flag) {
                print $line;
            }
        }
    }
    
    
    
    
    
    
    
    #############################
    ########  END MAIN CODE  ####
    #############################

}

## Quit
quit("",0);


















######################################################################
## Function:    help ()
##
## Description: For all those newbies ;) 
##              Prints a help message and exits the program.
## 
######################################################################
sub help {
print <<EOM;

$conf{'programName'}-$conf{'version'} by $conf{'authorName'} <$conf{'authorEmail'}>

This program will parse a full mysqldump file and 
extract the necessary portions required to restore 
a single table.  The output is printed to STDOUT, so you'll
want to redirect to a file from the command line, like so:
$conf{'programName'} > somefile.sql

Brought to you by the fine tech folk at www.tsheets.com - Time Is Money, Track It!

Usage:  $conf{'programName'} -t <table name> -r <restore file> [options]
  
  Required:
    -t <table name>       table name to extract from the file
    
    
  Optional:
    -r <restore file>     mysqldump file that you want to parse. If not specified, 
                          then it reads from STDIN
    --listTables          If set, then a list of tables existing in your restore file is returned,
                          and no other actions are taken
    --noExtras            If set, then extra cmds at top of mysqldump file
                          will not be included (such as disabling foreign key checks).
                          Usually you will want these things changed before restoring a
                          table, so the default is for these to be included.
    -v                    verbosity - use multiple times for greater effect
    -h                    Display this help message

                                                               
  
EOM
exit(1);
}





######################################################################
##  Function: initialize ()
##  
##  Does all the script startup jibberish.
##  
######################################################################
sub initialize {

  ## Set STDOUT to flush immediatly after each print  
  $| = 1;

  ## Intercept signals
  $SIG{'QUIT'}  = sub { quit("$$ - $conf{'programName'} - EXITING: Received SIG$_[0]", 1); };
  $SIG{'INT'}   = sub { quit("$$ - $conf{'programName'} - EXITING: Received SIG$_[0]", 1); };
  $SIG{'KILL'}  = sub { quit("$$ - $conf{'programName'} - EXITING: Received SIG$_[0]", 1); };
  $SIG{'TERM'}  = sub { quit("$$ - $conf{'programName'} - EXITING: Received SIG$_[0]", 1); };
  
  ## ALARM and HUP signals are not supported in Win32
  unless ($^O =~ /win/i) {
      $SIG{'HUP'}   = sub { quit("$$ - $conf{'programName'} - EXITING: Received SIG$_[0]", 1); };
      $SIG{'ALRM'}  = sub { quit("$$ - $conf{'programName'} - EXITING: Received SIG$_[0]", 1); };
  }
  
  return(1);
}








######################################################################
##  Function: processCommandLine ()
##  
##  Processes command line storing important data in global var %conf
##  
######################################################################
sub processCommandLine {
    
    
    ############################
    ##  Process command line  ##
    ############################
    
    my $x;
    my @ARGS = @ARGV;
    my $numargv = scalar(@ARGS);
    help() unless ($numargv);
    for (my $i = 0; $i < $numargv; $i++) {
        $x = $ARGS[$i];
        if    ($x =~ /^-h$|^--help$/)   { help(); }
        elsif ($x =~ /^-v+/i)           { my $tmp = (length($&) - 1); $conf{'debug'} += $tmp; }
        elsif ($x =~ /^-l$/)            { $i++; $conf{'logFile'}    = $ARGS[$i];}
        elsif ($x =~ /^-p$/)            { $i++; $conf{'policyName'} = $ARGS[$i];}
        elsif ($x =~ /^-t$/)            { $i++; $conf{'tableName'}  = $ARGS[$i];}
        elsif ($x =~ /^-r$/)            { $i++; $conf{'restoreFile'}= $ARGS[$i];}
        elsif ($x =~ /^--noExtras$/i)   {       $conf{'noExtras'}   = 1;        }
        elsif ($x =~ /^--listTables$/i) {       $conf{'listTables'} = 1;        }
        else  { 
            printmsg("Error: \"$x\" is not a recognised option!", 0);
            help(); 
        }
    }
    
    my @required = (
                      'tableName',
    );
    
    if ($conf{'listTables'}) {
        $conf{'mode'} = 'running';
        return(1);
    }
    
    foreach (@required) {
        if (!$conf{$_}) {
            quit("ERROR: Value [$_] was not set after parsing command line arguments!", 1);
        }
    }
    $conf{'mode'} = 'running';
    return(1);
}
 















###############################################################################################
##  Function:    printmsg (string $message, int $level)
##
##  Description: Handles all messages - logging them to a log file, 
##               printing them to the screen or both depending on
##               the $level passed in, $conf{'debug'} and wether
##               $conf{'mode'}.
##
##  Input:       $message                A message to be printed, logged, etc.
##               $level                  The debug level of the message. If
##                                       not defined 0 will be assumed.  0 is
##                                       considered a normal message, 1 and 
##                                       higher is considered a debug message.
##               $leaveCarriageReturn    Whether or not to strip carriage returns (always will strip, unless other than 0)
##  
##  Output:      Prints to STDOUT, to LOGFILE, both, or none depending 
##               on the state of the program.
##  
##  Example:     printmsg ("WARNING: We believe in generic error messages... NOT!", 1);
###############################################################################################
sub printmsg {
    my %incoming = ();
    (
        $incoming{'message'},
        $incoming{'level'},
        $incoming{'leaveCarriageReturn'},
    ) = @_;
    $incoming{'level'} = 0 if (!defined($incoming{'level'}));
    $incoming{'leaveCarriageReturn'} = 0 if (!defined($incoming{'leaveCarriageReturn'}));
    $incoming{'message'} =~ s/\r|\n/ /sg unless ($incoming{'leaveCarriageReturn'} >= 1);

    ## Add program name and PID
    ## $incoming{'message'} = "- $conf{'programName'} [$$]: " . $incoming{'message'};
    ## add prepend info
    ## $incoming{'message'} = "$conf{'prepend'} : $incoming{'message'}";

    ## Continue on if the debug level is >= the incoming message level
    if ($conf{'debug'} >= $incoming{'level'}) {
       ## Print to the log file
        if ($conf{'logFile'}) {
            open (LOGFILE, ">>$conf{'logFile'}");
            print LOGFILE "$conf{'programName'}:[". localtime() . "] $incoming{'message'}\n";
            close (LOGFILE);
        }
        if ($conf{'alertCommand'} && ($conf{'debug'} == 0) && ($incoming{'message'} =~ /ERR|CRIT|WARN/) ) {
            my $tmpAlert = $conf{'alertCommand'};
            $tmpAlert =~ s/MESSAGE/$incoming{'message'}/g;
            system ($tmpAlert);
        }
        ## Print to STDOUT
        if ($conf{'debug'} >= 1) {
            print STDOUT "$conf{'programName'}:[" . localtime() . "]($incoming{'level'}): $incoming{'message'}\n";
        }
        else {
            print STDOUT "$conf{'programName'}:[" . localtime() . "] $incoming{'message'}\n";
        }
    }

    ## Return
    return(0);
}









######################################################################
##  Function:    quit (string $message, int $errorLevel)
##  
##  Description: Exits the program, optionally printing $message.  It 
##               returns an exit error level of $errorLevel to the 
##               system  (0 means no errors, and is assumed if empty.)
##
##  Example:     quit("Exiting program normally", 0);
######################################################################
sub quit {
  my %incoming = ();
  (
    $incoming{'message'},
    $incoming{'errorLevel'}
  ) = @_;
  
  
  $incoming{'errorLevel'} = 0 if (!defined($incoming{'errorLevel'}));
  
  ## Print exit message
  if ($incoming{'message'}) { 
      printmsg($incoming{'message'}, 0);
  }
  
  ## Exit
  exit($incoming{'errorLevel'});
}



