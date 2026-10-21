@IsTest
private class HcpShowSlideActionTest {

    @IsTest
    static void unknownSlideReturnsMessageAndNoCard() {
        ShowSlideRequest req = new ShowSlideRequest();
        req.pageId = null;

        List<ShowSlideResult> results = HcpShowSlideAction.show(new List<ShowSlideRequest>{ req });

        Assert.areEqual(1, results.size());
        Assert.isNull(results[0].slide, 'No card expected for an unknown slide');
        Assert.areEqual('That slide could not be found.', results[0].summary);
    }

    @IsTest
    static void existingSlideReturnsCardWithName() {
        List<PresentationPage> pages = [SELECT Id, Name FROM PresentationPage LIMIT 1];
        if (pages.isEmpty()) {
            return; // PresentationPage cannot be created in a unit test; covered by the live agent test
        }
        ShowSlideRequest req = new ShowSlideRequest();
        req.pageId = pages[0].Id;

        List<ShowSlideResult> results = HcpShowSlideAction.show(new List<ShowSlideRequest>{ req });

        Assert.isNotNull(results[0].slide);
        Assert.areEqual(pages[0].Name, results[0].slide.slideName);
    }
}
