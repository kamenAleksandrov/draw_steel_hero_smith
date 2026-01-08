#!/usr/bin/env node
/**
 * Simplify complications.json to only:
 * id, type, name, description (story text only), effects { benefit, drawback, both }
 * Behavior:
 * - Parse original description looking for labels:
 *   'Benefit and Drawback:' => effects.both
 *   'Benefit:' => benefit text until 'Drawback:' or end
 *   'Drawback:' => drawback text until end
 * - description becomes everything BEFORE the first encountered label (trimmed)
 * - If no labels present, keep full description as description and omit effects
 */
const fs = require('fs');
const path = require('path');

const FILE = path.join(__dirname, '..', 'data', 'story', 'complications.json');

function split(description){
  if(!description) return { story: null, effects: null };
  const bothIdx = description.indexOf('Benefit and Drawback:');
  if(bothIdx !== -1){
    const story = description.slice(0, bothIdx).trim() || null;
    const both = description.slice(bothIdx + 'Benefit and Drawback:'.length).trim() || null;
    return { story, effects: { benefit: null, drawback: null, both } };
  }
  const benefitIdx = description.indexOf('Benefit:');
  const drawbackIdx = description.indexOf('Drawback:');
  if(benefitIdx === -1 && drawbackIdx === -1){
    return { story: description.trim() || null, effects: null };
  }
  let storyEnd = Math.min(
    benefitIdx === -1 ? Infinity : benefitIdx,
    drawbackIdx === -1 ? Infinity : drawbackIdx
  );
  if(!isFinite(storyEnd)) storyEnd = 0; // one label appears first
  const story = description.slice(0, storyEnd).trim() || null;
  let benefit = null, drawback = null;
  if(benefitIdx !== -1){
    const start = benefitIdx + 'Benefit:'.length;
    const end = drawbackIdx !== -1 ? drawbackIdx : description.length;
    benefit = description.slice(start, end).trim() || null;
  }
  if(drawbackIdx !== -1){
    const start = drawbackIdx + 'Drawback:'.length;
    drawback = description.slice(start).trim() || null;
  }
  if(!benefit && !drawback){
    return { story: story || description.trim() || null, effects: null };
  }
  return { story, effects: { benefit, drawback, both: null } };
}

function simplify(entry){
  const { story, effects } = split(entry.description || '');
  const out = {
    id: entry.id,
    type: 'complication',
    name: entry.name,
    description: story
  };
  if(effects) out.effects = effects;
  return out;
}

function main(){
  if(!fs.existsSync(FILE)){
    console.error('complications.json not found');
    process.exit(1);
  }
  const data = JSON.parse(fs.readFileSync(FILE,'utf-8'));
  if(!Array.isArray(data)){
    console.error('Expected array root');
    process.exit(1);
  }
  const simplified = data.map(simplify);
  fs.writeFileSync(FILE, JSON.stringify(simplified, null, 2));
  console.log('Simplified complications:', simplified.length);
}

if(require.main === module){
  main();
}

module.exports = { split, simplify };
