package FS::part_export::sqlmail;

use vars qw(@ISA);
use FS::Record qw(qsearchs);
use FS::part_export;
use Digest::MD5 qw(md5_hex);

@ISA = qw(FS::part_export);

sub rebless { shift; }

sub _export_insert {
  my($self, $svc) = (shift, shift);
  # this is a svc_something.

  my $svcdb = $svc->cust_svc->part_svc->svcdb;
  my $export_table = $self->option($svcdb . '_table')
    or die('Export table not defined for svcdb: ' . $svcdb);
  my @export_fields = split(/\s+/, $self->option($svcdb . '_fields'));
  my $svchash = update_values($self, $svc, $svcdb);

  foreach my $key (keys(%$svchash)) {
    unless (grep { $key eq $_ } @export_fields) {
      delete $svchash->{$key};
    }
  }

  my $error = $self->sqlmail_queue( $svc->svcnum, 'insert',
    $self->option('server_type'), $export_table,
    (map { ($_, $svchash->{$_}); } keys(%$svchash)));
  return $error if $error;
  '';

}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  my $svcdb = $new->cust_svc->part_svc->svcdb;
  my $export_table = $self->option($svcdb . '_table')
    or die('Export table not defined for svcdb: ' . $svcdb);
  my @export_fields = split(/\s+/, $self->option($svcdb . '_fields'));
  my $svchash = update_values($self, $new, $svcdb);

  foreach my $key (keys(%$svchash)) {
    unless (grep { $key eq $_ } @export_fields) {
      delete $svchash->{$key};
    }
  }

  my $error = $self->sqlmail_queue( $new->svcnum, 'replace',
    $old->svcnum, $self->option('server_type'), $export_table,
    (map { ($_, $svchash->{$_}); } keys(%$svchash)));
  return $error if $error;
  '';

}

sub _export_delete {
  my( $self, $svc ) = (shift, shift);

  my $svcdb = $svc->cust_svc->part_svc->svcdb;
  my $table = $self->option($svcdb . '_table')
    or die('Export table not defined for svcdb: ' . $svcdb);

  $self->sqlmail_queue( $svc->svcnum, 'delete', $table,
    $svc->svcnum );
}

sub sqlmail_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::sqlmail::sqlmail_$method",
  };
  $queue->insert(
    $self->option('datasrc'),
    $self->option('username'),
    $self->option('password'),
    @_,
  );
}

sub sqlmail_insert { #subroutine, not method
  my $dbh = sqlmail_connect(shift, shift, shift);
  my( $server_type, $table ) = (shift, shift);

  my %attrs = @_;

  map { $attrs{$_} = $attrs{$_} ? qq!'$attrs{$_}'! : 'NULL'; } keys(%attrs);
  my $query = sprintf("INSERT INTO %s (%s) values (%s)",
                      $table, join(",", keys(%attrs)),
                      join(',', values(%attrs)));

  $dbh->do($query) or die $dbh->errstr;
  $dbh->disconnect;

  '';
}

sub sqlmail_delete { #subroutine, not method
  my $dbh = sqlmail_connect(shift, shift, shift);
  my( $table, $svcnum ) = @_;

  $dbh->do("DELETE FROM $table WHERE svcnum = $svcnum") or die $dbh->errstr;
  $dbh->disconnect;

  '';
}

sub sqlmail_replace {
  my $dbh = sqlmail_connect(shift, shift, shift);
  my($oldsvcnum, $server_type, $table) = (shift, shift, shift);

  my %attrs = @_;
  map { $attrs{$_} = $attrs{$_} ? qq!'$attrs{$_}'! : 'NULL'; } keys(%attrs);

  my $query = sprintf('UPDATE %s SET %s WHERE svcnum = %s',
                      $table, join(', ', map {"$_ = $attrs{$_}"} keys(%attrs)),
                      $oldsvcnum);

  my $rv = $dbh->do($query) or die $dbh->errstr;

  if ($rv == 0) {
    $query = sprintf("INSERT INTO %s (%s) values (%s)",
                     $table, join(",", keys(%attrs)),
                     join(',', values(%attrs)));
    $dbh->do($query) or die $dbh->errstr;
  }

  $dbh->disconnect;

  '';
}

sub sqlmail_connect {
  DBI->connect(@_) or die $DBI::errstr;
}

sub update_values {

  # Update records to conform to a particular server_type.

  my ($self, $svc, $svcdb) = (shift,shift,shift);
  my $svchash = { %{$svc->hashref} } or return ''; # We need a copy.

  if ($svcdb eq 'svc_acct') {
    if ($self->option('server_type') eq 'courier_crypt') {
      my $salt = join '', ('.', '/', 0..9,'A'..'Z', 'a'..'z')[rand 64, rand 64];
      $svchash->{_password} = crypt($svchash->{_password}, $salt);

    } elsif ($self->option('server_type') eq 'dovecot_plain') {
      $svchash->{_password} = '{PLAIN}' . $svchash->{_password};
      
    } elsif ($self->option('server_type') eq 'dovecot_crypt') {
      my $salt = join '', ('.', '/', 0..9,'A'..'Z', 'a'..'z')[rand 64, rand 64];
      $svchash->{_password} = '{CRYPT}' . crypt($svchash->{_password}, $salt);

    } elsif ($self->option('server_type') eq 'dovecot_digest_md5') {
      my $svc_domain = qsearchs('svc_domain', { svcnum => $svc->domsvc });
      die('Unable to lookup svc_domain with domsvc: ' . $svc->domsvc)
        unless ($svc_domain);

      my $domain = $svc_domain->domain;
      my $md5hash = '{DIGEST-MD5}' . md5_hex(join(':', $svchash->{username},
                                             $domain, $svchash->{_password}));
      $svchash->{_password} = $md5hash;
    }
  } elsif ($svcdb eq 'svc_forward') {
    if ($self->option('resolve_dstsvc') && $svc->dstsvc_acct) {
      $svchash->{dst} = $svc->dstsvc_acct->username . '@' .
                        $svc->dstsvc_acct->svc_domain->domain;
    }
  }

  return($svchash);

}

