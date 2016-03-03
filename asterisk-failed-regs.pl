#!/usr/bin/perl -w
#
# 	Created 2008
#	Fred Posner <fred@qxork.com>
#	Last Updated August 2015.
#
#	Find attempts and block them in iptables.
#
use strict;
use warnings;

#
#	Definitions listed individually for I can't remember why.
#
#	failhost will be an array of matching ip addresses from the log
#	currblocked is a hash of currently blocked ip addresses
#	addblocked checks failhost
#	action runs system commands
#	logfile is (shockingly) the log file to read
#  date holds the date value, formatted as desired.
#	rotate is a simple counter (0/1) for rotating log.
#
my (@failhost);
my %currblocked;
my %addblocked;
my $action;
my $logfile;

my $date = &get_date;
my $rotate = 0;

#
#	Check if log file has been passed, if not
#	use default messages file
#

if ($ARGV[0]) {
	$logfile = $ARGV[0];
} else {
	$logfile = "/var/log/asterisk/messages";
}

#
#	open log file
#	and grep each line for trouble
#

open (MYINPUTFILE, "$logfile") or die "\n", $!, "Does $logfile exist\?\n\n";

while (<MYINPUTFILE>) {
	my ($line) = $_;
	chomp($line);
	#	registrations for peers that don't exist
	if ($line =~ m/\' failed for \'(.*?)\' - No matching peer found/) {
		push(@failhost,$1);
	}
	#	bad passwords / etc.
	elsif ($line =~ m/\' failed for \'(.*?):/) {
		push(@failhost,$1);	
	}
	#	bad calls to default context
	elsif ($line =~ m/\((.*?):(.*?)\) to extension \'(.*?)\' rejected because extension not found in context \'default\'/) {
		push(@failhost,$1);
	}
	elsif ($line =~ m/\((.*?):(.*?)\) to extension \'(.*?)\' rejected because extension not found in context \'public\'/) {
		push(@failhost,$1);
	}
}

#
#	get current blocked ipaddresses in asterisk chain
#

my $blockedhosts = `/sbin/iptables -n -L asterisk`;

#
#	grep through and get ip addresses, adding them to currblocked
#

while ($blockedhosts =~ /(.*)/g) {
	my ($line2) = $1;
	chomp($line2);
	if ($line2 =~ m/(\d+\.\d+\.\d+\.\d+)(\s+)/) {
		$currblocked{ $1 } = 'blocked';
	}
}

while (my ($key, $value) = each(%currblocked)) {
	print $key . "\n";
}

#
#	match found addresses against current blocked
#

if (@failhost) {
	#	log results in /var/log/asterisk/logparse.log. 
	open (RESULTS, ">> /var/log/asterisk/logparse.log") or die "ERROR: Could not save log.\n";;
	&count_unique(@failhost);
	while (my ($ip, $count) = each(%addblocked)) {
		if (exists $currblocked{ $ip }) {
			print RESULTS "$date: $ip already blocked\n";
		} elsif (index($ip, "10.1.101.") != "-1") {
                #       whitelist ip address / ranges
			print RESULTS "$date: $ip is whitelisted\n";
		} else { 
		#	add ip address to asterisk chain with date time domment.
			$action = `/sbin/iptables -I asterisk -s $ip -j DROP -m comment --comment "blocked $date $count attempts "`;
			print RESULTS "$date: $ip blocked. $count attempts.\n";
			$rotate = 1;
		}
	}

	#	we found a bad attempt, so let's rotate the log.
	if ($rotate == 1) {
		$action = `/usr/sbin/asterisk -rx "logger rotate"`;
	}

	close (RESULTS);
} else {
	print "no failed registrations.\n";
}

sub count_unique {
	my @array = @_;
	my %count;
	map { $count{$_}++ } @array;
	map {($addblocked{ $_ } = ${count{$_}})} sort keys(%count);
}

sub get_date {
	#	return date and time from local time.
	my ($sec,$min,$hour,$day,$mon,$yrnum,$wday,$yday,$isdst) = localtime(time);
	return sprintf("%04d-%02d-%02d %02d:%02d", $yrnum+1900, $mon+1, $day, $hour, $min);
}

