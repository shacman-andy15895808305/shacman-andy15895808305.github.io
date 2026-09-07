(function(){
  'use strict';
  var form=document.getElementById('dump-quote-form');
  if(!form)return;
  var link=document.getElementById('dump-whatsapp-link');
  var status=document.getElementById('dump-quote-status');
  form.addEventListener('input',function(){link.hidden=true;status.textContent='';});
  form.addEventListener('submit',function(event){
    event.preventDefault();
    if(!form.reportValidity())return;
    var data=new FormData(form);
    var message=['Hello Andy, I would like a SHACMAN dump truck quotation.'];
    [['country','Destination'],['model','Model'],['quantity','Quantity'],['material','Material'],['payload','Target payload (tonnes)'],['contact','Name / company'],['conditions','Route and requirements']].forEach(function(field){var value=String(data.get(field[0])||'').trim();if(value)message.push(field[1]+': '+value);});
    link.href='https://wa.me/8618591976330?text='+encodeURIComponent(message.join('\n'));
    link.hidden=false;
    status.textContent='Your enquiry is ready. Open WhatsApp below to review and send it. Nothing has been sent yet.';
  });
})();
