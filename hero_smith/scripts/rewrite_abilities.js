#!/usr/bin/env node
/**
 * Rewrites abilities.json entries (except the already-updated first one) into unified structured format.
 * Rules per user specification:
 * - costs: single object { resource, amount }. If legacy cost is "All your Heroic Resource" -> { resource:"heroic_resource", amount:"all" }. Null cost -> { resource:null, amount:null }.
 * - range: { distance: string | string[] | null, area: string | null } mutually exclusive. If area keywords (burst|cube) present -> area set and distance null. Mixed melee/ranged like "Melee 1 or ranged 10" -> distance array ["Melee 1","Ranged 10"].
 * - description -> story_text. Keep story_text if present.
 * - power_roll: omit entirely if original has null/none.
 *   structure: {
 *     label: "Power roll",
 *     characteristics: [list],
 *     tiers: { low:{...}, mid:{...}, high:{...} }
 *   }
 *   Characteristic options parsed from string after "Power Roll +" splitting on commas and "or". Map abbreviations M,A,R,I,P to full names.
 * - Tiers built from roll_result_low/mid/high or (if absent) from structured power_roll.roll_results
 * - Tier parsing: primary damage expression expected first if present in form "<number> + <char options> damage" (optionally with type). Do not parse if pattern not logical.
 * - Conditions list recognized: Bleeding, Dazed, Frightened, Grabbed, Prone, Restrained, Slowed, Taunted, Weakened (case-insensitive).
 * - Potency tokens: pattern /([MARIP])<([WAS])/ retained in rawPotencies array; not split semantically for now (user unsure). Associate token with following condition if present.
 * - Damage types kept inside damage_expression; detection list for validation only: untyped, acid, cold, corruption, fire, holy, lightning, poison, psychic, sonic.
 * - Secondary descriptive text after semicolon(s) retained in descriptive_text; movement/other effects kept there too (not split further except conditions & potency tokens).
 */
const fs = require('fs');
const path = require('path');

const FILE = path.join(__dirname, '..', 'data', 'abilities', 'abilities.json');

const CHAR_MAP = { M: 'Might', A: 'Agility', R: 'Reason', I: 'Intuition', P: 'Presence' };
const CONDITIONS = ['bleeding','dazed','frightened','grabbed','prone','restrained','slowed','taunted','weakened'];
const POTENCY_RE = /([MARIP])<([WAS])/g; // e.g. A<w
const DAMAGE_LINE_RE = /^\s*(\d+)\s*\+\s*([^;]+?)\s*damage\b/i; // captures base and the characteristic segment

function normalizeCost(cost){
  if(!cost) return { resource: null, amount: null };
  const c = cost.trim().toLowerCase();
  if(c === 'all your heroic resource') return { resource: 'heroic_resource', amount: 'all' };
  return { resource: 'raw', amount: cost }; // fallback
}

function parseCharacteristics(str){
  if(!str) return [];
  const m = str.match(/power roll \+(.+)/i);
  if(!m) return [];
  let seg = m[1];
  seg = seg.replace(/\bor\b/gi, ',');
  return seg.split(/[,/]/).map(s=>s.trim())
    .filter(Boolean)
    .map(s=>{
      const ab = s[0];
      if(CHAR_MAP[ab] && (s.length===1 || /\b(Might|Agility|Reason|Intuition|Presence)\b/i.test(s))) return CHAR_MAP[ab];
      // full names
      const cap = s.charAt(0).toUpperCase()+s.slice(1).toLowerCase();
      return cap;
    })
    .filter((v,i,a)=>a.indexOf(v)===i);
}

function buildRange(entry){
  const raw = entry.range || entry.distance || '';
  if(!raw) return { distance: null, area: null };
  const lower = raw.toLowerCase();
  if(/\b(burst|cube)\b/.test(lower)){
    // attempt to split pattern like "3 cube within 1"
    const m = raw.match(/^(\d+\s+cube)/i);
    if(m){
      const rest = raw.slice(m[0].length).trim();
      return { distance: rest || null, area: m[1] };
    }
    return { distance: null, area: raw };
  }
  if(/melee\s+\d+\s+or\s+ranged\s+\d+/i.test(lower)){
    const parts = raw.split(/or/i).map(s=>s.trim()).filter(Boolean);
    return { distance: parts, area: null };
  }
  return { distance: raw, area: null };
}

function extractTier(rawEffect){
  if(rawEffect==null) return null;
  let text = rawEffect; // already a string like "3 + M or A damage; you can shift 1 square"
  const all_text = text;
  let damage_expression = null;
  let base_damage_value = null;
  let characteristic_damage_options = [];
  const m = text.match(DAMAGE_LINE_RE);
  if(m){
    base_damage_value = parseInt(m[1],10);
    damage_expression = m[0].trim();
    // parse characteristic part for options
    const optSeg = m[2];
    const optParts = optSeg.split(/\bor\b/i).map(s=>s.replace(/[,+]/g,'').trim());
    characteristic_damage_options = optParts.map(p=>p.split(/\s+/)[0]).map(ab=>CHAR_MAP[ab]||ab).filter((v,i,a)=>a.indexOf(v)===i);
  }
  // Remove damage_expression from remaining to derive descriptive_text
  let descriptive_text = null;
  if(damage_expression){
    descriptive_text = text.replace(damage_expression,'').replace(/^\s*;?/,'').trim() || null;
  }
  // Potencies and conditions extraction from either part
  const rawPotencies = [];
  let potMatch;
  while((potMatch = POTENCY_RE.exec(all_text))){
    rawPotencies.push(potMatch[0]);
  }
  const conditions = CONDITIONS.filter(c=>new RegExp(`\\b${c}\\b`,'i').test(all_text));
  const potencies = rawPotencies.map(tok=>({ raw: tok, condition: conditions.find(c=>new RegExp(c,'i').test(all_text))||null }));
  return {
    damage_expression,
    base_damage_value,
    characteristic_damage_options,
    damage_types: null, // kept inside expression; not separating per user decision
    secondary_damage_expression: null, // not splitting further per clarified rules
    descriptive_text,
    potencies,
    conditions,
    all_text
  };
}

function buildPowerRoll(entry){
  // Two possible legacy formats: string power_roll + roll_result_* OR structured power_roll object (first test entry)
  if(entry.power_roll == null) return null;
  if(typeof entry.power_roll === 'object' && entry.power_roll.roll_results){
    const pr = entry.power_roll;
    // characteristics_score e.g. string listing? We convert to characteristics array from that string plus maybe parse.
    const characteristics = pr.characteristics_score ? pr.characteristics_score.split(/\s*,\s*|\s+or\s+/i).map(s=>s.trim()).filter(Boolean) : [];
    const tiers = {};
    if(pr.roll_results.low){ tiers.low = extractTier(pr.roll_results.low.descriptive_text || pr.roll_results.low.damage || null); }
    if(pr.roll_results.mid){ tiers.mid = extractTier(pr.roll_results.mid.descriptive_text || pr.roll_results.mid.damage || null); }
    if(pr.roll_results.high){ tiers.high = extractTier(pr.roll_results.high.descriptive_text || pr.roll_results.high.damage || null); }
    return { label: 'Power roll', characteristics, tiers };
  }
  if(typeof entry.power_roll === 'string'){
    const characteristics = parseCharacteristics(entry.power_roll);
    const tiers = {};
    if(entry.roll_result_low) tiers.low = extractTier(entry.roll_result_low.effect);
    if(entry.roll_result_mid) tiers.mid = extractTier(entry.roll_result_mid.effect);
    if(entry.roll_result_high) tiers.high = extractTier(entry.roll_result_high.effect);
    // Remove empty tiers
    Object.keys(tiers).forEach(k=>{ if(!tiers[k]) delete tiers[k]; });
    if(Object.keys(tiers).length===0) return null;
    return { label: 'Power roll', characteristics, tiers };
  }
  return null;
}

function rewriteAbility(entry, isFirst){
  // First entry may already match; still normalize
  const costs = normalizeCost(entry.cost || (entry.costs && entry.costs.amount ? entry.costs : null));
  const range = buildRange(entry);
  const power_roll = buildPowerRoll(entry);
  const out = {
    id: entry.id,
    name: entry.name,
    costs,
    story_text: entry.story_text || entry.description || null,
    keywords: entry.keywords || [],
    type: entry.action_type || entry.type || null,
    range,
    targets: entry.targets || null,
    power_roll: power_roll || undefined,
    effect: entry.effect ?? null,
    special_effect: entry.special_effect ?? null
  };
  if(!out.power_roll) delete out.power_roll; // omit
  return out;
}

function main(){
  if(!fs.existsSync(FILE)){
    console.error('abilities.json not found');
    process.exit(1);
  }
  const data = JSON.parse(fs.readFileSync(FILE,'utf-8'));
  if(!Array.isArray(data)){
    console.error('abilities.json root must be array');
    process.exit(1);
  }
  const rewritten = data.map((a,i)=>rewriteAbility(a,i===0));
  fs.writeFileSync(FILE, JSON.stringify(rewritten, null, 2));
  console.log('Rewrote abilities:', rewritten.length);
}

if(require.main === module){
  main();
}

module.exports = { rewriteAbility, buildPowerRoll, extractTier };
