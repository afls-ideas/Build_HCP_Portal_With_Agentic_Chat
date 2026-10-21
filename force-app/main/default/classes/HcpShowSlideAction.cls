/**
 * Shows a presentation slide inline in the HCP portal chat. Same card payload as ShowSlideAction
 * (PresentationRecommendationWrapper), but the thumbnail is served through a pre-created ContentDistribution link:
 * the agent runs Apex as its agent user while the image is fetched by the portal visitor's browser, so a
 * session-authenticated /sfc/servlet.shepherd URL (what ShowSlideAction returns) would not load for a portal user.
 * Top-level global + @JsonAccess is what lets the @apexClassType binding resolve.
 */
@JsonAccess(serializable='always' deserializable='always')
global with sharing class HcpShowSlideAction {

    @InvocableMethod(label='Show Slide to HCP' description='Shows a presentation slide and its thumbnail image inline in the HCP portal chat')
    global static List<ShowSlideResult> show(List<ShowSlideRequest> requests) {
        List<ShowSlideResult> results = new List<ShowSlideResult>();
        for (ShowSlideRequest req : requests) {
            results.add(showOne(req));
        }
        return results;
    }

    private static ShowSlideResult showOne(ShowSlideRequest req) {
        ShowSlideResult res = new ShowSlideResult();
        List<PresentationPage> pages = String.isBlank(req.pageId) ? new List<PresentationPage>() : [
            SELECT Id, Name, PageNumber FROM PresentationPage WHERE Id = :req.pageId LIMIT 1
        ];
        if (pages.isEmpty()) {
            res.summary = 'That slide could not be found.';
            return res;
        }
        PresentationPage page = pages[0];

        PresentationRecommendationWrapper slide = new PresentationRecommendationWrapper();
        slide.slideName = page.Name;
        slide.pageNumber = page.PageNumber != null ? page.PageNumber.intValue() : null;
        try {
            slide.thumbnailUrl = thumbnailUrlFor(page.Id);
        } catch (Exception e) {
            // A missing thumbnail must not fail the action: the agent would retry it in a loop. The card shows a placeholder.
            slide.thumbnailUrl = null;
        }

        List<PresentationLinkedPage> links = [
            SELECT Presentation.Name FROM PresentationLinkedPage WHERE PresentationPageId = :page.Id LIMIT 1
        ];
        if (!links.isEmpty() && links[0].Presentation != null) {
            slide.presentationName = links[0].Presentation.Name;
        }

        res.slide = slide;
        res.summary = 'Showing slide "' + page.Name + '".';
        return res;
    }

    /**
     * The agent user can neither create ContentDistribution rows nor read their fields (it sees blank shells), so the
     * public thumbnail URL per slide is kept in the HCP_Slide_Thumbnail__c list custom setting, written by an admin
     * (scripts/apex/publishImmunexisThumbnails.apex). Null when a slide has none; the card shows a placeholder.
     */
    private static String thumbnailUrlFor(Id presentationPageId) {
        HCP_Slide_Thumbnail__c thumbnail = HCP_Slide_Thumbnail__c.getValues(String.valueOf(presentationPageId));
        return thumbnail == null ? null : thumbnail.Thumbnail_Url__c;
    }
}
