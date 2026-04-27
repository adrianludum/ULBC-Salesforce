import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCampaignDetails from '@salesforce/apex/ULBC_LandingPageController.getCampaignDetails';
import saveLandingPage from '@salesforce/apex/ULBC_LandingPageController.saveLandingPage';

const STEPS = ['details', 'menu', 'tickets', 'preview'];

export default class UlbcLandingPageWizard extends LightningElement {
    @api recordId;

    currentStep = 0;
    isOpen = false;
    isSaving = false;
    copied = false;

    // Form fields
    eventName = '';
    eventDescription = '';
    startDate = '';
    startTime = '';
    endTime = '';
    venue = '';
    dressCode = '';
    menu = '';
    transportInfo = '';
    ticketPrice = 75;
    stripePriceId = '';
    ticketIncludes = 'Includes reception drinks, three-course dinner, and half a bottle of wine per guest.';
    existingHtml = '';

    dressCodeOptions = [
        { label: 'Black Tie', value: 'Black Tie' },
        { label: 'Smart Casual', value: 'Smart Casual' },
        { label: 'Casual', value: 'Casual' },
        { label: 'No Dress Code', value: 'No Dress Code' }
    ];

    @wire(getCampaignDetails, { campaignId: '$recordId' })
    wiredCampaign({ data, error }) {
        if (data) {
            this.eventName = data.name || '';
            this.eventDescription = data.description || '';
            this.startDate = data.startDate || '';
            this.startTime = data.startTime || '';
            this.endTime = data.endTime || '';
            this.venue = data.venue || '';
            this.dressCode = data.dressCode || '';
            this.menu = data.menu || '';
            this.transportInfo = data.transportInfo || '';
            this.ticketPrice = data.ticketPrice || 75;
            this.stripePriceId = data.stripePriceId || '';
            this.existingHtml = data.landingPageHtml || '';
        }
    }

    // --- Navigation ---
    get stepName() { return STEPS[this.currentStep]; }
    get isDetailsStep() { return this.currentStep === 0; }
    get isMenuStep() { return this.currentStep === 1; }
    get isTicketsStep() { return this.currentStep === 2; }
    get isPreviewStep() { return this.currentStep === 3; }
    get isFirstStep() { return this.currentStep === 0; }
    get isLastStep() { return this.currentStep === STEPS.length - 1; }
    get nextLabel() { return this.isLastStep ? 'Save & Download HTML' : 'Next'; }
    get hasExistingPage() { return !!this.existingHtml; }

    get progressItems() {
        return [
            { label: 'Event Details', num: 1, cls: this.currentStep >= 0 ? 'step-active' : 'step-inactive' },
            { label: 'Menu & Info', num: 2, cls: this.currentStep >= 1 ? 'step-active' : 'step-inactive' },
            { label: 'Tickets', num: 3, cls: this.currentStep >= 2 ? 'step-active' : 'step-inactive' },
            { label: 'Preview', num: 4, cls: this.currentStep >= 3 ? 'step-active' : 'step-inactive' }
        ];
    }

    openWizard() {
        this.isOpen = true;
        this.currentStep = 0;
        this.copied = false;
    }

    closeWizard() {
        this.isOpen = false;
    }

    handlePrevious() {
        if (this.currentStep > 0) this.currentStep--;
    }

    handleNext() {
        if (this.isLastStep) {
            this.saveAndCopy();
        } else {
            this.currentStep++;
            if (this.currentStep === 3) {
                this.renderPreview();
            }
        }
    }

    renderPreview() {
        // Use setTimeout to wait for the iframe to render in the DOM
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const iframe = this.template.querySelector('.ev-preview-iframe');
            if (iframe) {
                const fullHtml = `<!DOCTYPE html>
<html><head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link href="https://fonts.googleapis.com/css2?family=Archivo+Narrow:wght@400;600;700&family=IBM+Plex+Sans:wght@300;400;600;700&display=swap" rel="stylesheet">
</head><body style="margin:0;padding:0;background:#fff;">
${this.generatedHtml}
</body></html>`;
                iframe.srcdoc = fullHtml;
            }
        }, 100);
    }

    // --- Field handlers ---
    handleFieldChange(event) {
        const field = event.target.dataset.field;
        this[field] = event.target.value;
    }

    handlePriceChange(event) {
        this.ticketPrice = parseFloat(event.target.value) || 0;
    }

    // --- Date/time formatting ---
    get formattedDate() {
        if (!this.startDate) return 'Date TBC';
        const d = new Date(this.startDate + 'T12:00:00');
        const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        const months = ['January', 'February', 'March', 'April', 'May', 'June',
                        'July', 'August', 'September', 'October', 'November', 'December'];
        return `${days[d.getDay()]} ${d.getDate()}${this.ordinal(d.getDate())} ${months[d.getMonth()]} ${d.getFullYear()}`;
    }

    get formattedTime() {
        if (!this.startTime) return '';
        return this.formatTimeDisplay(this.startTime);
    }

    formatTimeDisplay(t) {
        if (!t) return '';
        const parts = t.split(':');
        let h = parseInt(parts[0], 10);
        const m = parts[1];
        const ampm = h >= 12 ? 'pm' : 'am';
        if (h > 12) h -= 12;
        if (h === 0) h = 12;
        return m === '00' ? `${h}:00${ampm}` : `${h}:${m}${ampm}`;
    }

    ordinal(n) {
        const s = ['th', 'st', 'nd', 'rd'];
        const v = n % 100;
        return s[(v - 20) % 10] || s[v] || s[0];
    }

    // --- Menu parsing ---
    get parsedMenu() {
        if (!this.menu) return [];
        return this.menu.split('\n').filter(l => l.trim()).map(line => {
            const colonIdx = line.indexOf(':');
            if (colonIdx > 0) {
                return {
                    course: line.substring(0, colonIdx).trim(),
                    description: line.substring(colonIdx + 1).trim(),
                    key: line.substring(0, colonIdx).trim()
                };
            }
            return { course: '', description: line.trim(), key: line.trim() };
        });
    }

    // --- HTML Generation ---
    get generatedHtml() {
        const esc = (s) => (s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

        let menuHtml = '';
        if (this.menu) {
            menuHtml = '<h2>Menu</h2>\n<div class="menu-section">\n';
            this.parsedMenu.forEach(item => {
                menuHtml += '  <div class="menu-course">\n';
                if (item.course) {
                    menuHtml += `    <h3>${esc(item.course)}</h3>\n`;
                }
                menuHtml += `    <p>${esc(item.description)}</p>\n`;
                menuHtml += '  </div>\n';
            });
            menuHtml += '</div>\n<hr class="double-hr">\n';
        }

        let transportHtml = '';
        if (this.transportInfo) {
            transportHtml = `<h2>Getting There</h2>\n<p>${esc(this.transportInfo).replace(/\n/g, '<br>')}</p>\n`;
        }

        const timeStr = this.startTime ? ` — ${this.formatTimeDisplay(this.startTime)}` : '';
        const dressHtml = this.dressCode && this.dressCode !== 'No Dress Code'
            ? `<div><dt>Dress Code</dt><dd>${esc(this.dressCode)}</dd></div>` : '';

        const endTimeStr = this.endTime ? `<br>${this.formatTimeDisplay(this.endTime)} — Close` : '';

        return `<style>
  *,*::before,*::after{box-sizing:border-box;}
  .ulbc-ev{max-width:900px;margin:0 auto;font-family:'IBM Plex Sans',sans-serif;color:#2c2828;line-height:1.7;}

  /* ── Hero ── */
  .ulbc-hero{position:relative;min-height:420px;background:linear-gradient(160deg,#532580 0%,#3a1a5c 60%,#2a1145 100%);overflow:hidden;display:flex;align-items:center;justify-content:center;text-align:center;margin-bottom:0;}
  .ulbc-hero::before{content:'';position:absolute;top:-50%;right:-20%;width:500px;height:500px;border-radius:50%;background:rgba(184,74,44,.15);pointer-events:none;}
  .ulbc-hero::after{content:'';position:absolute;bottom:-30%;left:-15%;width:400px;height:400px;border-radius:50%;background:rgba(178,168,184,.08);pointer-events:none;}
  .ulbc-hero-content{position:relative;z-index:1;padding:3em 2em;}
  .ulbc-hero .ev-kicker{font-family:'Archivo Narrow',sans-serif;font-size:.9em;font-weight:600;letter-spacing:3px;text-transform:uppercase;color:#b84a2c;margin-bottom:.5em;}
  .ulbc-hero h1{font-family:'Archivo Narrow',sans-serif;color:#fff;font-size:3em;font-weight:700;text-transform:uppercase;letter-spacing:2px;margin:0 0 .3em;line-height:1.1;}
  .ulbc-hero .ev-date-hero{font-family:'Archivo Narrow',sans-serif;font-size:1.15em;color:#b2a8b8;letter-spacing:1px;margin-bottom:1.5em;}
  .ulbc-hero .ev-cta-hero{display:inline-block;background:#b84a2c;color:#fff;font-family:'Archivo Narrow',sans-serif;font-size:1.1em;font-weight:700;text-transform:uppercase;letter-spacing:2px;padding:.9em 3em;border:none;border-radius:50px;cursor:pointer;text-decoration:none;transition:all .3s;}
  .ulbc-hero .ev-cta-hero:hover{background:#d4562f;transform:translateY(-2px);box-shadow:0 8px 25px rgba(184,74,44,.4);}

  /* ── Accent bar ── */
  .ulbc-accent-bar{height:5px;background:linear-gradient(90deg,#532580,#b84a2c,#b2a8b8);}

  /* ── Section styling ── */
  .ulbc-ev h2{font-family:'Archivo Narrow',sans-serif;color:#532580;font-size:1.6em;font-weight:700;text-transform:uppercase;letter-spacing:1px;margin:2em 0 .8em;text-align:center;}
  .ulbc-ev h2::after{content:'';display:block;width:60px;height:3px;background:#b84a2c;margin:.5em auto 0;}

  /* ── Info cards ── */
  .ev-info-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:1.5em;margin:2em 0;padding:0 1em;}
  .ev-info-card{background:#f8f6fa;border-radius:12px;padding:1.8em 1.5em;text-align:center;border-top:4px solid #532580;transition:transform .2s;}
  .ev-info-card:hover{transform:translateY(-3px);}
  .ev-info-card .ev-card-icon{font-size:1.8em;margin-bottom:.5em;}
  .ev-info-card dt{font-family:'Archivo Narrow',sans-serif;font-weight:700;color:#532580;font-size:.8em;text-transform:uppercase;letter-spacing:1.5px;margin-bottom:.4em;}
  .ev-info-card dd{margin:0;font-size:1em;line-height:1.5;}

  /* ── Description ── */
  .ev-description{max-width:650px;margin:2em auto;padding:0 1em;text-align:center;font-size:1.1em;color:#444;}

  /* ── Divider ── */
  .ev-divider{display:flex;align-items:center;gap:1em;margin:3em auto;max-width:300px;}
  .ev-divider::before,.ev-divider::after{content:'';flex:1;height:1px;background:#b2a8b8;}
  .ev-divider span{color:#b2a8b8;font-size:.8em;letter-spacing:2px;text-transform:uppercase;font-family:'Archivo Narrow',sans-serif;}

  /* ── Menu ── */
  .ev-menu{max-width:600px;margin:0 auto 2em;padding:0 1em;}
  .ev-menu-item{padding:1.2em 0;border-bottom:1px solid #e8e4eb;display:flex;gap:1.5em;align-items:baseline;}
  .ev-menu-item:last-child{border-bottom:none;}
  .ev-menu-item h3{font-family:'Archivo Narrow',sans-serif;color:#b84a2c;font-size:.85em;font-weight:700;text-transform:uppercase;letter-spacing:1.5px;min-width:80px;margin:0;}
  .ev-menu-item p{margin:0;flex:1;}

  /* ── Ticket CTA ── */
  .ev-ticket{background:linear-gradient(160deg,#532580,#3a1a5c);border-radius:16px;padding:3em 2em;margin:2em 1em;text-align:center;position:relative;overflow:hidden;}
  .ev-ticket::before{content:'';position:absolute;top:-40%;right:-20%;width:300px;height:300px;border-radius:50%;background:rgba(255,255,255,.04);pointer-events:none;}
  .ev-ticket h2{color:#fff!important;margin-top:0!important;}
  .ev-ticket h2::after{background:#b84a2c;}
  .ev-ticket .ev-price{font-family:'Archivo Narrow',sans-serif;font-size:3.5em;font-weight:700;color:#fff;margin:.2em 0;}
  .ev-ticket .ev-price small{font-size:.35em;color:#b2a8b8;font-weight:400;display:block;}
  .ev-ticket .ev-includes{color:#b2a8b8;font-size:.95em;max-width:450px;margin:0 auto 1.5em;}
  .ev-ticket .ev-qty{display:flex;align-items:center;justify-content:center;gap:1.2em;margin:1.5em 0;}
  .ev-ticket .ev-qty button{width:44px;height:44px;border:2px solid rgba(255,255,255,.4);background:transparent;color:#fff;font-size:1.4em;font-weight:700;border-radius:50%;cursor:pointer;transition:all .2s;}
  .ev-ticket .ev-qty button:hover{border-color:#fff;background:rgba(255,255,255,.1);}
  .ev-ticket .ev-qty .ev-qty-num{font-size:1.8em;font-weight:700;color:#fff;min-width:2em;text-align:center;}
  .ev-ticket .ev-total{color:#b2a8b8;font-size:1em;margin-bottom:1.5em;}
  .ev-ticket .ev-total strong{color:#fff;font-size:1.2em;}
  .ev-ticket .ev-buy{display:inline-block;background:#b84a2c;color:#fff;font-family:'Archivo Narrow',sans-serif;font-size:1.2em;font-weight:700;text-transform:uppercase;letter-spacing:2px;padding:1em 4em;border:none;border-radius:50px;cursor:pointer;transition:all .3s;text-decoration:none;}
  .ev-ticket .ev-buy:hover{background:#d4562f;transform:translateY(-2px);box-shadow:0 8px 30px rgba(184,74,44,.5);}
  .ev-ticket .ev-secure{color:rgba(255,255,255,.5);font-size:.8em;margin-top:1.2em;}

  /* ── Transport ── */
  .ev-transport{max-width:600px;margin:0 auto 3em;padding:0 1em;text-align:center;color:#555;}

  /* ── Footer ── */
  .ev-footer{text-align:center;padding:2em;color:#b2a8b8;font-size:.85em;border-top:1px solid #e8e4eb;margin-top:2em;}
  .ev-footer a{color:#532580;}

  @media(max-width:600px){
    .ulbc-hero h1{font-size:2em;}
    .ulbc-hero{min-height:320px;}
    .ev-info-grid{grid-template-columns:1fr 1fr;}
    .ev-ticket .ev-price{font-size:2.5em;}
    .ev-menu-item{flex-direction:column;gap:.3em;}
  }
</style>

<div class="ulbc-ev">

  <div class="ulbc-hero">
    <div class="ulbc-hero-content">
      <div class="ev-kicker">University of London Boat Club</div>
      <h1>${esc(this.eventName)}</h1>
      <div class="ev-date-hero">${esc(this.formattedDate)}${timeStr ? ' &mdash; ' + this.formatTimeDisplay(this.startTime) : ''}</div>
      <a href="#tickets" class="ev-cta-hero">Get Your Tickets</a>
    </div>
  </div>

  <div class="ulbc-accent-bar"></div>

  ${this.eventDescription ? '<p class="ev-description">' + esc(this.eventDescription) + '</p>' : ''}

  <div class="ev-info-grid">
    <div class="ev-info-card">
      <div class="ev-card-icon">&#128197;</div>
      <dt>Date</dt>
      <dd>${esc(this.formattedDate)}</dd>
    </div>
    <div class="ev-info-card">
      <div class="ev-card-icon">&#128336;</div>
      <dt>Time</dt>
      <dd>${this.formatTimeDisplay(this.startTime) || 'TBC'}${this.endTime ? ' &ndash; ' + this.formatTimeDisplay(this.endTime) : ''}</dd>
    </div>
    <div class="ev-info-card">
      <div class="ev-card-icon">&#127969;</div>
      <dt>Venue</dt>
      <dd>${esc(this.venue || 'TBC')}</dd>
    </div>
    ${this.dressCode && this.dressCode !== 'No Dress Code' ? '<div class="ev-info-card"><div class="ev-card-icon">&#128084;</div><dt>Dress Code</dt><dd>' + esc(this.dressCode) + '</dd></div>' : ''}
  </div>

  ${menuHtml ? '<div class="ev-divider"><span>Menu</span></div>' : ''}

  ${this.menu ? '<div class="ev-menu">' + this.parsedMenu.map(item =>
    '<div class="ev-menu-item">' +
    (item.course ? '<h3>' + esc(item.course) + '</h3>' : '') +
    '<p>' + esc(item.description) + '</p></div>'
  ).join('') + '</div>' +
  '<p style="text-align:center;font-size:.9em;color:#888;">Dietary requirements? Email <a href="mailto:boathouse@ulbc.co.uk" style="color:#b84a2c;">boathouse@ulbc.co.uk</a></p>' : ''}

  <div class="ev-divider"><span>Tickets</span></div>

  <div class="ev-ticket" id="tickets">
    <h2>Secure Your Place</h2>
    <div class="ev-price">&pound;${this.ticketPrice}<small>per person</small></div>
    <p class="ev-includes">${esc(this.ticketIncludes)}</p>

    <div class="ev-qty">
      <button type="button" onclick="changeQty(-1)" aria-label="Decrease">&#8722;</button>
      <span class="ev-qty-num" id="qty-display">1</span>
      <button type="button" onclick="changeQty(1)" aria-label="Increase">+</button>
    </div>
    <p class="ev-total">Total: <strong><span id="total-display">&pound;${this.ticketPrice}</span></strong></p>

    <div id="guest-fields" style="display:none;max-width:400px;margin:1.5em auto;text-align:left;">
      <p style="color:#b2a8b8;font-size:.9em;text-align:center;margin-bottom:1em;">Please enter your guest details</p>
    </div>

    <button class="ev-buy" id="checkout-btn" onclick="checkout()">Buy Tickets</button>
    <p class="ev-secure">&#128274; Secure payment via Stripe. Digital ticket sent to your email.</p>
  </div>

  ${this.transportInfo ? '<div class="ev-divider"><span>Getting There</span></div><div class="ev-transport"><p>' + esc(this.transportInfo).replace(/\n/g, '<br>') + '</p></div>' : ''}

  <div class="ev-footer">
    ULBC Trust &mdash; Registered Charity No. 1174721<br>
    <a href="https://ulbc.co.uk">ulbc.co.uk</a>
  </div>

</div>

<script src="https://js.stripe.com/v3/"></script>
<script>
  const STRIPE_PRICE_ID='${esc(this.stripePriceId || 'price_REPLACE_ME')}';
  const CAMPAIGN_ID='${this.recordId}';
  const TICKET_PRICE=${this.ticketPrice};
  let quantity=1;

  function changeQty(d){
    quantity=Math.max(1,Math.min(10,quantity+d));
    document.getElementById('qty-display').textContent=quantity;
    document.getElementById('total-display').innerHTML='&pound;'+(quantity*TICKET_PRICE);
    renderGuestFields();
  }

  function renderGuestFields(){
    var container=document.getElementById('guest-fields');
    if(quantity<=1){container.style.display='none';container.innerHTML='';return;}
    container.style.display='block';
    var html='<p style="color:#b2a8b8;font-size:.9em;text-align:center;margin-bottom:1em;">Please enter your guest details</p>';
    for(var i=1;i<quantity;i++){
      html+='<div style="margin-bottom:1.2em;padding:1em;background:rgba(255,255,255,.08);border:1px solid rgba(255,255,255,.15);border-radius:8px;">';
      html+='<p style="color:#fff;font-weight:600;font-size:.85em;margin:0 0 .5em;text-transform:uppercase;letter-spacing:1px;">Guest '+i+'</p>';
      html+='<input type="text" id="guest_'+i+'_name" placeholder="Full name" style="width:100%;padding:.6em;margin-bottom:.5em;border:1px solid rgba(255,255,255,.25);border-radius:4px;background:rgba(255,255,255,.1);color:#fff;font-family:inherit;font-size:.95em;">';
      html+='<input type="email" id="guest_'+i+'_email" placeholder="Email (optional)" style="width:100%;padding:.6em;border:1px solid rgba(255,255,255,.25);border-radius:4px;background:rgba(255,255,255,.1);color:#fff;font-family:inherit;font-size:.95em;">';
      html+='</div>';
    }
    container.innerHTML=html;
  }

  function getGuestData(){
    var guests={};
    for(var i=1;i<quantity;i++){
      var nameEl=document.getElementById('guest_'+i+'_name');
      var emailEl=document.getElementById('guest_'+i+'_email');
      if(nameEl&&nameEl.value)guests['guest_'+i+'_name']=nameEl.value;
      if(emailEl&&emailEl.value)guests['guest_'+i+'_email']=emailEl.value;
    }
    return guests;
  }

  function checkout(){
    // Collect guest data and pass to Stripe via metadata
    // In production, POST to your server which creates a Stripe Checkout Session
    // with metadata including guest details and campaign_id
    var guests=getGuestData();
    console.log('Guest data:',guests);
    console.log('Campaign:',CAMPAIGN_ID,'Qty:',quantity);
    window.location.href='https://buy.stripe.com/REPLACE_WITH_PAYMENT_LINK';
  }

  var p=new URLSearchParams(window.location.search);
  if(p.get('success')==='true'){document.querySelector('.ev-ticket').innerHTML='<h2 style="color:#fff;margin-top:0;">Thank You!</h2><p style="font-size:1.2em;color:#fff;">Your tickets have been booked.</p><p style="color:#b2a8b8;">Check your email for your digital ticket and Apple/Google Wallet pass.</p>';}
  document.querySelectorAll('a[href="#tickets"]').forEach(function(a){a.addEventListener('click',function(e){e.preventDefault();document.getElementById('tickets').scrollIntoView({behavior:'smooth'});});});
</script>`;
    }

    // --- Save & Copy ---
    async saveAndCopy() {
        this.isSaving = true;
        try {
            const html = this.generatedHtml;
            await saveLandingPage({
                campaignId: this.recordId,
                html: html,
                menu: this.menu,
                dressCode: this.dressCode,
                transportInfo: this.transportInfo,
                stripePriceId: this.stripePriceId,
                description: this.eventDescription,
                ticketPrice: this.ticketPrice,
                venue: this.venue,
                startTime: this.startTime,
                endTime: this.endTime
            });

            this.existingHtml = html;
            this.downloadHtmlFile(html);
            this.copied = true;

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Landing page saved and HTML file downloaded.',
                variant: 'success'
            }));
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || error.message || 'Failed to save',
                variant: 'error'
            }));
        }
        this.isSaving = false;
    }

    async handleCopyHtml() {
        const html = this.existingHtml || this.generatedHtml;
        await navigator.clipboard.writeText(html);
        this.copied = true;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Copied',
            message: 'HTML copied to clipboard',
            variant: 'success'
        }));
    }

    handleDownloadHtml() {
        const html = this.existingHtml || this.generatedHtml;
        this.downloadHtmlFile(html);
    }

    downloadHtmlFile(html) {
        const fullHtml = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${this.eventName || 'Event'}</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=Archivo+Narrow:wght@400;600;700&family=IBM+Plex+Sans:wght@300;400;600;700&display=swap" rel="stylesheet">
</head>
<body style="margin:0; padding:0; background:#fff;">
${html}
</body>
</html>`;

        const dataUri = 'data:text/html;charset=utf-8,' + encodeURIComponent(fullHtml);
        const slug = (this.eventName || 'event').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/-+$/, '');

        // Use a hidden anchor in the template
        const anchor = this.template.querySelector('.ev-download-link');
        if (anchor) {
            anchor.href = dataUri;
            anchor.download = `${slug}-landing-page.html`;
            anchor.click();
        } else {
            // Fallback: open in new window
            window.open(dataUri, '_blank');
        }
    }
}
