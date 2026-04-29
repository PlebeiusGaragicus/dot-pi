import { browse } from './_lib/browse-client';

await browse.goto('https://news.ycombinator.com');
const links = JSON.parse(await browse.links()) as Array<{ text: string; href: string }>;
const stories = links
  .filter(link => link.href.includes('item?id=') === false)
  .filter(link => link.text && !['new', 'past', 'comments', 'ask', 'show', 'jobs', 'submit'].includes(link.text.toLowerCase()))
  .slice(0, 30);

process.stdout.write(JSON.stringify(stories, null, 2));
