use Test::More tests => 18 ; #18

my $fulltest  = 18 ;
my $shorttest = 2 ;

BEGIN {
  use_ok('Net::LDAP::Express') ;
  use_ok('Net::LDAP::Entry') ;
}

SKIP: {
  skip "doing local tests only",$fulltest-$shorttest
    unless $ENV{TEST_HOST} ;
  my $server = $ENV{TEST_HOST}   || 'localhost' ;
  my $port   = $ENV{TEST_PORT}   || 389 ;
  my $base   = $ENV{TEST_BASE}   || 'ou=simple,o=test' ;
  my $binddn = $ENV{TEST_BINDDN} || 'cn=admin,o=test' ;
  my $bindpw = $ENV{TEST_BINDPW} || 'secret' ;
  my @search = qw(uid mail cn objectclass) ;
  my $query  = 'marco' ;

  my @ent_data = qw(Marco Marongiu
		    Larry Wall
		    Tim Vroom) ;
  my %ent_common = (
		    objectclass => [qw(top person inetOrgPerson)],
		   ) ;
  my $ldap = Net::LDAP::Express->new(host => $server,
				    port => $port,
				    base => $base,
				    bindDN => $binddn,
				    bindpw => $bindpw,
				    searchattrs => \@search) ;

  isa_ok($ldap,'Net::LDAP::Express') ;

  # Add subtrees
  {
    my $r ;
    my $root = Net::LDAP::Entry->new ;
    $root->dn("o=test") ;
    $root->add(
	       objectclass => [qw(top organization)],
	       o => 'test',
	      ) ;
    $r = $ldap->add_many($root) ;
    ok(@$r == 1 or $ldap->errcode == 68) ; # Ok if already exists

    my $subtree = Net::LDAP::Entry->new ;
    $subtree->dn("ou=simple,o=test") ;
    $subtree->add(
		  objectclass => [qw(top organizationalUnit)],
		  ou => 'simple',
		 ) ;
    $r = $ldap->add_many($subtree) ;
    ok(@$r == 1 or $ldap->errcode == 68) ; # Ok if already exists
  }

  # add_many
  {
    my @e ;
    while (my ($givenname,$sn) = splice @ent_data,0,2) {
      my $e = Net::LDAP::Entry->new ;
      my $cn = "$givenname $sn" ;
      my $uid = lc $givenname ;
      my $mail = "$uid@"."simple.ldap.net" ;

      $e->dn("cn=$cn,$base") ;
      my %attrs = (
		   givenName => $givenname,
		   sn        => $sn,
		   cn        => $cn,
		   mail      => $mail,
		   uid       => $uid,
		   %ent_common,
		  ) ;
      $e->add(%attrs) ;
      push @e,$e ;
    }

    my $r = $ldap->add_many(@e) ;
    cmp_ok(@$r,'==',@e,'add') ;
    is($ldap->error,undef,'error code for add') ;
  }


  {
    # Search
    my $entries = $ldap->simplesearch('person') ;
    ok(defined($entries),"search") ;
    is($ldap->error,undef,'error code for search') ;

    # Modify and update
    foreach my $e (@$entries) {
      $e->delete('mail') ;
    }

    my $r = $ldap->update(@$entries) ;
    cmp_ok(@$r,'==',@$entries,'update') ;
    is($ldap->error,undef,'error code for update') ;
  }

  {
    my ($r,$e) ;

    # Search again, and rename
    my $entries = $ldap->simplesearch('person') ;
    ok(defined($entries),"search") ;
    is($ldap->error,undef,'error code for search') ;
    cmp_ok(@$entries,'>=',3) ;

    # Rename the first entry
    $e = shift @$entries ;
    $r = $ldap->rename($e,'cn=Graham Barr') ;
    is($ldap->error,undef,'rename') ;
  }

  # Search again, and delete_many
  my $entries = $ldap->simplesearch('person') ;
  ok(defined($entries),"search") ;

  my $r = $ldap->delete_many(@$entries) ;
  cmp_ok(@$r,'==',@$entries,'delete') ;
  is($ldap->error,undef,'error code for delete') ;

}
