package etm;
use feature ":5.10";
use Dancer2;
use Dancer2::Plugin::Auth::OAuth;
use Data::Dumper;
use LWP::UserAgent;
use JSON;
use JSON::Create 'create_json';
use URI::Encode qw(uri_encode);
our $VERSION = '0.1';

get '/' => sub { # {{{1
  if (validLogin()){
    say "Valid login";
    my $sessionData = session->read('oauth');
    my $teams = session->read('teams');
    template 'index' => { 'title' => 'ETM',
  	                'sessionData' => $sessionData, 
  			'joinedTeams' => $teams,
  			};
  }else{
    say "inValid login /";
    redirect '/about';
  }
};# }}}
get '/about' => sub { # {{{1
  my $sessionData = session->read('oauth');
  my $teams = session->read('teams');
  template 'about' => { 'title' => 'ETM About',
	                'sessionData' => $sessionData, 
			};
};# }}}
get '/teamdetail/:team_id' => sub { # {{{1
  if (validLogin()){
    my $team_id = route_parameters->get('team_id');
    template 'teamdetail' => {
      'title' => 'ETM Team Detail',
      'team_id' => $team_id
    }
  }else{
    say "inValid login /teamdetail";
    redirect '/about';
  }
};# }}}
post '/api/sendmessage' => sub { # {{{1
  my %reply;
  if (validLogin()){
    say "Send message";
    my $body = decode_json request->body;
    my $teamId = $body->{id};
    my $generalId = uri_encode($body->{generalid}, {encode_reserved => 1});
    say $generalId;
    my $url= "https://graph.microsoft.com/v1.0/teams/$teamId/channels/$generalId/messages";
    say $url;
    # Bereid een JSON object voor met content
    my $content= createCard($body->{message},$teamId);
    my $result = _callAPI($url,'POST',$content);
    if ($result->is_success){
      say "Success";
      print Dumper $result;
      $reply{rc} = $result->{_rc};
    }else{
      say "Faillure";
      print Dumper $result;
      $reply{rc} = $result->{_rc};
      $reply{msg} = $result->{_msg};
      $reply{status_line} = $result->status_line;
      #die $result->status_line;
    }
  }else{
    $reply{rc} = '401';
    $reply{msg} = 'unauthorized';
    $reply{status_line} = 'Not the correct authorization.';
  }
  send_as JSON => \%reply;
}; #}}}
get '/api/reloadteams' => sub { # {{{1
  if (validLogin()){
    session->delete('teams');
    loadTeams();
    my $teams_data = session->read('teams');
    send_as JSON => $teams_data;
  }
}; #}}}
sub getJoinedTeams { # {{{1
  my @teams;
  #my $url = 'https://graph.microsoft.com/v1.0/me/joinedTeamsi?$select=id,displayName,description';
  my $url = 'https://graph.microsoft.com/v1.0/me/joinedTeams?$select=id,displayName,description';
  _doGetItems($url, \@teams);
  #print Dumper \@teams;
  #return \@teams;
  my %teamsData;
  foreach my $team (@teams){
	$teamsData{teams}{$$team{id}}{displayName} = $$team{displayName};
	$teamsData{teams}{$$team{id}}{description} = $$team{description};

	# Team staat in de hash, mooi moment om aanvullende
	# gegevens over het team te zoeken
	my @channels;
	getTeamChannels($team->{id},\@channels);
	foreach my $channel (@channels){
	  $teamsData{teams}{$$team{id}}{channels}{$$channel{id}}{displayName} = $$channel{displayName};
	  $teamsData{teams}{$$team{id}}{channels}{$$channel{id}}{description} = $$channel{description};
	}
  }
  session->write(%teamsData);
}# }}}
sub getTeamChannels { #{{{1
  my $teamID = shift;
  my $channels = shift;
  say "Getting channels for ID $teamID";
  my $url = "https://graph.microsoft.com/v1.0/teams/$teamID/channels";
  _doGetItems($url, $channels);
}#}}}
# _doGetItem: Recursive functions to get items from graph {{{1
sub _doGetItems {
	my $url = shift;
	my $items = shift;
	my $result = _callAPI($url, 'GET');
	if ($result->is_success){
		my $reply =  decode_json($result->decoded_content);
		while (my ($i, $el) = each @{$reply->{'value'}}) {
			push @{$items}, $el;
		}
		if ($$reply{'@odata.nextLink'}){
			_doGetItems($reply->{'@odata.nextLink'}, $items);
		}
	}else{
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
	 (defined $session_data->{$provider}{access_token})
	){
  		getJoinedTeams();
     }
}#}}}
# sub validLogin() {{{1
# Controleert:
# - of er een sessie
# - of de sessie ververst moet worden
# - of de ingelogde gebruiker de juiste rollen heeft
sub validLogin { 
  say "validLogin";
  my $result = 0;
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
    $result =  0;
  }

  if (
       ( grep (/^etm$/, @{$session_data->{$provider}{login_info}{roles}}) ) &&
       ( grep (/^Medewerkers$/, @{$session_data->{$provider}{login_info}{roles}}) )
     ){
    say "role etm en Medewerkers";
    $result = 42;
  }else{
    say "geen role etm en Medewerkers";
    $result = 0;
  }
  return $result;
}#}}}
sub _callAPI {# {{{1
	my $url = shift;
	my $method = shift;
	my $content = shift || undef;
        my $session_data = session->read('oauth');
        my $provider = 'azuread';
        my $token = $session_data->{$provider}{access_token};
	my $ua = LWP::UserAgent->new(
		'send_te' => '0',
	);
	my $req = HTTP::Request->new();
	$req->method($method);
	$req->uri($url);
	$req->header('Accept'        => '*/*',            );
	$req->header('Authorization' => "Bearer $token", );
	$req->header('User-Agent'    => 'Perl/LWP',    );
	$req->header('Content-Type'  => 'application/json');
	if (defined $content){
	  say "in content";
	  $req->content($content);
	  print Dumper $req;
	}
	my $result = $ua->request($req);
	return $result;
} # }}}
sub createCard{
  my $msg = shift;
  my $team = shift;
  my %card;
  $card{body}{content} = "Bericht voor team :<br>";
  $card{body}{content} .= $msg;
  $card{body}{contentType} = 'html';
#  $card{mentions}[0]{id} = '0';
#  $card{mentions}[0]{mentionText} = 'Hallo team';
#  $card{mentions}[0]{mentioned}{user}{displayName} = 'Hallo team';
#  $card{mentions}[0]{mentioned}{user}{id} = $team;
#  $card{mentions}[0]{mentioned}{user}{userIdentityType} = 'aadGroup';
  my $reply = encode_json \%card;
  print Dumper $reply;
  return $reply;
 
}
42;
