import axios from 'axios';

async function testSearch() {
    const baseUrl = 'https://flixhqz.com';
    const query = 'Matrix';
    const url = `${baseUrl}/search/${query}`;
    
    console.log(`Testing search at: ${url}`);
    
    try {
        const { data } = await axios.get(url, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'
            }
        });
        
        console.log(data.substring(0, 1500));
    } catch (e) {
        console.error(`Search failed: ${e.message}`);
    }
}

testSearch();
