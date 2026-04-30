import https from 'https';

async function testExtraction() {
    console.log('--- STEALTH EXTRACTION TEST ---');
    
    // We try a different decoder or a direct source if possible
    // But since eatmynerds.live is blocking us, we will try to sniff a public embed
    const testUrl = 'https://vidsrc.to/embed/movie/12009'; // John Wick 2
    
    console.log(`[STEP] Testing if we can reach Vidsrc: ${testUrl}`);
    
    const options = {
        headers: { 
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://vidsrc.to/'
        }
    };

    https.get(testUrl, options, (res) => {
        console.log(`\n[RESULT] Status: ${res.statusCode}`);
        if (res.statusCode === 200) {
            console.log('✅ Success: Site reached!');
        } else if (res.statusCode === 403 || res.statusCode === 503) {
            console.log('❌ Blocked by Cloudflare (403/503)');
        } else {
            console.log(`❌ Failed: Status ${res.statusCode}`);
        }
    }).on('error', (err) => {
        console.log(`\n❌ Connection Error: ${err.message}`);
    });
}

testExtraction();
