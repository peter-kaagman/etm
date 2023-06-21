package etm;
use Dancer2;
use Dancer2::Plugin::Auth::OAuth;
use Data::Dumper;
use LWP::UserAgent;
use JSON;

our $VERSION = '0.1';

get '/' => sub { # {{{1
  my $sessionData = session->read('oauth');
  print Dumper $$sessionData{'azuread'};
  print "\n\n". $$sessionData{azuread}{'user_info'}{'givenName'}. "\n\n";
  print "\n\n". $$sessionData{azuread}{'access_token'}. "\n\n";
  #my $joinedTeams = &getJoinedTeams($sessionData);
  #print Dumper $joinedTeams;
  my $session_data = session->read('oauth');
  my $teams = getJoinedTeams($$sessionData{azuread}{access_token});
  template 'index' => { 'title' => 'ETM',
	                'sessionData' => $sessionData, 
			'joinedTeams' => $teams,
			};
};# }}}

sub _doGetJoinedTeams { # {{{1
	my $token = shift;
	my $url = shift;
	my $teams = shift;
	my $result = _callAPI($token,$url, 'GET');
	if ($result->is_success){
		my $reply =  decode_json($result->decoded_content);
		while (my ($i, $el) = each @{$$reply{'value'}}) {
			push @{$teams}, $el;
		}
		if ($$reply{'@odata.nextLink'}){
			do_fetch($token,$$reply{'@odata.nextLink'}, $teams);
		}
		#print Dumper $$reply{'value'};
	}else{
	#	print Dumper $result;
		die $result->status_line;
	}
} #	}}}

sub getJoinedTeams {
  my $token = shift;
  my @teams;
  my $url = "http://graph.microsoft.com/v1.0/me/joinedTeams";
  _doGetJoinedTeams($token, $url, \@teams);
  print Dumper \@teams;
  return \@teams;
}

hook before => sub {
    my $session_data = session->read('oauth');
    my $provider = "azuread"; # Lower case of the authentication plugin used
 
    my $now = DateTime->now->epoch;
 
    if ((
	!defined $session_data || 
	!defined $session_data->{$provider} || 
	!defined $session_data->{$provider}{id_token}
	) && request->path !~ m{^/auth}) {
      return forward "/auth/$provider";
 
    } elsif ( 
	    defined $session_data->{$provider}{refresh_token} && 
	    defined $session_data->{$provider}{expires} && 
	    $session_data->{$provider}{expires} < $now && request->path !~ m{^/auth}
    ) {
      return forward "/auth/$provider/refresh";
    }
};
sub _callAPI { # {{{1
	my $token = shift;
	my $url = shift;
	my $verb = shift;
	my $ua = LWP::UserAgent->new(
		'send_te' => '0',
	);
	my $r  = HTTP::Request->new(
	$verb => $url,
		[
		'Accept'        => '*/*',
		'Authorization' => "Bearer ".$token,
		'User-Agent'    => 'curl/7.55.1',
		'Content-Type'  => 'application/json'
		],
	);	
	my $result = $ua->request($r);
	return $result;
} # }}}

true;
