import { LightningElement, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { loadScript } from 'lightning/platformResourceLoader';
import CHAT_INIT from '@salesforce/resourceUrl/hcpChatInit';
import getSlides from '@salesforce/apex/HcpPortalController.getSlides';
import LOGO from '@salesforce/resourceUrl/hcp_logo';
import HERO_BG from '@salesforce/resourceUrl/hcp_hero_bg';
import HERO_DOCTOR from '@salesforce/resourceUrl/hcp_hero_doctor';
import AGENT_BAND from '@salesforce/resourceUrl/hcp_agent_band';
import USER_ID from '@salesforce/user/Id';
import FIRST_NAME from '@salesforce/schema/User.FirstName';

const SITE_PATH = '/hcpportal';

const TOPICS = [
    { key: 'overview', slide: 'Immunexis Overview', title: 'Overview', tag: 'Mechanism of action', question: 'How does Immunexis work?', icon: 'M12 2l9 5v10l-9 5-9-5V7z' },
    { key: 'efficacy', slide: 'Immunexis Efficacy', title: 'Efficacy', tag: 'Clinical remission', question: 'How fast does Immunexis start working?', icon: 'M3 17l6-6 4 4 8-8M15 7h6v6' },
    { key: 'safety', slide: 'Immunexis Safety', title: 'Safety', tag: 'Adverse events', question: 'What are the side effects?', icon: 'M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z' },
    { key: 'dosing', slide: 'Immunexis Dosing', title: 'Dosing & Administration', tag: 'Dose and sites', question: 'Where should I administer the drug?', icon: 'M5 19L19 5M14 4l6 6M4 14l6 6' },
    { key: 'resources', slide: 'Immunexis Resources', title: 'Patient Resources', tag: 'Support and savings', question: 'Is there a co-pay savings card for patients?', icon: 'M4 5h16v14H4zM4 9h16M9 14h6' }
];

export default class HcpPortalHome extends LightningElement {
    logo = LOGO;
    slides = [];
    helpMessage = '';

    @wire(getRecord, { recordId: USER_ID, fields: [FIRST_NAME] })
    user;

    renderedCallback() {
        if (this.chatRequested) {
            return;
        }
        this.chatRequested = true;
        loadScript(this, CHAT_INIT).catch((e) => {
            // eslint-disable-next-line no-console
            console.error('Chat init failed', e);
        });
    }

    @wire(getSlides)
    wiredSlides({ data }) {
        this.slides = data || [];
    }

    get topics() {
        const urlByTitle = {};
        this.slides.forEach((s) => {
            urlByTitle[s.title] = s.thumbnailUrl;
        });
        return TOPICS.map((t) => ({ ...t, thumbnailUrl: urlByTitle[t.slide], hasThumbnail: !!urlByTitle[t.slide] }));
    }

    get heroStyle() {
        return `background-image: linear-gradient(100deg, rgba(8, 22, 44, 0.92) 25%, rgba(8, 22, 44, 0.35) 100%), url(${HERO_BG});`;
    }

    get doctorStyle() {
        return `background-image: url(${HERO_DOCTOR});`;
    }

    get bandStyle() {
        return `background-image: linear-gradient(90deg, rgba(8, 22, 44, 0.78), rgba(8, 22, 44, 0.35)), url(${AGENT_BAND});`;
    }

    get greeting() {
        const first = this.user?.data?.fields?.FirstName?.value;
        return first ? `Welcome back, ${first}` : 'Welcome back';
    }

    get logoutUrl() {
        return `${SITE_PATH}/secur/logout.jsp`;
    }

    get year() {
        return new Date().getFullYear();
    }

    // The chat widget lives outside this component, so launching it is best effort; the hint covers the fallback.
    openChat() {
        let launched = false;
        try {
            const bootstrap = window.embeddedservice_bootstrap;
            if (bootstrap?.utilAPI?.launchChat) {
                bootstrap.utilAPI.launchChat();
                launched = true;
            }
        } catch (e) {
            launched = false;
        }
        this.helpMessage = launched ? '' : 'Use the chat button at the bottom right of the page to start.';
    }

    handleTopic(event) {
        this.selectedQuestion = event.currentTarget.dataset.question;
        this.helpMessage = `Ask the agent: "${this.selectedQuestion}"`;
        this.openChat();
        if (!this.helpMessage) {
            this.helpMessage = `Ask the agent: "${this.selectedQuestion}"`;
        }
    }
}
