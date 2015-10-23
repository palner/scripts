#!/usr/bin/perl
use IO::Socket;
use POSIX 'strftime';
use Getopt::Long;
use strict;
$| = 1;

my $USAGE = "Usage: sipcheck.pl [-v] [-s <src_host>] [p <src_port>] <hostname>\nExample\: sipcheck.pl -v hdef.me\n";
my $Receive_Timeout = 5;
my $sock = IO::Socket::INET->new(Proto => 'udp',
	LocalPort => '6655',
	ReuseAddr => 1)
	or die "Could not make socket: $@";

my ($verbose, $host, $my_ip, $my_port);
GetOptions ("verbose|v" => \$verbose,
	"source-ip|s=s" => \$my_ip,
	"source-port|p=n" => \$my_port)
	or die "Invalid opions:\n\n$USAGE\n";

my $host = shift(@ARGV) or die $USAGE;
my $dst_addr = inet_aton($host) or die "Could not find host: $host";
my $dst_ip = inet_ntoa($dst_addr);
my $portaddr = sockaddr_in(5060, $dst_addr);

$my_ip = "127.0.0.1" unless defined($my_ip);
$my_port = "6655" unless defined($my_port);

my $callid = ""; 
$callid .= ('0'..'9', "a".."f")[int(rand(16))] for 1 .. 32;
my $date = strftime('%a, %e %B %Y %I:%M:%S %Z',localtime());
my $branch="z9hG4bk" . time();

my $packet = qq(OPTIONS sip:$dst_ip SIP/2.0
Via: SIP/2.0/UDP $my_ip:$my_port;branch=$branch
From: <sip:ping\@$my_ip>
To: <sip:$host>
Contact: <sip:ping\@$my_ip>
Call-ID: $callid\@$my_ip
CSeq: 102 Options
User-Agent: sipcheck.pl
Date: $date
Allow: ACK, CANCEL
Content-Length: 0
);

print "Sending: \n\n$packet\n" if $verbose;
send($sock, $packet, 0, $portaddr) == length($packet)
	or die "cannot send to $host: $!";

eval {
	local $SIG{ALRM} = sub { die "alarm time out" };
	alarm $Receive_Timeout;
	$portaddr = recv($sock, $packet, 1500, 0) or die "couldn't receive: $!";
	alarm 0;
	1;
} or die($@);

if ($verbose) {
		print("host said: \n\n$packet\n");
	} else {
		print("$host is alive\n");
}
