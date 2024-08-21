async function closeDuplicateTabs() {
/*
  try {
        const tabs = await browser.tabs.query({});
        const uniqueUrls = new Set();
        const duplicateTabs = [];
        let initialTabCount = tabs.length;

        for (const tab of tabs) {
            if (uniqueUrls.has(tab.url)) {
                duplicateTabs.push(tab.id);
            } else {
                uniqueUrls.add(tab.url);
            }
        }

        let duplicatesCount = duplicateTabs.length;

        for (const tabId of duplicateTabs) {
            await browser.tabs.remove(tabId);
        }

        let finalTabCount = initialTabCount - duplicatesCount;

        console.log(`Initial Tab Count: ${initialTabCount}`);
        console.log(`Duplicates Found: ${duplicatesCount}`);
        console.log(`Tabs Closed: ${duplicatesCount}`);
        console.log(`Final Tab Count: ${finalTabCount}`);
    } catch (error) {
        console.error('Error closing duplicate tabs:', error);
    }
*/

  console.log("Inside closeDuplicateTabs");
}

