#!/usr/bin/perl -Tw
#
# $Id: cust_main_county-expand.cgi,v 1.4 1999-01-18 09:41:25 ivan Exp $
#
# ivan@sisd.com 97-dec-16
#
# Changes to allow page to work at a relative position in server
#	bmccane@maxbaud.net	98-apr-3
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: cust_main_county-expand.cgi,v $
# Revision 1.4  1999-01-18 09:41:25  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.3  1998/12/17 06:17:01  ivan
# fix double // in relative URLs, s/CGI::Base/CGI/;
#
# Revision 1.2  1998/11/18 09:01:38  ivan
# i18n! i18n!
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(header menubar popurl);
use FS::cust_main_county;

my($cgi) = new CGI;

&cgisuidsetup($cgi);

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/
  or die "Illegal taxnum!";
my($taxnum)=$1;

my($cust_main_county)=qsearchs('cust_main_county',{'taxnum'=>$taxnum});
die "Can't expand entry!" if $cust_main_county->getfield('county');

my $p1 = popurl(1);
print $cgi->header( '-expires' => 'now' ), header("Tax Rate (expand)", menubar(
  'Main Menu' => popurl(2),
)), <<END;
    <FORM ACTION="${p1}process/cust_main_county-expand.cgi" METHOD=POST>
      <INPUT TYPE="hidden" NAME="taxnum" VALUE="$taxnum">
      Separate by
      <INPUT TYPE="radio" NAME="delim" VALUE="n" CHECKED>line
      (rumor has it broken on some browsers) or
      <INPUT TYPE="radio" NAME="delim" VALUE="s">whitespace.
      <BR><INPUT TYPE="submit" VALUE="Submit">
      <BR><TEXTAREA NAME="expansion" ROWS=100></TEXTAREA>
    </FORM>
    </CENTER>
  </BODY>
</HTML>
END

