## Chat History

### Where to save?

Save to directory: `/chatHistorys`

### What's the format?

fileName: `chatHistory_${id}.json`
content: 
  title: string default is "New Chat at ${date}". the date is in native format.
  messageList: the json of messageList in ChatView.swift

### How to read?

1. App will save a currentChatHistoryId in session, which means after app is off, the currentChatHistoryId will be lost.
2. when currentChatHistoryId is nil, we will show a new chat history view.
3. when currentChatHistoryId is not nil, we will show the chat history view of the id.
4. On the top left of ChatView, there is a button to show left drawer view
  1. drawer view will display the list of chatHistorys order by update date desc.
  2. at the bottom of drawer view, it is a area fixed, and debug button will be there. and debug button will show as a icon, and the menu will be show after click not the long press.

### How to delete it?
1. in drawer view, long press a chatHistory, will show a list of menu.
  1. rename
  2. delete

### How to add it?
1. at top right of ChatView, there is a button to add chat history.No clear button.
