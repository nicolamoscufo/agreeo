const path = require('path');
const artifactDir = "C:\\Users\\Anton\\.gemini\\antigravity\\brain\\8e0b61a7-747c-44b7-a68f-fa4b10e57fc8";
const p = "/Users/Anton/.gemini/antigravity/brain/8e0b61a7-747c-44b7-a68f-fa4b10e57fc8/agreeo_app_logo_1779385049109.png";
const resolved = path.resolve(p);
console.log("Resolved:     ", resolved);
console.log("ArtifactDir:  ", artifactDir);
console.log("Starts with:  ", resolved.startsWith(artifactDir));
console.log("Lower starts: ", resolved.toLowerCase().startsWith(artifactDir.toLowerCase()));
