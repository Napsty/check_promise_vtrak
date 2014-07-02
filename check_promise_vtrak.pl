#!/usr/bin/perl -w
#########################################################################
# Script:       check_promise_vtrak.pl
# Author:       Claudio Kuenzler
# Based on:     check_promise_chassis.pl by Barry O'Donovan 
# License:      MIT
# Copyright:    2007 Barry O'Donovan (bod) - http://www.barryodonovan.com/
# Copyright:    2007 Open Source Solutions Ltd - http://www.opensolutions.ie/
# Copyright:    2014 Claudio Kuenzler (ck) - http://www.claudiokuenzler.com/
# Usage:        ./check_promise_vtrak.pl -H <host> [-C <community>] -m <model> -t <type>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of 
# this software and associated documentation files (the "Software"), to deal in 
# the Software without restriction, including without limitation the rights to 
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies 
# of the Software, and to permit persons to whom the Software is furnished to do 
# so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all 
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A 
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION 
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# History:
# 2007XXXX Created check_promise_chassis.pl (bod)
# 20140626 Fork/rewrite for multiple Vtrack models (ck)
# 20140627 Added enclosure check type (ck)
# 20140701 Extended disk check with different subchecks (ck)
# 20140701 Added ps check type (ck)
# 20140701 Added fan check type (ck)
# 20140702 Added ctrl check type (ck)
#########################################################################
my $version = '20140702';
#########################################################################
use strict;
use Getopt::Long;
use Net::SNMP;
use Switch;
#########################################################################
# Variable Declaration
my $hostname = '';
my $port = '';
my $community = '';
my $model = '';
my $type = '';
my $warning = '';
my $critical = '';
my $help = '';
my $status;
my $TIMEOUT = 10;
my %ERRORS = ('UNKNOWN' , '-1',
              'OK' , '0',
              'WARNING', '1',
              'CRITICAL', '2');
my $state = "OK";
my $answer = "";
my $snmpkey;
my $key;
my $oid_base = '';
my $session = '';
my $error = '';
my $oid_model = '';
my $oid_vendorname = '';
my $oid_serialnumber = '';
my $oid_firmware = '';
my $oid_ctrl_present = '';
my $oid_ctrl_opstatus = '';
my $oid_ctrl_readiness = '';
my $oid_encl_id = '';
my $oid_encl_count = '';
my $oid_encl_type = '';
my $oid_encl_opstatus = '';
my $oid_ps_opstatus = '';
my $oid_disk_type = '';
my $oid_disk_model = '';
my $oid_disk_serial = '';
my $oid_disk_firmware = '';
my $oid_disk_opstatus = '';
my $oid_disk_present = '';
my $oid_disk_online = '';
my $oid_disk_offline = '';
my $oid_disk_pfa = '';
my $oid_disk_rebuilding = '';
my $oid_disk_missing = '';
my $oid_disk_unconfigured = '';
my $oid_disk_sparenumber = '';
my $oid_fan_opstatus = '';
my $oid_temp_current = '';
my $oid_temp_opstatus = '';
my $oid_bat_remcapacity = '';
my $oid_bat_opstatus = '';
#########################################################################
# User Input
if ( @ARGV > 0 ) {
  GetOptions(
  'H=s' => \$hostname,
  'p=s' => \$port,
  'C:s' => \$community,
  'm=s' => \$model,
  't=s' => \$type,
  'help' => \$help,
  );
}
#########################################################################
# Check if user asks for help
if ( $help ne '' ) {
  help(); exit 0;
}

# Check if model was set
if ( $model eq '' ) {
  print "CRITICAL: No model defined. Use -m parameter. See help for more info.\n";
  exit 2;
}

# Set community to default public if not set by user
if ( $community eq '' ) {
  $community = "public";
}

# Set port to default 161 if not set by user
if ( $port eq '' ) {
  $port = "161";
}
#########################################################################
# Subs
sub help {
print "check_promise_vtrak.pl (c) 2014 Claudio Kuenzler based on check_promise_chassis.pl by Barry O'Donovan
Version: $version\n
Usage: ./check_promise_vtrak.pl -H host [-p port] [-C community] -m model -t checktype\n
Options:
-H\tHostname or IP address of the Promise Vtrak Head
-C\tSNMP community name (if not set, public will be used).
-m\tModel of the Vtrak. Currently supported: E310x, E610x, M610x
-t\tType to check. See below for valid types.
-w\tWarning threshold (not working on all checks)
-c\tCritical threshold (not working on all checks)
--help\tShow this help/usage.\n
Check Types:
ctrl\t\t -> Checks the status of all controllers
disk\t\t -> Checks the status of all physical disks
enclosure\t -> Check status of all enclosures
fan\t\t -> Check status of all fans (blowers)
info\t\t -> Show basic information of the Vtrak
ps\t\t -> Check status of all power supplies\n";
}
#########################################################################
# OID Definition
if ( $model =~ m/(E310|E610|M610)/) {
  $oid_base = '.1.3.6.1.4.1.7933.1.20';
  $oid_model = "$oid_base.1.2.1.4.1";
  $oid_vendorname = "$oid_base.1.2.1.3.1";
  $oid_serialnumber = "$oid_base.1.2.1.5.1";
  $oid_firmware = "$oid_base.1.3.1.13.1.1";
  $oid_ctrl_present = "$oid_base.1.1.1.7.1";
  $oid_ctrl_opstatus = "$oid_base.1.3.1.15.1";
  $oid_ctrl_readiness = "$oid_base.1.3.1.17.1";
  $oid_encl_id = "$oid_base.1.10.1.1.1";
  $oid_encl_type = "$oid_base.1.10.1.2.1";
  $oid_encl_count = "$oid_base.1.1.1.9.1";
  $oid_encl_opstatus = "$oid_base.1.10.1.3.1";
  $oid_ps_opstatus = "$oid_base.1.12.1.2.1.1";
  $oid_disk_type = "$oid_base.2.1.1.2.1";
  $oid_disk_model = "$oid_base.2.1.1.4.1";
  $oid_disk_serial = "$oid_base.2.1.1.5.1";
  $oid_disk_firmware = "$oid_base.2.1.1.6.1";
  $oid_disk_opstatus = "$oid_base.2.1.1.8.1";
  $oid_disk_present = "$oid_base.1.3.1.19.1.1";
  $oid_disk_online = "$oid_base.1.3.1.20.1.1";
  $oid_disk_offline = "$oid_base.1.3.1.21.1.1";
  $oid_disk_pfa = "$oid_base.1.3.1.22.1.1";
  $oid_disk_rebuilding = "$oid_base.1.3.1.23.1.1";
  $oid_disk_missing = "$oid_base.1.3.1.24.1.1";
  $oid_disk_unconfigured = "$oid_base.1.3.1.25.1.1";
  $oid_disk_sparenumber = "$oid_base.2.4.1.14";
  $oid_fan_opstatus = "$oid_base.1.11.1.3.1.1";
  $oid_temp_current = "$oid_base.1.13.1.2.1.1";
  $oid_temp_opstatus = "$oid_base.1.13.1.3.1.1";
  $oid_bat_remcapacity = "$oid_base.1.15.1.11";
  $oid_bat_opstatus = "$oid_base.1.15.1.14";
}
elsif ( $model =~ m/(M200)/) {
  $oid_base = '.1.3.6.1.4.1.7933.1.10';
#  $oid_model = "$oid_base.1.2.1.4.1";
#  $oid_vendorname = "$oid_base.1.2.1.3.1";
#  $oid_serialnumber = "$oid_base.1.2.1.5.1";
#  $oid_firmware = "$oid_base.1.3.1.13.1.1";
#  $oid_ctrl_opstatus = "$oid_base.1.3.1.15.1";
#  $oid_ctrl_activestatus = "$oid_base.1.3.1.17.1";
#  $oid_encl_id = "$oid_base.1.10.1.1.1";
#  $oid_encl_type = "$oid_base.1.10.1.2.1";
#  $oid_encl_count = "$oid_base.1.1.1.9.1";
#  $oid_encl_opstatus = "$oid_base.1.10.1.3.1";
  $oid_ps_opstatus = ".1.3.6.1.4.1.7933.2.1.4.1.1.2.1";
  $oid_disk_type = "$oid_base.2.1.1.2.1";
  $oid_disk_model = "$oid_base.2.1.1.4.1";
  $oid_disk_serial = "$oid_base.2.1.1.5.1";
  $oid_disk_firmware = "$oid_base.2.1.1.6.1";
  $oid_disk_opstatus = "$oid_base.2.1.1.8.1";
#  $oid_disk_present = "$oid_base.1.3.1.19";
#  $oid_disk_online = "$oid_base.1.3.1.20";
  $oid_disk_offline = "$oid_base.1.2.1.1.22.1";
  $oid_disk_pfa = "$oid_base.1.2.1.1.23.1";
  $oid_disk_rebuilding = "$oid_base.1.2.1.1.24.1";
  $oid_disk_missing = "$oid_base.1.2.1.1.25.1";
#  $oid_disk_unconfigured = "$oid_base.1.3.1.25";
#  $oid_disk_sparenumber = "$oid_base.2.4.1.14";
  $oid_fan_opstatus = ".1.3.6.1.4.1.7933.2.1.3.1.1.3.1";
  $oid_temp_current = ".1.3.6.1.4.1.7933.2.1.5.1.1.2.1";
  $oid_temp_opstatus = ".1.3.6.1.4.1.7933.2.1.5.1.1.3.1";
  $oid_bat_remcapacity = ".1.3.6.1.4.1.7933.2.1.7.1.1.11.1";
  $oid_bat_opstatus = "1.3.6.1.4.1.7933.2.1.7.1.1.14.1";
}
else {
  print "Unknown model $model given. Please refer to help for valid models.\n";
  exit 3;
}

my $oid_hostname = ".1.3.6.1.2.1.1.5.0";
my $oid_uptime = ".1.3.6.1.2.1.1.3.0";
#########################################################################
# SNMP Connection

# Just in case of problems, let's not hang Nagios
$SIG{'ALRM'} = sub {
     print ("ERROR: No snmp response from $hostname\n");
     exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);

($session,$error) = Net::SNMP->session(
                  -hostname  => $hostname,
                  -community => $community,
                  -port      => $port,
                  -version   => 2,
                  );

if( !defined( $session ) ) 
{
    $state='UNKNOWN';
    $answer=$error;
    print ("$state: $answer");
    exit $ERRORS{$state};
}
#########################################################################
# Plugin Checks
switch ($type) {
# --------- info --------- #
case "info" {
  my @oidlist = ($oid_model, $oid_vendorname, $oid_serialnumber, $oid_firmware, $oid_uptime);
  my $result = $session->get_request(-varbindlist => \@oidlist);

  if (!defined($result)) {
    printf("ERROR: Description table : %s.\n", $session->error);
  if ($session->error =~ m/noSuchName/ || $session->error =~ m/does not exist/) {
    print "Are you really sure the target host is a $model???!\n";
  }
  $session->close;
  exit 2;
  }

  my $vendorname = $$result{$oid_vendorname};
  my $model = $$result{$oid_model};
  my $serialnumber = $$result{$oid_serialnumber};
  my $firmware = $$result{$oid_firmware};
  my $uptime = $$result{$oid_uptime};

  print "$vendorname $model - S/N: $serialnumber - Firmware: $firmware - Uptime: $uptime\n";
  exit 0;
}
# --------- disk --------- #
case "disk" {
  my $result = $session->get_table(-baseoid => $oid_disk_opstatus);
  my @oidlist = ($oid_disk_present, $oid_disk_online, $oid_disk_offline, $oid_disk_pfa, $oid_disk_rebuilding, $oid_disk_missing, $oid_disk_unconfigured);
  my $result2 = $session->get_request(-varbindlist => \@oidlist);

  if (!defined($result) || !defined($result2)) {
    printf("ERROR: Description table : %s.\n", $session->error);
    if ($session->error =~ m/noSuchName/ || $session->error =~ m/does not exist/) {
      print "Are you really sure the target host is a $model???!\n";
    }
    $session->close;
    exit 2;
  }

  my %value = %{$result};
  my $key;
  my $diskcount = keys %{$result};
  my $oidend = '';
  my $diskproblem = 0;
  my $diskwarn = 0;
  my $diskmessage = '';

  my $disk_present = $$result2{$oid_disk_present};
  my $disk_online = $$result2{$oid_disk_online};
  my $disk_offline = $$result2{$oid_disk_offline};
  my $disk_pfa = $$result2{$oid_disk_pfa};
  my $disk_rebuilding = $$result2{$oid_disk_rebuilding};
  my $disk_missing = $$result2{$oid_disk_missing};
  my $disk_unconfigured = $$result2{$oid_disk_unconfigured};

  # print "Diskcount: $diskcount\n";  # debug

  foreach $key (keys %{$result}) {
    #print "$key\n"; # debug
    #print "$value{$key}\n"; # debug
    my $oidend = (split(/\./, $key))[-1];
    #print "OIDEND: $oidend\n"; # debug

    if( !( $value{$key} =~ "OK" ) ) {
      # get the enclosure number of this drive
      #print "Need to query $oid_base.2.1.1.14.1.$oidend\n"; # debug
      my @oidlist2 = ("$oid_base.2.1.1.14.1.$oidend");
      my $response = $session->get_request(-varbindlist => \@oidlist2);
      my $enclosure = $$response{"$oid_base.2.1.1.14.1.$oidend"};
      #print "This drive is in Enclosure: $enclosure\n"; # debug

      # get the slot number of this drive
      #print "Need to query $oid_base.2.1.1.15.$enclosure.$oidend\n"; # debug
      my @oidlist3 = ("$oid_base.2.1.1.15.$enclosure.$oidend");
      my $response3 = $session->get_request(-varbindlist => \@oidlist3);
      my $slot = $$response3{"$oid_base.2.1.1.15.$enclosure.$oidend"};
      #print "This drive is slot $slot in Enclosure $enclosure\n"; # debug
      $diskmessage .= "Drive $slot in enclosure $enclosure ";
      $diskproblem++;
    }

  }

  # Check for offline disks
  if ( $disk_offline > 0 ) {
    $diskmessage .= "$disk_offline disk(s) offline ";
    $diskproblem++;
  }
  # Check for missing disks
  elsif ( $disk_missing > 0 ) {
    $diskmessage .= "$disk_missing disk(s) missing ";
    $diskproblem++;
  }

  # Check for disks with pre-failures
  if ( $disk_pfa > 0 ) {
    $diskmessage .= "$disk_pfa disk(s) with pre-failure ";
    $diskwarn++;
  }
  # Check for disks currently rebuilding
  elsif ( $disk_rebuilding > 0 ) {
    $diskmessage .= "$disk_rebuilding disk(s) rebuilding ";
    $diskwarn++;
  }
  # Check for disks currently unconfigured
  elsif ( $disk_unconfigured > 0 ) {
    $diskmessage .= "$disk_unconfigured disk(s) unconfigured ";
    $diskwarn++;
  }

  if ( $diskproblem > 0 ) {
    print "DISK CRITICAL - $diskproblem DISKS NOT OK ( $diskmessage)\n";
    exit 2
  }
  elsif ( $diskwarn > 0 ) {
    print "DISK WARNING - $diskwarn DISK WARNINGS ( $diskmessage)\n";
    exit 1
  }
  else {
    print "DISK OK - $diskcount DISKS ($disk_online online)\n";
    exit 0
  }


}
# --------- diskonline --------- #
# This is a very special case. I had a case where a physical disk was not detected by 
# the enclosure (Slot X: Empty) but the physical disk was in the slot.
# This check compares the number of present disks versus the number of online disks.
case "diskonline" {
  my $result = $session->get_table(-baseoid => $oid_disk_present);
  my $result2 = $session->get_table(-baseoid => $oid_disk_online);

  if (!defined($result) || !defined($result2)) {
    printf("ERROR: Description table : %s.\n", $session->error);
  if ($session->error =~ m/noSuchName/ || $session->error =~ m/does not exist/) {
    print "Are you really sure the target host is a $model???!\n";
  }
  $session->close;
  exit 2;
  }

  my %value = %{$result};
  my %value2 = %{$result2};
  my $key;
  my $present = 0;
  my $online = 0;

  foreach $key (keys %{$result}) {
    #print "$key\n"; # debug
    #print "$value{$key}\n"; # debug
    $present = $present + $value{$key};
  }

  foreach $key (keys %{$result2}) {
    #print "$key\n"; # debug
    #print "$value2{$key}\n"; # debug
    $online = $online + $value2{$key};
  }

  if ( $present != $online ) {
    print "DISKONLINE WARNING: $present disks are present but only $online are online. Please check.\n";
    exit 1;
  }
  else {
    print "DISKONLINE OK - Disks present: $present - Disks online: $online\n";
    exit 0;
  }


}
# --------- enclosure --------- #
# Checks the health status of all enclosures connected to this head
case "enclosure" {
  my $result = $session->get_table(-baseoid => $oid_encl_opstatus);
  my @oidlist = ($oid_encl_count);
  my $result2 = $session->get_request(-varbindlist => \@oidlist);

  if (!defined($result) || !defined($result2)) {
    printf("ERROR: Description table : %s.\n", $session->error);
  if ($session->error =~ m/noSuchName/ || $session->error =~ m/does not exist/) {
    print "Are you really sure the target host is a $model???!\n";
  }
  $session->close;
  exit 2;
 }

  my %value = %{$result};
  my $key;
  my $enclcount = $$result2{$oid_encl_count};
  my $problemcount = 0;
  my $problemmessage = '';


  foreach $key (keys %{$result}) {
    #print "Key: $key\n"; # debug
    #print "Value: $value{$key}\n"; # debug
    my $oidend = (split(/\./, $key))[-1];
    #print "OIDEND: $oidend\n"; # debug
    if( !( $value{$key} =~ "OK" ) ) {
      # get the id of the non ok enclosure
      my @oidlist = ("$oid_encl_id.$oidend");
      my $response = $session->get_request(-varbindlist => \@oidlist);
      my $enclid = $$response{"$oid_encl_id.$oidend"};
      #print "This Enclosure has the ID: $enclid\n"; # debug
      # get the type of the non ok enclosure
      @oidlist = ("$oid_encl_type.$oidend");
      $response = $session->get_request(-varbindlist => \@oidlist);
      my $encltype = $$response{"$oid_encl_type.$oidend"};
      #print "Enclosure Description: $encltype\n"; # debug
      $problemmessage .= "Enclosure $enclid ($encltype) ";
      $problemcount++;
    }
  }

  if ( $problemcount > 0 ) {
    print "ENCLOSURE CRITICAL - $problemcount enclosure(s) not ok ($problemmessage)\n";
    exit 2
  }
  else {
    print "ENCLOSURE OK - $enclcount enclosure(s) attached\n";
    exit 0
  }

}
# --------- ps --------- #
# Checks the health status of all power supplies
case "ps" {
  my $result = $session->get_table(-baseoid => $oid_ps_opstatus);

  if (!defined($result)) {
    printf("ERROR: Description table : %s.\n", $session->error);
  if ($session->error =~ m/noSuchName/ || $session->error =~ m/does not exist/) {
    print "Are you really sure the target host is a $model???!\n";
  }
  $session->close;
  exit 2;
 }

  my %value = %{$result};
  my $key;
  my $pscount = keys %{$result};
  my $problemcount = 0;


  foreach $key (keys %{$result}) {
    #print "Key: $key\n"; # debug
    #print "Value: $value{$key}\n"; # debug
    if( ( "$value{$key}" ne "Powered On and Functional" ) ) {
      $problemcount++;
    }
  }

  if ( $problemcount > 0 ) {
    print "POWER SUPPLY CRITICAL - $problemcount power supply not ok\n";
    exit 2
  }
  else {
    print "POWER SUPPLY OK - $pscount power supplies attached\n";
    exit 0
  }

}
# --------- fan --------- #
# Checks the health status of all fans (blowers)
case "fan" {
  my $result = $session->get_table(-baseoid => $oid_fan_opstatus);

  if (!defined($result)) {
    printf("ERROR: Description table : %s.\n", $session->error);
  if ($session->error =~ m/noSuchName/ || $session->error =~ m/does not exist/) {
    print "Are you really sure the target host is a $model???!\n";
  }
  $session->close;
  exit 2;
 }

  my %value = %{$result};
  my $key;
  my $fancount = keys %{$result};
  my $problemcount = 0;


  foreach $key (keys %{$result}) {
    #print "Key: $key\n"; # debug
    #print "Value: $value{$key}\n"; # debug
    if( ( "$value{$key}" ne "Functional" ) ) {
      $problemcount++;
    }
  }

  if ( $problemcount > 0 ) {
    print "FANS CRITICAL - $problemcount fan(s) not ok\n";
    exit 2
  }
  else {
    print "FANS OK - $fancount fans attached and functional\n";
    exit 0
  }

}
# --------- ctrl --------- #
# Checks the health status of all controllers
case "ctrl" {
  my $result = $session->get_table(-baseoid => $oid_ctrl_opstatus);
  my @oidlist = ($oid_ctrl_present);
  my $result2 = $session->get_request(-varbindlist => \@oidlist);

  if (!defined($result) || !defined($result2)) {
    printf("ERROR: Description table : %s.\n", $session->error);
  if ($session->error =~ m/noSuchName/ || $session->error =~ m/does not exist/) {
    print "Are you really sure the target host is a $model???!\n";
  }
  $session->close;
  exit 2;
 }

  my %value = %{$result};
  my $key;
  my $ctrlcount = $$result2{$oid_ctrl_present};
  my $problemcount = 0;
  my $problemmsg = '';

  foreach $key (keys %{$result}) {
    #print "Key: $key\n"; # debug
    #print "Value: $value{$key}\n"; # debug
    my $oidend = (split(/\./, $key))[-1];
    if ( "$value{$key}" eq "Not Present" ) {
      # do nothing
    }
    elsif( ( "$value{$key}" ne "OK" ) ) {
      $problemcount++;
      $problemmsg .= "controller not ok ";
    }
    # get the readiness state of the controller
    my @oidlist = ("$oid_ctrl_readiness.$oidend");
    my $response = $session->get_request(-varbindlist => \@oidlist);
    my $readiness = $$response{"$oid_ctrl_readiness.$oidend"};
    #print "Readiness: $readiness\n"; # debug
    if ( "$readiness" ne "Active" &&  "$value{$key}" ne "Not Present" ) {
      $problemcount++;
      $problemmsg .= "controller not active ";
    }
  }

  if ( $problemcount > 0 ) {
    print "CONTROLLER CRITICAL - $problemcount $problemmsg\n";
    exit 2
  }
  else {
    print "CONTROLLER OK - $ctrlcount controller(s) active\n";
    exit 0
  }

}
# --------- no type --------- #
else {
  print "Error: No type given. What do you want to check?\n";
  exit 2;
}

} # end switch
#########################################################################
# Close SNMP Session
$session->close();

print "UNKNOWN - The script should have exited before this point\n";
exit 3
