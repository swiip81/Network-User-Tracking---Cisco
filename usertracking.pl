#!/usr/bin/perl
## Realtime User tracking
## Florent USSEIL
## 14/08/2010 version 0.1
## 21/08/2010 version 0.2

use warnings;
use Net::Appliance::Session ;

my $username        = 'user';
my $password        = 'password';
my @list_core       = qw / ncecore-a01.nce.net ncecore-b01.nce.net
                        / ;

use strict ;

my ($HOSTNAME,$MYIP,$MYMAC) ;

$HOSTNAME  = "ncestoto" ;
#$MYIP     = "192.168.1.52" ;
#$MYMAC    = "00:25:B3:1A:32:02" ;
#$MYMAC    = "00:25:b3:1a:32:02" ;
#$MYMAC    = "0025b31a3202" ;
#$MYMAC    = "0025.b31a.3202" ;


if ($HOSTNAME)
{
 if ( $HOSTNAME !~ m/\.nce\.net/ )
        {
        $HOSTNAME = $HOSTNAME . ".nce.net" ;
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
 if (!defined $HOSTNAME)
 {
        print "Looking for a hostname...\n" ;
        my @bytes = split( /\./, $MYIP );
        my $packedaddr = pack( "C4", @bytes );
        $HOSTNAME = ( gethostbyaddr( $packedaddr, 2 ) )[0];
        print "* Found hostname\t: $HOSTNAME\n" ;
 }
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
        print "Looking for a hostname...\n" ;
        my @bytes = split( /\./, $MYIP );
        my $packedaddr = pack( "C4", @bytes );
        $HOSTNAME = ( gethostbyaddr( $packedaddr, 2 ) )[0];
        print "* Found hostname\t: $HOSTNAME\n" ;
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
        if ( @list_core > 1 )
                {
                        foreach $device ( @list_core )
                        {
                                $result = (&connectandrun( $device , "sh mac-address-table | in $MYMAC"))[0] ;
                                if ( defined $result )
                                {
                                        @list_core = ( $device ) ;
                                        last ;
                                }
                        }
                }
                $device = $list_core[0] ;
                while ( 1 )
                {
                $result = undef ;
                $result = (&connectandrun( $device , "sh mac-address-table | in $MYMAC"))[0] ;
                if ( defined $result )
                        {
                                if ( $result =~ m/^\*/)
                                {
                                        $port = (split(/\s+/,$result))[6] ;
                                }
                                else
                                {
                                        $port = (split(/\s+/,$result))[5] ;
                                }
                                $nextdevice = undef ;
                                $nextdevice = (&connectandrun( $device , "sh cdp nei $port "))[4] ;
                                if ( defined $nextdevice )
                                                                {
                                        chomp($nextdevice);
                                        $nextdevice =~ s/\s+//g ;
                                        print "* Next hop $nextdevice\n" ;
                                        if ( $nextdevice =~ m/ncewlapc/ )
                                                {
                                                print " => Next hop is WIFI : $nextdevice\n" ;
                                                last
                                                }
                                        if ( $nextdevice =~ m/SEP/ )
                                                {
                                                print " => Next hop is IPPHONE : $nextdevice\n" ;
                                                last
                                                }
                                        $device = $nextdevice ;
                                }
                                else
                                {
                                        last ;
                                }
                        }
                }
                print "\n**********\n Tracking result :\n" ;
                if ( defined $HOSTNAME ) { print " - HOSTNAME: \t$HOSTNAME\n" ; }
                if ( defined $MYIP )     { print " - IP: \t\t$MYIP\n" ; }
                print " - MAC: \t$MYMAC\n" ;
                print " - NetDev:\t$device\n" ;
                print " - Port:\t$port\n" ;
                $port =~ s/[FastEthernet|GigaEthernet|Gi|Fa]//ig ;
                $result = undef ;
                $result = (&connectandrun( $device , "sh interface status | in $port "))[0] ;
                if ( defined $result )  { print "$result" ; }
                $result = undef ;
                $result = (&connectandrun( $device , "sh interface link | in $port "))[0] ;
                if ( defined $result )  { print "$result" ; }
                $result = undef ;
                $result = join("",&connectandrun( $device , "sh mac-address-table | in $port ")) ;
                if ( defined $result )  { print "$result" ; }
                print "\n**********\n" ;
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
#print " =>  $device : $command\n"  ;
my $session_obj = Net::Appliance::Session->new(
        Host => $device,
        Transport => 'SSH',
  ) ;
#$session_obj->input_log(*log);
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
