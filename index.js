#!/usr/bin/env node
import { search, getTVDetails, getEpisodes, getEmbedLink, getVLCPath, getBravePath } from './scraper.js';
import { resolveStream } from './resolver.js';
import { spawn } from 'child_process';
import enquirer from 'enquirer';
import chalk from 'chalk';
import ora from 'ora';
import open from 'open';
import gradient from 'gradient-string';

const { AutoComplete, Input, Select } = enquirer;

const logo = `
 ███▄ ▄███▓ ▒█████   ██▒   █▓ ███▄    █  ▒█████  ▓█████▄ ▓█████ 
▓██▒▀█▀ ██▒▒██▒  ██▒▓██░   █▒ ██ ▀█   █ ▒██▒  ██▒▒██▀ ██▌▓█   ▀ 
▓██    ▓██░▒██░  ██▒ ▓██  █▒░▓██  ▀█ ██▒▒██░  ██▒░██   █▌▒███   
▒██    ▒██ ▒██   ██░  ▒██ █░░▓██▒  ▐▌██▒▒██   ██░░▓█▄   ▌▒▓█  ▄ 
▒██▒   ░██▒░ ████▓▒░   ▒▀█░  ▒██░   ▓██░░ ████▓▒░░▒████▓ ░▒████▒
░ ▒░   ░  ░░ ▒░▒░▒░    ░ ▐░  ░ ▒░   ▒ ▒ ░ ▒░▒░▒░ ░▒▒▓  ▒ ░░ ▒░ ░
░  ░      ░  ░ ▒ ▒░    ░ ░░  ░ ░░   ░ ▒░  ░ ▒ ▒░  ░ ▒  ▒  ░ ░  ░
░      ░   ░ ░ ░ ▒       ░░     ░   ░ ░ ░ ░ ░ ▒   ░ ░  ░    ░   
       ░       ░ ░        ░           ░       ░ ░     ░       ░  ░
                         ░                          ░             
`;

const showLogo = () => {
  console.clear();
  console.log(gradient.pastel.multiline(logo));
  console.log(chalk.bold.cyan('  Your Personal Movies & Series CLI Scraper (TMDB + VidSrc)\n'));
};

const openInBrave = async (url) => {
  const bravePath = getBravePath();
  if (bravePath) {
    // Using spawn to directly launch Brave is more reliable on Windows
    try {
      spawn(bravePath, [url], { detached: true, stdio: 'ignore' }).unref();
    } catch (err) {
      await open(url);
    }
  } else {
    await open(url);
  }
};

const run = async () => {
  showLogo();

  const cliQuery = process.argv.slice(2).join(' ');
  let query = cliQuery;

  if (!query) {
    const searchInput = new Input({
      message: 'What are you looking for?',
      initial: 'Inception'
    });
    query = await searchInput.run();
  } else {
    console.log(chalk.cyan(`  Searching for: ${chalk.bold(query)}`));
  }

  const spinner = ora('Searching TMDB...').start();
  const results = await search(query);
  spinner.stop();

  if (results.length === 0) {
    console.log(chalk.red('  No results found. Try again with a different name.'));
    return;
  }

  const resultSelector = new AutoComplete({
    name: 'showIndex',
    message: 'Select a result:',
    choices: results.map((r, i) => ({ 
      name: i.toString(), 
      message: `${r.title} (${r.type}) [${r.releaseDate}]` 
    }))
  });

  const selectedIndex = await resultSelector.run();
  const show = results[parseInt(selectedIndex)];

  if (!show) {
    console.log(chalk.red('  Error: Could not retrieve info for the selected item.'));
    return;
  }

  let finalArgs = { type: show.type, id: show.id, season: 1, episode: 1 };

  if (show.type === 'TV Series') {
    spinner.text = 'Fetching Season details...';
    spinner.start();
    const seasons = await getTVDetails(show.id);
    spinner.stop();

    const seasonSelector = new Select({
      name: 'season',
      message: 'Select Season:',
      choices: seasons.map(s => s.title)
    });

    const selectedSeasonName = await seasonSelector.run();
    const selectedSeason = seasons.find(s => s.title === selectedSeasonName);
    finalArgs.season = selectedSeason.number;

    spinner.text = 'Fetching Episode list...';
    spinner.start();
    const episodes = await getEpisodes(show.id, finalArgs.season);
    spinner.stop();

    if (episodes.length === 0) {
      console.log(chalk.red('  No episodes found for this season.'));
      return;
    }

    const episodeSelector = new AutoComplete({
      name: 'episode',
      message: 'Select Episode:',
      choices: episodes.map(e => e.title)
    });

    const selectedEpName = await episodeSelector.run();
    const selectedEp = episodes.find(e => e.title === selectedEpName);
    finalArgs.episode = selectedEp.number;
  }

  spinner.text = 'Preparing playback sources...';
  spinner.start();
  const sources = getEmbedLink(finalArgs.type, finalArgs.id, finalArgs.season, finalArgs.episode);
  spinner.stop();

  const sourceSelector = new Select({
    name: 'source',
    message: 'Select Playback Source:',
    choices: [
      { name: 'Direct Play (VLC / Ad-Free) 🚀', value: 'vlc' },
      { name: 'VidSrc (Default)', value: sources.vidsrc },
      { name: 'VidSrc.xyz (Mirror)', value: sources.vidsrc_xyz },
      { name: 'VsEmbed (vsembed.su)', value: sources.vsembed },
      { name: 'MultiEmbed (Alternative)', value: sources.multiembed }
    ]
  });

  const selectedSourceLabel = await sourceSelector.run();
  
  if (selectedSourceLabel.includes('Direct Play')) {
    spinner.text = 'Extracting direct video link (this may take 15-20s)...';
    spinner.start();
    try {
      // Use vsembed as it's the one the user manually selected and it worked
      const directLink = await resolveStream(sources.vsembed);
      spinner.stop();

      console.log(chalk.green.bold('\n  SUCCESS! Stream link captured.'));
      console.log(chalk.gray(`  Link: ${directLink}`));

      const vlcPath = getVLCPath();
      if (vlcPath) {
        console.log(chalk.cyan('  Launching VLC media player...'));
        spawn(vlcPath, [directLink], { detached: true, stdio: 'ignore' }).unref();
      } else {
        console.log(chalk.yellow('\n  VLC not found. Please copy the link above and paste it into VLC (Open Network Stream).'));
      }
    } catch (error) {
      spinner.stop();
      console.error(chalk.red('\n  Extraction failed:'), error.message);
      console.log(chalk.yellow('  Falling back to browser-based playback...'));
      await open(sources.vidsrc);
    }
    return;
  }

  const options = [
    { name: 'VidSrc (Default)', value: sources.vidsrc },
    { name: 'VidSrc.xyz (Mirror)', value: sources.vidsrc_xyz },
    { name: 'VsEmbed (vsembed.su)', value: sources.vsembed },
    { name: 'MultiEmbed (Alternative)', value: sources.multiembed }
  ];
  const selectedUrl = options.find(o => o.name === selectedSourceLabel).value;

  console.log(chalk.green.bold('\n  SUCCESS! Opening player in your browser (Brave)...'));
  console.log(chalk.gray(`  Link: ${selectedUrl}`));
  await openInBrave(selectedUrl);
};

run().catch(err => {
  if (err === '' || err?.name === 'Error' && err?.message?.includes('cancelled')) return;
  console.error(chalk.red('\n  An error occurred:'), err);
});
