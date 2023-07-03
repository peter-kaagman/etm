package etm;
use feature ":5.10";
use Dancer2;
use Dancer2::Plugin::Auth::OAuth;
use Data::Dumper;
use LWP::UserAgent;
use JSON;
use JSON::Create 'create_json';
our $VERSION = '0.1';

get '/' => sub { # {{{1
  if (validateLogin()){
    say "Valid login";
    my $sessionData = session->read('oauth');
    my $teams = session->read('teams');
    template 'index' => { 'title' => 'ETM',
  	                'sessionData' => $sessionData, 
  			'joinedTeams' => $teams,
  			};
  }else{
    say "inValid login";
    redirect '/about';
  }
};# }}}
get '/about' => sub { # {{{1
  my $sessionData = session->read('oauth');
  #my $teams = getJoinedTeams($$sessionData{azuread}{access_token});
  my $teams = session->read('teams');
  print "/n/nAbout/n/n";
  template 'about' => { 'title' => 'ETM About',
	                'sessionData' => $sessionData, 
			};
};# }}}
post '/api/sendmessage' => sub { # {{{1
  if (validateLogin()){
    my $data = from_json(request->body);

    # Bereid een JSON object voor met content
    my %content;
    $content{'body'}{'content'} = $$data{'message'};
    print create_json(\%content);
  }
}; #}}}
get '/api/reloadteams' => sub { # {{{1
  if (validateLogin()){
    session->delete('teams');
    loadTeams();
    my $teams_data = session->read('teams');
    send_as JSON => $teams_data;
  }
}; #}}}
sub getJoinedTeams { # {{{1
  my $token = shift;
  my @teams;
  my $url = "https://graph.microsoft.com/v1.0/me/joinedTeams";
  _doGetItems($token, $url, \@teams);
  #print Dumper \@teams;
  #return \@teams;
  my %teamsData;
  foreach my $team (@teams){
	$teamsData{teams}{$$team{id}}{displayName} = $$team{displayName};
	$teamsData{teams}{$$team{id}}{description} = $$team{description};

	# Team staat in de hash, mooi moment om aanvullende
	# gegevens over het team te zoeken
	my @channels;
	getTeamChannels($token, $$team{id},\@channels);
	foreach my $channel (@channels){
	  $teamsData{teams}{$$team{id}}{channels}{$$channel{id}}{displayName} = $$channel{displayName};
	  $teamsData{teams}{$$team{id}}{channels}{$$channel{id}}{description} = $$channel{description};
	}
  }
  session->write(%teamsData);
}# }}}
sub getTeamChannels { #{{{1
  my $token = shift;
  my $teamID = shift;
  my $channels = shift;
  say "Getting channels for ID $teamID";
  my $url = "https://graph.microsoft.com/v1.0/teams/$teamID/channels";
  _doGetItems($token, $url, $channels);
}#}}}
# _doGetItem: Recursive functions to get items from graph {{{1
sub _doGetItems {
	my $token = shift;
	my $url = shift;
	my $items = shift;
	my $result = _callAPI($token,$url, 'GET');
	if ($result->is_success){
		my $reply =  decode_json($result->decoded_content);
		while (my ($i, $el) = each @{$$reply{'value'}}) {
			push @{$items}, $el;
		}
		if ($$reply{'@odata.nextLink'}){
			_doGetItems($token,$$reply{'@odata.nextLink'}, $items);
		}
		#print Dumper $$reply{'value'};
	}else{
	#	print Dumper $result;
		die $result->status_line;
	}
} #}}}
sub loadTeams { #{{{1
    my $teams_data = session->read('teams');
    my $session_data = session->read('oauth');
    my $provider = 'azuread';
    # Laad teamsdata als er een oauth sessie is
    # en geen teams
    if ( 
         (!defined $teams_data) &&
	 (defined $session_data->{$provider}{id_token})
	){
  		getJoinedTeams($$session_data{azuread}{access_token});
     }
}#}}}
# sub validateLogin() {{{1
# Controleert:
# - of er een sessie
# - of de sessie ververst moet worden
# - of de ingelogde gebruiker de juiste rollen heeft
sub validateLogin { 
  say "validateLogin";
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

 
  say "Roles:";
  #say  $$session_data{azuread}{login_info}{roles}[0];
  if (!defined $session_data->{$provider}{login_info}{roles}){
    say "geen roles";
    return 0;
  }

  if (
       ( grep (/^etm$/, @{$session_data->{$provider}{login_info}{roles}}) ) &&
       ( grep (/^Medewerkers$/, @{$session_data->{$provider}{login_info}{roles}}) )
     ){
    say "role etm en Medewerkers";
    return 42;
  }else{
    say "geen role etm en Medewerkers";
    return 0;
  }
}#}}}
sub _callAPI { # {{{1
	my $token = shift;
	my $url = shift;
	my $verb = shift;
	my $content = shift || undef;
	my $ua = LWP::UserAgent->new(
		'send_te' => '0',
	);
	my $req = HTTP::Request->new();
	$req->method($verb);
	$req->uri($url);
	$req->header('Accept'        => '*/*',            );
	$req->header('Authorization' => "Bearer $token", );
	$req->header('User-Agent'    => 'curl/7.55.1',    );
	$req->header('Content-Type'  => 'application/json');
	if (defined $content){
	  $req->content($content)
	}
	my $result = $ua->request($req);
	#print Dumper $result;
	return $result;
} # }}}

42;
