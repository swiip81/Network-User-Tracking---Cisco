#!/usr/bin/perl
## Realtime User tracking
## Florent USSEIL
## 14/08/2010 version 0.1
 
use warnings;
use Net::Appliance::Session ;
 
my $username        = 'usernamen';
my $password        = 'password';
my @list_core       = qw / ncecore-a.toto.net
			   ncecore-b.toto.net
			   ncecore-c.toto.net
			/ ;
 
use strict ;
 
my ($HOSTNAME,$MYIP,$MYMAC) ;
 
#$HOSTNAME  = "stationname" ;
#$MYIP     = "192.168.1.52" ;
$MYMAC    = "00:25:B3:1A:32:02" ;
#$MYMAC    = "00:25:b3:1a:32:02" ;
#$MYMAC    = "0025b31a3202" ;
#$MYMAC    = "0025.b31a.3202" ;
 
 
if ($HOSTNAME)
{
 if ( $HOSTNAME !~ m/toto/ )
  	{
	$HOSTNAME = $HOSTNAME . ".toto.net" ;
	}
 print "* Found hostname\t: $HOSTNAME\n" ;
 print "Looking for an IP...\n" ;
 my $raw_addr  = ( gethostbyname( "$HOSTNAME" ) )[4];
 my @octets    = unpack( "C4", $raw_addr );
 $MYIP = join( ".", @octets );
}
 
if ($MYIP)
{
 print "* Found ip address\t: $MYIP\n" ;
 print "Looking for a mac address...\n" ;
 $MYMAC = &getmacwithip($MYIP) ;
 system("ping -c 1 $MYIP > /dev/null") ;
}
 
if ($MYMAC)
{
 print "* Found mac address\t: $MYMAC\n" ;
 print "Checking mac address format...\n" ;
 $MYMAC = &checkmacformat($MYMAC) ;
 print "* Found mac address\t: $MYMAC\n" ;
 if ( !defined $MYIP )
        {
        print "Looking for an IP...\n" ;
        $MYIP = &getipwithmac($MYMAC) ;
        print "* Found ip address\t: $MYIP\n" ;
        system("ping -c 1 $MYIP > /dev/null") ;
        }
 
 print "Checking path to enduser...\n" ;
 &searchthismac($MYMAC) ;
}
 
else
{
print "Nothing to do...\n" ;
}
 
## END
## SUB ROUTINES UNDER ##
 
sub searchthismac
{
	my $MYMAC   = $_[0] ;
	my ($result,$device,$nextdevice,$port) ;
        foreach $device ( @list_core )
        {
         $result = (&connectandrun( $device , "sh mac-address-table | in $MYMAC"))[0] ;
         if ( defined $result )
                 {
                 chomp($result);
                 print $result . "\n" ; 
		 $port = (split(/\s+/,$result))[6] ;
		 #print $port . "\n" ;
		 $nextdevice = (&connectandrun( $device , "sh cdp nei $port"))[4] ;
			if ( defined $nextdevice )
			{
		 	chomp($nextdevice);
			$nextdevice =~ s/\s+//g ;
		 	print "* Next hop $nextdevice\n" ;
			$result = (&connectandrun( $nextdevice , "sh mac-address-table | in $MYMAC"))[0] ;
			 if ( defined $result )
				{
				chomp($result);
				print "* End with $result\n" ;
				}
			}
                 }
         }
}
 
sub getmacwithip
{
        my $MYIP   = $_[0] ;
        my ($result,$device) ;
        foreach $device ( @list_core )
        {
         $result = (&connectandrun( $device , "sh arp | in $MYIP"))[0] ;
         if ( defined $result )
                 {
		 @list_core = ( $device ) ;
                 chomp($result);
                 $result =~ s/.+(....\.....\.....).+/$1/ ;
                 return ($result) ;
                 }
         }
 return ("") ;
}
 
sub getipwithmac
{
        my $MYMAC   = $_[0] ;
        my ($result,$device) ;
        foreach $device ( @list_core )
        {
         $result = (&connectandrun( $device , "sh arp | in $MYMAC"))[0] ;
         if ( defined $result )
                 {
                 @list_core = ( $device ) ;
                 chomp($result);
                 $result =~ s/.+\s(\d+\.\d+\.\d+\.\d+)\s.+/$1/ ;
                 return ($result) ;
                 }
         }
 return ("") ;
}
 
sub checkmacformat
{
chomp $_[0] ;
$_[0] = lc($_[0]) ;
if ($_[0] =~ m/:/)
 {
  $_[0] =~ s/(..):(..):(..):(..):(..):(..)/$1$2\.$3$4\.$5$6/ ;
 }
if ($_[0] !~ m/\./)
  {
  $_[0] =~ s/(..)(..)(..)(..)(..)(..)/$1$2\.$3$4\.$5$6/ ;
 }
return ($_[0]) ;
}
 
sub connectandrun
 {
 my $device   = $_[0] ;
 my $command  = $_[1] ;
print "Connect to $device : $command\n"  ;
my $session_obj = Net::Appliance::Session->new(
        Host => $device,
	Transport => 'SSH',
  ) ;
$session_obj->input_log(*log);
$session_obj->connect(
	Name => $username,
	Password => $password,
	SHKC => 0
) ;
#$session_obj->begin_privileged($password) ;
my @result = $session_obj->cmd($command) ;
#$session_obj->close ;
return (@result) ;
 }
