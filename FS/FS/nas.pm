package FS::nas;

use strict;
use vars qw( @ISA );
use FS::Record qw(qsearchs); #qsearch);
use FS::UID qw( dbh ); #to lock the tables for heartbeat; ugh, MySQL-specific

@ISA = qw(FS::Record);

=head1 NAME

FS::nas - Object methods for nas records

=head1 SYNOPSIS

  use FS::nas;

  $record = new FS::nas \%hash;
  $record = new FS::nas {
    'nasnum'  => 1,
    'nasip'   => '10.4.20.23',
    'nasfqdn' => 'box1.brc.nv.us.example.net',
  };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->heartbeat($timestamp);

=head1 DESCRIPTION

An FS::nas object represents an Network Access Server on your network, such as
a terminal server or equivalent.  FS::nas inherits from FS::Record.  The
following fields are currently supported:

=over 4

=item nasnum - primary key

=item nas - NAS name

=item nasip - NAS ip address

=item nasfqdn - NAS fully-qualified domain name

=item last - timestamp indicating the last instant the NAS was in a known
             state (used by the session monitoring).

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new NAS.  To add the NAS to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'nas'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  $self->ut_numbern('nasnum')
    || $self->ut_text('nas')
    || $self->ut_ip('nasip')
    || $self->ut_domain('nasfqdn')
    || $self->ut_numbern('last');
}

=item heartbeat TIMESTAMP

Updates the timestamp for this nas

=cut

sub heartbeat {
  my($self, $timestamp) = @_;
  my $dbh = dbh;
  my $sth = $dbh->prepare("LOCK TABLES nas WRITE");
  $sth->execute or die $sth->errstr; #die?
  my $lock_self = qsearchs('nas', { 'nasnum' => $self->nasnum } )
    or die "can't find own record for $self nasnum ". $self->nasnum;
  if ( $timestamp > $lock_self->last ) {
    my $new_self = new FS::nas ( { $lock_self->hash } );
    $new_self->last($timestamp);
    #is there a reason to? #$self->last($timestamp);
    $new_self->replace($lock_self);
  };
  $sth = $dbh->prepare("UNLOCK TABLES");
  $sth->execute or die $sth->errstr; #die?
}

=back

=head1 VERSION

$Id: nas.pm,v 1.4 2001-02-21 01:45:37 ivan Exp $

=head1 BUGS

The B<heartbeat> method is MySQL-specific.  Yuck.  It's also not quite
perfectly subclassable, which is much less yuck.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

