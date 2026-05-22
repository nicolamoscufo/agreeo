const path = require('path');

const artifactDir = "C:\\Users\\Anton\\.gemini\\antigravity\\brain\\8e0b61a7-747c-44b7-a68f-fa4b10e57fc8";

const testPaths = [
  "/Users/Anton/.gemini/antigravity/brain/8e0b61a7-747c-44b7-a68f-fa4b10e57fc8/agreeo_app_logo_1779385049109.png",
  "/C:/Users/Anton/.gemini/antigravity/brain/8e0b61a7-747c-44b7-a68f-fa4b10e57fc8/agreeo_app_logo_1779385049109.png"
];

for (const p of testPaths) {
  const resolved = path.resolve(p);
  const startsWith = resolved.toLowerCase().startsWith(artifactDir.toLowerCase());
  console.log(`Path: ${p}`);
  console.log(`  Resolved: ${resolved}`);
  console.log(`  Starts with artifactDir (case-insensitive): ${startsWith}`);
}
