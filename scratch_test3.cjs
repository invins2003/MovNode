const cheerio = require('cheerio');
const fs = require('fs');
const html = fs.readFileSync('episodes_test.html', 'utf8');
const $ = cheerio.load(html);
const episodes = [];
$('*').each((i, el) => {
    const title = $(el).find('h3').text().trim();
    if (title && title.includes('Episode') || title.match(/^\\d+$/) || title.includes('1')) {
        // Just extract text from common episode card classes
    }
});
// let's just find all h3s
const h3s = [];
$('h3').each((i, el) => { h3s.push($(el).text().trim()); });
console.log('H3s:', h3s);

const h2s = [];
$('h2').each((i, el) => { h2s.push($(el).text().trim()); });
console.log('H2s:', h2s);

const episodeCards = [];
$('.card').each((i, el) => { episodeCards.push($(el).text().trim().substring(0, 50).replace(/\\n/g, ' ')); });
console.log('Cards:', episodeCards.length);

const wrappers = [];
$('.wrapper').each((i, el) => { wrappers.push($(el).text().trim().substring(0, 50).replace(/\\n/g, ' ')); });
console.log('Wrappers:', wrappers.length);

const info = [];
$('.info').each((i, el) => { info.push($(el).text().trim().substring(0, 50).replace(/\\n/g, ' ')); });
console.log('Info:', info.length);
