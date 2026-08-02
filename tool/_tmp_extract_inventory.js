const fs = require('fs');
const p =
  'C:/Users/Precision 7520/.cursor/projects/d-flutter-projects-rafiq-academy/agent-transcripts/88516ff0-0b39-4aae-8472-31a3181e1114/88516ff0-0b39-4aae-8472-31a3181e1114.jsonl';
const lines = fs.readFileSync(p, 'utf8').split('\n');
const j = JSON.parse(lines[940]);
const t = j.message.content[0].text;
const markers = ['Teacher', 'المعلم', '## 2', '## 3', 'screen'];
for (const m of markers) {
  const i = t.indexOf(m);
  console.log('---', m, i);
}
const i = t.indexOf('**المعلم**');
const j2 = t.indexOf('**ولي');
console.log(t.slice(i >= 0 ? i : 0, j2 > i ? j2 + 200 : 9000));
