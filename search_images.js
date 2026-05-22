const fs = require('fs');
const path = require('path');

function searchMdFiles(dir) {
  let results = [];
  try {
    const list = fs.readdirSync(dir);
    for (const file of list) {
      const fullPath = path.join(dir, file);
      const stat = fs.statSync(fullPath);
      if (stat.isDirectory()) {
        if (!file.startsWith('.') && file !== 'node_modules') {
          results = results.concat(searchMdFiles(fullPath));
        }
      } else if (file.endsWith('.md')) {
        results.push(fullPath);
      }
    }
  } catch (e) {}
  return results;
}

const mdFiles = searchMdFiles("c:\\\\Users\\\\Anton\\\\agreeo");
mdFiles.push("C:\\\\Users\\\\Anton\\\\.gemini\\\\antigravity\\\\brain\\\\8e0b61a7-747c-44b7-a68f-fa4b10e57fc8\\\\walkthrough.md");
mdFiles.push("C:\\\\Users\\\\Anton\\\\.gemini\\\\antigravity\\\\brain\\\\8e0b61a7-747c-44b7-a68f-fa4b10e57fc8\\\\design.md");

for (const file of mdFiles) {
  try {
    const content = fs.readFileSync(file, 'utf8');
    const matches = content.match(/!\[.*?\]\(.*?\)/g);
    if (matches) {
      console.log(`File: ${file}`);
      for (const match of matches) {
        console.log(`  ${match}`);
      }
    }
  } catch (e) {}
}
