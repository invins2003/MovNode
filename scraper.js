import axios from 'axios';
import fs from 'fs';

const API_KEY = 'd131017ccc6e5462a81c9304d21476de';
const API_BASE = 'https://api.themoviedb.org/3';

const client = axios.create({
  baseURL: API_BASE,
  timeout: 10000,
});

export const search = async (query) => {
  try {
    const { data } = await client.get(`/search/multi`, {
      params: { api_key: API_KEY, query }
    });
    
    return (data.results || [])
      .filter(item => item.media_type === 'movie' || item.media_type === 'tv')
      .map(item => ({
        title: item.title || item.name,
        type: item.media_type === 'movie' ? 'Movie' : 'TV Series',
        id: item.id.toString(),
        releaseDate: item.release_date || item.first_air_date || 'N/A'
      }));
  } catch (error) {
    console.error('Search failed:', error.message);
    return [];
  }
};

export const getTVDetails = async (id) => {
  try {
    const { data } = await client.get(`/tv/${id}`, {
      params: { api_key: API_KEY }
    });
    
    return (data.seasons || [])
      .filter(s => s.season_number > 0)
      .map(s => ({
        title: s.name || `Season ${s.season_number}`,
        number: s.season_number
      }));
  } catch (error) {
    console.error('Fetch seasons failed:', error.message);
    return [{ title: 'Season 1', number: 1 }];
  }
};

export const getEpisodes = async (tvId, seasonNum) => {
  try {
    const { data } = await client.get(`/tv/${tvId}/season/${seasonNum}`, {
      params: { api_key: API_KEY }
    });
    
    return (data.episodes || []).map(ep => ({
      title: `Episode ${ep.episode_number}: ${ep.name}`,
      number: ep.episode_number
    }));
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
