import { search, getTVDetails, getEpisodes, getEmbedLink } from './scraper.js';

async function test() {
  console.log('--- Testing Search (Inception) ---');
  const results = await search('Inception');
  console.log('Results Count:', results.length);
  const movie = results.find(r => r.type === 'Movie');
  if (movie) {
    console.log('Found Movie:', movie.title, 'ID:', movie.id, 'Date:', movie.releaseDate);
    const sources = getEmbedLink('Movie', movie.id);
    console.log('Default Embed Link:', sources.vidsrc);
    console.log('VsEmbed Link:', sources.vsembed);
  }

  console.log('\n--- Testing Series (The Boys) ---');
  const seriesResults = await search('The Boys');
  const series = seriesResults.find(r => r.type === 'TV Series');
  if (series) {
    console.log('Found Series:', series.title, 'ID:', series.id);
    const seasons = await getTVDetails(series.id);
    console.log('Seasons Count:', seasons.length);
    if (seasons.length > 0) {
      console.log('First Season:', seasons[0].title);
      const episodes = await getEpisodes(series.id, seasons[0].number);
      console.log('Episodes in S1:', episodes.length);
      if (episodes.length > 0) {
        console.log('First Episode:', episodes[0].title);
        const epSources = getEmbedLink('TV Series', series.id, seasons[0].number, episodes[0].number);
        console.log('Default Episode Embed Link:', epSources.vidsrc);
        console.log('VsEmbed Episode Link:', epSources.vsembed);
      }
    }
  }
}

test().catch(console.error);
