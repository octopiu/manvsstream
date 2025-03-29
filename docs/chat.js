export class YoutubeChat {
    constructor (vid) {
        this.chat_url = `https://www.youtube.com/youtubei/v1/live_chat/get_live_chat?key=${vid}`
    }
    async getMessages () {
        const res = await fetch(this.chat_url, {
            method: 'POST',
            webClientInfo: { isDocumentHidden: false },
            headers: {
                'Content-Type': 'application/json',
            },
        })
        console.log(await res.text())
    }
}