public with sharing class HcpPortalController {
    public class SlideInfo {
        @AuraEnabled public String title;
        @AuraEnabled public String thumbnailUrl;
    }

    // Slide titles and thumbnail links are stored in the HCP_Slide_Thumbnail__c setting by publishImmunexisThumbnails.apex,
    // because portal users cannot read PresentationPage or ContentDistribution.
    @AuraEnabled(cacheable=true)
    public static List<SlideInfo> getSlides() {
        List<SlideInfo> slides = new List<SlideInfo>();
        for (HCP_Slide_Thumbnail__c setting : HCP_Slide_Thumbnail__c.getAll().values()) {
            SlideInfo slide = new SlideInfo();
            slide.title = setting.Title__c;
            slide.thumbnailUrl = setting.Thumbnail_Url__c;
            slides.add(slide);
        }
        return slides;
    }
}
