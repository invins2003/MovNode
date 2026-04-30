import axios from 'axios';

async function testDecryption() {
    // Capture from subagent earlier
    const embedUrl = 'https://ployan.live/get/83579481a8cc35d8-818c617e1f9a911e86e72277-1e30ee9ad6d0073aad90707a87ffc6987968b64750003dbc8f80b8b4ce4c3406f499d4';
    const userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

    console.log(`Testing decryption at: ${embedUrl}`);
    
    try {
        const { data: html } = await axios.get(embedUrl, {
            headers: {
                'User-Agent': userAgent,
                'Referer': 'https://flixhqz.com/'
            }
        });

        const nonceRegex48 = /\b[a-zA-Z0-9]{48}\b/;
        const nonceRegex16 = /\b([a-zA-Z0-9]{16})\b.*?\b([a-zA-Z0-9]{16})\b.*?\b([a-zA-Z0-9]{16})\b/;

        let nonce;
        const match48 = html.match(nonceRegex48);
        if (match48) {
            nonce = match48[0];
            console.log(`✅ Found 48-char nonce: ${nonce}`);
        } else {
            const match16 = html.match(nonceRegex16);
            if (match16) {
                nonce = match16[1] + match16[2] + match16[3];
                console.log(`✅ Found combined 16-char nonce: ${nonce}`);
            }
        }

        if (!nonce) {
            console.error('❌ Nonce not found in HTML');
            return;
        }

        const urlObj = new URL(embedUrl);
        const embedHost = `${urlObj.protocol}//${urlObj.host}`;
        const fileId = urlObj.pathname.split('/').pop();
        
        // Try paths from repo
        const apiPath = '/embed-1/v3/e-1/getSources';
        const apiUrl = `${embedHost}${apiPath}?id=${fileId}&_k=${nonce}`;
        
        console.log(`Trying API call: ${apiUrl}`);
        
        const { data: apiRes } = await axios.get(apiUrl, {
            headers: {
                'Referer': embedHost + '/',
                'X-Requested-With': 'XMLHttpRequest',
                'User-Agent': userAgent
            }
        });

        if (apiRes.sources) {
            console.log('🎉 SUCCESS! Found sources:', apiRes.sources);
        } else {
            console.log('❌ API responded but no sources found.');
        }

    } catch (e) {
        console.error(`Decryption failed: ${e.message}`);
    }
}

testDecryption();
