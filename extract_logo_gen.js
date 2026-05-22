const fs = require('fs');
const readline = require('readline');

const logPath = "C:\\\\Users\\\\Anton\\\\.gemini\\\\antigravity\\\\brain\\\\8e0b61a7-747c-44b7-a68f-fa4b10e57fc8\\\\.system_generated\\\\logs\\\\transcript.jsonl";

const rl = readline.createInterface({
  input: fs.createReadStream(logPath, { encoding: 'utf8' }),
  crlfDelay: Infinity
});

rl.on('line', (line) => {
  try {
    const data = JSON.parse(line);
    if (line.includes("generate_image")) {
      console.log(`Step ${data.step_index}: generate_image call`);
      console.log(JSON.stringify(data.tool_calls));
      console.log("=".repeat(50));
    }
  } catch (e) {
  }
});
