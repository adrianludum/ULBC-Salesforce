import { LightningElement, wire } from 'lwc';
import ULBC_LOGO from '@salesforce/resourceUrl/ULBC_Logo';
import getKPIMetrics from '@salesforce/apex/ULBC_DashboardController.getKPIMetrics';
import getDonorsByTier from '@salesforce/apex/ULBC_DashboardController.getDonorsByTier';
import getDonationsByFund from '@salesforce/apex/ULBC_DashboardController.getDonationsByFund';
import getGiftsByYear from '@salesforce/apex/ULBC_DashboardController.getGiftsByYear';
import getGiftAidStatus from '@salesforce/apex/ULBC_DashboardController.getGiftAidStatus';
import getCrewsByRegatta from '@salesforce/apex/ULBC_DashboardController.getCrewsByRegatta';
import getEventAttendance from '@salesforce/apex/ULBC_DashboardController.getEventAttendance';
import getActiveCampaigns from '@salesforce/apex/ULBC_DashboardController.getActiveCampaigns';
import getUpgradeProspects from '@salesforce/apex/ULBC_DashboardController.getUpgradeProspects';
import getLapsedDonors from '@salesforce/apex/ULBC_DashboardController.getLapsedDonors';
import getRecentDonations from '@salesforce/apex/ULBC_DashboardController.getRecentDonations';
import getReportIds from '@salesforce/apex/ULBC_DashboardController.getReportIds';

const CHART_COLORS = ['#784CA8', '#e91e8c', '#00d4aa', '#a08cb8', '#c77dff', '#ff6b9d', '#4ecdc4', '#ffe66d'];

export default class UlbcDashboard extends LightningElement {
    logoUrl = ULBC_LOGO;
    kpiMetrics = {};
    kpiLoading = true;
    kpiError;
    donorsByTier = [];
    donationsByFund = [];
    giftsByYear = [];
    giftAidStatus = [];
    crewsByRegatta = [];
    eventAttendance = [];
    activeCampaigns = [];
    upgradeProspects = [];
    lapsedDonors = [];
    recentDonations = [];
    reportIds = {};
    tierLoading = true;
    fundLoading = true;
    yearLoading = true;
    giftAidLoading = true;
    crewsLoading = true;
    eventsLoading = true;
    campaignsLoading = true;
    prospectsLoading = true;
    lapsedLoading = true;
    donationsLoading = true;
    tierError;
    fundError;
    yearError;
    giftAidError;
    crewsError;
    eventsError;
    campaignsError;
    prospectsError;
    lapsedError;
    donationsError;

    @wire(getReportIds)
    wiredReportIds({ data, error }) {
        if (data) {
            this.reportIds = data;
        }
    }

    @wire(getKPIMetrics)
    wiredKPI({ data, error }) {
        this.kpiLoading = false;
        if (data) {
            this.kpiMetrics = data;
            this.kpiError = undefined;
        } else if (error) {
            this.kpiError = this.reduceError(error);
        }
    }

    @wire(getDonorsByTier)
    wiredTiers({ data, error }) {
        this.tierLoading = false;
        if (data) {
            const total = data.reduce((s, d) => s + d.value, 0);
            this.donorsByTier = data.map((d, i) => ({
                label: d.label || 'Unknown',
                value: d.value,
                pct: total > 0 ? ((d.value / total) * 100).toFixed(0) : '0',
                color: CHART_COLORS[i % CHART_COLORS.length],
                swatchStyle: `background-color: ${CHART_COLORS[i % CHART_COLORS.length]};`,
                key: 'tier-' + i
            }));
            this.tierError = undefined;
        } else if (error) {
            this.tierError = this.reduceError(error);
        }
    }

    @wire(getDonationsByFund)
    wiredFunds({ data, error }) {
        this.fundLoading = false;
        if (data) {
            const max = Math.max(...data.map(d => d.value), 1);
            this.donationsByFund = data.map((d, i) => ({
                label: d.label || 'Unallocated',
                value: d.value,
                formattedValue: this.formatCurrency(d.value),
                barStyle: `width: ${(d.value / max) * 100}%;`,
                key: 'fund-' + i
            }));
            this.fundError = undefined;
        } else if (error) {
            this.fundError = this.reduceError(error);
        }
    }

    @wire(getGiftsByYear)
    wiredYears({ data, error }) {
        this.yearLoading = false;
        if (data && data.length > 0) {
            this.giftsByYear = data.map(d => ({
                year: d.year,
                amount: d.amount || 0,
                formattedAmount: this.formatCurrency(d.amount || 0)
            }));
            this.yearError = undefined;
        } else if (error) {
            this.yearError = this.reduceError(error);
        }
    }

    @wire(getGiftAidStatus)
    wiredGiftAid({ data, error }) {
        this.giftAidLoading = false;
        if (data) {
            const maxAmt = Math.max(...data.map(d => d.amount || 0), 1);
            this.giftAidStatus = data.map((d, i) => ({
                label: d.label || 'Unknown',
                amount: d.amount || 0,
                count: d.count || 0,
                formattedAmount: this.formatCurrency(d.amount || 0),
                color: CHART_COLORS[i % CHART_COLORS.length],
                swatchStyle: `background-color: ${CHART_COLORS[i % CHART_COLORS.length]};`,
                barStyle: `width: ${((d.amount || 0) / maxAmt) * 100}%; background: linear-gradient(90deg, ${CHART_COLORS[i % CHART_COLORS.length]}, ${CHART_COLORS[(i + 1) % CHART_COLORS.length]});`,
                key: 'ga-' + i
            }));
            this.giftAidError = undefined;
        } else if (error) {
            this.giftAidError = this.reduceError(error);
        }
    }

    @wire(getCrewsByRegatta)
    wiredCrews({ data, error }) {
        this.crewsLoading = false;
        if (data) {
            const max = Math.max(...data.map(d => d.value), 1);
            this.crewsByRegatta = data.map((d, i) => ({
                label: d.label || 'Unknown',
                value: d.value,
                barStyle: `width: ${(d.value / max) * 100}%;`,
                key: 'crew-' + i
            }));
            this.crewsError = undefined;
        } else if (error) {
            this.crewsError = this.reduceError(error);
        }
    }

    @wire(getEventAttendance)
    wiredEvents({ data, error }) {
        this.eventsLoading = false;
        if (data) {
            const max = Math.max(...data.map(d => d.attendeeCount), 1);
            this.eventAttendance = data.map((d, i) => ({
                eventName: d.eventName,
                eventId: d.eventId,
                attendeeCount: d.attendeeCount,
                barStyle: `width: ${(d.attendeeCount / max) * 100}%;`,
                startDate: this.formatDate(d.startDate),
                key: 'evt-' + i
            }));
            this.eventsError = undefined;
        } else if (error) {
            this.eventsError = this.reduceError(error);
        }
    }

    @wire(getActiveCampaigns)
    wiredCampaigns({ data, error }) {
        this.campaignsLoading = false;
        if (data) {
            this.activeCampaigns = data.map((c, i) => ({
                Id: c.Id,
                Name: c.Name,
                linkUrl: '/' + c.Id,
                type: c.Type || '',
                status: c.Status || '',
                startDate: this.formatDate(c.StartDate),
                endDate: this.formatDate(c.EndDate),
                members: (c.NumberOfContacts || 0) + (c.NumberOfLeads || 0),
                key: 'camp-' + i
            }));
            this.campaignsError = undefined;
        } else if (error) {
            this.campaignsError = this.reduceError(error);
        }
    }

    @wire(getUpgradeProspects)
    wiredProspects({ data, error }) {
        this.prospectsLoading = false;
        if (data) {
            this.upgradeProspects = data.map((c, i) => ({
                Id: c.Id,
                Name: c.Name,
                linkUrl: '/' + c.Id,
                trustId: c.ULBC_Trust_ID__c || '',
                tier: c.ULBC_Donor_Tier__c || '',
                giving: this.formatCurrency(c.ULBC_Rolling_12m_Giving__c || 0),
                key: 'up-' + i
            }));
            this.prospectsError = undefined;
        } else if (error) {
            this.prospectsError = this.reduceError(error);
        }
    }

    @wire(getLapsedDonors)
    wiredLapsed({ data, error }) {
        this.lapsedLoading = false;
        if (data) {
            this.lapsedDonors = data.map((c, i) => ({
                Id: c.Id,
                Name: c.Name,
                linkUrl: '/' + c.Id,
                trustId: c.ULBC_Trust_ID__c || '',
                lastGift: this.formatDate(c.ULBC_Last_Gift_Date__c),
                giving: this.formatCurrency(c.ULBC_Rolling_12m_Giving__c || 0),
                key: 'lp-' + i
            }));
            this.lapsedError = undefined;
        } else if (error) {
            this.lapsedError = this.reduceError(error);
        }
    }

    @wire(getRecentDonations)
    wiredDonations({ data, error }) {
        this.donationsLoading = false;
        if (data) {
            this.recentDonations = data.map((d, i) => ({
                name: d.name || '',
                amount: this.formatCurrency(d.amount || 0),
                closeDate: this.formatDate(d.closeDate),
                fundName: d.fundName || '',
                contactName: d.contactName || '',
                contactUrl: d.contactId ? '/' + d.contactId : '',
                hasContactLink: !!d.contactId,
                key: 'rd-' + i
            }));
            this.donationsError = undefined;
        } else if (error) {
            this.donationsError = this.reduceError(error);
        }
    }

    // --- KPI Getters ---
    get totalContacts() { return this.formatNumber(this.kpiMetrics.totalContacts || 0); }
    get totalDonors() { return this.formatNumber(this.kpiMetrics.totalDonors || 0); }
    get giftsThisYear() { return this.formatCurrency(this.kpiMetrics.giftsThisYear || 0); }
    get giftsLastYear() { return this.formatCurrency(this.kpiMetrics.giftsLastYear || 0); }
    get totalGiftsAllTime() { return this.formatCurrency(this.kpiMetrics.totalGiftsAllTime || 0); }
    get lapsedCount() { return this.formatNumber(this.kpiMetrics.lapsedCount || 0); }
    get upgradeProspectCount() { return this.formatNumber(this.kpiMetrics.upgradeProspectCount || 0); }

    // --- SVG Donut Helpers ---
    _polar(cx, cy, r, deg) {
        const rad = (deg - 90) * Math.PI / 180;
        return { x: cx + r * Math.cos(rad), y: cy + r * Math.sin(rad) };
    }

    _arc(cx, cy, outerR, innerR, startA, endA) {
        if (endA - startA >= 359.99) endA = startA + 359.99;
        const os = this._polar(cx, cy, outerR, startA);
        const oe = this._polar(cx, cy, outerR, endA);
        const ie = this._polar(cx, cy, innerR, endA);
        const is_ = this._polar(cx, cy, innerR, startA);
        const lg = (endA - startA) > 180 ? 1 : 0;
        return `M ${os.x} ${os.y} A ${outerR} ${outerR} 0 ${lg} 1 ${oe.x} ${oe.y} L ${ie.x} ${ie.y} A ${innerR} ${innerR} 0 ${lg} 0 ${is_.x} ${is_.y} Z`;
    }

    _svgDonut(data, valueField) {
        const cx = 100, cy = 100, outerR = 80, innerR = 50, labelR = 65;
        const total = data.reduce((s, d) => s + (d[valueField] || 0), 0);
        if (total === 0) return [];
        let cumAngle = 0;
        return data.map((d, i) => {
            const val = d[valueField] || 0;
            const pct = (val / total) * 100;
            const angle = (pct / 100) * 360;
            const startA = cumAngle;
            const endA = cumAngle + angle;
            const midA = (startA + endA) / 2;
            const lp = this._polar(cx, cy, labelR, midA);
            cumAngle = endA;
            return {
                path: this._arc(cx, cy, outerR, innerR, startA, endA),
                color: d.color || CHART_COLORS[i % CHART_COLORS.length],
                label: d.label || 'Unknown',
                pct: pct.toFixed(0),
                labelX: lp.x.toFixed(1),
                labelY: lp.y.toFixed(1),
                showLabel: pct >= 8,
                labelText: `${pct.toFixed(0)}%`,
                key: 'seg-' + i,
                labelKey: 'sl-' + i,
                dataValue: d.label || ''
            };
        });
    }

    get tierSvgSegments() {
        if (!this.donorsByTier || !this.donorsByTier.length) return [];
        return this._svgDonut(this.donorsByTier, 'value');
    }

    get tierSvgLabels() {
        return this.tierSvgSegments.filter(s => s.showLabel);
    }

    // --- SVG Line Chart ---
    get svgPolylinePoints() {
        if (!this.giftsByYear || this.giftsByYear.length < 2) return '';
        const amounts = this.giftsByYear.map(d => d.amount);
        const maxAmt = Math.max(...amounts, 1);
        const width = 400, height = 180, padding = 30;
        const plotW = width - padding * 2;
        const plotH = height - padding * 2;
        const step = plotW / (this.giftsByYear.length - 1);
        return this.giftsByYear.map((d, i) => {
            const x = padding + i * step;
            const y = padding + plotH - (d.amount / maxAmt) * plotH;
            return `${x},${y}`;
        }).join(' ');
    }

    get svgDots() {
        if (!this.giftsByYear || this.giftsByYear.length < 2) return [];
        const amounts = this.giftsByYear.map(d => d.amount);
        const maxAmt = Math.max(...amounts, 1);
        const width = 400, height = 180, padding = 30;
        const plotW = width - padding * 2;
        const plotH = height - padding * 2;
        const step = plotW / (this.giftsByYear.length - 1);
        return this.giftsByYear.map((d, i) => ({
            cx: padding + i * step,
            cy: padding + plotH - (d.amount / maxAmt) * plotH,
            key: 'dot-' + i
        }));
    }

    get svgYearLabels() {
        if (!this.giftsByYear || this.giftsByYear.length < 2) return [];
        const width = 400, height = 180, padding = 30;
        const plotW = width - padding * 2;
        const step = plotW / (this.giftsByYear.length - 1);
        const len = this.giftsByYear.length;
        const showEvery = len > 20 ? 5 : len > 12 ? 4 : len > 8 ? 3 : len > 5 ? 2 : 1;
        return this.giftsByYear.map((d, i) => ({
            x: padding + i * step,
            y: height - 3,
            label: String(d.year),
            key: 'ylbl-' + i,
            show: (i % showEvery === 0 || i === len - 1)
        })).filter(l => l.show);
    }

    get svgAmountLabels() {
        if (!this.giftsByYear || this.giftsByYear.length < 2) return [];
        const amounts = this.giftsByYear.map(d => d.amount);
        const maxAmt = Math.max(...amounts, 1);
        const width = 400, height = 180, padding = 30;
        const plotW = width - padding * 2;
        const plotH = height - padding * 2;
        const step = plotW / (this.giftsByYear.length - 1);
        const len = this.giftsByYear.length;
        const showEvery = len > 20 ? 5 : len > 12 ? 4 : len > 8 ? 3 : len > 5 ? 2 : 1;
        return this.giftsByYear.map((d, i) => ({
            x: padding + i * step,
            y: padding + plotH - (d.amount / maxAmt) * plotH - 6,
            label: this.formatCurrencyShort(d.amount),
            key: 'albl-' + i,
            show: (i % showEvery === 0 || i === len - 1)
        })).filter(l => l.show);
    }

    // --- Has* Getters ---
    get hasYearData() { return this.giftsByYear && this.giftsByYear.length >= 2; }
    get hasTierData() { return this.donorsByTier && this.donorsByTier.length > 0; }
    get hasFundData() { return this.donationsByFund && this.donationsByFund.length > 0; }
    get hasGiftAidData() { return this.giftAidStatus && this.giftAidStatus.length > 0; }
    get hasCrewData() { return this.crewsByRegatta && this.crewsByRegatta.length > 0; }
    get hasEventData() { return this.eventAttendance && this.eventAttendance.length > 0; }
    get hasCampaignData() { return this.activeCampaigns && this.activeCampaigns.length > 0; }
    get hasProspectData() { return this.upgradeProspects && this.upgradeProspects.length > 0; }
    get hasLapsedData() { return this.lapsedDonors && this.lapsedDonors.length > 0; }
    get hasDonationData() { return this.recentDonations && this.recentDonations.length > 0; }

    // --- Report Navigation ---
    _goToReport(devName, fvIndex, fvValue) {
        const rid = this.reportIds[devName];
        if (!rid) return;
        let url = '/lightning/r/Report/' + rid + '/view';
        if (fvIndex !== undefined && fvValue != null && fvValue !== '') {
            url += '?fv' + fvIndex + '=' + encodeURIComponent(fvValue);
        }
        // eslint-disable-next-line no-restricted-properties
        window.location.href = url;
    }

    handleTierClick(event) {
        this._goToReport('ULBC_Donors_By_Tier', 0, event.currentTarget.dataset.tier);
    }

    handleFundClick() {
        this._goToReport('ULBC_Donations_By_Fund');
    }

    handleYearClick() {
        this._goToReport('ULBC_Gifts_By_Year');
    }

    handleCrewClick(event) {
        this._goToReport('ULBC_Crews_By_Regatta', 0, event.currentTarget.dataset.regatta);
    }

    handleGiftAidClick() {
        this._goToReport('ULBC_Gift_Aid_Status');
    }

    handleEventClick(event) {
        const eventId = event.currentTarget.dataset.eventid;
        if (eventId) {
            window.location.href = '/' + eventId;
        }
    }

    // --- Formatting ---
    formatNumber(val) {
        if (val == null) return '0';
        return Number(val).toLocaleString('en-GB');
    }

    formatCurrency(val) {
        if (val == null) return '\u00A30';
        return '\u00A3' + Number(val).toLocaleString('en-GB', {
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        });
    }

    formatCurrencyShort(val) {
        if (val == null) return '\u00A30';
        if (val >= 1000000) return '\u00A3' + (val / 1000000).toFixed(1) + 'M';
        if (val >= 1000) return '\u00A3' + (val / 1000).toFixed(0) + 'k';
        return '\u00A3' + Number(val).toFixed(0);
    }

    formatDate(val) {
        if (!val) return '';
        const d = new Date(val);
        return d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
    }

    reduceError(error) {
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return 'Unknown error';
    }
}
