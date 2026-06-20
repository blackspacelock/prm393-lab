# Update UI and additional page requirement

--

## 1. UI update

### FR-01 - The screen new UI 

**Priority:** High

**Description:**
The screen UI should show only four main page include: Home, Journals, Keywords, Profile
+ The "Home" page is the current "Trending" page
+ The "Journals" page is a new page which defaultly display a list of lately active journals [details in FR.03]
+ The "Keywords" page is the current "Search" page but will be integrated with the current "Dashboard", "Heatmap", "Network" page[details in FR.??]
+ The profile page is a new page which will display the user profile [will be implemented later]

### FR-02 - UI button

**Priority:** High

**Description:**
- Move all the button in the top left corner or right left corner of all page:
+ The "Search" page: The current Topic hierarchy with burger icon button in the top left corner will be move to below the search bar and display as a button with name "Topic hierarchy" with current icon in front of it ; the filter button in top right corner will be move next to the new "Topic hierarchy" button with the name "Filter" with current icon in front of it 
+ The "Saved" page (which will become a tab of the new "Profile" page): move the "Clear all" button under the search bar and the current filter button
+ The "Dashboard" page (which will become a tab of the new "Keyword" page): Move the "Filter by year range" icon button to inside the page and display it like a 1 row button name "Filter by year range

### FR-03 - Journals page 

**Priority:** Medium

**Description:**
- The Journal page should have a search bar to search for Journal's name
- The Journal page should have filter 
- Each search result journal must be clickable and display a page show detail of the journals and 2 tabs bar
+ Authors list: show the authors list which have paper belongs to the journals (the list result is clickable and when click on it will show the list of all the author's paper, display like the paper list when click in the Author node of the "Author nertwork" page)
+ Paper list: show the paper list belongs to the journals (the list result is clickable and view with paper detail page, it display 50 results at first and a "Show more" button to show the next 50 and click again to show next 50 until all showed)

### FR-04 - New  intergarated Keyword page

**Priority:** High

**Description:**
- This is the current "Search" page but name will be changed to "Keyword" and have 4 tabs bar below the search bar and buttons, which is the Keyword it selft and three current page "Dashboard", "Heatmap", "Network"

### FR-04 - Profile page

**Priority:** Low

**Description:**
- This will be the future page where user can login and custom their account profile
- Currently, just display the Saved page for it