// One-time setup (run as an admin): create public content-distribution links for the Immunexis slide thumbnails so the
// HCP portal chat can show them. HcpShowSlideAction only READS these links; it never creates them at chat time.
// The agent user can neither create ContentDistribution rows nor read their fields, so each slide's public download URL is
// also written to the HCP_Slide_Thumbnail__c list custom setting (Name = PresentationPage Id), which the action reads.
// Re-runnable: existing links are not recreated and the settings are refreshed every run.
Set<Id> pageIds = new Set<Id>();
for (PresentationLinkedPage lp : [SELECT PresentationPageId FROM PresentationLinkedPage WHERE Presentation.Name = 'Immunexis']) {
    pageIds.add(lp.PresentationPageId);
}
Map<Id, Id> versionByDoc = new Map<Id, Id>();
for (ContentDocumentLink cdl : [
    SELECT ContentDocument.LatestPublishedVersionId FROM ContentDocumentLink
    WHERE LinkedEntityId IN :pageIds AND ContentDocument.FileType IN ('JPG', 'JPEG', 'PNG')
]) {
    versionByDoc.put(cdl.ContentDocumentId, cdl.ContentDocument.LatestPublishedVersionId);
}
Set<Id> haveLink = new Set<Id>();
for (ContentDistribution cd : [SELECT ContentVersionId FROM ContentDistribution WHERE ContentVersionId IN :versionByDoc.values()]) {
    haveLink.add(cd.ContentVersionId);
}
List<ContentDistribution> toCreate = new List<ContentDistribution>();
for (Id versionId : new Set<Id>(versionByDoc.values())) {
    if (!haveLink.contains(versionId)) {
        toCreate.add(new ContentDistribution(
            Name = 'HCP slide thumbnail ' + versionId, ContentVersionId = versionId,
            PreferencesAllowViewInBrowser = true, PreferencesLinkLatestVersion = true, PreferencesNotifyOnVisit = false));
    }
}
insert toCreate;
System.debug('Immunexis thumbnails: ' + versionByDoc.size() + ' found, ' + toCreate.size() + ' links created');
Map<Id, String> urlByVersion = new Map<Id, String>();
for (ContentDistribution cd : [SELECT ContentVersionId, ContentDownloadUrl FROM ContentDistribution WHERE ContentVersionId IN :versionByDoc.values()]) {
    urlByVersion.put(cd.ContentVersionId, cd.ContentDownloadUrl);
}
Map<Id, String> titleByPage = new Map<Id, String>();
for (PresentationPage pp : [SELECT Id, Name FROM PresentationPage WHERE Id IN :pageIds]) {
    titleByPage.put(pp.Id, pp.Name);
}
Map<String, HCP_Slide_Thumbnail__c> settings = new Map<String, HCP_Slide_Thumbnail__c>();
for (ContentDocumentLink cdl : [
    SELECT LinkedEntityId, ContentDocument.LatestPublishedVersionId FROM ContentDocumentLink
    WHERE LinkedEntityId IN :pageIds AND ContentDocument.FileType IN ('JPG', 'JPEG', 'PNG')
]) {
    String url = urlByVersion.get(cdl.ContentDocument.LatestPublishedVersionId);
    if (url != null) {
        settings.put(String.valueOf(cdl.LinkedEntityId), new HCP_Slide_Thumbnail__c(Name = String.valueOf(cdl.LinkedEntityId), Thumbnail_Url__c = url, Title__c = titleByPage.get(cdl.LinkedEntityId)));
    }
}
delete [SELECT Id FROM HCP_Slide_Thumbnail__c];
insert settings.values();
System.debug('Thumbnail URLs stored in ' + settings.size() + ' HCP_Slide_Thumbnail__c settings');
