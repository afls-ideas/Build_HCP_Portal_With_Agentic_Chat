import { LightningElement } from 'lwc';
import LOGO from '@salesforce/resourceUrl/hcp_logo';
import HERO_BG from '@salesforce/resourceUrl/hcp_hero_bg';
import HERO_DOCTOR from '@salesforce/resourceUrl/hcp_hero_doctor';

export default class HcpLoginHero extends LightningElement {
    logo = LOGO;

    get heroStyle() {
        return `background-image: linear-gradient(100deg, rgba(8, 22, 44, 0.92) 25%, rgba(8, 22, 44, 0.35) 100%), url(${HERO_BG});`;
    }

    get doctorStyle() {
        return `background-image: url(${HERO_DOCTOR});`;
    }
}
