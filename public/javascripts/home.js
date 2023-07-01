// vanilla JS
document.addEventListener( 'DOMContentLoaded', function() {
  console.log("Document ready");

  loadTeams();

  let reloadTeams = document.querySelector('#reloadTeams');
  reloadTeams.addEventListener('click', function(event){
    event.preventDefault();
    loadTeams();
    //fetch('/api/reloadteams');
  });

  let form = document.querySelector('#sendMessage');
  form.addEventListener('submit', function(event){
    event.preventDefault();
    const data = new FormData(event.target);
    const message = data.get('message');
    if (message.length > 0){
      let teams = document.querySelectorAll('input:checked');
      if (teams.length > 0){
        Array.from(teams).forEach(function (team, index){
	  console.log('Bericht: ' + message + ' => ' +  team.id);
	  fetch('/api/sendmessage',{
	   method: 'POST',
	   body: JSON.stringify({
	     id: team.id,
	     message: message
	   }),
	   headers: {
	     'Content-type': 'application/json; charset=UTF-8'
	   }
	  });
	});
      }else{
        console.log('Geen teams geselecteerd');
      }
    }else{
      console.log('Bericht is leeg');
    }
  });

  function loadTeams(){
    console.log('loadTeams');
    fetch('/api/reloadteams')
    .then(function(response){
      return response.json();
    })
    .then(function(data){
      var table = '<table>';
      for (let id in data){
        table += '<tr><td>'+id+'</td></tr>';
      }
      table += '</table>';
      var tc = document.querySelector('#teamList');
      tc.innerHTML = table;
    })
    .catch(function(err){
      console.log('error');
      console.warn('Some error: ', err);
    });
  }

}, false);
