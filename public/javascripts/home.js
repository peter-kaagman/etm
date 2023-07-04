// vanilla JS
document.addEventListener( 'DOMContentLoaded', function() {
  console.log("Document ready");

  loadTeams();

  let reloadTeams = document.querySelector('#reloadTeams'); //{{{1
  reloadTeams.addEventListener('click', function(event){
    event.preventDefault();
    loadTeams();
  });// }}}

  let form = document.querySelector('#sendMessage');///{{{1
  form.addEventListener('submit', function(event){
    event.preventDefault();
    const data = new FormData(event.target);
    const message = data.get('message');
    if (message.length > 0){
      let teams = document.querySelectorAll('input:checked');
      if (teams.length > 0){
        Array.from(teams).forEach(function (team, index){
	  console.log('Bericht: ' + message + ' => ' +  team.id + ' => ' + team.name);
	  fetch('/api/sendmessage',{
	   method: 'POST',
	   headers: {
	     'Accept': 'application/json',
	     'Content-Type': 'application/json'
	   },
	   body: JSON.stringify({
	     id: team.id,
	     generalid: team.name,
	     message: message
	   })
	  })
	  .then(function(response){
	    return response.json();
	  })
	  .then(function(data){
	    console.log(data)
	  })
	  .catch(function(err){
            console.log('error');
            console.warn('Some error: ', err);
	  });
	});
      }else{
        console.log('Geen teams geselecteerd');
      }
    }else{
      console.log('Bericht is leeg');
    }
  });//}}}

  function loadTeams(){//{{{1
    console.log('loadTeams');
    fetch('/api/reloadteams')
    .then((response) => { //{{{2
      // Do something with the response
      console.log(typeof(response));
      return response.json();
    }) // then(response) }}}
    /*
    .then((unsorted) => { //{{{2
      // Do something with the response
      function compare(a,b){
        if (a.displayName < b.displayName){
	  return -1;
	}
        if (a.displayName > b.displayName){
	  return 1;
	}
	return 0;
      }
      return Object(unsorted).sort(compare);
    }) // then(unsorted) }}}
    */
    .then((teamsObj) => {//{{{2
      // Do something with teamsObj
      console.log(typeof(teamsObj));
      const list = document.querySelector('#teamList');
      const table = document.createElement(`table`);
      const aRow = document.createElement(`tr`);
      const aCell = document.createElement(`td`);
      const aHead = document.createElement(`th`);
      
      // Headers{{{3
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
      table.append(row);//}}}
      // Data rows {{{3
      const rows = Object.entries(teamsObj).forEach(([id, value]) => {
        const generalID = getGeneralId(value.channels);
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
        checkbox.setAttribute('name', generalID);
        cellMessage.append(checkbox);
        row.append(cellMessage);
        // End row
        table.append(row);
      }); // Data rows }}}
      // Replace list content with new table
      list.textContent = ``;
      list.append(table);
    })// then(teamsObj) }}}
    .catch((err) => { //{{{2
      console.warn('Some error: ', err);
    }); // catch(err) }}}
  } // end loadTeams }}}


  function getGeneralId(channels){
      //const rows = Object.entries(teamsObj).forEach( ([id, value]) => {
    let generalChannel = '';
    const channel = Object.entries(channels).forEach( ([id, value] ) => {
      //console.log(`Id: ${id}`);
      if (channels[id].displayName == 'General'){
        generalChannel = id;
      };
    });
    return generalChannel;
  }

}, false);//}}


