## PRD

1. In ChatView, You will have a button as microphone icon.
2. And long press it, will start recording.
3. When you release the button, it will stop recording.
4. After the recording is stopped, will use whisper of OpenAI to transcribe the recording.
5. Submit the text just like a chat message.


## Development

1. Add a new button in Debug Context Menu of ChatView: "View Recording Files".
2. And will render a new view: FilesView will display all the files in the app's document directory "/recordings".
3. FilesView will display order by update date desc.
4. Click a file, will play the audio.
5. After the recording is stopped, will save the audio to the document directory "/recordings" with name as UUID.
