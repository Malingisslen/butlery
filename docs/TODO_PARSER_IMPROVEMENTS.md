# Recipe Parser Improvements

## Status: Pending (Low Priority)

## Issue
The recipe import parsers (URL and photo/OCR) are not extracting recipe data reliably. This is a larger fix that requires significant work.

## Affected Components
- Site-specific parsers: ICA.se, Arla.se, Köket.se, Recept.se
- OCR extraction service for photo imports
- Generic URL parser fallback

## Symptoms
- Incomplete ingredient extraction
- Missing or incorrect instructions
- Portions/time not always detected
- Photo OCR accuracy issues

## Suggested Improvements
1. Review and update site-specific CSS selectors for each parser
2. Improve OCR text post-processing
3. Add better fallback parsing logic
4. Consider using AI-assisted extraction for better accuracy

## Priority
Address after all small bugs are fixed during testing phase.

## Created
2025-11-28 during Journey 2 testing
