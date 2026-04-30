import axios from 'axios';
import * as cheerio from 'cheerio';
import fs from 'fs';

const TMDB_BASE = 'https://www.themoviedb.org';

const client = axios.create({
  baseURL: TMDB_BASE,
  headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': 'https://www.themoviedb.org/',
  }
});

export const search = async (query) => {
  try {
    const { data } = await client.get(`/search?query=${encodeURIComponent(query)}`);
    const $ = cheerio.load(data);
    const results = [];

    // The selector from the HTML dump is .comp:media-card or similar
    $('[class*="media-card"]').each((i, el) => {
      const link = $(el).find('a[href*="/movie/"], a[href*="/tv/"]');
      const href = link.attr('href');
      if (!href) return;
      const title = $(el).find('h2').first().text().trim();
      const type = href.startsWith('/movie') ? 'Movie' : (href.startsWith('/tv') ? 'TV Series' : 'Unknown');
      
      const idMatch = href.match(/\/(movie|tv)\/(\d+)/);
      const id = idMatch ? idMatch[2] : null;
      
      if (!id) return;

      const releaseDate = $(el).find('.release_date').first().text().trim() || 'N/A';

      results.push({ title, type, id, href, releaseDate });
    });

    return results.filter(r => r.type !== 'Unknown');
  } catch (error) {
    console.error('Search failed:', error.message);
    return [];
  }
};

export const getTVDetails = async (id) => {
  try {
    const { data } = await client.get(`/tv/${id}`);
    const $ = cheerio.load(data);
    const seasons = [];

    // Modern TMDB uses .season.card or similar structures
    $('.season.card, .comp\\:media-card, .season').each((i, el) => {
      const title = $(el).find('h2, h3').first().text().trim();
      if (title.toLowerCase().includes('season')) {
        const numMatch = title.match(/Season (\d+)/i);
        const num = numMatch ? parseInt(numMatch[1]) : seasons.length + 1;
        seasons.push({ title, number: num });
      }
    });

    if (seasons.length === 0) {
       seasons.push({ title: 'Season 1', number: 1 });
    }

    return seasons;
  } catch (error) {
    console.error('Fetch seasons failed:', error.message);
    return [{ title: 'Season 1', number: 1 }];
  }
};

export const getEpisodes = async (tvId, seasonNum) => {
  try {
    const { data } = await client.get(`/tv/${tvId}/season/${seasonNum}`);
    const $ = cheerio.load(data);
    const episodes = [];

    // Modern TMDB layout for episodes
    $('.episode_list .card, .episode_list .episode, .episode').each((i, el) => {
      const title = $(el).find('.episode_title h3, h3, h2').first().text().trim();
      const numElement = $(el).find('.episode_number').first();
      const number = parseInt(numElement.text().trim()) || (i + 1);
      
      if (title && !episodes.some(e => e.number === number)) {
        episodes.push({ title: `Episode ${number}: ${title}`, number: number });
      }
    });

    // Fallback if primary selector fails
    if (episodes.length === 0) {
      $('.episode_number').each((i, el) => {
        const container = $(el).closest('.info, .content, div');
        const title = container.find('h3, h2').first().text().trim();
        if (title) {
          episodes.push({ title: `Episode ${i+1}: ${title}`, number: i+1 });
        }
      });
    }

    return episodes;
  } catch (error) {
    console.error('Fetch episodes failed:', error.message);
    return [];
  }
};

export const getEmbedLink = (type, id, season = 1, episode = 1) => {
  const isMovie = type.toLowerCase() === 'movie';
  
  return {
    vidsrc: isMovie 
      ? `https://vidsrc.to/embed/movie/${id}` 
      : `https://vidsrc.to/embed/tv/${id}/${season}/${episode}`,
    vidsrc_xyz: isMovie 
      ? `https://vidsrc.xyz/embed/movie?tmdb=${id}` 
      : `https://vidsrc.xyz/embed/tv?tmdb=${id}&season=${season}&episode=${episode}`,
    multiembed: isMovie 
      ? `https://multiembed.mov/directstream.php?video_id=${id}&tmdb=1` 
      : `https://multiembed.mov/directstream.php?video_id=${id}&tmdb=1&s=${season}&e=${episode}`,
    vsembed: isMovie
      ? `https://vsembed.su/embed/movie/${id}`
      : `https://vsembed.su/embed/tv/${id}/${season}-${episode}`
  };
};

export const getVLCPath = () => {
  const commonPaths = [
    'C:\\Program Files\\VideoLAN\\VLC\\vlc.exe',
    'C:\\Program Files (x86)\\VideoLAN\\VLC\\vlc.exe'
  ];

  for (const path of commonPaths) {
    if (fs.existsSync(path)) return path;
  }
  
  if (process.platform === 'android') return 'termux-open';
  return null;
};

export const getBravePath = () => {
  const commonPaths = [
    'C:\\Program Files\\BraveSoftware\\Brave-Browser\\Application\\brave.exe',
    'C:\\Program Files (x86)\\BraveSoftware\\Brave-Browser\\Application\\brave.exe',
    process.env.LOCALAPPDATA + '\\BraveSoftware\\Brave-Browser\\Application\\brave.exe'
  ];

  for (const path of commonPaths) {
    if (fs.existsSync(path)) return path;
  }

  if (process.platform === 'android') return 'termux-open';
  return null;
};
