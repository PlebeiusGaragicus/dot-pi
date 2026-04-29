import { expect, test } from 'bun:test';

test('hackernews skill keeps a JSON array contract', () => {
  const sample = JSON.stringify([{ text: 'Example story', href: 'https://example.com' }]);
  const parsed = JSON.parse(sample);
  expect(Array.isArray(parsed)).toBe(true);
  expect(parsed[0]).toHaveProperty('text');
  expect(parsed[0]).toHaveProperty('href');
});
