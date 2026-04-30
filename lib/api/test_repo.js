import axios from 'axios';
import * as cheerio from 'cheerio';

async function testSearch() {
    const baseUrl = 'https://flixhqz.com';
    const query = 'Matrix';
    const url = `${baseUrl}/search/?q=${encodeURIComponent(query)}`;
    
    console.log(`Testing search at: ${url}`);
    
    try {
        const { data } = await axios.get(url, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'
            }
        });
        
        const $ = cheerio.load(data);
        const results = $('.flw-item');
        console.log(`Found ${results.length} results.`);
        
        results.each((_, el) => {
            const title = $(el).find('.film-name a').text().trim();
            console.log(`- ${title}`);
        });
    } catch (e) {
        console.error(`Search failed: ${e.message}`);
    }
}

testSearch();
