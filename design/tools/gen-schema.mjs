#!/usr/bin/env node
// Butlery · genererar fas0/verify-report.schema.json ur REPORT_SCHEMA i
// report-logic.mjs. EN källa — schemafilen och validatorn kan inte glida isär.
import { writeFileSync } from 'node:fs';
import { REPORT_SCHEMA } from './report-logic.mjs';
writeFileSync('fas0/verify-report.schema.json', JSON.stringify(REPORT_SCHEMA, null, 2) + '\n');
console.log('✔ fas0/verify-report.schema.json genererad ur REPORT_SCHEMA (' + REPORT_SCHEMA.$id + ')');
