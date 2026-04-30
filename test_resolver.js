import { resolveStream } from './resolver.js';
import chalk from 'chalk';

async function testResolver() {
  const testUrl = 'https://vsembed.su/embed/movie/27205'; // Inception
  console.log(chalk.cyan(`Testing resolver with URL: ${testUrl}`));
  
  try {
    const streamUrl = await resolveStream(testUrl);
    console.log(chalk.green('\nSUCCESS! Captured stream URL:'));
    console.log(chalk.white(streamUrl));
    
    if (streamUrl.includes('.m3u8')) {
      console.log(chalk.green('✓ Verified: Captured link is a valid HLS stream (.m3u8)'));
    } else {
      console.log(chalk.yellow('! Warning: Captured link might not be a standard HLS stream.'));
    }
  } catch (error) {
    console.error(chalk.red('\nExtraction failed:'), error.message);
  }
}

testResolver();
