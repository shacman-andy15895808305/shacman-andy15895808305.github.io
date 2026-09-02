(function(){
  if(/\/news\.html$/.test(location.pathname)){
    var firstNewsGrid=document.querySelector('.section:not(.gray) .news-grid');
    if(firstNewsGrid){firstNewsGrid.classList.add('news-grid--featured');}
    var currentNews=document.querySelector('.nav-links a[href="news.html"]');
    if(currentNews){currentNews.setAttribute('aria-current','page');}
    var quoteNav=document.querySelector('.nav-links a[href="request-quote.html"]');
    if(quoteNav){quoteNav.classList.add('quote-link');}
  }
  var page=(document.querySelector('h1')||document.querySelector('title'));
  var topic=page?page.textContent.trim():'SHACMAN truck';
  var message='Hello Andy, I am interested in '+topic+'. Please help me choose a configuration and prepare a quotation.';
  var wa='https://wa.me/8618591976330?text='+encodeURIComponent(message);
  var footer=document.querySelector('footer');
  if(footer&&!document.querySelector('.lead-cta')){
    var box=document.createElement('section');
    box.className='lead-cta';
    box.setAttribute('aria-label','Request a truck quotation');
    box.innerHTML='<div class="lead-cta__inner"><div><h2>Need a configuration-based quotation?</h2><p>Send your destination, application, quantity and operating conditions. Andy will reply with the information needed for a suitable configuration.</p></div><div class="lead-cta__actions"><a class="lead-cta__btn" href="request-quote.html">Build My Enquiry</a><a class="lead-cta__btn lead-cta__btn--ghost" href="truck-buying-guide.html">Read Buying Guide</a></div></div>';
    footer.parentNode.insertBefore(box,footer);
  }
  if(!document.querySelector('.lead-float')){
    var float=document.createElement('a');
    float.className='lead-float';float.href=wa;float.target='_blank';float.rel='noopener';float.setAttribute('aria-label','Ask Andy on WhatsApp about '+topic);float.textContent='WhatsApp Andy';document.body.appendChild(float);
  }
})();
