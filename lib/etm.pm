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
  my $sessionData = session->read('oauth');
  #my $teams = getJoinedTeams($$sessionData{azuread}{access_token});
  my $teams = session->read('teams');
  template 'index' => { 'title' => 'ETM',
	                'sessionData' => $sessionData, 
			'joinedTeams' => $teams,
			};
};# }}}

post '/api/sendmessage' => sub { # {{{1
  my $data = from_json(request->body);

  # Bereid een JSON object voor met content
  my %content;
  $content{'body'}{'content'} = $$data{'message'};
  print create_json(\%content);

}; #}}}

get '/api/reloadteams' => sub { # {{{1
  session->delete('teams');
  return redirect "/";
}; #}}}
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

sub getJoinedTeams { # {{{1
  my $token = shift;
  my @teams;
  my $url = "http://graph.microsoft.com/v1.0/me/joinedTeams";
  _doGetJoinedTeams($token, $url, \@teams);
  #print Dumper \@teams;
  #return \@teams;
  my %teamsData;
  foreach(@teams){
	$teamsData{teams}{$$_{id}}{displayName} = $$_{displayName};
	$teamsData{teams}{$$_{id}}{description} = $$_{description};

	# Team staat in de hash, mooi moment om aanvullende
	# gegevens over het team te zoeken
	getTeamChannels($token, %teamData{teams}{id});
  }
  session->write(%teamsData);
}# }}}

sub getTeamChannels {
  my $token = shift;
  my $teamID = shift;
}

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
  		#print "\nLoading teams\n\n";
  		getJoinedTeams($$session_data{azuread}{access_token});
     }
}#}}}

hook before => sub {# {{{1
    my $session_data = session->read('oauth');#{{{2
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
    }# }}}

    loadTeams();


};# }}}

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
	$req->header('Accept' => '*/*');
	$req->header('Accept'        => '*/*',            );
	$req->header('Authorization' => "Bearer ".$token, );
	$req->header('User-Agent'    => 'curl/7.55.1',    );
	$req->header('Content-Type'  => 'application/json');
	if (defined $content){
	  $req->content($content)
	}
	my $result = $ua->request($req);
	#print Dumper $result;
	return $result;
} # }}}

true;
