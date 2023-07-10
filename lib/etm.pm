package etm;
use feature ":5.10";
use Dancer2;
use Dancer2::Plugin::Auth::OAuth;
use Data::Dumper;
use LWP::UserAgent;
use JSON;
#use JSON::Create 'create_json';
use URI::Encode qw(uri_encode);
use Data::GUID;
our $VERSION = '0.1';

my $appCnf = setting('AppSetting');

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
# /api/sendmessage {{{1
# Route om een bericht te sturen aan een team/channel
post '/api/sendmessage' => sub {
  my %reply;
  if (validLogin()){
    say "Send message";
    my $body = decode_json request->body;
    my $url= $appCnf->{GraphEndpoint} . 
             '/teams/'.
	     $body->{id} .
	     '/channels/' .
	     uri_encode($body->{generalid}, {encode_reserved => 1}) .
	     '/messages';
    # Bereid een JSON object voor met content
    my $content= createCard($body->{message},$body->{generalid});
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
# /api/reloadTeams {{{1
# Route om het herladen van de teams info te forceren
# Dit wordt gedaan door de teams uit de sessie te verwijderen
# en vervolgens opnieuw te laden.
# Wordt door JS aangeroepen nadat de DOM geladen is
# en als de gebruiker erom vraag.
get '/api/reloadteams' => sub {
  if (validLogin()){
    #
    # Graph geeft af en toe een 401 unauthorized, rete irritant
    # workaround is vlgs zeggen een call naar een sharepoint api
    #&callSharepoint;
    session->delete('teams');
    loadTeams();
    my $teams_data = session->read('teams');
    send_as JSON => $teams_data;
  }
}; #}}}
# getJoinedTeams {{{1
# Zoekt de teams waar de gebruiker lid van is
# Vervolgens wordt er per team gekeken naar
# - is de gebruiker eigenaar
# - welke channels heeft het team
# Deze gevevens worden opgeslagen in de session
sub getJoinedTeams {
  my @teams;
  my $url = $appCnf->{GraphEndpoint} . '/me/joinedTeams?$select=id,displayName,description';
  _doGetItems($url, \@teams);
  #print Dumper \@teams;
  #return \@teams;
  my %teamsData;
  foreach my $team (@teams){
	$teamsData{teams}{$team->{id}}{displayName} = $team->{displayName};
	$teamsData{teams}{$team->{id}}{description} = $team->{description};

	# Team staat in de hash, mooi moment om aanvullende
	# gegevens over het team te zoeken
	# Ben ik eigenaar?
	$teamsData{teams}{$team->{id}}{role} = getMyTeamRole($team->{id});
	#
	# Welke channels zijn er?
	my @channels;
	getTeamChannels($team->{id},\@channels);
	foreach my $channel (@channels){
	  $teamsData{teams}{$team->{id}}{channels}{$channel->{id}}{displayName} = $channel->{displayName};
	  $teamsData{teams}{$team->{id}}{channels}{$channel->{id}}{description} = $channel->{description};
	}
  }
  session->write(%teamsData);
}# }}}
# getMyTeamRole {{{1
# Bereid de request voor om te zien of de gebruiker eigenaar is van een team
sub getMyTeamRole {
  my $teamId = shift;
  my $role = "member";
  my $url = "$appCnf->{GraphEndpoint}/groups/$teamId/owners?\$select=displayName";
  my $result = _callAPI($url,'GET');
  if ($result->is_success){
    my $reply =  decode_json($result->decoded_content);
    #print Dumper $reply;
  }else{
    print Dumper $result;
    die $result->status_line;
  }
  return $role;
} # }}}
# getTeamChannels {{{1
# Bereid het ophalen voor van het ophalen van channels voor een bepaald tema
# doGetItems doet het uiteindelijke werk.
# Gevonden channels komen in de $channels reference
sub getTeamChannels { 
  my $teamId = shift;
  my $channels = shift;
  my $url = "$appCnf->{GraphEndpoint}/teams/$teamId/channels?\$select=id,displayName,description";
  _doGetItems($url, $channels);
}#}}}
# _doGetItem {{{1 
# Generieke recursive function om items te laden bij graph
# Indien er een nextLink is roept hij zichzelf aan.
# Geeft de items terug via de $items reference
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
		print Dumper $result;
		die $result->status_line
	}
} #}}}
# loadTeams {{{1
# Laad teamsdata als er een oauth sessie is
# en geen teams
sub loadTeams { 
    my $teams_data = session->read('teams');
    my $session_data = session->read('oauth');
    my $provider = 'azuread';
    if ( 
         (!defined $teams_data) &&
	 (defined $session_data->{$provider}{access_token})
	){
  		getJoinedTeams();
     }
}#}}}
# validLogin() {{{1
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
#  _callAPI {{{1
# Generieke functie om een request te sturen
sub _callAPI {
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
	  say "====== content";
	  say $content;
	  $req->content($content);
	  $req->content_length(length($content));
	  say "=====request";
	  print Dumper $req;
	}
	my $result = $ua->request($req);
	return $result;
} # }}}
# createCard {{{1
# Maakt een messagecard evt met icon en highlight
sub createCard{
  my $msg = shift;
  my $channel = shift;
  
  my %payload = (
	  type => "AdaptiveCard",
	  version => "1.0",
	  body => [ 
	    {
	      type => "TextBlock",
	      text =>  "Here is a ninja cat", 
	    }, 
	    {
	      type => "Image",
	      url => "http://adaptivecatds.io/content/cats/1.png" 
	    }, 
	  ],
  );
  my $content = encode_json \%payload;
  say "===payload";
  say $content;

  my $id = Data::GUID->new;
  say "my GUID $id";
  
  my %card = ( 
    body => { 
      contentType => "html", 
      content => "<attachment id=\"$id\"></attachment>" 
    }, 
    attachments => [ 
      { 
        id => "$id", 
	content_type => "application/vnd.microsoft.card.adaptive", 
	content => $content,
      }
    ]
  );
  say "card als hash";
  print Dumper %card;
  my $reply = encode_json \%card;
  say "card als json";
  say $reply;
  return $reply;
 
}#}}}
# callSharepoint {{{1
# Een poging om van de 401 fouten bij graph af te komen
# request mislukt maar zou evengoed effect kunnen hebbeb.
sub callSharepoint {
  my $hostPath = 'https://atlascollegehoorn.sharepoint.com';
  my $resource = 'AC-MijnAtlas';
  my $url = "$hostPath/sites/$resource/_api/search/query?querytext=\'contentclass:STS_Site\'&selectproperties=\'Path\'&refinementfilters=\'SPSiteUrl:(\"{$hostPath}/sites/*\")\'";
  say "callSharepoint";
  _callAPI($url,'GET');
}#}}}
42;
