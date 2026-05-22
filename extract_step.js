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
    if (data.step_index >= 4382 && data.step_index <= 4390) {
      console.log(`Step ${data.step_index}: Type: ${data.type}, Source: ${data.source}, Status: ${data.status}`);
      if (data.tool_calls) {
        console.log("Tool Calls:", JSON.stringify(data.tool_calls, null, 2));
      }
      if (data.content) {
        console.log("Content:", data.content.substring(0, 500));
      }
      console.log("=".repeat(50));
    }
  } catch (e) {
  }
});
