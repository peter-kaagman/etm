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
    .then(function(teamsObj){
      const list = document.querySelector('#teamList');
      const table = document.createElement(`table`);
      const aRow = document.createElement(`tr`);
      const aCell = document.createElement(`td`);
      const aHead = document.createElement(`th`);
      
      // Headers
      const row = aRow.cloneNode();
      const cellNaam = aHead.cloneNode();
      cellNaam.textContent = 'Naam';
      row.append(cellNaam);
      const cellRol = aHead.cloneNode();
      cellRol.textContent = 'Rol';
      row.append(cellRol);
      const cellMessage = aHead.cloneNode();
      cellMessage.textContent = 'Bericht';
      row.append(cellMessage);
      table.append(row);

      // Data rows
      const rows = Object.entries(teamsObj).forEach( ([id, value]) => {
	// Start row
        const row = aRow.cloneNode();
	// Naam
        const cellNaam = aCell.cloneNode();
	const anchor = document.createElement('a');
	anchor.href = `/teamdetail/${id}`;
	anchor.innerText = teamsObj[id].displayName;
	cellNaam.append(anchor);
	row.append(cellNaam);
	// Rol
        const cellRol = aCell.cloneNode();
	cellRol.textContent = 'ntb'
	row.append(cellRol);
	// Bericht
        const cellMessage = aCell.cloneNode();
	const checkbox = document.createElement('input');
	checkbox.setAttribute('type', 'checkbox');
	checkbox.setAttribute('id', id);
	checkbox.setAttribute('name', id);
	cellMessage.append(checkbox);
	row.append(cellMessage);
	// End row
	table.append(row);
      });
      list.textContent = ``;
      list.append(table);
    })
    .catch(function(err){
      console.log('error');
      console.warn('Some error: ', err);
    });
  }

}, false);
