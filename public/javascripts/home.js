// jQuery
//$(function() {
//
//  console.log("Document ready");
//
//  $("#sendMessage").on( "submit", function(event){
//    event.preventDefault();
//    if ( $("#message").val().length > 0 ) {
//    console.log("submitted send form");
//    $("input:checked").each(function (index){
//      console.log("team: "+index+" this: "+this.id);
//    });
//    }else{
//      console.log("Bericht is leeg");
//    }
//  })
//})

// vanilla JS
document.addEventListener( 'DOMContentLoaded', function() {
  console.log("Document ready");

  let form = document.querySelector('#sendMessage');
  form.addEventListener('submit', onMessageSubmit);

  function onMessageSubmit(event){
    event.preventDefault();
    const data = new FormData(event.target);
    const message = data.get('message');
    if (message.length > 0){
      let teams = document.querySelectorAll('input:checked');
      if (teams.length > 0){
        Array.from(teams).forEach(function (team, index){
	  console.log('Bericht: ' + message + ' => ' +  team.id);
	});
      }else{
        console.log('Geen teams geselecteerd');
      }
    }else{
      console.log('Bericht is leeg');
    }
  }

}, false);
