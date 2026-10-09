#!/usr/bin/env node
// Butlery · BEVIS PÅ ATT EN KEDJEKÖRNING FULLFÖLJDES.
// Kör: node tools/run-complete.mjs --log=<rålogg> [--not-runid=<id>] [--exit=<kod>]
//
// F1-U13: workflowens andra körning stod bakom ett obevakat `|| true`. En
// krasch innan rapporten skrivits svaldes då tyst: generatorhasharna var
// oförändrade (ingenting hann skrivas), REPRO-SUMMARY blev grön, och grinden
// läste den GAMLA finaliserade rapporten. Exit 0 på en körning som aldrig
// hände.
//
// Exitkoden ensam duger inte som bevis: den kända innehållsbaslinjen ger
// avsiktligt 1. Fullföljd bevisas i stället maskinellt — kedjan måste ha
// skrivit sina egna slutmarkörer:
//
//   1 fas0/verify-exit finns och innehåller en heltalsexitkod
//   2 råloggen bär SELFTEST-SUMMARY
//   3 råloggen bär METATEST-SUMMARY
//   4 råloggen bär kedjans sista rad (SLUTLIG EXIT)
//   5 fas0/verify-report.json går att tolka och bär ett runId
//   6 runId skiljer sig från den föregående körningens (--not-runid)
//   7 rapportens exitkod stämmer med fas0/verify-exit
//   8 kedjans exitkod ligger inom det tillåtna (0 eller 1) om --exit anges
import { readFileSync, existsSync } from 'node:fs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const LOG = arg('log');
const NOT_RUNID = arg('not-runid');
const EXIT = arg('exit');
if (!LOG) { console.error('✖ ange --log=<rålogg>'); process.exit(2); }

const problems = [];
const need = (ok, why) => { if (!ok) problems.push(why); };

// 1 · exitmarkören
let verifyExit = null;
if (!existsSync('fas0/verify-exit')) problems.push('fas0/verify-exit saknas — kedjan skrev aldrig sin exitmarkör');
else {
  const raw = readFileSync('fas0/verify-exit', 'utf8').trim();
  if (!/^\d+$/.test(raw)) problems.push('fas0/verify-exit innehåller "' + raw + '", ingen heltalsexitkod');
  else verifyExit = Number(raw);
}

// 2–4 · råloggens slutmarkörer
if (!existsSync(LOG)) problems.push('råloggen ' + LOG + ' finns inte');
else {
  const log = readFileSync(LOG, 'utf8');
  need(/^SELFTEST-SUMMARY /m.test(log), 'råloggen saknar SELFTEST-SUMMARY — körningen nådde aldrig selftest eller stympades');
  need(/^METATEST-SUMMARY /m.test(log), 'råloggen saknar METATEST-SUMMARY — körningen nådde aldrig metatest eller stympades');
  need(/SLUTLIG EXIT/.test(log), 'råloggen saknar kedjans slutrad (SLUTLIG EXIT)');
}

// 5–7 · rapporten
let report = null;
if (!existsSync('fas0/verify-report.json')) problems.push('fas0/verify-report.json saknas');
else {
  try { report = JSON.parse(readFileSync('fas0/verify-report.json', 'utf8')); }
  catch (e) { problems.push('fas0/verify-report.json går inte att tolka: ' + e.message); }
}
if (report) {
  need(/^[0-9a-f]{16}$/.test(String(report.runId || '')), 'rapporten saknar ett giltigt runId');
  if (NOT_RUNID && String(report.runId) === NOT_RUNID)
    problems.push('rapportens runId är oförändrat (' + NOT_RUNID + ') — den här körningen skrev ingen ny rapport');
  if (verifyExit !== null && report.finalExitCode !== undefined && Number(report.finalExitCode) !== verifyExit)
    problems.push('rapportens finalExitCode ' + report.finalExitCode + ' ≠ fas0/verify-exit ' + verifyExit);
}

// 8 · tillåten exitkod
if (EXIT !== undefined && EXIT !== '') {
  const code = Number(EXIT);
  if (!Number.isInteger(code) || code < 0 || code > 1)
    problems.push('kedjan avslutades med ' + EXIT + ' — bara 0 eller 1 är väntat (1 = den kända röda innehållsbaslinjen)');
}

for (const p of problems) console.error('✖ ' + p);
console.log('RUN-COMPLETE runId=' + (report ? report.runId : 'saknas') +
  ' verifyExit=' + verifyExit + ' chainExit=' + (EXIT === undefined ? 'ej angiven' : EXIT) +
  ' problems=' + problems.length);
if (problems.length) process.exitCode = 1;
else console.log('✔ körningen fullföljdes — rapport, exitmarkör och båda testsummeringarna finns');
