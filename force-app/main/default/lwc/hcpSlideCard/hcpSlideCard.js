import { LightningElement, api } from 'lwc';

/**
 * Renders a presentation slide card inside the HCP portal chat (Enhanced Web Chat). The platform sets `value`
 * to the PresentationRecommendationWrapper returned by HcpShowSlideAction (object or JSON string).
 */
export default class HcpSlideCard extends LightningElement {
    @api value;

    get slide() {
        const raw = this.value;
        if (raw == null) {
            return null;
        }
        if (typeof raw === 'string') {
            try {
                return raw.trim() ? JSON.parse(raw) : null;
            } catch (e) {
                return null;
            }
        }
        return typeof raw === 'object' ? raw : null;
    }

    get hasSlide() {
        return !!this.slide?.slideName;
    }

    get slideName() {
        return this.slide?.slideName ?? '';
    }

    get presentationName() {
        return this.slide?.presentationName ?? '';
    }

    get pageNumber() {
        return this.slide?.pageNumber ?? '';
    }

    get thumbnailUrl() {
        return this.slide?.thumbnailUrl ?? '';
    }

    get hasThumbnail() {
        return !!this.thumbnailUrl;
    }
}
